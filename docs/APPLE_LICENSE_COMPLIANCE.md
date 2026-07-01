# Apple macOS License Compliance — S1 Due Diligence

> **Not legal advice.** This is due-diligence research quoting Apple's published macOS
> Software License Agreement (Sequoia) and how the cloud-Mac industry operates under it.
> Have a lawyer review the sublease chain before charging customers.

**Date:** 2026-07-01 · **Source of truth:** [macOS Sequoia SLA (Apple Legal, PDF)](https://www.apple.com/legal/sla/docs/macOSSequoia.pdf)

---

## TL;DR

Running MacBridge on cloud Macs is **legal in principle** — Apple's license has a
purpose-built carve-out (Section 3, "Leasing for Permitted Developer Services") that the
whole cloud-Mac industry runs under. **But the specific pricing/COGS model in
`COST_BENEFIT_RISK_ANALYSIS.md` is not compliant**: it assumes ~10 users time-sharing one
Mac at ~$8.90/user. Apple's license requires each end user to have **sole and exclusive
use of a dedicated Mac for a minimum of 24 consecutive hours**, and explicitly prohibits
**time-sharing / terminal-sharing / service-bureau** use. The multi-tenancy that produced
the $8.90 COGS and the 35–66% margins is forbidden by the license, not just operationally
awkward.

**Net:** the business is viable, but only on a **1 customer : 1 dedicated Mac, ≥24h**
basis — which means COGS is roughly a *whole* Mac (~$89/mo monthly, ~$15/day), not a tenth
of one. Reprice accordingly.

---

## The governing clauses (verbatim, macOS Sequoia SLA)

### Section 2B(iii) — the two-VM allowance (owner's own use)

> "to install, use and run up to **two (2) additional copies or instances** of the Apple
> Software … within virtual operating system environments on each Apple-branded computer
> **you own or control that is already running the Apple Software**, for purposes of:
> (a) software development; (b) testing during software development; (c) using macOS
> Server; or (d) personal, non-commercial use."

### Section 2B — the service-bureau prohibition

> "Except as expressly permitted in Section 3, the grant set forth in Section 2B(iii)
> above **does not permit you to use the virtualized copies or instances of the Apple
> Software in connection with service bureau, time-sharing, terminal sharing, relay
> service or other similar types of services.**"

This is the clause a naive "10 users share one Mac, 30-minute sessions" model runs
straight into.

### Section 3 — Leasing for Permitted Developer Services (the carve-out that makes it legal)

> "You may **lease or sublease** a validly licensed version of the Apple Software in its
> entirety to an individual or organization (each, a 'Lessee') provided that all of the
> following conditions are met:
> **(i)** the leased Apple Software must be used for the **sole purpose of providing
> Permitted Developer Services** and each Lessee must review and agree to be bound by the
> terms of this License;
> **(ii)** each lease period must be for a **minimum period of twenty-four (24)
> consecutive hours**;
> **(iii)** during the lease period, the End User Lessee must have **sole and exclusive
> use and control** of the Apple Software and the Apple-branded hardware on which it is
> installed, except that you, as the party leasing the Apple Software ('Lessor'), may
> provide administrative support …;
> **(iv)** prior to using the Apple Software, the End User Lessee must review and agree to
> be bound by the terms applicable to any software preinstalled … (e.g., Xcode)."

And the definition that scopes it:

> "**Permitted Developer Services** means continuous integration services, including but
> not limited to software development, building software from source, automated testing
> during software development, and running necessary developer tools to support such
> activities."

### How the industry complies (corroboration)

AWS EC2 Mac instances are **bare-metal Dedicated Hosts with a 24-hour minimum allocation
"to comply with the Apple macOS Software License Agreement."** MacStadium and other
providers operate the same 1:1 bare-metal model. This is the operational shape Section 3
mandates.

---

## What this means for MacBridge

### The good news

- **Purpose is squarely inside "Permitted Developer Services."** Flutter/iOS software
  development, building from source, automated testing, running dev tools — this is
  exactly what Section 3 permits. MacBridge is not trying to do anything the license
  forbids at the level of *intent*.
- **Sub-leasing is explicitly allowed** ("lease or sublease … to an individual or
  organization"), so MacBridge-as-reseller is a recognized shape — provided the Section 3
  conditions flow through to the end user.

### The hard constraints (these bite)

1. **24-hour minimum, per user.** You cannot rotate multiple customers through one Mac in
   a day. The `MVP_BUILD_PLAN` "stop after 30 min / resume" idle model is fine *only if
   the same customer keeps the same Mac* — you may not reallocate that Mac to a different
   customer before 24 consecutive hours have elapsed.
2. **Sole and exclusive use and control.** One end user per Mac during the lease. The
   "10 users per Mac" assumption underpinning the $8.90 COGS is **not permitted**.
3. **The 2-VM allowance does not rescue it.** Section 2B(iii)'s two VMs are for the
   owner's *own* dev/test, and 2B explicitly bans using them for time-sharing/service-
   bureau. It is not a multi-tenancy loophole.
4. **Each customer must accept Apple's SLA** (3.A.i and 3.A.iv) — including preinstalled
   software terms (Xcode). This has to be part of onboarding.

### The consequence for the numbers

`COST_BENEFIT_RISK_ANALYSIS.md` models COGS at **$8.90/user** on the premise of 10 users
sharing a Mac. Under a compliant 1:1 dedicated model, COGS is roughly a **whole Mac**:

| Provider basis | Approx. compliant COGS / customer / month |
|----------------|-------------------------------------------|
| VPSMAC monthly M4 | ~$89 |
| Macly daily M4 ($14.99/day) | ~$450 if kept 24/7; less if the customer only holds it in ≥24h bursts |

At those numbers, **$19 Vanilla and even $39 Agent lose money** against a dedicated Mac.
The pricing has to change to one of:

- **Pass-through + margin on a dedicated Mac** (e.g., a floor around real Mac cost, so a
  plan is priced like "$X/mo for your own cloud Mac" — closer to what MacStadium/AWS
  charge), or
- **Usage-priced ≥24h blocks** (customer pays for dedicated ≥24h allocations, not a flat
  "always available" fee subsidized by imagined multi-tenancy).

This is the same **persistence-vs-multitenancy tension** already flagged in the audit —
now confirmed as a *legal* constraint, not merely an operational one. Apple's license
forbids the multi-tenancy that the margin model assumed.

---

## Recommendations

1. **Reprice around 1:1 dedicated Macs with ≥24h allocations.** Treat the $8.90/10-users
   model as dead. Model real COGS as a whole Mac and price above it.
2. **Confirm your provider is Apple-compliant *and* permits reselling.** Bare-metal 1:1
   with 24h enforcement (AWS/MacStadium do this). Then check Macly's / VPSMAC's *own* ToS
   explicitly allow you to sublease/resell access — that is a separate contract from
   Apple's SLA.
3. **Put Apple SLA acceptance in onboarding.** Section 3 requires each end user to agree
   to the License and to preinstalled-software terms. Add an explicit acceptance step to
   the Welcome Wizard / signup before first use.
4. **Enforce the 24h floor in the control plane.** The idle-stop/cleanup lifecycle must
   never hand a Mac to a *different* customer inside 24 hours. `cleanup.sh` between users
   is correct; the *reallocation timing* is the compliance-sensitive part.
5. **Scope the product strictly to developer services.** Market and gate it as a Flutter/
   iOS build-and-test environment. Do not offer it as general-purpose macOS desktop
   access, which would fall outside "Permitted Developer Services."
6. **Get a lawyer to review the sublease chain** (Apple → provider → MacBridge → customer)
   before charging. This document is research, not legal advice.

---

## Sources

- [Apple macOS Sequoia Software License Agreement (PDF)](https://www.apple.com/legal/sla/docs/macOSSequoia.pdf) — Sections 2B(iii), 2B service-bureau prohibition, 3 (Leasing for Permitted Developer Services)
- [Apple Legal — Software License Agreements index](https://www.apple.com/legal/sla/)
- [Amazon EC2 Mac Instances](https://aws.amazon.com/ec2/instance-types/mac/) and [EC2 Mac user guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-mac-instances.html) — bare-metal Dedicated Host, 24-hour minimum "to comply with the Apple macOS Software License Agreement"
