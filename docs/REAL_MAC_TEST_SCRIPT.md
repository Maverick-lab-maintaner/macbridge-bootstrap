# Real-Mac UX Test Script — the $15 Macly Day

> Run this like a customer would, in order, on a rented Macly M4 (or any Mac with GUI
> access). It validates every promise in one session, produces the golden image (finishes
> S2), and captures the usage data (S5) the pricing model needs.
> **Rule for the whole session: you are a customer, not the founder.** If you have to
> think, that's a finding. Write down every hesitation.
>
> Time budget: ~2.5–3.5 hours active. Keep a timer note per phase — the timings ARE data.

## Before you rent

- [ ] Phone has **Termius** installed (for the reconnect test)
- [ ] **DeskIn** ready on Windows (GUI access)
- [ ] Have one beta key at hand (e.g. `MB-JPC6-J79N-78HR-9GEH`) — mark it used afterwards
- [ ] Have your Anthropic (and optionally OpenAI) API key available — BYO keys, as designed
- [ ] Note Macly rental start time: `____:____` (lease-clock + cost datum)

---

## Phase 1 — First contact (target: <10 min) · Promise: "connect, and it's ready to start"

Connect via SSH from Windows (`ssh <user>@<ip>`).

| # | Do | Pass looks like | ⏱/notes |
|---|----|----|----|
| 1.1 | `sw_vers && xcodebuild -version` | Xcode present (Macly image) — if **not**, this is a **golden-image finding**: note it, install via DeskIn App Store once (~45 min, timed) | |
| 1.2 | `brew --version \|\| echo none` | Note whether brew is preinstalled — image datum | |
| 1.3 | **The real customer path:** `brew tap maverick-lab-maintaner/tap && brew install macbridge` | Installs clean; **first-ever live run of the formula.** `macbridge --version` → `v0.1.0` | |
| 1.4 | `macbridge status` | Renders the TUI; honest verdict (likely `blocked`/`degraded` — no Flutter yet). **No crash, no confusing output** | |

**UX question to answer in writing:** did anything up to here require knowledge a Windows Flutter dev wouldn't have?

## Phase 2 — `macbridge install`, agent tier (target: ~35 min unattended) · Promise: "one command"

| # | Do | Pass looks like | ⏱/notes |
|---|----|----|----|
| 2.1 | `macbridge install` (tier defaults to **agent**) | **The TUI asks which agents you want** (1 Claude / 2 OpenCode / 3 Codex / a / n). Pick **`a` (all)** — this is the never-tested path | |
| 2.2 | Watch the layers | Layer 0→4 verified in sequence; failures (if any) name the layer and how to resume (`--from N`) | |
| 2.3 | Final verdict | **🟢 MAC READY — agent tier** incl. the real `flutter build ios` smoke | |
| 2.4 | `macbridge status` | `ready`, all rows green **including claude/opencode/codex** | |

If a layer fails: capture the output verbatim (that's a doctor-rule candidate), fix per the message, `macbridge install --from N`. **A failure with a clear recovery is a pass for the doctor philosophy; a confusing failure is the finding.**

## Phase 3 — The agent moment (target: <5 min) · Promise: "type `claude` and your agent has a Mac"

This is the vibecoder differentiator — never before executed.

| # | Do | Pass looks like | ⏱/notes |
|---|----|----|----|
| 3.1 | `which claude opencode codex` | All three resolve (PATH promise — Lesson 3) | |
| 3.2 | `export ANTHROPIC_API_KEY=...` then `claude` | Claude Code starts, no npm/config fight | |
| 3.3 | In Claude: *"create a Flutter counter app in ~/demo and build it for iOS simulator"* | The agent works natively — reads files, runs `flutter build`. **This is the product moment. Rate it 1–10** | |
| 3.4 | `opencode --version` and `codex --version` | Both run (their key setup can be noted, not deep-tested) | |
| 3.5 | `macbridge activate MB-XXXX...` then `macbridge doctor --signing` | Activates → Pro; signing doctor gives an honest "no identity" diagnosis with Apple links | |

## Phase 4 — The prepared studio (target: ~15 min) · Promise: "walk into a studio, not a server"

| # | Do | Pass looks like | ⏱/notes |
|---|----|----|----|
| 4.1 | `bash ~/.macbridge/tooling/workspace-setup.sh` | Installs LaunchAgent + login hook without errors — **first real run** | |
| 4.2 | Open **DeskIn** → log out/in (or reboot via provider) | On the GUI desktop: **Terminal opens itself showing the 🟢 readiness screen; Simulator boots on its own** | |
| 4.3 | Sit back for 10 seconds | Gut check: does it feel like "a studio prepared for me" or "a server I'm administering"? **Write the sentence you'd tell a friend** | |
| 4.4 | New SSH session from Windows | The readiness screen greets the login shell too | |

## Phase 5 — Persistence (target: ~10 min) · Promise: "close the laptop; the agent keeps working"

| # | Do | Pass looks like | ⏱/notes |
|---|----|----|----|
| 5.1 | `tmux new -s macbridge`, start `claude` on a long task | Running | |
| 5.2 | Kill the Windows SSH window mid-task | — | |
| 5.3 | Phone → Termius → SSH in → `tmux attach -t macbridge` | **Same session, agent still working.** The Phase-0 magic, now on the shipped product | |
| 5.4 | Back on Windows, reattach | Same state | |

## Phase 6 — Bank the golden image (target: ~20 min) · Finishes S2

| # | Do | Pass looks like | ⏱/notes |
|---|----|----|----|
| 6.1 | `bash ~/.macbridge/tooling/golden-image.sh build --skip-bootstrap --version v3` | Gates on `verify` = ready; arranges workspace; writes manifest; tags version | |
| 6.2 | `sudo bash ~/.macbridge/tooling/golden-image.sh manifest` | JSON with real component versions | |
| 6.3 | **Provider console → snapshot** the Mac as `macbridge-golden-v3` | The "0 minutes" claim becomes real for the Managed tier | |
| 6.4 | (If Macly allows) provision a fresh instance **from the snapshot**, run only `macbridge status` | `ready` in ~3 min = the imagined UX, proven | |

## Phase 7 — Teardown + data (target: ~10 min)

| # | Do | Pass looks like | ⏱/notes |
|---|----|----|----|
| 7.1 | `bash ~/.macbridge/tooling/cleanup.sh --dry-run` then `--force` | Wipes user data, preserves toolchain, keys/API-keys gone | |
| 7.2 | Record: total active hours, total wall hours, rental cost | **S5 datum #1** — the first real usage measurement | |
| 7.3 | Note rental end time and release the Mac | 24h Apple floor respected (you held it the whole day) | |

---

## The scorecard (fill this in before ending the rental)

| Promise | Verdict (✅/⚠️/❌) | The one sentence you'd tell a friend |
|---|---|---|
| `brew install` → working CLI | | |
| One command → verified iOS workspace | | |
| Agent choice TUI felt right | | |
| "Type `claude` and it works" | | |
| The prepared studio at login | | |
| Phone reconnect / agent kept working | | |
| Honest doctor when something broke | | |
| **Would YOU pay $19–29 for this?** | | |

**Exit rule:** every ❌/⚠️ row becomes either a fix or a doctor rule before LemonSqueezy is
switched on. If ≥6 rows are ✅ including the last one — flip the runbook
(`commerce/README.md`) and start handing out keys.
