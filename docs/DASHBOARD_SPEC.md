# MacBridge Customer Dashboard — Spec

> A **simple customer control plane**, not a full SaaS dashboard. Needed once any *managed*
> tier (Build Pass / Dedicated) ships. Pairs with [`PRICING_STRATEGY.md`](PRICING_STRATEGY.md)
> and [`APPLE_LICENSE_COMPLIANCE.md`](APPLE_LICENSE_COMPLIANCE.md).
>
> **Design principle:** the dashboard should make three things unmistakable at a glance —
> **what you bought, whether the Mac is included, and whether AI tokens are included** — and
> surface the compliance state (SLA acceptance, 24h lease window) that the license requires.

---

## Why it's needed

For the **Tooling** tier (BYO Mac) a dashboard is optional — the customer runs the CLI on
their own machine. But for **Build Pass** and **Dedicated**, MacBridge is allocating a Mac on
the customer's behalf, so they need to see and control it: status, connect info, lease
expiry, and start/stop/reset. Without it, "is my Mac up? when does it expire? did I accept
the license?" become support tickets.

## Almost everything it shows already exists as a signal

The control plane is mostly a **read view over data the repo already emits** — little new
backend logic:

| Dashboard element | Source in the repo |
|-------------------|--------------------|
| Machine status (ready/degraded/blocked) | `verify.sh --json` → the status contract (`lib/status-contract.sh`) |
| Doctor / signing status | `doctor.sh --json`, `signing-doctor.sh --json` (same contract) |
| Connect instructions (SSH/DeskIn) | `~/.macbridge/session.json` (written by `provision.ps1`) |
| Chosen tier | `session.json` `tier` field |
| Golden-image version | `/etc/macbridge-version` (via `migrate.sh`) |
| Health over time | `healthd.sh` webhook events → `dashboard/health-receiver.js` (Cloudflare) |
| Start / stop / reset | `macbridge ssh|stop`, `cleanup.sh` (the Go CLI already wraps these) |
| Lease window / expiry | **new** — allocation timestamp + 24h floor (see below) |
| SLA acceptance state | **new** — must be recorded at onboarding |
| AI keys connected? | derivable from the welcome-flow provider setup (`welcome.sh`) |

So the build is mostly: a small API that reads the status contract + session + a bit of new
lease/SLA state, and a thin UI.

---

## Screens / sections

### 1. Machine card (the hero)
- **State badge:** `READY` / `DEGRADED` / `BLOCKED` (green/amber/red) straight from the
  status contract `summary.state`.
- **Readiness checklist:** the same rows as `readiness.sh` (Flutter, Xcode, Simulator,
  CocoaPods, Ruby, Node, agents) with ✅/⚠️/❌.
- **Connect:** SSH command + DeskIn ID (from `session.json`), copy buttons.

### 2. Plan & inclusions (makes the three facts explicit)
A fixed, always-visible strip:

| Field | Example values |
|-------|----------------|
| **Tier** | Tooling · Build Pass · Dedicated |
| **Mac included?** | *No — bring your own* · *Yes, for this 24h pass* · *Yes, dedicated* |
| **AI tokens included?** | *No — your own Anthropic/OpenAI/Codex keys* (default for all tiers) |

This mirrors the site's pricing cards so a customer never wonders what they're paying for.

### 3. Lease window (compliance-critical)
- **Allocated at** / **earliest release** / **expires** timestamps.
- A visible **24-hour minimum** indicator: a Mac cannot be released before 24h have elapsed
  (Apple §3.A.ii). The UI must *prevent* a "stop → give to someone else" action inside the
  window; "stop" for a customer's *own* Mac is fine (it stays theirs).

### 4. Compliance & credentials state
- **Apple SLA / preinstalled-software terms:** `Accepted ✓ (date)` or `Action required`.
  First use is **blocked** until accepted (§3.A.i/iv).
- **AI keys:** `Connected (provider)` or `Not connected — using your own keys`. Never store
  the keys server-side by default; show connection state only.

### 5. Actions
- **Start / Resume**, **Stop** (own Mac), **Reset** (`cleanup.sh` → re-verify), **Run Doctor**,
  **Run Signing Check**. Each maps to an existing script/CLI command; Reset and Stop confirm.

### 6. Health history (Dedicated tier)
- A small timeline from `healthd` events (uptime, last verify state). Optional for MVP.

---

## UX states to handle

| State | Trigger | UI behaviour |
|-------|---------|--------------|
| **SLA not accepted** | new customer / new lease | Block connect; show acceptance modal first |
| **Provisioning** | Mac allocated, bootstrap running | Progress + "streaming" (mirrors `provision.ps1`) |
| **Ready** | status contract `ready` | Green machine card + connect info |
| **Degraded** | `degraded` | Amber; surface failing checks + "Run Doctor" |
| **Blocked** | `blocked` (critical fail) | Red; "Repair" / contact support |
| **Inside 24h window** | now < allocated+24h | Disable "release"; "stop (keeps it yours)" allowed |
| **Expiring soon** | Dedicated renewal / pass near end | Banner + renew/extend CTA |
| **AI keys missing** | agent tier, no provider configured | Non-blocking nudge: "connect your AI keys" |
| **Tooling tier (BYO Mac)** | no managed Mac | Hide machine controls; show CLI status + `doctor` output only |

---

## Scope

**MVP (ships with the first managed tier):** machine card (status contract), plan &
inclusions strip, connect info, lease window + 24h guard, SLA acceptance gate, AI-keys state,
and start/stop/reset/doctor actions.

**Later:** health-history timeline, billing/usage views, multi-Mac/team, in-dashboard key
management.

**Not this:** a general analytics SaaS. Keep it a control plane — status, connect, lease,
compliance, actions.

---

## New backend pieces required (small)

1. **Lease record** per allocation: `{ machine_id, customer_id, tier, allocated_at,
   earliest_release_at = allocated_at + 24h, expires_at }`. Enforces the §3 floor.
2. **SLA acceptance record**: `{ customer_id, accepted_at, sla_version }`. Gates first use.
3. **A read API** that composes the status contract (`verify --json`) + `session.json` +
   the two records above into one dashboard payload.

Everything else is the existing scripts and the Cloudflare receiver.
