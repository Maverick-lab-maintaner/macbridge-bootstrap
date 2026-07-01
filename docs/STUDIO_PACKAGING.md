# MacBridge Studio — Packaging the Software Product

> The build path for the software-first decision in [`BUSINESS_MODELS.md`](BUSINESS_MODELS.md):
> turn the existing tooling into an installable, licensed product that runs on a Mac the
> customer provides (cloud **or** a Mac they own).

---

## What "the product" actually is now

Studio is not new code — it is the tooling this repo already has, **packaged behind one
install target: the `macbridge` CLI** (`cmd/macbridge`). The CLI fronts the shell layer;
the customer never wires the scripts by hand.

| Studio capability | Existing implementation |
|-------------------|------------------------|
| Provision a Mac to ready | `bootstrap.sh` + `lib/layer0–4` |
| Prove it works | `verify.sh` → status contract |
| Diagnose & remediate | `doctor.sh` + `lib/doctor-rules.json` |
| Code-signing diagnosis | `signing-doctor.sh` (CLI: `doctor --signing`) |
| The prepared studio | `workspace-setup.sh` + `readiness.sh` |
| Reproducible image | `golden-image.sh` |
| Updates | `migrate.sh` → extended to a knowledge channel (below) |
| AI-agent readiness | `install-skills.sh`, agent setup (BYO keys) |

**The elevation:** the Go CLI moves from "Phase-1 stub" to the primary product surface.
`status`, `doctor`, `ssh`, `stop` exist; Studio adds `install`, `activate`/`license`, and
`update`.

## Three things Studio needs that hosting didn't

### 1. Distribution (how it gets onto a Mac)

| Channel | Use | Notes |
|---------|-----|-------|
| **Homebrew tap** (`brew install macbridge/tap/macbridge`) | primary for Mac devs | easiest updates; the expected path |
| **Signed & notarized `.pkg` / binary** (Developer ID) | non-Homebrew users, teams | MacBridge must sign+notarize its own binary — eat the dog food (`signing-doctor`) |
| **`curl … | bash` bootstrap installer** | fallback / CI | pins a version; verifies checksum |

npm is *not* the vehicle (the CLI is Go); the AI agents remain their own `npm -g` installs
that Studio *sets up*, with the customer's keys.

### 2. Licensing / entitlement (it's paid software now)

Hosting gated access by controlling the Mac. Studio runs on the customer's Mac, so it needs
its own entitlement check:

- **Model:** account + license key, **online activation with an offline grace period** (cache
  the entitlement; keep working for N days offline; re-check on `update`).
- **Freemium option (recommended to lower the BYO-onboarding friction):**
  - **Free:** `bootstrap`, `verify`, `readiness`, basic `doctor`.
  - **Pro (subscription):** `signing-doctor`, `workspace-setup` studio, `golden-image`, the
    **updates/knowledge channel**, and priority doctor-rules.
- **Never** store the customer's AI provider keys server-side; entitlement ≠ credentials.

The entitlement gate is what makes the recurring subscription defensible — see next.

### 3. Updates / knowledge channel (the recurring value)

The subscription is not paying for a binary; it is paying for **continuously verified
knowledge**. `doctor-rules.json` is the artifact that grows every time a Flutter/Xcode/
CocoaPods conflict is solved.

- `macbridge update` pulls a **signed knowledge bundle** (updated `doctor-rules.json`, golden
  recipes, ecosystem fixes) from a MacBridge endpoint, **entitlement-gated**.
- `migrate.sh`'s version concept extends from "golden image version" to "knowledge version."
- This is the moat made shippable: a fresh competitor has version 0 of the knowledge.

---

## Phased build plan

**P0 — Ship Studio to beta** *(status as of 2026-07-01)*
1. ~~Package the `macbridge` CLI over the current tooling; add `install`.~~ **Done** — the
   binary embeds the full tooling tree (`tooling.go`, Go `embed`) and extracts to
   `~/.macbridge/tooling` on first use; `macbridge install` runs the layered bootstrap
   locally; `status`/`doctor` run locally when no `--host` is given (remote mode unchanged).
2. ~~A simple license gate (key check, offline grace).~~ **Done** — `internal/license`:
   `MB-XXXX-XXXX-XXXX-CCCC` keys (FNV-1a checksum group, ambiguity-free alphabet), offline
   validation, `~/.macbridge/license.json` record, 30-day grace, free/Pro split
   (`macbridge activate` / `macbridge license`; signing diagnosis is the first Pro-gated
   surface, local mode only). Vendor keygen: `go run ./cmd/mbkeygen` — **never shipped in
   releases**. Server-side entitlement attaches at P1 with the updates channel.
3. Homebrew tap + a signed/notarized binary. **Half done** — release workflow
   (`.github/workflows/release.yml`, tag-triggered, builds darwin arm64/amd64 + windows,
   checksums, GitHub Release; builds *only* `./cmd/macbridge`) and the formula template
   (`dist/homebrew/macbridge.rb`). **Still needed:** create the tap repo, and Developer ID
   signing + notarization (needs Apple credentials in secrets).
4. A clean **BYO-onboarding** flow: "connect your Mac (cloud or your own) → `macbridge
   install` → ready." **Open** — the CLI mechanics exist; the guided flow/docs are next.

**P1 — Make the subscription recur**
5. `macbridge update` → signed knowledge bundle, entitlement-gated.
6. Free/Pro split on commands.

**P2 — Account + light dashboard**
7. Account/entitlement sync + the narrow control plane in
   [`WEBSITE_DASHBOARD_SPEC.md`](WEBSITE_DASHBOARD_SPEC.md) (Studio view: status + doctor +
   AI-keys state + license state; the machine/lease sections light up only for Managed).

**Later — Managed** (per `BUSINESS_MODELS.md`): wrap the same CLI in a hosting layer; reuse
`provision.ps1`, provider API (W5), fleet `healthd`/`hardening`.

---

## Risks / notes

- **MacBridge must code-sign its own distributable** (Developer ID + notarization) or macOS
  Gatekeeper will block it — a fitting first customer for `signing-doctor`.
- **License enforcement is soft** for a dev tool; rely on the *updates channel* value more than
  DRM. Offline grace keeps it non-hostile.
- **BYO onboarding is the real risk to conversion**, not the tech — invest there first.
- Keep Studio provider-agnostic: it should run identically on Macly, AWS EC2 Mac, MacStadium,
  or a Mac mini (this is also S3, now more valuable).
