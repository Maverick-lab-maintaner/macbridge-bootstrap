# MacBridge Go-To-Market — The Radar Funnel

> How MacBridge finds customers, why they pay, and how the found pain maps onto the
> license-compliant tiers. Pairs with [`PRICING_STRATEGY.md`](PRICING_STRATEGY.md) and
> [`APPLE_LICENSE_COMPLIANCE.md`](APPLE_LICENSE_COMPLIANCE.md); the philosophy is in
> [`../LEAD_INTEL_PACER.md`](../LEAD_INTEL_PACER.md).
>
> **Honest framing:** this is **demand *capture*, not demand creation.** Radar makes a
> founder fast and focused; it is not "AI sells for us." No funnel projections are made
> here — measure real conversion first.

---

## The thesis

MacBridge does not need to convince people they have a problem. Thousands of Windows
Flutter developers already type the problem into search boxes and forums every week:
*"how do I build iOS from Windows,"* *"codemagic alternative,"* *"xcode not found flutter."*
Radar's job is to **be there when they say it**, answer helpfully, and — only when it
genuinely fits — mention MacBridge.

**The query library *is* the positioning.** The exact sentences Radar listens for are the
exact pains MacBridge removes. Find the sentence, and the pitch has already been written by
the prospect.

---

## The funnel

```
  LISTEN            SCORE             DRAFT            APPROVE          CONVERT          LEARN
  ──────            ─────             ─────            ───────          ───────          ─────
  Agent-Reach   →   engine.py     →   2 reply      →   human      →    map to a     →   which queries
  across X,         heuristic         variants         reviews /        compliant        / platforms /
  Reddit, GitHub,   0–100 +           (help-only,      approves /       tier            reply styles
  YouTube, RSS      reply mode        help+mention)    edits            (§ Pricing)      actually convert
      │                 │                 │               │                │                │
   raw leads       ranked queue     drafted replies   posted only    Build Pass /     better ranking,
                                                       when it fits   Dedicated /      better templates
                                                                      Tooling
```

Everything before "Approve" is automated. **Posting is always human-gated** — no
auto-replies, no mass DMs, no product mention where the answer stands alone.

---

## Stage 1 — Listen (the eyes)

Radar collects lead items and matches them against four query buckets (`queries.json`):

| Bucket | Example phrases | Signal |
|--------|-----------------|--------|
| **direct_pain** | `flutter ios build windows`, `build ios without mac`, `xcode not found flutter`, `testflight without mac` | Has the exact problem |
| **cost_pain** | `codemagic expensive`, `codemagic alternative`, `macstadium too expensive` | Frustrated with an incumbent |
| **friction_pain** | `cocoapods flutter ios error`, `simulator runtime missing`, `mac setup is painful` | Stuck mid-task |
| **buying_intent** | `need this fast`, `deadline`, `client launch`, `this week`, `asap` | Ready to act now |
| **negative_context** | `drop your product`, `self-promo`, `promotion thread` | **Penalty** — avoid promo-bait |

**Today** the live source is Reddit search RSS (`sources.py: load_reddit_searches`) plus
manual files and RSS feeds. **At scale**, the ["agent that searches around"](../LEAD_INTEL_PACER.md)
— **Agent-Reach**, a read/search-only capability layer with ordered-backend fallback and a
`doctor` — plugs into `sources.py` (the documented Phase 4 seam) and extends listening to
the high-signal surfaces:

- **GitHub issues** — a failing `flutter build ios` on CocoaPods (highest signal, lowest promo-risk)
- **X** — venting about Codemagic cost / Xcode-from-Windows (fastest pain detection)
- **YouTube comments** — people stuck under "Flutter iOS from Windows" tutorials
- **Reddit** — explicit "what's the alternative" threads

Agent-Reach's fallbacks are what keep the listening from silently going dark when one
backend breaks — the difference between a demo and a durable engine.

## Stage 2 — Score (separate a buyer from noise)

`engine.py` assigns 0–100:

```
score = matches × 18
      + urgency_terms × 10        # asap, urgent, deadline, this week, today, friday, launch
      + commercial_terms × 8      # client, production, testflight, paying, expensive, alternative
      + 10 if pain
      + 12 if buying_intent
      + 5  if high-signal platform (github, hn, reddit, x)
      − 30 if negative_context
      → clamp 0..100
```

**Worked example:**

> *"Need to ship my Flutter app to TestFlight from Windows by **Friday**, **Codemagic** is killing me."*

- direct_pain + cost_pain matches (×18 each) → high base
- urgency: `friday`, `this week` → +10 each
- commercial: `testflight`, `codemagic`, `expensive` → +8 each
- +10 pain, +12 buying_intent
- → **≥70**, and on a low/medium-risk platform → mode `help_plus_soft_mention`

Versus *"what is flutter?"* → near-zero → `no_reply`.

**Reply modes** (`recommended_mode`): `<35 → no_reply`; high-risk platform (YouTube/LinkedIn)
→ `help_only`; `≥70` on a safe platform → `help_plus_soft_mention`; else `help_only`. The
product mention only unlocks at real intent on a promo-tolerant surface.

## Stage 3 — Draft & Approve (help-first, never spam)

Each qualified lead gets **two drafts**: `help_only` (answer the problem, one concrete step,
stop) and `help_plus_soft_mention` (answer first, then mention MacBridge lightly). They land
in a review queue + a local HTML board (`radar board`). **A human posts, edits, or ignores.**
Radar never posts on its own. The safety rules in `LEAD_INTEL_PACER.md` — no auto-DMs, no
fake stories, no unchanged cross-posting — are the reputation moat.

## Stage 4 — Convert (map the pain to a compliant tier)

The lead's shape tells you the tier (from `PRICING_STRATEGY.md`, all §3-compliant):

| Lead signal | Best-fit tier | Why |
|-------------|---------------|-----|
| *"deadline Friday, Codemagic killing me"* (sporadic, urgent) | **Build Pass — $29/day** (on-demand dedicated ≥24h) | One build, one dedicated Mac, release after. Matches the behaviour. |
| *"I ship iOS every week from Windows"* (recurring) | **Dedicated — $139/mo** | Always-on provisioned Mac + agents |
| *"I already have an AWS/MacStadium Mac, setup is hell"* | **Tooling — $19/mo** (BYO Mac) | Sell the provisioning/knowledge layer; zero Apple exposure |

The compliant structure is a *feature* here: the sporadic "Friday" buyer genuinely wants a
day-pass, not a subscription — the license constraint and real behaviour point the same way.

## Stage 5 — Learn

Track which **queries** produce real conversations, which **platforms** convert, and which
**reply styles** land — then reweight the scoring and templates. (Deliberately no projected
funnel numbers until this data exists; `HONEST_ASSESSMENT.md`: measure before projecting.)

---

## Why they pay — the competitive wedge

Radar surfaces people whose complaint *names a wall*. The pitch answers that specific wall:

| They're using | Its wall | MacBridge's wedge |
|---|---|---|
| **Codemagic / CI** (the most-named pain) | Build-only; failures debugged **blind** — no shell, no interactive access; cost climbs | An **interactive Mac + AI agent** that *diagnoses* the failure (`doctor`, `signing-doctor`) |
| **Raw cloud Mac** (Macly/MacStadium) | "Here's a Mac, good luck" — ~2 hrs setup every time | **Pre-provisioned & verified**; 0 setup; the prepared studio; agents installed |
| **Buying a Mac** | $600+ upfront; you maintain it (Xcode breaks Flutter overnight) | No hardware; the institutional-knowledge layer absorbs ecosystem breakage |
| **GitHub Actions** | A pipeline, not a dev environment | Somewhere you can actually *work and debug*, from Windows |

**Three things that are genuinely hard to copy:**
1. **Pre-installed AI agents native on macOS** (Claude Code / OpenCode / Codex) — no competitor offers this.
2. **The zero-setup verified environment** — golden image + `doctor` knowledge base; "proven to work before you touched it."
3. **Windows-first framing** — the exact audience Radar listens for.

---

## Guardrails / honest caveats

- **Radar captures demand; it doesn't create it.** Conversion depends on the product being
  good and the founder replying well.
- **"Better than Codemagic" is situational.** Codemagic is entrenched, has a free tier, and
  wins for pure automated CI. MacBridge wins on *interactive debugging + AI + Windows-first*
  — target the frustration, not a feature-checklist parity claim.
- **Platform rules bite.** Over-posting flags accounts; the human gate, help-first modes,
  and `negative_context` penalty only work if respected.
- **Prototype status.** The live edge is single-platform and rate-limit-prone until
  Agent-Reach lands; treat it as a founder tool, not an autopilot.

---

## Sources / related

- [`../LEAD_INTEL_PACER.md`](../LEAD_INTEL_PACER.md) — the full listen→classify→score→draft→approve→post→learn doctrine and safety rules
- [`../ops/radar/README.md`](../ops/radar/README.md) — the Radar module + Agent-Reach Phase 4 seam
- [`PRICING_STRATEGY.md`](PRICING_STRATEGY.md) — the compliant tiers the funnel converts into
- [`APPLE_LICENSE_COMPLIANCE.md`](APPLE_LICENSE_COMPLIANCE.md) — why the tiers are shaped this way
