# MacBridge Radar Phase 1

Phase 1 is a listening-only lead intelligence module.
Phase 2 adds a local review queue.
Phase 1 can also add one live Reddit search RSS connector so the scan is not limited to local fixtures.

It does four things:

1. load lead items from manual JSON files and optional RSS feeds
2. match them against MacBridge pain queries
3. score and classify them
4. write a JSON export plus a Markdown brief for review

Optional live discovery:

5. search Reddit RSS for the current pain buckets and fold those items into the same queue

Phase 2 adds:

5. create a queue file for founder review
6. let you mark items approved or rejected
7. export only approved items

This module does **not** auto-post anywhere.

## Why It Exists

MacBridge core is about provisioning and operating cloud Macs.
Radar is about finding people who already have the exact problem MacBridge solves.

That makes it an adjacent ops module, not part of the bootstrap path.

## Folder Layout

```text
ops/radar/
├── README.md
├── queries.json
├── feeds.txt
├── radar.py
├── schema/
│   └── lead-item.schema.json
├── sample/
│   └── manual_leads.json
└── output/
```

## Inputs

### Manual lead files

Manual files are JSON arrays with objects like:

```json
{
  "platform": "reddit",
  "author": "username",
  "url": "https://example.com/post",
  "title": "Need to ship Flutter app to TestFlight from Windows",
  "text": "Codemagic is too expensive and I need an alternative this week.",
  "captured_at": "2026-07-01T12:00:00Z"
}
```

### RSS feeds

`feeds.txt` contains one feed URL per line.

These are useful for:

- blog monitoring
- release/news watching
- niche content discovery

Phase 1 RSS support is optional. If a feed fails, the run continues.

## Run It

From the repo root:

```powershell
python ops/radar/radar.py scan --manual ops/radar/sample/manual_leads.json
```

Or with a custom output directory:

```powershell
python ops/radar/radar.py scan `
  --manual ops/radar/sample/manual_leads.json `
  --out ops/radar/output
```

Or include RSS:

```powershell
python ops/radar/radar.py scan `
  --manual ops/radar/sample/manual_leads.json `
  --feeds ops/radar/feeds.txt
```

Or turn on the live source connector:

```powershell
python ops/radar/radar.py scan `
  --manual ops/radar/sample/manual_leads.json `
  --hn `
  --hn-limit 1
```

The `--hn` flag is the historical CLI name. It now means "include the live Reddit search RSS connector."
The live edge is best-effort and may be rate-limited by Reddit, but the scan keeps going and still writes the queue.

## Outputs

Each run writes:

- `radar-report.json`
- `radar-brief.md`
- `review-queue.json`

The JSON is structured machine output.
The Markdown brief is the human review surface.

## Review Queue

List queue items:

```powershell
python ops/radar/radar.py review --queue ops/radar/output/review-queue.json --list
```

Approve one:

```powershell
python ops/radar/radar.py review --queue ops/radar/output/review-queue.json --approve lead_2026_07_01_001
```

Reject one:

```powershell
python ops/radar/radar.py review --queue ops/radar/output/review-queue.json --reject lead_2026_07_01_003
```

Export approved items only:

```powershell
python ops/radar/radar.py review `
  --queue ops/radar/output/review-queue.json `
  --export-approved ops/radar/output/approved-leads.json
```

## Scoring Logic

The score is heuristic, not ML.

It increases for:

- direct pain query matches
- urgency words
- commercial intent words
- strong platform fit

It decreases for:

- weak/noisy matches
- high promo risk

Recommended modes:

- `help_only`
- `help_plus_soft_mention`
- `no_reply`

## What To Build Next

Phase 2 now includes:

1. reply draft generation
2. lead review queue
3. approval and rejection states
4. approved-only export

Phase 3 now adds:

1. a local HTML review board
2. draft visibility by lead
3. a cleaner queue-review surface

The board is still read-only on purpose.
Review actions remain explicit CLI commands.

### Phase 4 (planned): Agent-Reach collection backend

Today `sources.py` only collects from three inputs: manual JSON files,
RSS feeds, and a single Hacker News-style search scraper. That is the thin
part of the module.

[Agent-Reach](https://github.com/Panniantong/Agent-Reach) is a read/search-only
capability layer that gives an agent access across X/Twitter, Reddit, GitHub,
YouTube, RSS, and more, with ordered backends and automatic fallback. It maps
directly onto the collection stage of this pipeline:

```text
Agent-Reach            MacBridge Radar
COLLECT  ───────────►  CLASSIFY → SCORE → DRAFT → REVIEW → BOARD
```

The seam is `sources.py`. A future adapter — registered alongside the existing
manual / RSS / HN loaders in `radar.py run_scan` — would look like:

```python
def load_agent_reach_searches(queries, limit) -> list[RawLead]:
    # subprocess: agent-reach search <platform> "<query>" --json
    # map results -> RawLead(platform, author, url, title, text, captured_at)
```

Design constraints, so the module stays honest:

- **Gate it behind a `--agent-reach` flag.** Radar must still run zero-dependency
  by default (mirrors the vanilla/agent tier split in bootstrap). Agent-Reach is
  an extra runtime dependency plus per-platform auth (e.g. X cookies).
- **Wrap every call like `fetch_feed_safe`.** A broken backend should degrade to
  "no leads from that platform," never crash the scan. Pin an Agent-Reach version.
- **The safety boundary is preserved.** Agent-Reach does not post, and Radar does
  not auto-post. Collection stays read-only; `review.py` remains the only path to
  outbound. Neither half can spam.

This is a documented seam, not yet implemented. Do not add the dependency until
Agent-Reach is confirmed installed on the target machines.

## HTML Board

Generate a local review board:

```powershell
python ops/radar/radar.py board `
  --queue ops/radar/output/review-queue.json `
  --out ops/radar/output/radar-board.html
```

This gives you:

- one card per lead
- score and recommendation
- query matches
- review status
- both reply draft variants

This is the founder surface for quick scanning before approving replies.
