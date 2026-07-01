# MacBridge Business Models — and the Software-First Decision

> Companion to [`PRICING_STRATEGY.md`](PRICING_STRATEGY.md) and
> [`APPLE_LICENSE_COMPLIANCE.md`](APPLE_LICENSE_COMPLIANCE.md). Where pricing works out the
> numbers, this works out *which company to build*.

---

## The reframe

Yesterday's fear: *"Apple might kill the business."*
After reading the license: *"Apple **defines** what business models are allowed."*

That is a completely different situation. It doesn't block MacBridge — it tells us which
shape to build. And the shape the license most cleanly permits is also the one that is
hardest to copy and highest-margin.

## The four models

| Model | Apple risk | Infra cost | Margin | Complexity | Rating |
|-------|-----------|-----------|--------|-----------|:---:|
| **C — Software only (BYO Mac)** | Very low | None | Very high (~92%) | Medium (onboarding) | ⭐⭐⭐⭐⭐ |
| **B — Managed 24h dedicated** | Medium | Moderate | Good (~38%) | Medium | ⭐⭐⭐⭐⭐ |
| **D — Provider partnership** | Low | Low | Good | High (business dev) | ⭐⭐⭐⭐☆ |
| **A — Monthly dedicated** | Medium | High | Moderate (~29%) | Low | ⭐⭐⭐⭐☆ |

- **A is the weakest to launch** — it makes you *"MacStadium with prettier setup,"* competing
  head-on with incumbents on their turf.
- **D is right long-term, impossible now** — a startup has no leverage with AWS/MacStadium yet.
- **C + B together are the play.**

## The decision: software-first, managed later

**Build MacBridge as two products on one codebase.**

```
                Product 1 — MacBridge Studio  (SOFTWARE, ship first)
                ─────────────────────────────────────────────────
                Runs on any Mac the customer provides:
                  Macly · AWS EC2 Mac · MacStadium · a Mac mini · a Mac Studio
                Revenue: monthly software subscription (~92% margin)

                Product 2 — MacBridge Managed (HOSTED, add later)
                ─────────────────────────────────────────────────
                We provision the dedicated Mac (≥24h) and hand it over ready.
                Revenue: day-pass ($29/day) or dedicated monthly ($139/mo)
```

Same bootstrap, same doctor, same workspace, same golden image — **different deployment
model.** Studio is the product; Managed is a convenience layer wrapped around it once demand
is validated.

**Chosen direction: ship Studio first.** It minimizes legal + infra risk, preserves the
hardest-to-copy asset, broadens the market, and leaves a clean path to add Managed without
changing the core.

---

## What this changes about the original plan (and the effect on the product)

| Original assumption | Under software-first | Effect on the product |
|---------------------|----------------------|-----------------------|
| MacBridge **hosts/provisions** cloud Macs | MacBridge is **software the customer runs** on a Mac they provide | The **Go `macbridge` CLI + the shell tooling become *the product***, packaged and licensed — not a hosting service |
| Revenue = access to hosted Macs; COGS = Mac rental | Revenue = **software subscription**; COGS ≈ **$0 infra** | SaaS margins (~92%); no idle-Mac burn; predictable support |
| We sublease macOS → **Apple SLA exposure** | Customer leases their own Mac → **no exposure** | Legal + compliance become the provider's problem, not ours |
| TAM = Windows Flutter devs needing a **cloud** Mac | TAM = **anyone with a Mac** wanting a verified, agent-ready, self-healing iOS workspace | **Market expands** to Mac mini / Mac Studio owners and existing cloud-Mac renters — see below |
| Onboarding: **buy → ready** (one click) | **buy → bring/connect a Mac → install → ready** | Extra step lowers conversion → the reason Managed (one-click) exists as tier 2 |
| Multi-tenant fleet (cleanup between users, `healthd`, `hardening`) | Single-owner Macs | `provision.ps1`, provider API (W5), fleet health/hardening become **Managed-tier features, deferred** |

**Concretely, the product surface reprioritizes:**

- **Now the product (Studio):** `bootstrap.sh` + layers, `verify.sh`, `doctor.sh` +
  `doctor-rules.json`, `signing-doctor.sh`, `readiness.sh`, `workspace-setup.sh`,
  `golden-image.sh`, `migrate.sh` (updates), agent-ready setup — all **customer-run**, fronted
  by the `macbridge` CLI.
- **Deferred to Managed:** provider API provisioning (W5), `provision.ps1` as a hosting bridge,
  fleet `healthd`/`hardening`, cleanup-between-users.
- **New, needed for Studio:** a licensing/entitlement gate, distribution (Homebrew tap /
  signed pkg / npm), and an **updates channel** — because the recurring value is the
  continuously-growing knowledge (doctor rules, recovery, ecosystem fixes).

**What does *not* change — and this matters:** every tool built this session *is* the Studio
product. Nothing was wasted. The status contract, the `doctor-rules` knowledge base, the
prepared-studio UX, and the agent-ready environment are exactly what Studio ships.

---

## The hidden market expansion

Because Studio needs no cloud, **someone who already owns a Mac mini or Mac Studio can still
buy it** — for the doctor flows, the prepared workspace, the signing diagnosis, the
agent-ready setup, recovery, and updates. MacBridge stops being limited to cloud-Mac renters.
That materially enlarges the addressable market and de-risks the "is there demand" question,
because it now includes people who already proved they'll spend on Apple hardware.

## The trajectory — from tool to knowledge platform

```
bootstrap.sh   →   doctor   →   doctor → known issue → recovery → success
                                      →   doctor → community fix → verified → available globally
```

Each solved Flutter/Xcode/CocoaPods conflict encoded into `doctor-rules.json` serves every
future customer instantly. After enough of them, MacBridge is not a script — it is a
**continuously verified workspace with accumulated, compounding knowledge** that a fresh
competitor cannot replicate. That knowledge is the real moat, and software-first is what makes
it the center of the product.

## The repositioned product definition

The old line — *"The product isn't the Mac, the bootstrap is the product"* — was directionally
right but too narrow. Bootstrap is one part. The product is now:

> **The product isn't the Mac. The product is the continuously verified development workspace** —
> bootstrap, doctor, recovery, readiness, signing, AI-agent readiness, updates, and the golden
> image, together.

---

## What to build first (sequencing)

1. **Package Studio.** Make the `macbridge` CLI the installable product surface over the
   existing tooling; add a license/entitlement gate and a distribution channel.
2. **Nail BYO onboarding.** A clean "connect your Mac (cloud or physical) → run MacBridge →
   ready" flow — this is where Studio's conversion is won or lost.
3. **Make the updates/knowledge channel real.** The subscription's recurring value.
4. **Validate demand.** Then, and only then, add **Managed** (B) as the one-click convenience,
   ideally via a provider partnership (D) so we never carry the Apple license.

This is the first business model where the technology, the economics, and the product vision
line up naturally — so it's the one to pursue first.
