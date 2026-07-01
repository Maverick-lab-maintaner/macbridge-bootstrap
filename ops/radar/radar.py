#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from board import write_board
from engine import build_lead_items, load_queries, write_outputs
from models import QueueFile, export_approved, load_queue, save_queue
from review import list_queue, update_queue_status
from sources import load_feeds, load_reddit_searches, load_manual_files


ROOT = Path(__file__).resolve().parent
DEFAULT_QUERIES = ROOT / "queries.json"
DEFAULT_OUTPUT = ROOT / "output"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MacBridge Radar")
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan = subparsers.add_parser("scan", help="Scan sources and generate reports")
    scan.add_argument("--manual", nargs="*", default=[], help="Manual JSON lead files")
    scan.add_argument("--feeds", default="", help="Optional feeds.txt path")
    scan.add_argument("--queries", default=str(DEFAULT_QUERIES), help="Path to queries.json")
    scan.add_argument("--reddit", action="store_true", help="Include live Reddit search RSS results")
    scan.add_argument("--reddit-limit", type=int, default=5, help="Max Reddit results per query")
    scan.add_argument("--out", default=str(DEFAULT_OUTPUT), help="Output directory")

    review = subparsers.add_parser("review", help="Review and update queue state")
    review.add_argument("--queue", required=True, help="Path to review-queue.json")
    review.add_argument("--list", action="store_true", help="List queue items")
    review.add_argument("--approve", default="", help="Approve one lead ID")
    review.add_argument("--reject", default="", help="Reject one lead ID")
    review.add_argument("--note", default="", help="Optional review note")
    review.add_argument("--export-approved", default="", help="Write approved leads to this file")

    board = subparsers.add_parser("board", help="Generate an HTML review board")
    board.add_argument("--queue", required=True, help="Path to review-queue.json")
    board.add_argument("--out", default=str(DEFAULT_OUTPUT / "radar-board.html"), help="Output HTML path")

    return parser.parse_args()


def run_scan(manual: list[str], feeds: str, queries_path: str, out_path: str, reddit: bool = False, reddit_limit: int = 5) -> int:
    queries = load_queries(Path(queries_path))
    raw_items = load_manual_files([Path(path) for path in manual])
    if feeds:
        raw_items.extend(load_feeds(Path(feeds)))
    if reddit:
        raw_items.extend(load_reddit_searches(queries, reddit_limit))
    if not raw_items:
        print("No lead items loaded. Provide --manual and/or --feeds.", file=sys.stderr)
        return 1
    raw_items = list(dict.fromkeys(raw_items))
    leads = build_lead_items(raw_items, queries)
    write_outputs(leads, Path(out_path))
    print(f"Wrote {len(leads)} leads to {Path(out_path)}")
    return 0


def run_review(queue: QueueFile, queue_path: Path, approve: str, reject: str, note: str, should_list: bool, export_path: str) -> int:
    current_queue = queue
    if approve:
        current_queue, found = update_queue_status(current_queue, approve, "approved", note)
        if not found:
            print(f"Lead not found: {approve}", file=sys.stderr)
            return 1
        save_queue(queue_path, current_queue)
        print(f"Approved {approve}")
    if reject:
        current_queue, found = update_queue_status(current_queue, reject, "rejected", note)
        if not found:
            print(f"Lead not found: {reject}", file=sys.stderr)
            return 1
        save_queue(queue_path, current_queue)
        print(f"Rejected {reject}")
    if should_list:
        print(list_queue(current_queue))
    if export_path:
        count = export_approved(current_queue, Path(export_path))
        print(f"Exported {count} approved leads to {export_path}")
    if not any((approve, reject, should_list, export_path)):
        print("No review action requested.", file=sys.stderr)
        return 1
    return 0


def run_board(queue: QueueFile, out_path: str) -> int:
    write_board(queue, Path(out_path))
    print(f"Wrote board to {out_path}")
    return 0


def main() -> int:
    args = parse_args()
    match args.command:
        case "scan":
            return run_scan(args.manual, args.feeds, args.queries, args.out, args.reddit, args.reddit_limit)
        case "review":
            return run_review(load_queue(Path(args.queue)), Path(args.queue), args.approve, args.reject, args.note, args.list, args.export_approved)
        case "board":
            return run_board(load_queue(Path(args.queue)), args.out)
        case _:
            print(f"Unsupported command: {args.command}", file=sys.stderr)
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
