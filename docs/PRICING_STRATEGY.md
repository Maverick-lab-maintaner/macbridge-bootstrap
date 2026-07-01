# MacBridge Pricing Strategy — Post-Compliance

> **Not financial or legal advice.** Follows directly from
> [`APPLE_LICENSE_COMPLIANCE.md`](APPLE_LICENSE_COMPLIANCE.md) (S1). Per-unit economics
> are grounded in verified provider costs; **no total-revenue projections** are made here —
> those wait for real usage and conversion data (per `HONEST_ASSESSMENT.md`: measure
> before projecting).

---

## The constraint that reset the model

Apple's macOS SLA §3 requires **1 customer : 1 dedicated Mac, ≥24 consecutive hours, sole
and exclusive use**, and §2B prohibits **time-sharing / terminal-sharing / service bureau**.

**What died:** the 10-users-per-Mac / **$8.90 COGS** / 35–66% margin model in
`COST_BENEFIT_RISK_ANALYSIS.md`. You cannot amortize one Mac across many concurrent users.

**What survives:** everything else — the product is legal, the purpose fits "Permitted
Developer Services," and the tech (bootstrap, golden image, doctor, signing, readiness) is
built. Only the *pricing structure* changes.

### Verified cost inputs

| Input | Value | Source |
|-------|-------|--------|
| Macly M4 (daily) | **$14.99 / day** | Phase 0 (`PROJECT_CONTEXT.md`) |
| VPSMAC M4 (monthly) | **$89 / month** | KB financial model |
| LemonSqueezy fee | **5% + $0.50** per transaction | KB |
| MacStadium / AWS EC2 Mac wholesale | *unverified* | **must confirm** |

---

## The four options, with unit economics

### Option C — Sell the software, not the Mac (bring-your-own provider)

The customer leases a Mac **directly** from a compliant provider (AWS EC2 Mac, MacStadium) —
they are the Lessee, they accept Apple's SLA — and MacBridge is the provisioning +
environment + knowledge layer they run on it (`golden-image.sh`, readiness studio, `doctor`,
signing diagnoser, agent setup, ongoing ecosystem fixes).

| | Per customer / month |
|--|--|
| Price (software subscription) | **$19** |
| Mac COGS | **$0** (customer's own) |
| LemonSqueezy (5% + $0.50) | ~$1.45 |
| **Gross profit** | **~$17.55** |
| **Gross margin** | **~92%** |

- **Apple exposure: none.** You never sublease macOS.
- **Trade-off:** customer needs their own Mac source → less "one-click." Mitigate with a
  strong BYO-provider onboarding flow.
- This is the "institutional knowledge is the moat" play, and it matches the repo's own
  thesis: *the bootstrap is the product.*

### Option B — On-demand dedicated Mac, ≥24h blocks

For users who won't touch a provider themselves: spin up **their own dedicated Mac for a
day**, ship a build, release it. Each allocation is ≥24h and single-tenant → compliant, and
it matches how sporadic iOS-build users actually behave.

| | Per 24h "build pass" |
|--|--|
| Price | **$29 / day** |
| Mac COGS (Macly) | $14.99 |
| LemonSqueezy (5% + $0.50) | ~$1.95 |
| Overhead (bandwidth/support) | ~$1.00 |
| **Gross profit** | **~$11.06 / day** |
| **Gross margin** | **~38%** |

- The **sweet spot** for the sporadic-builder market the multi-tenant idea was chasing —
  same demand, legal structure, and **no idle Macs to pay for**.
- Bundle option: "3-day pass $75" for release crunches.

### Option A — Dedicated monthly (always-on provisioned Mac)

Simple subscription, priced like a *real* dedicated Mac. Compete on "provisioned & verified
in minutes," not price.

| | Per customer / month |
|--|--|
| Price | **$139** |
| Mac COGS (VPSMAC monthly) | $89 |
| LemonSqueezy (5% + $0.50) | ~$7.45 |
| Overhead | ~$2.00 |
| **Gross profit** | **~$40.55** |
| **Gross margin** | **~29%** |

- This is the "keep-alive for AI agents 24/7" enterprise/pro tier — also fully compliant
  (one dedicated Mac, held continuously by one customer).
- Smaller, more professional market than the $19 fantasy — but real, and positive-margin.

### Option D — Reseller / partner with a compliant provider

Resell AWS EC2 Mac or MacStadium with a markup + your provisioning layer. **They** carry the
Apple relationship and compliance; you are the value-added UX/automation on top.

- **Apple exposure: on the provider**, not you.
- Economics depend on **wholesale rates you must confirm**; model as `(wholesale × markup) −
  fees`. Typically 20–40% markup on infra + your software margin.
- Fastest path to "managed, one-click" without carrying the license yourself.

---

## Recommendation: **C as the core, B/D as the convenience tier**

```
                 ┌─────────────────────────────────────────┐
   THE MOAT ───▶ │  MacBridge Tooling (Option C)           │  ~92% margin, $0 infra,
                 │  provisioning + knowledge, BYO Mac       │  zero Apple exposure
                 └─────────────────────────────────────────┘
                                    +
                 ┌─────────────────────────────────────────┐
 CONVENIENCE ─▶  │  Managed dedicated Macs (Option B/D)     │  on-demand ≥24h or monthly,
                 │  we provision it for you, ≥24h dedicated │  via a compliant provider
                 └─────────────────────────────────────────┘
```

- **Core = the software/knowledge layer (C).** Zero Apple risk, ~92% margin, it *is* the
  moat, and it is already built. This is the base subscription.
- **Convenience = managed on-demand ≥24h dedicated Macs (B), ideally via a provider
  partnership (D)** so MacBridge does not carry the Apple license directly.
- **Kill the flat multi-tenant $19 tier** — it was never license-compliant.
- The **S2 "prepared studio" UX is the differentiator in every option** — whether you host
  or the customer does.

### Proposed tiers (replaces the old $19/$39/$79 multi-tenant table)

| Tier | Price | What | Compliant basis |
|------|-------|------|-----------------|
| **CLI / Tooling** | $19/mo | Provisioning + `doctor` + signing + agents + ecosystem updates, on the customer's own Mac | C — no sublease |
| **Build Pass** | $29/day (≥24h) | We provision a dedicated Mac for a day; ship and release | B/D — ≥24h, single-tenant |
| **Dedicated** | $139/mo | Your own always-on provisioned Mac + agents 24/7 | A/D — one dedicated Mac |

---

## Decision checklist (open questions, in priority order)

1. **Does Macly / VPSMAC's own ToS permit reselling?** (20-min read.) If **no** → Option B
   with them is off; use AWS/MacStadium via Option D. This single answer decides B-vs-D.
2. **Get AWS EC2 Mac + MacStadium wholesale rates** to finalize B/D margins.
3. **Pick the tier structure** (recommended: the three above) and confirm the numbers
   against real COGS.
4. **Lawyer-review the remaining sublease chain** — none if you stay pure-C; Apple→provider→
   MacBridge→customer if you host.
5. **Add Apple-SLA acceptance to onboarding** for any hosted model (§3.A.i/iv).

---

*Grounded in verified provider costs; totals deliberately omitted until beta usage and
conversion are measured.*
