#!/usr/bin/env python3
from __future__ import annotations

import re
import json
from pathlib import Path

from models import Draft, LeadItem, QueueFile, RawLead, dedupe, lead_to_dict, now_iso


URGENCY_TERMS = ("asap", "urgent", "deadline", "this week", "today", "friday", "launch")
COMMERCIAL_TERMS = ("client", "production", "testflight", "paying", "expensive", "alternative")
QUESTION_TERMS = ("how", "what", "any", "need", "should", "?")
COMPLAINT_TERMS = ("painful", "failing", "broken", "expensive", "fighting", "stuck", "issue", "error")
PLATFORM_RISK = {
    "reddit": "medium",
    "x": "medium",
    "twitter": "medium",
    "hackernews": "low",
    "github": "low",
    "rss": "low",
    "web": "low",
    "youtube": "high",
    "linkedin": "high",
}


def load_queries(path: Path) -> dict[str, list[str]]:
    return json.loads(path.read_text(encoding="utf-8"))


def build_lead_items(raw_items: list[RawLead], queries: dict[str, list[str]]) -> list[LeadItem]:
    created_on = now_iso()[0:10].replace("-", "_")
    items = [build_one_lead(raw, index, created_on, queries) for index, raw in enumerate(raw_items, start=1)]
    return sorted(items, key=lambda item: item.fit_score, reverse=True)


def build_one_lead(raw: RawLead, index: int, created_on: str, queries: dict[str, list[str]]) -> LeadItem:
    text = normalize_text(raw)
    matches = find_query_matches(text, queries)
    tags = classify_tags(text, matches)
    score = score_lead(raw.platform, text, matches, tags, queries)
    risk = PLATFORM_RISK.get(raw.platform.lower(), "medium")
    mode = recommended_mode(score, risk)
    summary = summarize(" ".join(part for part in (raw.title, raw.text) if part))
    return LeadItem(
        id=f"lead_{created_on}_{index:03d}",
        platform=raw.platform,
        source_type=raw.source_type,
        url=raw.url,
        author=raw.author,
        captured_at=raw.captured_at,
        query_matches=tuple(matches),
        summary=summary,
        tags=tuple(tags),
        fit_score=score,
        promo_risk=risk,
        recommended_mode=mode,
        drafts=tuple(build_drafts(raw.platform, summary, mode)),
    )


def normalize_text(raw: RawLead) -> str:
    return " ".join(part for part in (raw.title, raw.text) if part).lower()


def find_query_matches(text: str, queries: dict[str, list[str]]) -> list[str]:
    matches: list[str] = []
    for bucket in ("direct_pain", "cost_pain", "friction_pain", "buying_intent"):
        for query in queries.get(bucket, []):
            if query.lower() in text:
                matches.append(query)
    return dedupe(matches)


def classify_tags(text: str, matches: list[str]) -> list[str]:
    tags: list[str] = []
    if matches:
        tags.append("pain")
    if any(token in text for token in QUESTION_TERMS):
        tags.append("question")
    if "alternative" in text or "instead" in text:
        tags.append("comparison")
    if any(token in text for token in COMPLAINT_TERMS):
        tags.append("complaint")
    if any(token in text for token in COMMERCIAL_TERMS + URGENCY_TERMS):
        tags.append("buying_intent")
    if not tags:
        tags.append("noise")
    return dedupe(tags)


def score_lead(platform: str, text: str, matches: list[str], tags: list[str], queries: dict[str, list[str]]) -> int:
    score = len(matches) * 18
    score += count_contains(text, URGENCY_TERMS) * 10
    score += count_contains(text, COMMERCIAL_TERMS) * 8
    if "pain" in tags:
        score += 10
    if "buying_intent" in tags:
        score += 12
    if platform in ("github", "hackernews", "reddit", "x", "twitter"):
        score += 5
    if any(term in text for term in queries.get("negative_context", [])):
        score -= 30
    return max(0, min(score, 100))


def count_contains(text: str, terms: tuple[str, ...]) -> int:
    return sum(1 for term in terms if term in text)


def recommended_mode(score: int, risk: str) -> str:
    if score < 35:
        return "no_reply"
    if risk == "high":
        return "help_only"
    if score >= 70:
        return "help_plus_soft_mention"
    return "help_only"


def summarize(text: str) -> str:
    compact = re.sub(r"\s+", " ", text).strip()
    return compact if len(compact) <= 140 else compact[:137] + "..."


def build_drafts(platform: str, summary: str, mode: str) -> list[Draft]:
    drafts = [
        Draft(
            mode="help_only",
            text=(
                f"It sounds like you're hitting a real {platform} workflow problem. "
                "I would first isolate whether the blocker is Xcode/toolchain setup, CocoaPods/Ruby, or signing."
            ),
        )
    ]
    if mode == "help_plus_soft_mention":
        drafts.append(
            Draft(
                mode="help_plus_soft_mention",
                text=(
                    f"It sounds like you're dealing with the exact pain around shipping iOS from Windows: {summary} "
                    "If useful, this is the kind of workflow MacBridge is being built for: prepared cloud Mac plus a verified toolchain."
                ),
            )
        )
    return drafts


def write_outputs(leads: list[LeadItem], out_dir: Path) -> QueueFile:
    out_dir.mkdir(parents=True, exist_ok=True)
    queue = QueueFile(generated_at=now_iso(), items=tuple(leads))
    report = {"generated_at": queue.generated_at, "leads": [lead_to_dict(lead) for lead in leads]}
    (out_dir / "radar-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (out_dir / "radar-brief.md").write_text(render_markdown(leads, queue.generated_at), encoding="utf-8")
    from models import save_queue

    save_queue(out_dir / "review-queue.json", queue)
    return queue


def render_markdown(leads: list[LeadItem], generated_at: str) -> str:
    lines = ["# MacBridge Radar Brief", "", f"Generated: {generated_at}", "", f"Total leads: {len(leads)}", ""]
    for lead in leads:
        lines.extend(
            [
                f"## {lead.platform} | score {lead.fit_score} | {lead.recommended_mode}",
                "",
                f"- Author: `{lead.author}`",
                f"- URL: {lead.url}",
                f"- Tags: {', '.join(lead.tags)}",
                f"- Query matches: {', '.join(lead.query_matches) if lead.query_matches else 'none'}",
                f"- Promo risk: `{lead.promo_risk}`",
                f"- Summary: {lead.summary}",
                "",
            ]
        )
    return "\n".join(lines) + "\n"
