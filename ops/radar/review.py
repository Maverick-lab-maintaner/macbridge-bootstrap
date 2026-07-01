#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import asdict

from models import LeadItem, QueueFile, now_iso


def list_queue(queue: QueueFile) -> str:
    return "\n".join(
        f"{item.id} | {item.status} | {item.platform} | score={item.fit_score} | {item.recommended_mode} | {item.summary}"
        for item in queue.items
    )


def update_queue_status(queue: QueueFile, lead_id: str, status: str, note: str) -> tuple[QueueFile, bool]:
    updated: list[LeadItem] = []
    found = False
    for item in queue.items:
        if item.id == lead_id:
            found = True
            updated.append(
                LeadItem(
                    **{
                        **asdict(item),
                        "drafts": tuple(item.drafts),
                        "query_matches": tuple(item.query_matches),
                        "tags": tuple(item.tags),
                        "status": status,
                        "reviewed_at": now_iso(),
                        "review_notes": note or item.review_notes,
                    }
                )
            )
        else:
            updated.append(item)
    return QueueFile(generated_at=queue.generated_at, items=tuple(updated)), found
