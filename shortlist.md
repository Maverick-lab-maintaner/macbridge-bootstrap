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

- [!] **S1 — Apple ToS due diligence (30 min).** Marked ❌ *Not done* in
  `HONEST_ASSESSMENT.md`. Existential risk, cheap to check. **Do before charging anyone.**
- [!] **S2 — Build + snapshot the golden image**, including the auto-arranged workspace
  (Terminal open, Simulator booted, Wizard running). This is where the "excellent UX"
  actually lives and what makes the "0 minutes" claim true. Requires a Mac + GUI once.
- [!] **S3 — Test provider abstraction** — confirm `bootstrap.sh` runs identically on
  Macly AND VPSMAC without modification.
- [!] **S4 — Code-signing diagnoser.** The #1 user pain after setup. Currently
  "diagnose, don't handle" — not implemented. Could start as a `doctor` rule.
- [!] **S5 — Instrument real usage** (hours/day, concurrent users per Mac). The whole
  margin model rests on the unvalidated 10-users-per-Mac assumption; measure it before
  trusting the COGS. Note the tension with "your data persists" (persistence vs. multi-tenancy).
- [!] **S6 — Measure conversion** — ask beta users "would you pay $X?" after real use.

---

## What's left (running tally)

**Done (4/4 code items):** W1, W2, W3, W4 — all `provision.ps1` fixes implemented and
syntax-validated. Not yet live-tested against a real Mac (no Mac available this session);
verified via the PowerShell AST parser and by inspecting the generated remote commands.

**Left — nothing I can implement in code without new inputs:**

| ID | Item | Why it's blocked on you |
|----|------|-------------------------|
| W5 | Provider API provisioning | Needs a chosen provider (Macly/VPSMAC) + API keys. Phase 1. |
| S1 | Apple ToS due diligence | 30-min human research task. **Gates charging anyone.** |
| S2 | Golden image + auto-arranged workspace | Needs a Mac + one-time GUI session. This is where the UX lives. |
| S3 | Provider abstraction test | Needs accounts on two providers. |
| S4 | Code-signing diagnoser | Buildable next as a `doctor` rule — say the word and I'll start it. |
| S5 | Usage instrumentation | Needs a running beta Mac to measure; `healthd` already emits usage events to build on. |
| S6 | Conversion measurement | Needs real beta users. |

**The single most important next step is S2 (golden image)** — it delivers the "excellent
UX" and validates the "0 minutes" promise. S1 (Apple ToS) is the cheapest and must precede
any charging. Everything in section A is now off your plate.
