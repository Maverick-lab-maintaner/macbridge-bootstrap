#!/usr/bin/env python3
from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True, slots=True)
class RawLead:
    platform: str
    author: str
    url: str
    title: str
    text: str
    captured_at: str
    source_type: str = "post"


@dataclass(frozen=True, slots=True)
class Draft:
    mode: str
    text: str


@dataclass(frozen=True, slots=True)
class LeadItem:
    id: str
    platform: str
    source_type: str
    url: str
    author: str
    captured_at: str
    query_matches: tuple[str, ...]
    summary: str
    tags: tuple[str, ...]
    fit_score: int
    promo_risk: str
    recommended_mode: str
    drafts: tuple[Draft, ...]
    status: str = "pending_review"
    reviewed_at: str = ""
    review_notes: str = ""


@dataclass(frozen=True, slots=True)
class QueueFile:
    generated_at: str
    items: tuple[LeadItem, ...]


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def dedupe(values: list[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            output.append(value)
    return output


def lead_to_dict(item: LeadItem) -> dict[str, object]:
    payload = asdict(item)
    payload["drafts"] = [asdict(draft) for draft in item.drafts]
    payload["query_matches"] = list(item.query_matches)
    payload["tags"] = list(item.tags)
    return payload


def dict_to_lead_item(raw: dict[str, object]) -> LeadItem:
    drafts = tuple(Draft(mode=draft["mode"], text=draft["text"]) for draft in raw.get("drafts", []))
    return LeadItem(
        id=str(raw.get("id", "")),
        platform=str(raw.get("platform", "")),
        source_type=str(raw.get("source_type", "post")),
        url=str(raw.get("url", "")),
        author=str(raw.get("author", "")),
        captured_at=str(raw.get("captured_at", "")),
        query_matches=tuple(str(item) for item in raw.get("query_matches", [])),
        summary=str(raw.get("summary", "")),
        tags=tuple(str(item) for item in raw.get("tags", [])),
        fit_score=int(raw.get("fit_score", 0)),
        promo_risk=str(raw.get("promo_risk", "medium")),
        recommended_mode=str(raw.get("recommended_mode", "no_reply")),
        drafts=drafts,
        status=str(raw.get("status", "pending_review")),
        reviewed_at=str(raw.get("reviewed_at", "")),
        review_notes=str(raw.get("review_notes", "")),
    )


def load_queue(path: Path) -> QueueFile:
    raw = json.loads(path.read_text(encoding="utf-8"))
    items = tuple(dict_to_lead_item(item) for item in raw.get("items", []))
    return QueueFile(generated_at=raw.get("generated_at", now_iso()), items=items)


def save_queue(path: Path, queue: QueueFile) -> None:
    payload = {"generated_at": queue.generated_at, "items": [lead_to_dict(item) for item in queue.items]}
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def export_approved(queue: QueueFile, path: Path) -> int:
    approved = [lead_to_dict(item) for item in queue.items if item.status == "approved"]
    path.write_text(json.dumps({"generated_at": now_iso(), "approved": approved}, indent=2), encoding="utf-8")
    return len(approved)
