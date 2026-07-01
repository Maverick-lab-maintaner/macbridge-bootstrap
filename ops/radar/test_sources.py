from __future__ import annotations

import json
import sys
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import radar  # noqa: E402
import sources  # noqa: E402


def test_fetch_hackernews_query_maps_hits_to_raw_leads() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/search.rss"
        assert request.url.params["q"] == "flutter ios build windows"
        assert request.url.params["sort"] == "new"
        assert request.url.params["t"] == "month"
        assert request.url.params["limit"] == "2"
        return httpx.Response(
            200,
            text=(
                "<?xml version='1.0' encoding='UTF-8'?>"
                "<feed xmlns='http://www.w3.org/2005/Atom'>"
                "<entry>"
                "<title>Need a faster way to ship Flutter iOS</title>"
                "<link href='https://www.reddit.com/r/flutterdev/comments/123abc/post/' />"
                "<summary>TestFlight is blocked on my Windows workflow.</summary>"
                "<published>2026-07-01T12:30:00Z</published>"
                "</entry>"
                "</feed>"
            ),
        )

    transport = httpx.MockTransport(handler)
    with httpx.Client(transport=transport) as client:
        items = sources.fetch_hackernews_query(client, "flutter ios build windows", limit=2)

    assert len(items) == 1
    lead = items[0]
    assert lead.platform == "reddit"
    assert lead.author == "reddit"
    assert lead.source_type == "search_result"
    assert lead.title == "Need a faster way to ship Flutter iOS"
    assert lead.text == "TestFlight is blocked on my Windows workflow."
    assert lead.url == "https://www.reddit.com/r/flutterdev/comments/123abc/post/"
    assert lead.captured_at == "2026-07-01T12:30:00Z"


def test_run_scan_can_include_hackernews_results(tmp_path, monkeypatch) -> None:
    queries_path = tmp_path / "queries.json"
    queries_path.write_text(json.dumps({"direct_pain": ["flutter ios build windows"]}), encoding="utf-8")
    out_dir = tmp_path / "out"

    def fake_load_hackernews_searches(queries: dict[str, list[str]], limit: int) -> list[sources.RawLead]:
        assert queries["direct_pain"] == ["flutter ios build windows"]
        assert limit == 1
        return [
            sources.RawLead(
                platform="reddit",
                author="reddit",
                url="https://www.reddit.com/r/flutterdev/comments/123abc/post/",
                title="Need a faster way to ship Flutter iOS",
                text="TestFlight is blocked on my Windows workflow.",
                captured_at="2026-07-01T12:30:00Z",
                source_type="search_result",
            )
        ]

    monkeypatch.setattr(radar, "load_hackernews_searches", fake_load_hackernews_searches)

    exit_code = radar.run_scan([], "", str(queries_path), str(out_dir), hn=True, hn_limit=1)

    assert exit_code == 0
    queue = json.loads((out_dir / "review-queue.json").read_text(encoding="utf-8"))
    assert queue["items"][0]["platform"] == "reddit"
