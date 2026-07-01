# MacBridge — Deploy Shortlist

Derived from the audit pass (see `HISTORY.md` Act XI) against the KnowledgeBase
(`HONEST_ASSESSMENT.md`, `MVP_BUILD_PLAN.md`, `ONBOARDING_ENVIRONMENT_STRATEGY.md`,
`COST_BENEFIT_RISK_ANALYSIS.md`). Scoped to **Deploy A** — a hand-provisioned paid
beta of 5–10 users — not public self-service (which is Phase 1/2 and unbuilt).

Legend: `[ ]` open · `[x]` done · `[~]` deferred (needs API/scale work) · `[!]` manual/strategic (not code)

---

## A. Windows-side code fixes (implementable now, in `provision.ps1`)

- [x] **W1 — Stop SCP-ing junk to the Mac.** `scp -r $BootstrapDir` copied `.git/`,
  `logs/`, and `macbridge.exe` (a 6.5 MB Windows binary, useless on macOS). Now stages a
  curated set (top-level `*.sh` + `lib/`) into a temp dir and copies only that.
  *Done — staging block in `provision.ps1`.*
- [x] **W2 — Make the 35-min bootstrap survive a dropped SSH.** Bootstrap now launches
  detached via `nohup` (live log `bootstrap-live.log` + exit-code file `bootstrap.rc`),
  streams live with `tail -F`, and reads the real exit code afterward. Added `-Resume`
  (re-attach an in-progress run, skipping stage/copy/launch) and `-FromLayer N` (passes
  `--from` to `bootstrap.sh`). *Done — launch/stream/rc blocks in `provision.ps1`.*
- [x] **W3 — Preflight the OpenSSH client.** Fails early with an actionable message if
  `ssh`/`scp` are missing from PATH. *Done — preflight loop in `provision.ps1`.*
- [x] **W4 — Write `session.json` as UTF-8.** `Set-Content ... -Encoding utf8`.
  *Done — plus a guard rejecting a `RemoteDir` without `/` before any `rm -rf`.*

## B. Windows-side, deferred (needs provider work — Phase 1)

- [~] **W5 — Provider API provisioning.** `-MacHost` must already be known; there is no
  "create a Mac" step. The Go CLI `provision` is a stub. Real self-service deploy (B)
  depends on this. Out of scope for the manual beta.

## C. Deploy prerequisites (manual / strategic — cannot be coded here)

- [x] **S1 — Apple ToS due diligence.** Done — see `docs/APPLE_LICENSE_COMPLIANCE.md`.
  **Key finding:** cloud Mac is legal under the macOS SLA Section 3 ("Leasing for Permitted
  Developer Services"), and MacBridge's *purpose* fits it. **But** the license requires each
  end user to have **sole and exclusive use of a dedicated Mac for ≥24 consecutive hours**
  and prohibits **time-sharing / terminal-sharing / service bureau** — so the
  10-users-per-Mac / $8.90-COGS model in `COST_BENEFIT_RISK_ANALYSIS.md` is **not
  compliant**. Viable only 1 customer : 1 dedicated Mac (≥24h), which means COGS ≈ a whole
  Mac (~$89/mo), not a tenth. **Repricing required before charging; get a lawyer to review
  the sublease chain.** (Not legal advice.)
- [~] **S2 — Golden image + auto-arranged workspace.** Tooling built:
  `readiness.sh` (the "🟢 MacBridge Ready" screen rendered from the status contract),
  `workspace-setup.sh` (LaunchAgent opens Terminal + boots the Simulator on login; a
  `~/.zprofile` hook greets every login shell with the readiness screen), and
  `golden-image.sh` (build → verify → workspace → version manifest → snapshot guidance,
  plus a `verify` drift-check). **Still manual:** the one-time Xcode GUI install and the
  provider snapshot itself — inherent, needs a real Mac + provider console.
- [!] **S3 — Test provider abstraction** — confirm `bootstrap.sh` runs identically on
  Macly AND VPSMAC without modification.
- [x] **S4 — Code-signing diagnoser.** The #1 user pain after setup. Implemented as
  read-only `signing-doctor.sh`: checks signing identities (valid + expired counts),
  provisioning profiles, and — with `--project PATH` — the project's bundle id and
  DEVELOPMENT_TEAM, flagging team/keychain mismatches. Reuses the status contract
  (`--json`), prints Apple-guide links, and never creates certs or touches the Apple
  account. *v1 done; future: decode profiles to match bundle id ↔ profile.*
- [!] **S5 — Instrument real usage** (hours/day, concurrent users per Mac). The whole
  margin model rests on the unvalidated 10-users-per-Mac assumption; measure it before
  trusting the COGS. Note the tension with "your data persists" (persistence vs. multi-tenancy).
- [!] **S6 — Measure conversion** — ask beta users "would you pay $X?" after real use.

---

## D. Tech-debt follow-ups (surfaced by CI, not blocking deploy)

- [x] **SH1 — ShellCheck warning cleanup.** Done. Removed dead vars (`LOG_FILE` in
  layers 0–3, `NPM_GLOBAL_BIN` + `CLAUDE_INSTALLED` superseded/unused in layer3,
  `PF_ANCHOR`, `LIB_DIR`, `SKIP`, `RED`, two orphaned `SCRIPT_DIR`, and hardening's
  redundant `PASS/FAIL` re-init that `_utils.sh` already provides), and annotated the
  one `SC2207` in `migrate.sh` with a reason (kept the portable `IFS`/`()` form —
  `mapfile` is bash 4+, but macOS ships bash 3.2). CI gate restored to `severity: warning`.

---

## Status

Everything that is **code** is done and merged to `master` across three green PRs.
Everything **left needs the real world** — a Mac, a provider, or beta users.

### Done (merged)

| PR | Scope | Items |
|----|-------|-------|
| [#1](https://github.com/Maverick-lab-maintaner/macbridge-bootstrap/pull/1) | Audit hardening | CI Go+Python jobs; `httpx2` typosquat → real `httpx`; committed radar module + docs; `provision.ps1` W1–W4; **S4** signing diagnoser (+ CLI `doctor --signing`); `install-skills.sh` runtime bug |
| [#2](https://github.com/Maverick-lab-maintaner/macbridge-bootstrap/pull/2) | **S2 tooling** | `readiness.sh` (Ready screen), `workspace-setup.sh` (prepared studio), `golden-image.sh` (build/verify/manifest) |
| [#3](https://github.com/Maverick-lab-maintaner/macbridge-bootstrap/pull/3) | **SH1** | cleared all ShellCheck warnings; gate enforced at `severity: warning` |

Done item IDs: **W1, W2, W3, W4, S4, S2 (tooling), SH1, S1 (research).** CI is green and
now genuinely enforced. S1 surfaced a new business blocker — **S7 (reprice for 1:1
dedicated Macs)** — because the multi-tenant COGS model is not license-compliant. Caveat: `provision.ps1`, `signing-doctor.sh`, and the S2 scripts are validated
locally (AST parser, mocked contracts, `--dry-run`) but **not yet run on a real Mac**.

### Left — all blocked on real-world inputs (no more code I can write)

| ID | Item | Blocked on |
|----|------|-----------|
| S2 (finish) | Golden image **snapshot** | Install Xcode via GUI once + snapshot via provider console. `golden-image.sh build` guides it. |
| S7 | **Reprice for 1:1 dedicated Macs** | Analysis done — `docs/PRICING_STRATEGY.md` (four options + unit economics; recommends software-core + managed-convenience). Pending on you: the provider-resale ToS check (decides B vs D), a tier decision, and a lawyer review. |
| W5 / S3 | Provider API + multi-provider test | A chosen provider (Macly/VPSMAC) + API keys. |
| S5 | Usage instrumentation | A running beta Mac to measure (`healthd` already emits usage events to build on). |
| S6 | Conversion measurement | Real beta users. |

**Update (2026-07-01, post software-first):** S1 is done and repriced (S7 →
`docs/BUSINESS_MODELS.md`: ship **Studio** first). That reframing also reprioritizes the
leftovers: **S3 (provider-agnosticism)** is now *more* valuable (Studio must run identically
on any Mac), while **W5 (provider API)** is deferred to the Managed tier.

**The "never run on a real Mac" caveat is retired.** The `macos-smoke.yml` workflow ran
everything on real GitHub `macos-latest` runners: the read-only suite emitted valid
contracts (correctly diagnosing a bare runner as `blocked`), and after fixing three real
bugs the run found (`declare -A` is bash 4+ but macOS ships 3.2; `| head -1` +
`pipefail` = SIGPIPE false-FAILs; hyphenated smoke-test dir is an invalid Dart package
name), **the full `bootstrap --from 2` → verify → `flutter build ios` path produced the
first 🟢 MAC READY in the project's history** (run 28546747490, $0). See `HISTORY.md`
Act XVIII. Still untested on a real Mac: `workspace-setup.sh` login behaviour and
`provision.ps1` against a live host (both need GUI/SSH, not CI).

**Studio P0 is built and proven (2026-07-01, `HISTORY.md` Act XIX):** the `macbridge` CLI
is now the self-contained product surface — embedded tooling, `install`, local
`status`/`doctor`, offline license gate (free/Pro), release workflow + Homebrew formula
template — and **`macbridge install` reached 🟢 MAC READY on a real Apple-hardware runner**
under a strict (no error-swallowing) CI gate.

**v0.1.0 SHIPPED (2026-07-01, `HISTORY.md` Act XX):** public tap
(`brew tap maverick-lab-maintaner/tap && brew install macbridge`), tagged release with
darwin arm64/amd64 + windows artifacts and checksums, formula carries real sha256s,
verified three ways (release binary runs; strict smoke **on the tag** → 🟢 MAC READY;
checksums match). Five beta keys generated.

**Queued next (deliberately parked until the product is user-tested):**

- [~] **P1a — LemonSqueezy checkout + key delivery. BUILT DARK, not wired.**
  `commerce/lemonsqueezy-webhook.js` (HMAC-verified, idempotent per order, refuses all
  traffic without a signing secret) + `commerce/keygen.mjs` (JS port of the Go key math,
  **byte-exact** — pinned by `test-keygen.mjs` vectors and cross-validated both directions).
  Activation is a 30-min runbook in `commerce/README.md` (LemonSqueezy product → secret →
  deploy → test purchase → wire email delivery). **Do after the real-Mac UX test.**
- [~] **Customer Dashboard V1. BUILT DARK, demo mode.** `landing/dashboard/index.html`
  (noindex, unlinked from nav) renders every spec state — SLA gate, provisioning, ready,
  degraded, blocked, tooling-tier — from embedded sample payloads in the site design
  system; `dashboard/customer-api.js` is the read-composition worker (contract + lease +
  SLA + license from KV, 24h floor computed server-side), dark-guarded. Wire when the
  first Managed customer or ~10 active beta users exist.
- [ ] **UX test on a real Mac (the $15 Macly day) — script ready.** Run
  `docs/REAL_MAC_TEST_SCRIPT.md`: 7 phases with pass criteria + timers (first live
  `brew install` of the formula, agent-tier install via the TUI, the "type `claude`"
  moment, the prepared-studio login, phone/tmux reconnect, golden-image snapshot
  (finishes S2), cleanup + S5 usage data), ending in the promise scorecard whose exit
  rule decides when LemonSqueezy flips on. **This is the next action.**
- [ ] Apple Developer ID signing/notarization for direct downloads (Homebrew works without).
- [ ] Decide the S7 tier structure (business).

### Done since v0.1.0 (2026-07-01→02, Acts XX–XXII)

- [x] **v0.1.0 shipped & verified** — public tap, tagged release (darwin arm64/amd64 +
  windows + checksums), formula carries real sha256s; release binary executed; strict
  smoke on the tag → 🟢 MAC READY; 5 beta keys minted. (Act XX)
- [x] **Commerce + Dashboard built dark** — LemonSqueezy webhook (HMAC, idempotent,
  dark-guarded) with byte-exact JS keygen (CI-gated JS↔Go both directions); dashboard V1
  demo mode (all spec states) + customer-api worker (24h floor server-side). (Act XXI)
- [x] **Agent selection TUI** — `macbridge install` asks which agents (1/2/3/a/n),
  `--agents` for scripting, Layer 3 `wants()` gating; BYO-keys note in the prompt. (#18)
- [x] **Two hallucinated agent packages fixed & PROVEN** — OpenCode (`@ oh-my-opencode/cli`
  broken syntax → `opencode-ai`) and Codex (`@anthropic-ai/codex-cli` → `@openai/codex`).
  Verified on a real Apple runner: **first agent-tier 🟢 MAC READY**, all three agents on
  PATH, strict CI check keeps it that way. (Act XXII)
- [x] **Nightly Build Verification Agent** — the smoke workflow now runs the full
  agent-tier install (through a real `flutter build ios`) **every night at 05:17 UTC** on
  a clean Mac runner. When Apple/Flutter/Homebrew/npm ship something breaking, it goes red
  and GitHub emails the owner before a customer hits it. $0 (public repo). This implements
  the safety net from `MAINTENANCE_AGENT_ARCHITECTURE.md`.

### Maintenance posture (the "Xcode breaks overnight" question)

Covered: nightly clean-Mac verification (above) + **weekly release watchers**
(`release-watchers.yml`, Mondays 06:00 UTC — Xcode + Flutter feeds checked against a
cached baseline; a new release turns the run red → owner email → rebuild the golden
image; alerts exactly once per release) + failure emails (path proven — a real failure
notification already landed) + `doctor.sh` remediation (11 rules) + `migrate.sh` opt-in
upgrades + strict CI gates. **Open:** `doctor-rules.json` grows only by discipline
(every new breakage → a rule); no auto-escalation/user-notification flow yet (matters
once Managed customers exist); single-maintainer risk is inherent.
