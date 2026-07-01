#!/usr/bin/env python3
from __future__ import annotations

from html import escape
from pathlib import Path

from models import LeadItem, QueueFile


def write_board(queue: QueueFile, path: Path) -> None:
    path.write_text(render_board(queue), encoding="utf-8")


def render_board(queue: QueueFile) -> str:
    cards = "\n".join(render_card(item) for item in queue.items)
    return (
        "<!doctype html>\n"
        "<html lang=\"en\">\n"
        "<head>\n"
        "  <meta charset=\"utf-8\">\n"
        "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        "  <title>MacBridge Radar Board</title>\n"
        "  <style>\n"
        "    :root {\n"
        "      --bg: #0c1117;\n"
        "      --panel: #131b24;\n"
        "      --panel-2: #1a2633;\n"
        "      --text: #edf4f7;\n"
        "      --muted: #9ab0bf;\n"
        "      --accent: #58d2c1;\n"
        "      --warn: #f3c969;\n"
        "      --bad: #ee7e7e;\n"
        "      --good: #6fe0a4;\n"
        "      --border: rgba(160, 208, 230, 0.14);\n"
        "    }\n"
        "    body {\n"
        "      margin: 0;\n"
        "      font-family: \"Segoe UI\", sans-serif;\n"
        "      background: linear-gradient(180deg, #091017 0%, var(--bg) 100%);\n"
        "      color: var(--text);\n"
        "    }\n"
        "    main { max-width: 1200px; margin: 0 auto; padding: 32px 20px 48px; }\n"
        "    h1 { margin: 0 0 8px; }\n"
        "    p { color: var(--muted); }\n"
        "    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 18px; margin-top: 24px; }\n"
        "    .card { background: var(--panel); border: 1px solid var(--border); border-radius: 18px; padding: 18px; box-shadow: 0 18px 60px rgba(0,0,0,0.22); }\n"
        "    .row { display: flex; align-items: center; justify-content: space-between; gap: 12px; }\n"
        "    .meta { color: var(--muted); font-size: 13px; }\n"
        "    .pill { border-radius: 999px; padding: 4px 10px; font-size: 12px; background: var(--panel-2); border: 1px solid var(--border); }\n"
        "    .approved { color: var(--good); }\n"
        "    .rejected { color: var(--bad); }\n"
        "    .pending_review { color: var(--warn); }\n"
        "    .draft { background: var(--panel-2); border-radius: 12px; padding: 12px; margin-top: 10px; }\n"
        "    .summary { line-height: 1.5; }\n"
        "    a { color: var(--accent); }\n"
        "    code { color: var(--accent); }\n"
        "  </style>\n"
        "</head>\n"
        "<body>\n"
        "  <main>\n"
        "    <h1>MacBridge Radar Board</h1>\n"
        f"    <p>Generated: {escape(queue.generated_at)}. This board is read-only. Review decisions still happen through the queue commands.</p>\n"
        "    <div class=\"grid\">\n"
        f"{cards}\n"
        "    </div>\n"
        "  </main>\n"
        "</body>\n"
        "</html>\n"
    )


def render_card(item: LeadItem) -> str:
    tags = ", ".join(item.tags)
    queries = ", ".join(item.query_matches) if item.query_matches else "none"
    drafts = "\n".join(render_draft(draft.mode, draft.text) for draft in item.drafts)
    note = "" if not item.review_notes else f"<p class=\"meta\"><strong>Review note:</strong> {escape(item.review_notes)}</p>"
    return (
        "    <section class=\"card\">\n"
        "      <div class=\"row\">\n"
        f"        <strong>{escape(item.platform)}</strong>\n"
        f"        <span class=\"pill {escape(item.status)}\">{escape(item.status)}</span>\n"
        "      </div>\n"
        f"      <p class=\"meta\">{escape(item.id)} | score={item.fit_score} | mode={escape(item.recommended_mode)}</p>\n"
        f"      <p class=\"summary\">{escape(item.summary)}</p>\n"
        f"      <p class=\"meta\">Author: {escape(item.author)}</p>\n"
        f"      <p class=\"meta\">Promo risk: {escape(item.promo_risk)} | Tags: {escape(tags)}</p>\n"
        f"      <p class=\"meta\">Queries: {escape(queries)}</p>\n"
        f"      <p><a href=\"{escape(item.url)}\">Open source</a></p>\n"
        f"      {note}\n"
        f"{drafts}\n"
        "    </section>\n"
    )


def render_draft(mode: str, text: str) -> str:
    return (
        "      <div class=\"draft\">\n"
        f"        <div class=\"meta\"><code>{escape(mode)}</code></div>\n"
        f"        <div>{escape(text)}</div>\n"
        "      </div>\n"
    )
