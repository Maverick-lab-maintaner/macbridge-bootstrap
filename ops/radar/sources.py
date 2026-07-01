#!/usr/bin/env python3
from __future__ import annotations

import logging
import json
import re
import socket
import xml.etree.ElementTree as element_tree
from pathlib import Path

import httpx2

from models import RawLead, dedupe, now_iso

LOGGER = logging.getLogger(__name__)
REDDIT_SEARCH_URL = "https://www.reddit.com/search.rss"
SEARCH_BUCKETS = ("direct_pain", "cost_pain", "friction_pain", "buying_intent")
SEARCH_STOP_WORDS = {"from", "for", "with", "without", "this", "that", "what", "need", "need", "any", "the", "and", "ios"}


def load_manual_files(paths: list[Path]) -> list[RawLead]:
    items: list[RawLead] = []
    for path in paths:
        for item in json.loads(path.read_text(encoding="utf-8")):
            items.append(
                RawLead(
                    platform=item.get("platform", "unknown"),
                    author=item.get("author", "unknown"),
                    url=item.get("url", ""),
                    title=item.get("title", ""),
                    text=item.get("text", ""),
                    captured_at=item.get("captured_at", now_iso()),
                    source_type=item.get("source_type", "post"),
                )
            )
    return items


def load_hackernews_searches(queries: dict[str, list[str]], limit: int = 5) -> list[RawLead]:
    items: list[RawLead] = []
    seen: set[RawLead] = set()
    with create_hackernews_client() as client:
        for query in build_hackernews_queries(queries):
            for item in fetch_hackernews_query(client, query, limit):
                if item not in seen:
                    seen.add(item)
                    items.append(item)
    return items


def load_feeds(path: Path) -> list[RawLead]:
    if not path.exists():
        return []
    leads: list[RawLead] = []
    with create_hackernews_client() as client:
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if line and not line.startswith("#"):
                leads.extend(fetch_feed_safe(client, line))
    return leads


def build_hackernews_queries(queries: dict[str, list[str]]) -> list[str]:
    bucket_queries: list[str] = []
    for bucket in SEARCH_BUCKETS:
        tokens: list[str] = []
        for query in queries.get(bucket, []):
            tokens.extend(token for token in re.split(r"[^A-Za-z0-9]+", query.lower()) if len(token) >= 3 and token not in SEARCH_STOP_WORDS)
        limited = dedupe(tokens)[:5]
        if limited:
            bucket_queries.append(" ".join(limited))
    return dedupe(bucket_queries)


def create_hackernews_client() -> httpx2.Client:
    transport = httpx2.HTTPTransport(
        http2=True,
        retries=3,
        limits=httpx2.Limits(max_connections=200, max_keepalive_connections=40, keepalive_expiry=30.0),
        socket_options=[(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)],
    )
    hooks = {
        "request": [log_request],
        "response": [log_response],
    }
    return httpx2.Client(
        transport=transport,
        timeout=httpx2.Timeout(connect=5.0, read=30.0, write=10.0, pool=10.0),
        follow_redirects=True,
        headers={"User-Agent": "MacBridge Radar/1.0"},
        event_hooks=hooks,
    )


def log_request(request: httpx2.Request) -> None:
    LOGGER.info("HN request %s", request.url)


def log_response(response: httpx2.Response) -> None:
    LOGGER.info("HN response %s %s", response.status_code, response.request.url)


def fetch_hackernews_query(client: httpx2.Client, query: str, limit: int) -> list[RawLead]:
    try:
        response = client.get(
            REDDIT_SEARCH_URL,
            params={
                "q": query,
                "sort": "new",
                "t": "month",
                "limit": str(max(1, limit)),
            },
        )
        response.raise_for_status()
    except httpx2.HTTPStatusError as exc:
        LOGGER.warning("Reddit search failed for %s: %s", query, exc.response.status_code)
        return []
    root = element_tree.fromstring(response.text.encode("utf-8"))
    return parse_atom_items(root, platform="reddit", author="reddit", source_type="search_result")


def parse_hackernews_hit(hit: dict[str, str | list[str]]) -> RawLead:
    title = first_text(hit, ("title", "story_title"))
    text = first_text(hit, ("story_text", "comment_text", "text"))
    url = first_text(hit, ("story_url", "url"))
    author = first_text(hit, ("author",))
    captured_at = first_text(hit, ("created_at",))
    source_type = first_text(hit, ("source_type",))
    if not source_type:
        tags = hit.get("_tags", [])
        if isinstance(tags, list) and tags:
            source_type = str(tags[0])
        else:
            source_type = "hn_hit"
    return RawLead(
        platform="hackernews",
        author=author or "unknown",
        url=url,
        title=title,
        text=text,
        captured_at=captured_at or now_iso(),
        source_type=source_type,
    )


def first_text(hit: dict[str, str | list[str]], keys: tuple[str, ...]) -> str:
    for key in keys:
        value = hit.get(key, "")
        if isinstance(value, str):
            text = value.strip()
            if text:
                return text
    return ""


def fetch_feed_safe(client: httpx2.Client, url: str) -> list[RawLead]:
    try:
        return fetch_feed(client, url)
    except (httpx2.HTTPError, element_tree.ParseError):
        return []


def fetch_feed(client: httpx2.Client, url: str) -> list[RawLead]:
    try:
        response = client.get(url)
        response.raise_for_status()
    except httpx2.HTTPStatusError as exc:
        LOGGER.warning("Feed fetch failed for %s: %s", url, exc.response.status_code)
        return []
    root = element_tree.fromstring(response.text.encode("utf-8"))
    rss_items = parse_rss_items(root)
    return rss_items if rss_items else parse_atom_items(root)


def parse_rss_items(root: element_tree.Element) -> list[RawLead]:
    return [
        RawLead(
            platform="rss",
            author="feed",
            url=text_or_empty(item.find("link")),
            title=text_or_empty(item.find("title")),
            text=strip_html(text_or_empty(item.find("description"))),
            captured_at=text_or_empty(item.find("pubDate")) or now_iso(),
            source_type="feed_item",
        )
        for item in root.findall(".//item")
    ]


def parse_atom_items(
    root: element_tree.Element,
    *,
    platform: str = "rss",
    author: str = "feed",
    source_type: str = "feed_item",
) -> list[RawLead]:
    namespace = {"atom": "http://www.w3.org/2005/Atom"}
    items: list[RawLead] = []
    for entry in root.findall(".//atom:entry", namespace):
        link_node = entry.find("atom:link", namespace)
        link = "" if link_node is None else link_node.attrib.get("href", "")
        items.append(
            RawLead(
                platform=platform,
                author=author,
                url=link,
                title=text_or_empty(entry.find("atom:title", namespace)),
                text=strip_html(text_or_empty(entry.find("atom:summary", namespace))),
                captured_at=text_or_empty(entry.find("atom:published", namespace)) or now_iso(),
                source_type=source_type,
            )
        )
    return items


def text_or_empty(node: element_tree.Element | None) -> str:
    return "" if node is None or node.text is None else node.text.strip()


def strip_html(text: str) -> str:
    return re.sub(r"<[^>]+>", " ", text).replace("\n", " ").strip()
