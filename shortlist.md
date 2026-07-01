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

**Next real-world move: S1 (Apple ToS)** — cheapest, and it gates everything commercial.
When you have a Mac provisioned, the live `golden-image.sh build` → snapshot flow is the
one that turns the S2 tooling into an actual image.
