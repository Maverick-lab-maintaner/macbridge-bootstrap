# MacBridge Website and Dashboard Spec

This document defines what the public website and first customer dashboard need to say and do now that the pricing model, hosting model, and AI model are clearer.

It exists to prevent the public surface from selling the wrong thing.

## The Problem

The current landing page still presents MacBridge as one simple `$19/month` offer.
That is no longer accurate.

The repo now has a clearer model:

- `CLI / Tooling` for customers who bring their own provider
- `Build Pass` for a dedicated 24-hour Mac
- `Dedicated` for an always-on managed Mac

The site also does not clearly explain whether:

- the Mac is included
- the AI is included
- the user brings their own API keys
- there is a customer control plane after signup

That ambiguity will create support load and false expectations.

## The Product Model The Site Must Reflect

MacBridge is two things:

1. a software and knowledge layer
2. an optional managed-Mac convenience layer

The public framing should be:

- the core product is the prepared, verified, AI-ready macOS workflow
- the managed Mac is an optional convenience tier, not the whole company

This matters because the compliant business model is not "cheap shared Mac access."
It is:

- tooling on top of a customer-owned Mac
- or a dedicated managed Mac allocation

## The AI Model

The website must state this explicitly:

- MacBridge includes an AI-ready environment
- MacBridge does not include unlimited Anthropic/OpenAI/Codex usage by default
- the customer normally brings their own API keys

The correct public language is:

> MacBridge prepares the environment for Claude Code, OpenCode, and Codex.
> Model usage is billed by your own AI provider unless a plan explicitly says otherwise.

This avoids three bad assumptions:

1. that MacBridge includes unlimited Claude or OpenAI usage
2. that margins are large enough to absorb unpredictable token spend
3. that the user does not need their own provider account

If MacBridge ever wants "AI included," it should be a separate plan with one of these structures:

- capped monthly credits
- metered overage
- team seat plus bundled allowance

It should not be silently bundled into the base plans.

## The Website Must Change In Four Places

### 1. Hero

The hero should stop sounding like one generic hosted-Mac offer.

It should say:

- what MacBridge is
- who it is for
- what the user is buying

Recommended message:

> Ship iOS from Windows with a prepared macOS workflow.
> Bring your own provider or use a managed dedicated Mac.

The subcopy should make the wedge explicit:

- verified toolchain
- prepared studio
- interactive debugging
- AI-ready environment

### 2. Pricing

The pricing section must move from one card to a three-offer structure.

#### Offer 1: CLI / Tooling

- Price: `$19/month`
- Customer provides the Mac or provider account
- Includes provisioning, doctor flows, signing diagnosis, environment updates, and setup guidance
- AI keys: customer-supplied
- Best for developers who want the knowledge layer without managed hosting

#### Offer 2: Build Pass

- Price: `$29/day`
- Includes one dedicated managed Mac for a compliant 24-hour allocation
- Best for sporadic builders shipping to TestFlight or doing release work
- AI keys: customer-supplied

#### Offer 3: Dedicated

- Price: `$139/month`
- Includes one always-on dedicated managed Mac
- Best for teams or heavy users who need continuity
- AI keys: customer-supplied

Each card must explicitly state:

- whether the Mac is included
- whether AI usage is included
- whether the user must bring their own API keys

### 3. Comparison / Why It Wins

The site should compare MacBridge against:

- Codemagic
- raw cloud Mac providers
- buying a Mac
- pure CI

The comparison should not claim "better at everything."
It should say:

- Codemagic is stronger for pure CI automation
- raw cloud Macs are stronger if you want unopinionated hardware only
- MacBridge wins on prepared environment, interactive debugging, AI-native setup, and Windows-first framing

That makes the pitch more credible.

### 4. Call To Action

The current CTA is too generic.
It should route users by intent:

- "I already have a Mac/provider"
- "I need a managed dedicated Mac"
- "I want beta access"

This routing matters because the onboarding flow is different for each case.

## Dashboard Requirement

Yes, MacBridge needs a dashboard UI.

Not a huge SaaS dashboard first.
A narrow control plane.

The dashboard exists to answer:

- what did I buy
- what is active right now
- how do I connect
- what is broken
- what do I do next

## Dashboard V1

The first dashboard should have these sections.

### A. Access Card

Shows:

- plan name
- Mac included: yes/no
- current machine state
- lease window or renewal state
- SSH details
- GUI access details

Primary actions:

- copy SSH command
- open connection guide
- view current environment status

### B. Environment Status

Shows the read-only health surface:

- Xcode
- Flutter
- CocoaPods
- Simulator
- agent binaries
- signing readiness

This should reuse the same status contract the repo already emits rather than inventing a second truth surface.

### C. AI Configuration

Shows:

- Claude key connected: yes/no
- OpenAI key connected: yes/no
- Codex-compatible setup: yes/no
- billing note: "usage billed by your provider"

This section matters because it answers the question the website currently leaves fuzzy:

> Does my plan include AI, or do I need my own keys?

### D. Compliance and Terms

Needed for hosted plans.

Shows:

- Apple SLA accepted: yes/no
- hosted lease start time
- hosted lease end time or renewal state
- plan type and dedicated-machine status

This matters because the product now has a compliance-sensitive hosting model.

### E. Actions

For managed plans:

- start
- stop
- reset
- extend lease
- request help

For tooling-only plans:

- rerun onboarding
- open provider setup guide
- run doctor guide

## Implementation: reuse the signals the repo already emits

Almost every element above is a **read view over data the repo already produces** — little new
backend logic:

| Dashboard element | Source in the repo |
|-------------------|--------------------|
| Machine status (ready/degraded/blocked) | `verify.sh --json` → the status contract (`lib/status-contract.sh`) |
| Environment status rows | the same contract (`readiness.sh` renders the identical rows) |
| Doctor / signing status | `doctor.sh --json`, `signing-doctor.sh --json` (same contract) |
| Connect instructions (SSH/DeskIn), tier | `~/.macbridge/session.json` (written by `provision.ps1`) |
| Environment version | `/etc/macbridge-version` / `golden-image.sh manifest` (via `migrate.sh`) |
| Health over time (V2) | `healthd.sh` webhook events → `dashboard/health-receiver.js` (Cloudflare) |
| Start / stop / reset | `macbridge ssh|stop`, `cleanup.sh` (the Go CLI already wraps these) |
| AI-keys state | derivable from the welcome-flow provider setup (`welcome.sh`) |

## New backend pieces required (small, hosted plans only)

1. **Lease record** per allocation: `{ machine_id, customer_id, tier, allocated_at,
   earliest_release_at = allocated_at + 24h, expires_at }` — enforces the Apple §3 24-hour floor
   (the dashboard must *prevent* releasing a Mac to a different customer inside the window).
2. **SLA-acceptance record**: `{ customer_id, accepted_at, sla_version }` — gates first use
   (§3.A.i/iv); the connect action is blocked until it exists.
3. **A read API** that composes the status contract + `session.json` + the two records above
   into one dashboard payload.

Everything else is the existing scripts and the Cloudflare receiver.

## Dashboard V2

Later, add:

- environment history
- provisioning events
- build notes
- cost and lease timeline
- support tickets
- saved projects

But V1 should stay narrow.

## The Correct Customer Mental Model

The site and dashboard should teach this model:

### Tooling plan

> You bring the Mac. MacBridge brings the prepared workflow.

### Build Pass

> You rent one dedicated Mac for a release window. MacBridge prepares it and gets you to the build surface fast.

### Dedicated

> You keep one dedicated Mac continuously, with MacBridge managing the environment around it.

### AI

> MacBridge supports your AI coding workflow, but your model usage is normally billed by your own AI provider.

This is the sentence the website currently needs most.

## Website Copy Rules

Every pricing or CTA surface must explicitly answer:

1. Is the Mac included?
2. Is the lease dedicated or shared?
3. Are AI tokens included?
4. Does the customer bring their own API keys?
5. Is this self-service, managed, or beta-assisted?

If a section does not answer those questions, it is incomplete.

## Recommended Next Implementation Order

1. replace the single `$19/month` website card with the three-offer model
2. add an "AI usage" note directly under each plan
3. add a "How billing works" explainer
4. add dashboard mockups or a simple authenticated shell
5. wire the dashboard to the existing status and doctor outputs

## Bottom Line

The public surface should stop selling one fuzzy thing.

It should clearly present:

- a tooling subscription
- a managed build pass
- a dedicated managed tier
- an AI-ready but not AI-bundled default model

And yes, a dashboard UI is now warranted, because the hosted and BYO flows are different enough that email-only onboarding will become confusing fast.

