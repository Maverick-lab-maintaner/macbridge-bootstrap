# MacBridge — Build History

> **20 commits. 36 files. ~6,800 lines. One Mac needed to test — zero Macs needed to build.**

---

## Prologue: Phase 0 Validation (June 29, 2026)

Before a single line was written, the product was validated on a Macly M4 ($14.99/day). Two hours of manual provisioning produced **10 hard lessons** that became the architecture. Every lesson was earned through a real failure. None were theoretical.

**Sources:** 813-line provisioning journal (`Macly process.md`) + 1,040-line terminal log (`Maclyseverterminal.txt`).

| # | Lesson | Failure Mode | Encoded As |
|:---:|------|------------|------|
| 1 | Xcode requires GUI to install | SSH alone insufficient. App Store download needs DeskIn remote desktop. | `layer1-apple.sh` — verifies Xcode exists, provides GUI instructions if missing. Never attempts to install. |
| 2 | System Ruby 2.6 rejects CocoaPods | `sudo gem install cocoapods` failed with `ffi requires Ruby version >= 3.0. The current ruby version is 2.6.10.210.` | `layer2-dev.sh` — `brew install ruby` before CocoaPods. Version check at ≥3.0 gate. |
| 3 | PATH is part of provisioning, not an afterthought | Homebrew installed but `brew` not found. Ruby installed but `pod` not found. Installing ≠ executable. | Every layer — `ensure_path()` called after every install. `.zprofile` updated immediately, never deferred. |
| 4 | `~/.local` ownership breaks silently | `mkdir ~/.local/bin` failed with "Permission denied." Directory owned by root from earlier `sudo` install. Everything depending on `.local` broke silently. | `layer0-machine.sh` — ownership check on `.local`, `.ssh`, `.config` BEFORE any installation. Auto-fixes with `chown`. |
| 5 | GitHub password auth is dead | `git clone https://...` asked for password. GitHub no longer supports password authentication. | `layer2-dev.sh` — SSH keygen + `ssh -T git@github.com` verification. Public key displayed for manual GitHub upload. |
| 6 | SPM integration breaks on some Flutter plugins | `flutter build ios` failed with `public headers ("include") directory path for 'flutter_native_splash' is invalid`. Plugin doesn't support SPM. | `layer4-project.sh` — actual `flutter build ios --debug --no-codesign` smoke test. `flutter doctor` green ≠ build succeeds. |
| 7 | The provisioning IS the product — the Mac is a commodity | The 2-hour manual journey crystallized the insight: Macly, VPSMAC, MacStripe — any provider works. The knowledge of how to provision and verify is the IP. | Entire architecture. The bootstrap script is the product. The Mac is interchangeable hardware. |
| 8 | Verification at every layer — never assume | Multiple steps appeared to succeed but failed silently. Each failure discovered reactively, not proactively. | `install → verify → continue` pattern in every layer. Layer passes independently before the next begins. Failure is isolated. |
| 9 | User never sees provisioning — it all happens before login | The customer's journey: sign up → pay → receive "Ready" email → SSH in → start coding. Never the 2-hour setup. | Bootstrap runs before credentials are sent. Mac is not "allocated" until all health checks pass. User sees one word: "Ready." |
| 10 | One command should do everything — `bootstrap` | Phase 0 involved ~30 individual commands across 2 hours. Each required context, PATH knowledge, and troubleshooting. | `bootstrap.sh` — single entry point. Idempotent. Deterministic. `--from N` resume on failure. |

**Phase 0 also validated:**
- tmux session persisted across device switches (laptop → phone via Termius → laptop). Agent kept working unattended.
- Data persists across Macly timeouts. Stop/resume workflow proven.
- AI agents (Claude Code, OpenCode) confirmed working on cloud Mac. OpenCode found 6 iOS blockers in ShiftFlowr in ~3 minutes.
- Full toolchain confirmed: Xcode 26.6, Flutter 3.44.4, CocoaPods 1.16.2, Ruby 4.x.

**The biggest realization:** MacBridge is not a Mac rental. It's a **developer environment orchestration layer.** The Mac is a commodity. The knowledge of how to provision it — and verify it — is the product.

---

## Act I: The Core — Provisioning Pipeline

### Commit 1: `feat: add master orchestrator and health verification`
**Files:** `bootstrap.sh` (208 lines), `verify.sh` (222 lines), `.gitignore`, `logs/.gitkeep`
**Added:** 515 lines

**The reasoning:** Lesson 10 demanded one command. Lesson 8 demanded verification. These two scripts are the entry and exit of every provisioning session — bootstrap runs the layers, verify proves they worked.

**Architecture decision:** Both scripts designed to work standalone AND together. Bootstrap can `--from N` resume after layer failure. Verify is read-only, independent — runs on any Mac, provisioned by MacBridge or not. Trust but verify.

**The twist:** Verify supports `--quick` (critical paths only, ~5s), `--json` (machine-readable output), and full mode. Three modes for three use cases: CI health check, programmatic consumption, and human audit.

```
bootstrap.sh  ──runs──▶  Layer 0 → 1 → 2 → 3 → 4  ──audited by──▶  verify.sh
```

---

### Commit 2: `feat: add Layer 0-4 provisioning scripts`
**Files:** `lib/layer0-machine.sh` (152 lines), `lib/layer1-apple.sh` (161 lines), `lib/layer2-dev.sh` (238 lines), `lib/layer3-agents.sh` (207 lines), `lib/layer4-project.sh` (116 lines)
**Added:** 1,002 lines

**The architecture:** Five scripts, five gates. Each layer independently passes or stops. No partial state.

```
Layer 0: Machine Reachable
  ├── macOS check
  ├── Disk >50GB free (Lesson 4: ownership verification)
  ├── Network connectivity (ping 8.8.8.8 + 1.1.1.1)
  ├── HOME writable
  ├── Directory ownership (.local, .ssh, .config)
  ├── SSH enable + keepalive config (ServerAliveInterval 60)
  └── VNC status check

Layer 1: Apple Toolchain
  ├── Command Line Tools (xcode-select -p, auto-install via softwareupdate)
  ├── Xcode version + xcodebuild (Lesson 1: GUI-only install, golden image provides)
  ├── License acceptance (sudo xcodebuild -license accept)
  ├── First launch (sudo xcodebuild -runFirstLaunch)
  └── iOS Simulator runtime (xcrun simctl list, auto-download via xcodebuild -downloadPlatform)

Layer 2: Development Tools
  ├── Homebrew + PATH (Lesson 3: ensure_path, .zprofile update)
  ├── Ruby 4.x via Homebrew (Lesson 2: NOT system 2.6, version gate at ≥3.0)
  ├── Flutter SDK + flutter doctor
  ├── CocoaPods + PATH fix (gem bin directory discovery, multiple fallback paths)
  ├── Git + SSH keygen (Lesson 5: ed25519, public key display)
  ├── GitHub SSH verification (ssh -T git@github.com)
  └── GitHub CLI (gh — for Device Flow auth)

Layer 3: AI Agents
  ├── Node.js 22 (npm global bin PATH configuration)
  ├── Claude Code (npm install -g @anthropic-ai/claude-code)
  ├── OpenCode (npm install)
  ├── Codex CLI (npm/pip install)
  └── tmux + configuration (mouse mode, scrollback 50000, escape-time 10ms)

Layer 4: Smoke Test
  ├── flutter create test_app
  ├── flutter pub get
  ├── pod install (CocoaPods integration test)
  └── flutter build ios --debug --no-codesign (Lesson 6: actual build catches what flutter doctor misses)
```

**Key decisions:**

- Layer 1 never installs Xcode. Golden image provides it. This is a hard architectural boundary — App Store download requires GUI.
- Layer 2 installs Homebrew Ruby BEFORE CocoaPods. System Ruby 2.6 is a trap. The version check is a gate, not a warning.
- Layer 3 agents are optional — failed npm installs are warnings, not failures. User provides their own API keys.
- Layer 4 uses `--no-codesign` because code signing requires an Apple Developer account ($99/yr) — tied to a specific developer's identity. The smoke test proves the build pipeline works. Signing is the user's responsibility.
- Every layer follows `install → verify → continue`. Every verification is a `which` check or equivalent. Never assume.

---

### Commit 3: `feat: add session cleanup script`
**File:** `cleanup.sh` (220 lines)
**Added:** 258 lines

**The insight:** After the 24-hour Macly rental, cleanup was manual. Project clones, SSH keys, git config, agent configurations — all user data that must not leak to the next customer.

**What gets wiped:**
```
Projects:     rm -rf ~/projects/* ~/shiftflowr* ~/test_app*
SSH keys:     rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
Git config:   git config --global --unset user.name/email
Agent configs: ~/.claude.json, ~/.opencode.json, ~/.codex.json, ~/.config/claude|opencode|codex
Shell history: rm -f ~/.zsh_history ~/.bash_history + history -c
npm cache:    npm cache clean --force
tmux sessions: tmux kill-server
known_hosts:  rm -f ~/.ssh/known_hosts
Browser cache: ~/Library/Caches/com.apple.Safari
```

**What gets preserved (golden image state):**
```
Xcode 26.6, iOS Simulator runtime, Flutter SDK, CocoaPods + Ruby, Homebrew, Node.js 22, Agent CLI binaries, macOS system
```

**The twist:** Cleanup is also the first thing that runs when a NEW user gets the Mac. Not optional. Not "nice to have." A privacy liability if forgotten. Supports `--dry-run` (preview), `--force` (skip confirmation), and verifies toolchain preservation after wipe.

**When cleanup runs:**
| Trigger | Action |
|---------|--------|
| User clicks "Stop Mac" | Run cleanup → stop Mac |
| Rental expires (24h) | Run cleanup → reclaim Mac |
| User clicks "Reset Mac" | Run cleanup → re-run bootstrap → Mac ready |
| Mac provisioned for NEW user | Run cleanup automatically before first login |

---

## Act II: DevOps Toolchain

**Context:** The user shared a detailed DevOps concerns document. Seven concerns covering fleet management, secrets, networking, bootstrap failures, monitoring, provisioning automation, and update policy. All learned from experience — "you will be operating infrastructure, not just building an app."

### Commit 4: `feat: add shared utilities and centralized log shipping`
**Files:** `lib/_utils.sh` (152 lines), `bootstrap.sh` (modified, +`--report-to`)
**Added:** 201 lines

**The problem:** Bootstrap fails at 2am on a customer Mac. You have no log. You SSH in and find nothing. This happened in Phase 0 — Lesson 8 said "never assume." But you can't assume you'll be watching when a customer's Mac breaks.

**The solution:** A shared utility library with centralized logging.

```
_utils.sh provides:
  ┌─ Color output: GREEN, RED, YELLOW, CYAN, BOLD, NC
  │   Terminal detection — strips colors for non-TTY (piped output, cron)
  │
  ├─ Output helpers: step(), ok(), warn(), fail(), info(), header()
  │   Each increments PASS/FAIL/WARN counters
  │
  ├─ Logging: log() — timestamped file + stdout
  │
  ├─ Webhook reporting:
  │   report_to_webhook()  — POST JSON to MACBRIDGE_REPORT_URL
  │   report_event()       — structured event (type, status, detail, layer)
  │
  ├─ Utilities: ensure_path(), has(), version_of(), disk_free_gb(),
  │   memory_usage_pct(), ensure_machine_id(), print_banner(), print_summary()
  │
  └─ Initialization: mkdir -p logs, ensure_machine_id
```

**Bootstrap integration:**
```bash
bash bootstrap.sh --report-to https://dash.example.com/api/report
```
Every layer pass/fail ships a JSON event: `bootstrap_started`, `bootstrap_layer` (×5), `bootstrap_complete`. Machine ID, hostname, timestamp, status, detail. Central endpoint receives the full provisioning lifecycle.

**The twist:** The utility library is optional. Layer scripts have fallback color definitions — they work standalone without `_utils.sh`. You can SCP a single layer file to a Mac and run it without the whole repo. Deliberate modularity.

---

### Commit 5: `feat: add fleet health agent with JSON output and cron support`
**File:** `healthd.sh` (188 lines)
**Added:** 188 lines

**The concern:** "Is machine X responding? Is disk space running low? Did the health check pass? When did the customer last connect?" None of this exists out of the box. You build it.

**The architecture:**
```
Every Mac in the fleet:
  cron every 5 min ──▶ healthd.sh ──▶ 19 checks ──▶ JSON ──▶ POST to central

Output per check:
  {"key": "flutter", "label": "Flutter SDK", "status": "PASS", "value": "3.44.4"}

Overall:
  {"machine_id": "mac-m4-abc", "hostname": "macly-47",
   "timestamp": "2026-07-01T00:00:00Z", "overall": "healthy",
   "failed_count": 0, "checks": {...}}
```

**The 19 checks:**
| Category | Checks |
|----------|--------|
| System | Disk free (>50GB gate), system load |
| Apple Toolchain | Xcode installed, xcodebuild version, iOS Simulator runtime |
| Dev Tools | Homebrew, Flutter, Ruby, CocoaPods, Git, SSH keys, GitHub CLI |
| Agents | Node.js, Claude Code, OpenCode, Codex CLI, tmux |
| Connectivity | Network reachability (8.8.8.8), GitHub SSH authentication |

**The decision:** GitHub SSH is a WARN, not a FAIL. A Mac without GitHub access is still a functional build environment — the user just can't clone private repos. WARN vs FAIL distinction prevents false alarms.

**Usage:**
```bash
bash healthd.sh                                              # Once, JSON to stdout
bash healthd.sh --webhook https://dash.example.com/api/health  # Ship to central
bash healthd.sh --interval 300                                 # Daemon mode
bash healthd.sh --install-cron --webhook <url>                 # Auto every 5 min
```

---

### Commit 6: `feat: add firewall hardening for cloud Mac isolation`
**File:** `hardening.sh` (222 lines)
**Added:** 269 lines

**The question from the DevOps doc:** "What if a customer's machine gets compromised and starts attacking others?" Cloud Macs share a network. Provider firewalls exist but you can't trust them alone.

**The defense:**
```
1. Application Firewall:     enabled + stealth mode
2. PF (Packet Filter):       custom ruleset
   ├── block in all          (default deny inbound)
   ├── pass out all          (allow all outbound)
   ├── pass in on lo0        (loopback)
   ├── pass in proto tcp port {22, 5900}  (SSH + VNC only)
   └── pass in proto icmp    (monitoring ping)
3. LaunchDaemon:             /Library/LaunchDaemons/com.macbridge.pf.plist
                             PF rules persist across reboots
4. Disabled services:        AFP, SMB, FTP, Telnet
5. Verify SSH stays enabled: Critical — locking yourself out is unrecoverable
```

**Usage:**
```bash
bash hardening.sh              # Full lockdown (confirmation prompt)
bash hardening.sh --dry-run    # Preview without applying
bash hardening.sh --verify     # Read-only state check
```

**The twist:** The confirmation prompt — "Running remotely? Make sure SSH stays open or you will lose access." This isn't a warning, it's a save point. A remote Mac with no SSH access is bricked.

**Post-hardening state:** Only two ports open — SSH (22) and VNC (5900). Everything else blocked inbound. All outbound permitted.

---

### Commit 7: `feat: add Welcome Wizard, migration, and Windows provisioning`
**Files:** `welcome.sh` (188 lines), `migrate.sh` (175 lines), `provision.ps1` (160 lines)
**Added:** 771 lines

**The three pieces that complete the pipeline:**

#### welcome.sh — Stage 3: Welcome Wizard

The bootstrap ends with "🟢 MAC READY." Then what? The user stares at a terminal. The Welcome Wizard bridges the gap.

```
Step 0: Verify environment  — flutter, xcodebuild, pod, node, gh, tmux all present?
Step 1: GitHub Auth         — gh auth login (Device Flow, no password, no SSH key paste)
Step 2: AI Provider Keys    — Claude (Anthropic), OpenCode (OpenAI), Codex
Step 3: Project Clone       — Auto-clone or manual command
Step 4: tmux Session        — Attach to existing or create new
Summary:                     — Quick reference card with all commands
```

**The decision:** API keys go to the user's `.zprofile`, never stored on MacBridge servers. The user provides their own keys. MacBridge never sees them, never touches them.

#### migrate.sh — Update Policy Enforcement

**The policy (decided in Phase 0):** "Never force update a running customer environment."

```
migrate.sh:
  --check         → Show current vs latest golden image version
  --list          → Show all available golden images with toolchain descriptions
  --upgrade       → Apply latest upgrade (opt-in)
  --set-version   → Tag Mac with version (admin)

Upgrade flow:
  1. Back up user configs (~/.zprofile, .ssh/config, .tmux.conf)
  2. Apply new hardening rules if applicable
  3. Re-run verify.sh --quick
  4. Tag with new version
  5. Report: backup path, restore instructions
```

**Golden image versions:**
| Version | Contents |
|---------|----------|
| v1 | macOS 15 · Xcode 26.6 · iOS 26.5 Sim · Flutter 3.44.4 · CocoaPods 1.16.2 · Ruby 4.x · Node 22 · Agents + tmux |
| v2 | v1 + hardening.sh applied (PF firewall rules, LaunchDaemon persistence) |

#### provision.ps1 — Windows → Mac Bridge

You're on Windows. The Mac is a cloud IP. This script is the bridge.

```powershell
.\provision.ps1 -MacHost 203.0.113.47
.\provision.ps1 -MacHost 203.0.113.47 -Welcome -Hardening
.\provision.ps1 -MacHost 203.0.113.47 -ReportTo https://dash.example.com/api/report
```

**Flow:**
```
1. Validate SSH key exists
2. Test SSH connectivity
3. SCP entire macbridge-bootstrap directory to Mac
4. SSH in, run bootstrap.sh (streams output to Windows terminal)
5. Optional: run hardening.sh
6. Optional: run welcome.sh (interactive)
7. Save session info to ~/.macbridge/session.json
```

**The twist:** `session.json` persists connection details — no need to remember IP, user, or key path between sessions. Small detail, massive UX improvement.

---

## Act III: Public-Facing Product

### Commit 8: `feat: add landing page and update documentation`
**Files:** `landing/index.html` (567 lines), `README.md` (modified)
**Added:** 676 lines

**The design system:** Maverix Labs — dark cinematic, glassy panels, cyan signal accents.

| Token | Value | Role |
|-------|-------|------|
| `--surface-primary` | `#081017` | Canvas |
| `--surface-secondary` | `#0f1923` | Panels |
| `--surface-elevated` | `#132435` | Featured cards |
| `--text-primary` | `#edf4f7` | Headlines |
| `--text-secondary` | `#9eb6c7` | Body |
| `--text-tertiary` | `#72889b` | Metadata |
| `--accent-primary` | `#59e0d0` | CTAs, glow, signal |
| `--border-default` | `rgba(133, 209, 244, 0.18)` | Card borders |

**Typography:** Manrope (display + body), IBM Plex Mono (labels, versions, code). Google Fonts CDN.

**Page structure:**
```
Top Bar (sticky, glass-blur, cyan dot brandmark)
  │
Hero ("Ship your Flutter app to TestFlight. No Mac required.")
  │  Signal rail: Xcode 26.6 · Flutter 3.44.4 · Claude Code · OpenCode · Codex
  │
Problem/Comparison (2-hour pain vs 60-second MacBridge, side-by-side)
  │
How It Works (3-step cardless grid: Sign Up → Receive → Build)
  │
Environment (8-tool grid + 3 agent cards)
  │
Pricing (single tier, $19/mo)
  │
CTA Section (radial glow, signal rail)
  │
Footer (Maverix Labs, Phase 0 citation)
```

**Design discipline applied:**
- Cardless layouts, whitespace-driven rhythm
- No AI slop: no gradient backgrounds, no icon+blurb grids, no Inter/Roboto/Arial
- Every color traces to the approved palette
- Responsive: 480px / 768px / 1024px breakpoints
- Single-file HTML/CSS, Cloudflare Pages-ready

**The hero copy:** "Ship your Flutter app to TestFlight. No Mac required." Not "Rent a Mac." Not "Cloud macOS." The product is constraint removal, not infrastructure.

---

### Commit 9: `feat: add vanilla tier and two-tier pricing`
**Files:** `bootstrap.sh` (modified), `landing/index.html` (modified)
**Added:** 82 lines

**The twist:** The COST_BENEFIT_RISK_ANALYSIS designed two tiers but the code didn't reflect it. bootstrap.sh built everything — no way to skip agents.

**The fix:**
```bash
bash bootstrap.sh --tier vanilla   # Layers 0-2 + 4, skips Layer 3 (AI agents)
bash bootstrap.sh --tier agent     # All layers (default)
```

**What vanilla skips:**
- Layer 3: Node.js, Claude Code, OpenCode, Codex CLI, tmux
- Welcome Wizard Step 2: AI provider API key setup
- Success message: "Start coding: flutter run / flutter build ios" (not "claude / opencode / codex")

**Landing page update:**
| Tier | Price | Includes | Target |
|------|-------|---------|--------|
| Vanilla | $19/mo | Flutter-ready Mac. Xcode, CocoaPods, Simulator. No agents. | Traditional devs |
| Agent | $39/mo | Vanilla + Claude Code, OpenCode, Codex, tmux, skill library | Vibe coders |

Agent card gets featured treatment — `pricing-card-featured` class with `--depth-featured` border, `"Most Popular"` badge, and cyan glow.

---

### Commit 10: `feat: add skill library installer and tmux session launcher`
**Files:** `install-skills.sh` (223 lines), `tmux-launch.sh` (175 lines)
**Added:** 449 lines

#### install-skills.sh — The Differentiator

"No competitor offers 'Mac + pre-loaded Flutter skills.'" The AGENT_SKILL_LIBRARY.md listed 30+ specialist skills. This script installs them.

**5-tier skill taxonomy:**
```
Tier 1 — Ship Blockers (9 skills):
  dart-run-static-analysis, dart-resolve-package-conflicts, dart-fix-runtime-errors,
  flutter-code-gen, flutter-implement-json-serialization, generating-freezed-models,
  flutter-dio, flutter-fix-layout-issues, flutter-debugging

Tier 2 — Platform (6 skills):
  configuring-deep-links, configuring-codemagic, configuring-github-actions,
  deploying-with-fastlane, flutter-spm, xcode-project-setup

Tier 3 — Services (9 skills):
  integrating-firebase, firebase-auth-basics, firebase-firestore, firebase-crashlytics,
  firebase-remote-config-basics, integrating-supabase, integrating-sentry,
  integrating-revenuecat, integrating-google-ads

Tier 4 — Architecture (9 skills):
  flutter-apply-architecture-best-practices, flutter-state-management,
  implementing-riverpod, implementing-flutter-bloc, flutter-testing, flutter-ui,
  flutter-build-responsive-layout, applying-effective-dart, dart-use-pattern-matching

Tier 5 — Agent Workflow (9 skills, agent tier only):
  building-flutter-production-apps, flutter-native, flutter-security,
  running-flutter-isolates, persisting-data-with-drift, managing-hive-storage,
  managing-secure-storage, managing-shared-preferences, animating-flutter-widgets
```

**Discovery:** install-skills.sh discovers skills from the user's local machine (`~/.agents/skills/`, `~/.claude/skills/`, WSL paths). Copies to `~/.agents/skills/` on the Mac. AI agents (Claude Code, OpenCode, Codex) load skills from this directory.

#### tmux-launch.sh — Session Persistence, Automatic

**The workflow proven in Phase 0:** "Close laptop, commute, reconnect from phone. Agent kept working while I was away." Now automatic.

```bash
bash tmux-launch.sh --install     # Adds to .zprofile
bash tmux-launch.sh --agent claude # Prefer Claude on session create
bash tmux-launch.sh --uninstall   # Remove from .zprofile
```

**On SSH login:**
```
1. Check if inside existing tmux → skip (prevent nesting)
2. Check if interactive SSH session → skip for SCP/rsync
3. Detect available agents (claude, opencode, codex)
4. If macbridge session exists → attach
5. If not → create new session, auto-start preferred agent
6. Display: "Detach: Ctrl+B then D"
```

---

## Act IV: Quality Infrastructure

### Commit 11: `feat: add Cloudflare health receiver and brand design system`
**Files:** `dashboard/health-receiver.js` (130 lines), `wrangler.toml` (14 lines), `DESIGN.md` (112 lines)
**Added:** 309 lines

**The loop closure:** healthd.sh ships JSON. Now it has somewhere to land.

**Cloudflare Worker endpoints:**
```
POST /api/report       → Receive health check JSON, store in KV, track last_seen
GET  /api/status       → Fleet dashboard: healthy 🟢 / degraded 🔴 counts, per-machine table
GET  /api/status/:id   → Single machine detail JSON
```

**Fleet dashboard renders:**
```
MacBridge Fleet
  🟢 3 Healthy    🔴 1 Degraded    4 Total

  🟢  macly-47      healthy    0 failed    2026-07-01 12:05
  🟢  macstadium-12  healthy    0 failed    2026-07-01 12:04
  🟢  vpsmac-03      healthy    0 failed    2026-07-01 12:03
  🔴  macly-89       degraded   3 failed    2026-07-01 11:58
```

**DESIGN.md:** MacBridge brand design system — product frame, color tokens, typography (Manrope + IBM Plex Mono), component specs, motion rules. Derived from Maverix Labs design system, applied specifically to MacBridge.

---

### Commit 12: `feat: add release watchers, CI, and test harness`
**Files:** `lib/watcher-xcode.sh` (70 lines), `lib/watcher-flutter.sh` (75 lines), `.github/workflows/ci.yml` (55 lines), `test/run-tests.sh` (90 lines), `.gitignore` (modified)
**Added:** 413 lines

#### watcher-xcode.sh + watcher-flutter.sh — Maintenance Blind Spot

**The problem from MAINTENANCE_AGENT_ARCHITECTURE.md:** Xcode updates break Flutter environments overnight. How do you know?

**The solution:** Cron-installable watchers that monitor official release feeds.

```
watcher-xcode.sh:
  Data source: xcodereleases.com JSON API
  Stores known version in .cache/xcode-versions.txt
  Detects: new release → flags golden image rebuild needed

watcher-flutter.sh:
  Data source: Flutter releases JSON (storage.googleapis.com)
  Stores known version in .cache/flutter-versions.txt
  Detects: new stable release → flags rebuild within 48 hours
```

**Cron installation:**
```bash
bash lib/watcher-xcode.sh --install-cron     # Mondays at 6am
bash lib/watcher-flutter.sh --install-cron   # Mondays at 7am
```

#### .github/workflows/ci.yml — Quality Gate

```
On push/PR to master:
  Job 1: ShellCheck — lint all .sh files (ludeeus/action-shellcheck)
  Job 2: Syntax Validation — bash -n on every .sh file
  Job 3: Test Harness — run test/run-tests.sh
```

#### test/run-tests.sh — Local Validation

```
Test 1: Syntax — bash -n on every .sh file (find ... -name '*.sh' -print0)
Test 2: Help Output — each entry-point script returns 0 with --help
Test 3: Function Existence — key functions present in expected scripts
  (ensure_path, report_event, run_health_check, perform_upgrade, get_current_version)
```

---

### Commit 13: `feat: add Go CLI skeleton for Phase 1 provisioning`
**Files:** `go.mod`, `cmd/macbridge/main.go` (8 lines), `cmd/macbridge/commands/commands.go` (172 lines)
**Added:** 184 lines

**Phase 1 project structure:**
```
go.mod: module github.com/Maverick-lab-maintaner/macbridge-bootstrap
  Go 1.22, cobra v1.8.1 dependency

cmd/macbridge/main.go: Entry point → cobra root command

cmd/macbridge/commands/commands.go:
  ┌─ provision  →  API integration stub (Phase 2). Currently delegates to SSH.
  ├─ status     →  SSH + verify.sh --quick (pre-TUI)
  ├─ ssh        →  Interactive SSH with keepalive
  └─ stop       →  SSH + cleanup.sh --force
```

**Global flags:** `--host`, `--user`, `--key`, `--tier` (vanilla|agent), `--report-to`.

**Build:** `go build -o macbridge ./cmd/macbridge/`

---

### Commits 14-16: Landing page improvements + changelog + emails

**Commit 14:** `docs: add changelog and onboarding email templates`
- `CHANGELOG.md` — Golden image version history (v1, v2 with toolchain specs)
- `email/templates.md` — 4 onboarding emails with Handlebars variables

**Commit 15-16:** Landing page improvements by another agent — updated copy, OG tags, brand refinements.

---

## Act V: Polish & TUI

### Commit 17: `feat: add polish — Makefile, editorconfig, security headers, SEO, robots`
**Files:** `Makefile` (30 lines), `.editorconfig` (20 lines), `landing/_headers` (8 lines), `landing/robots.txt` (5 lines), `landing/index.html` (SEO additions)
**Added:** 294 lines

**Makefile:**
```
make test        → bash test/run-tests.sh
make lint        → shellcheck all .sh files
make check       → bash -n syntax check (no ShellCheck dependency)
make build       → go build -o macbridge ./cmd/macbridge/
make build-linux → GOOS=linux cross-compile
make clean       → remove binaries + .cache/
```

**Cloudflare `_headers`:**
```
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; ...
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**SEO additions (merged with other agent's OG tags):**
```
og:url, og:site_name, twitter:card (summary_large_image), twitter:title,
twitter:description, canonical URL
```

---

### Commit 18: `feat: add TUI dashboard to Go CLI status command`
**File:** `cmd/macbridge/commands/commands.go` (modified, +165 lines)
**Added:** 165 lines

**The MVP spec promised this.** The Go CLI's `status` command was a bare SSH + verify.sh call. Now it renders a proper terminal dashboard.

**Architecture:**
```
macbridge status --host 203.0.113.47
  │
  ├── SSH → healthd.sh on remote Mac → JSON output
  │
  ├── Parse JSON (dependency-free string matching — no encoding/json import)
  │   Extracts: machine_id, hostname, overall, failed_count
  │   Extracts nested: flutter.value, xcodebuild.value, ruby.value, etc.
  │
  └── Render ANSI box-drawn dashboard
```

**Rendered output:**
```
  ┌─────────────────────────────────────────────────┐
  │  🟢 Mac:    mac-m4-abc    (healthy)             │
  │  SSH:    admin@203.0.113.47                     │
  │  Host:   macly-47                               │
  │                                                 │
  │  Flutter:    3.44.4       ✅                    │
  │  Xcode:      26.6         ✅                    │
  │  Ruby:       4.0.5        ✅                    │
  │  CocoaPods:  1.16.2       ✅                    │
  │  Node.js:    22.5.1       ✅                    │
  │  Disk:       128GB        ✅                    │
  │                                                 │
  │  Claude:  ✅  OpenCode: ✅  Codex: ✅           │
  │                                                 │
  │  Health:  healthy (0 failed checks)             │
  └─────────────────────────────────────────────────┘
```

**Fallback:** If healthd.sh is not available on the remote Mac, falls back to `verify.sh --quick` with raw output.

**The twist:** The JSON parser is dependency-free — no `encoding/json` import. Crude string matching. Keeps the binary small and avoids Go module dependency sprawl. The trade-off is less robust parsing, but the healthd JSON format is controlled and predictable.

---

## The Architecture, Visualized

```
                    ┌──────────────────────────────┐
                    │     Golden Image (v2)         │
                    │  Built once via GUI (DeskIn)  │
                    │  Xcode + Sim pre-installed    │
                    │  Hardened firewall baseline   │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │      bootstrap.sh             │
                    │  Layer 0 → 1 → 2 → 3 → 4     │
                    │  --tier vanilla | agent       │
                    │  --report-to <webhook>        │
                    │  --from N (resume on failure) │
                    └──────────────┬───────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
┌───────▼──────┐          ┌───────▼──────┐          ┌───────▼──────┐
│  welcome.sh  │          │ hardening.sh │          │  healthd.sh  │
│  Stage 3     │          │  PF firewall │          │  Cron every  │
│  GitHub auth │          │  22+5900 ok  │          │  5 min → JSON│
│  AI key setup│          │  LaunchDaemon│          │  19 checks   │
│  Project clone│         │  Stealth mode│          │  Webhook POST│
│  tmux session│          └──────────────┘          └───────┬──────┘
└──────────────┘                                           │
                                              ┌────────────▼──────────┐
                                              │  Cloudflare Worker     │
                                              │  /api/report (receive) │
                                              │  /api/status (fleet)   │
                                              │  KV storage            │
                                              └───────────────────────┘

                    ┌──────────────────────────────┐
                    │        Supporting Cast        │
                    ├──────────────────────────────┤
                    │  migrate.sh     — Version mgmt│
                    │  cleanup.sh     — Session wipe│
                    │  verify.sh      — Health audit│
                    │  install-skills.sh — 30+ skills│
                    │  tmux-launch.sh — Auto-attach │
                    │  watcher-xcode.sh — Release RSS│
                    │  watcher-flutter.sh — Release RSS│
                    │  provision.ps1  — Windows→Mac │
                    ├──────────────────────────────┤
                    │  Go CLI         — macbridge   │
                    │  .github/ci.yml — Lint+Test   │
                    │  test/run-tests.sh — Harness   │
                    │  Makefile       — Build system│
                    │  landing/       — Public site │
                    │  dashboard/     — Fleet view  │
                    │  email/         — Onboarding  │
                    └──────────────────────────────┘
```

---

## The Product Stack — Three Layers

### Layer 1: Provisioning (What the customer never sees)
```
bootstrap.sh → Layer 0-4 → verify.sh → 🟢 MAC READY
welcome.sh → GitHub + AI keys + project clone
cleanup.sh → Wipe between users
migrate.sh → Golden image updates
install-skills.sh → 30+ Flutter/Firebird/iOS skills
hardening.sh → Firewall lockdown
```

### Layer 2: Operations (What keeps the fleet alive)
```
healthd.sh → cron every 5 min → JSON → Cloudflare Worker
watcher-xcode.sh + watcher-flutter.sh → Release RSS → Rebuild flags
CI (ShellCheck + syntax + test harness) → Quality gate on every push
provision.ps1 → Windows → SCP → SSH → bootstrap
Go CLI → macbridge provision | status | ssh | stop
```

### Layer 3: Public-Facing (What customers see)
```
landing/index.html → Cloudflare Pages
landing/_headers → Security headers
landing/robots.txt → SEO
email/templates.md → Onboarding emails (4 templates)
DESIGN.md → Brand design system
CHANGELOG.md → Version history
```

---

## Commit Timeline

```
aa3e418  feat: add master orchestrator and health verification          (+515)
9669832  feat: add Layer 0-4 provisioning scripts                       (+1002)
3bdf546  feat: add session cleanup script                               (+258)
3e1f77e  feat: add shared utilities and centralized log shipping        (+201)
b04f525  feat: add fleet health agent with JSON output and cron         (+188)
a7432b3  feat: add firewall hardening for cloud Mac isolation           (+269)
7d19282  feat: add Welcome Wizard, migration, and Windows provisioning  (+771)
80f37fc  feat: add landing page and update documentation                (+676)
6ae19e6  feat: add vanilla tier and two-tier pricing                    (+82)
32c5ae4  feat: add skill library installer and tmux session launcher    (+449)
4af4771  feat: add Cloudflare health receiver and brand design system   (+309)
8229090  feat: add release watchers, CI, and test harness               (+413)
a41eae0  docs: add changelog and onboarding email templates             (+182)
836c4be  feat: add Go CLI skeleton for Phase 1 provisioning             (+184)
4485f1e  feat: add polish — Makefile, editorconfig, headers, SEO       (+294)
fa32a6f  feat: add TUI dashboard to Go CLI status command              (+165)
d0fadd1  chore: normalize shell scripts                                 (+7)
──────────────────────────────────────────────────────────────────────────────
Total: 20 commits, 36 files, ~6,800 lines
```

---

## Act VI: Architecture Hardening — Shared Operational Contract

**Source:** Post-implementation audit. The repo had the right primitives — layered bootstrap, independent verification, fleet health shipping, a thin Go CLI. The missing architecture was not "more scripts." It was a **shared operational contract** across those scripts and a small seam for provider orchestration.

### Status Contract (`lib/status-contract.sh`)

**The problem:** verify.sh, healthd.sh, and the Go CLI each had their own output format. The dashboard assumed binary healthy/degraded. The CLI had a crude string-matching JSON parser. Every tool spoke a different language.

**The fix:** A canonical JSON schema (`contract_version: "1"`) shared by every tool in the system.

```
Before:
  verify.sh  →  custom text output
  healthd.sh →  similar-but-different JSON
  Go CLI     →  crude string-matching grep
  Dashboard  →  assumed binary healthy/degraded

After:
  verify.sh  ──┐
  healthd.sh ──┼──▶  status-contract.sh  ──▶  Unified JSON schema
  doctor.sh  ──┘      (contract_version: "1")
                │
                ├──▶  Go CLI (encoding/json struct parsing)
                └──▶  Dashboard (three-state model)
```

**The three-state model:**
| State | Condition | Meaning |
|-------|-----------|---------|
| `ready` | Zero critical failures | Environment production-ready |
| `degraded` | Non-critical failures or warnings | Works but needs attention |
| `blocked` | ≥1 critical failure | Cannot be used until repaired |

**The schema includes:**
- `provider` — name, kind, host (for multi-provider fleet tracking)
- `telemetry` — source, session ID, usage log path
- `summary` — state, checks_passed/failed/warn, critical_failed, next_action
- `checks` — per-check: label, status (PASS/WARN/FAIL), severity, value

**The severity model:** Each check has a severity — `critical` (blocks readiness), `advisory` (informational only). Critical failures trigger `blocked` state. Advisory warnings trigger `degraded`.

### Doctor + Rules (`doctor.sh` + `lib/doctor-rules.json`)

**The problem:** verify.sh told you WHAT failed. You had to know WHY and HOW to fix it. That knowledge lived in your head and the 10 Phase 0 lessons in markdown. A new operator facing a failed check had no path to resolution.

**The fix:** Institutional knowledge made executable. `doctor.sh` takes verify.sh JSON output, cross-references 15+ rules in `doctor-rules.json`, and outputs specific remediation steps per failing check.

```
$ bash doctor.sh

🔴 disk_50gb — Disk headroom is too low for reliable builds
   → Run `bash cleanup.sh --dry-run` to see reclaimable user data.
   → Run `bash cleanup.sh --force` if the machine can be reset.
   → Increase the VM disk allocation if cleanup is not enough.

🔴 xcode_app — Xcode is missing from the machine image
   → Install Xcode in the golden image through the GUI once.
   → Re-run `bash bootstrap.sh --from 1` after installation completes.

⚠️  github_ssh — GitHub SSH is not configured
   → Run `bash welcome.sh` to authenticate with GitHub Device Flow.
   → Or manually: gh auth login --hostname github.com --web.
```

**Rule structure:**
```json
{
  "id": "disk_50gb",
  "title": "Disk headroom is too low for reliable builds",
  "severity": "critical",
  "fix": [
    "Run `bash cleanup.sh --dry-run` to see reclaimable user data.",
    "Run `bash cleanup.sh --force` if the machine can be reset.",
    "Increase the VM disk allocation if cleanup is not enough."
  ]
}
```

**The decision:** Rules are JSON, not embedded in shell. Operators can add new rules without touching code. As new failure modes are discovered, the rules file grows. The 10 Phase 0 lessons become a living, executable knowledge base.

### Go CLI Restructure

**The problem:** `commands.go` was 172 lines in one monolithic file. The status command had a crude string-matching JSON parser — fragile, untyped, no error handling for malformed output. The provision command had hard-coded copy-paste instructions.

**The fix:** Proper Go package architecture.

| Before | After |
|--------|-------|
| `commands.go` (172 lines) | 5 files, clean separation |
| Crude string-matching grep | `encoding/json` struct parsing |
| Hard-coded SSH instructions | Provider interface + `BuildProvisionPlan()` |

**New file structure:**
```
cmd/macbridge/commands/
├── root.go          — Cobra root + global flags (--host, --user, --key, --tier, --report-to)
├── provision.go     — Provider-backed provisioning plan
├── status.go        — Real JSON parsing + status TUI + doctor subcommand
├── remote.go        — SSH helpers (runSSHCommand, runSSHOutput, hostRequired)
└── lifecycle.go     — Stop, cleanup, resume lifecycle operations
```

**Status command upgrade:**
```go
// Before: fragile string matching
extract := func(key string) string { ... crude grep ... }

// After: proper Go structs
type statusReport struct {
    MachineID   string                 `json:"machine_id"`
    Overall     string                 `json:"overall"`
    FailedCount int                    `json:"failed_count"`
    Checks      map[string]statusCheck `json:"checks"`
    Summary     struct {
        State      string `json:"state"`
        ChecksWarn int    `json:"checks_warn"`
    } `json:"summary"`
    Provider    struct { Name string; Kind string } `json:"provider"`
}
var report statusReport
json.Unmarshal(raw, &report)
```

**New `macbridge doctor` subcommand:** Remote invocation of `doctor.sh` via SSH. `macbridge doctor --host 203.0.113.47` runs the full remediation pipeline on the target Mac.

### Provider Abstraction (`internal/providers/`)

**The problem:** The original `provision` command baked in manual SSH assumptions — "scp this, ssh that, run bootstrap." No way to swap cloud Mac providers. No API integration seam.

**The fix:** A provider interface with `BuildProvisionPlan()`. The CLI calls `providers.DefaultProvider()` which returns a plan with `CopyCommand`, `BootstrapCommand`, `Notes`, and `ProviderName`. Today it returns manual SSH instructions. Tomorrow, a `MaclyProvider` or `VPSMACProvider` implements the same interface — the CLI doesn't change.

```go
// Today — manual provider
plan := providers.DefaultProvider().BuildProvisionPlan(providers.ProvisionRequest{...})
// plan.CopyCommand    → "scp -r . admin@203.0.113.47:~/macbridge-bootstrap"
// plan.BootstrapCommand → "ssh admin@203.0.113.47 'cd ~/macbridge-bootstrap && bash bootstrap.sh'"

// Tomorrow — API provider
plan := providers.MaclyProvider(apiKey).BuildProvisionPlan(...)
// plan.CopyCommand    → "" (API handles upload)
// plan.BootstrapCommand → "" (API triggers bootstrap server-side)
```

### Telemetry + Dashboard Upgrade

**Before:** `healthd.sh` shipped JSON to a webhook. If the webhook was down or network failed, the event was lost. No local record.

**After:** Dual-write telemetry. Events ship to webhook AND append to a local NDJSON log (`logs/usage-events.ndjson`). Durable, replayable. Operators can audit a Mac's health history even if the central dashboard was unreachable during an incident.

**Dashboard upgrade:** The Cloudflare Worker's fleet view now understands the three-state model. Machines are `ready` 🟢, `degraded` 🟡, or `blocked` 🔴 — not just the old binary `healthy`/`degraded`. A machine with a missing Xcode is `blocked`, not merely `degraded`. This distinction drives operational priority.

### What This Changed

The repo is still shell-first — the correct choice for this stage. The improvement is that it now has a **clear control plane**: verification is canonical, status semantics are explicit, remediation is encoded, telemetry is durable locally, and the Go CLI has an actual provider seam instead of hard-coded provisioning copy.

```
Before Act VI:
  Scripts that worked independently but didn't share a language.
  Knowledge lived in markdown and operator experience.

After Act VI:
  Scripts that share a contract. Knowledge lives in executable rules.
  Three explicit states. Provider abstraction. Durable telemetry.
  The same architecture that Railway and Render built at this stage.
```

---

## What's Not Here (And Why)

| Component | Status | Why Not |
|-----------|:---:|------|
| Provider API integration | ❌ | Needs Macly/VPSMac API credentials. Go CLI `provision` command is stubbed. |
| Golden image snapshot | ❌ | Needs actual Mac + GUI (DeskIn) to install Xcode from App Store. One-time manual step. |
| Bootstrap field test | ❌ | Needs a clean Mac to run end-to-end. Scripts encode proven Phase 0 commands but unverified as automated pipeline. |
| LemonSqueezy checkout | ❌ | Needs account setup. Pricing cards exist on landing page. |
| macOS-specific testing | ❌ | All scripts built and validated for syntax. Runtime testing requires macOS. |
| Go binary compilation | ❌ | `go.mod` + source written. Needs `go build` with toolchain installed. |

**Everything that can be built without a Mac is built.** The only remaining gates are hardware-dependent: provisioning a Mac, running the scripts, and integrating with a provider API.

---

## Act VII: Product Surface Hardening + CLI Status Repair

**Context:** The repo had crossed an important threshold. It was no longer just bootstrap scripts plus a README. It now had a public landing page, a shared design system, comparison guides, and a Go CLI with a terminal status surface. The missing work was no longer feature count. It was **credibility, consistency, and maintenance discipline**.

Three issues emerged together:

1. The landing page looked strong, but still had dead-end CTA behavior and some product messaging that leaned too close to internal bootstrap posture.
2. The blog/guides were useful, but some comparison and pricing claims were too time-sensitive to be treated as stable copy.
3. The Go CLI "TUI" for `macbridge status` could misreport quick-mode omissions as failures.

### Landing Page Redesign + UX Tightening

**Files:** `landing/index.html`, `DESIGN.md`

The landing page was rebuilt around the actual product claim:

> iOS builds from Windows, without buying or babysitting a Mac.

**The visual decision:** move from "nice repo microsite" to a more deliberate product surface. The page now uses a dark blue-green command-center palette, restrained cyan signal accents, strong display typography, glass panels, and a console-style environment block. The design system for that direction was codified in `DESIGN.md` so the site stopped depending on implicit taste decisions.

**The copy decision:** remove internal provisioning leakage and focus on the buyer-facing value:
- no Mac purchase,
- no first-day Xcode setup,
- a prepared cloud macOS environment,
- a path to TestFlight,
- agent-assisted development as part of the workflow.

**The UX pass** then fixed the parts that still felt unfinished:
- dead CTA behavior was replaced with a real contact/intake path,
- a dedicated contact/next-step section was added,
- mobile utility navigation became explicit instead of vanishing,
- footer utility links were added,
- skip link, focus states, and social meta tags were tightened.

**The important product decision:** the UI stopped pretending a dedicated signup backend already existed. The current intake path now points to the GitHub repo / issue flow instead of a fake destination.

### Shared Stylesheet Consolidation

**Files:** `landing/index.html`, `landing/assets/site.css`

The homepage and blog had drifted into an avoidable maintenance split:

```
landing/index.html      → private inline stylesheet
landing/blog/*.html     → /assets/site.css
```

This meant a visual fix could land in one surface but not the other.

**The fix:** the homepage now imports `/assets/site.css` directly. The shared stylesheet became the real source of truth for the public web surface, while the article/blog rules remain additive rather than forked into a second visual system.

### Blog / Guide Credibility Pass

**Files:**  
`landing/blog/index.html`  
`landing/blog/flutter-ios-without-a-mac.html`  
`landing/blog/macbridge-vs-codemagic.html`  
`landing/blog/macbridge-vs-cloud-mac-rental.html`

The guides were already product-relevant and technically useful, but several passages used exact vendor pricing and plan details in a way that would age badly.

**The correction:** move from "fixed-price certainty" to "snapshot / representative range / verify current rates" framing.

Examples of the change:
- Codemagic pricing language now reads as a dated snapshot, not a canonical price sheet.
- MacBridge early-access pricing is explicitly described as provisional beta positioning.
- Comparison tables now tell readers to verify current limits and rates instead of freezing exact tiers into evergreen copy.
- The guide index lead-in was softened so the blog reads more like a practical reference library than a static rate card.

**The editorial decision:** keep the commercial point of view, but stop overstating certainty where vendor pricing or hardware tiers can move underneath the content.

### Go CLI Status / TUI Repair

**File:** `cmd/macbridge/commands/status.go`

The "TUI" turned out not to be a full interactive terminal application. It was a structured text status renderer behind:

```bash
macbridge status --host <mac> --user <user> --key <key>
```

**The bug:** `status` shells into the Mac and runs:

```bash
bash verify.sh --json --quick
```

But `--quick` intentionally skips some checks. The original Go code treated any missing check as:

```go
FAIL
```

That meant the status surface could show false failures simply because quick mode omitted a check.

**The fix:** missing quick-mode checks now render as `SKIP`, not `FAIL`.

While that functional bug was being fixed, the dashboard was upgraded into a more readable terminal surface:
- structured sections (`Connection`, `Core toolchain`, `Agent surface`, `Attention`, `Next action`)
- stable issue collection and ordering
- explicit warning / failure badges
- provider and host summary
- use of the JSON contract already emitted by `verify.sh`

This kept the CLI dependency-light while making the status surface materially more trustworthy.

### Go Toolchain Clarification

**Context:** An earlier verification attempt reported that `go` was unavailable. The real issue was shell PATH visibility in the Windows environment used for that command, not a missing Go installation.

**What was later verified directly:**

```powershell
C:\Program Files\Go\bin\go.exe version
C:\Program Files\Go\bin\go.exe test ./...
```

Results:
- Go is installed and usable.
- `go test ./...` passed in `macbridge-bootstrap`.

**The real conclusion:** there was no repository-level Go failure. The issue was operational shell configuration, not Go source or module health.

### What This Changed

Before this pass:
- the landing page looked promising but still had dead ends and duplicated styling,
- some guide content was more sales-certain than durable,
- the CLI status surface could misreport omitted checks as failures,
- and the Go toolchain looked broken when it was actually just hidden from one shell.

After this pass:
- the public web surface reads more like a product and less like an internal provisioning artifact,
- the homepage and guides share one stylesheet,
- comparison copy is more credible over time,
- the status TUI is more trustworthy,
- and the Go situation is clarified: installed, testable, not a blocker.

---

## Act VIII: Windows Bring-Up, LSP Recovery, and the Difference Between Architecture and Runtime

**Context:** After the architectural work was documented in `c10834a` and the repo looked structurally stronger on paper, a more practical question followed:

> Is the Windows side actually ready before testing on a real Mac?

That question forced a second kind of validation. The problem was no longer "is the design coherent?" It was:

1. does the Windows operator surface really execute,
2. do the local toolchains actually resolve under Codex/OpenCode,
3. does the repo behave the same way under shell, Go, PowerShell, and LSP scrutiny,
4. and do the docs claim more than the implementation currently proves?

This pass exposed one of the most important lessons in the whole project:

> A repo can have the right architecture and still fail at the last inch because of transport, path, quoting, or shell-runtime details.

### The First Failure: LSP Was "Configured" but Not Actually Usable

The first runtime failure was not in repo code. It was in the Codex-side MCP configuration.

Codex would not start:

```text
Error loading config.toml: invalid transport
in `mcp_servers.lsp`
```

**The cause:** a top-level `[mcp_servers.lsp]` block had been added with only:

```toml
[mcp_servers.lsp]
startup_timeout_sec = 120
```

That looked harmless, but an MCP server definition without a `command` or `url` is invalid. The whole Codex config failed to load.

**The fix happened in two stages:**

1. first, complete the block into a valid server definition so Codex could boot again;
2. then remove the brittle version-pinned plugin path and replace it with a stable wrapper command.

The durable fix was:

```toml
[mcp_servers.lsp]
command = "C:\\Users\\MAVERIX\\.codex\\bin\\codex-lsp-latest.cmd"
startup_timeout_sec = 120
```

That wrapper script dynamically resolved the newest installed OMO plugin version instead of hardcoding `4.13.0`.

**What this taught:** a timeout override is not free-standing configuration. If you surface a top-level MCP server, you own the full transport definition.

### The Second Failure: `gopls` Was Installed But Still "Missing"

After the transport was fixed, `mcp__lsp.status` came back, but reported:

```text
- gopls: missing
```

even though `gopls.exe` was present and runnable.

**The actual state on disk:**
- `C:\Program Files\Go\bin\go.exe` existed
- `C:\Users\MAVERIX\tools\go\bin\go.exe` existed
- `C:\Users\MAVERIX\go\bin\gopls.exe` existed
- `gopls version` returned `golang.org/x/tools/gopls v0.22.0`

**The problem was not installation.** It was discovery by the already-running LSP daemon.

The daemon had started with an older process `PATH`, so the shell and the MCP did not agree about what "installed" meant.

**The fix:** add a user-level LSP client override:

```json
{
  "lsp": {
    "gopls": {
      "command": [
        "C:\\Users\\MAVERIX\\go\\bin\\gopls.exe"
      ],
      "extensions": [
        ".go"
      ]
    }
  }
}
```

in:

```text
C:\Users\MAVERIX\.codex\lsp-client.json
```

After that, `mcp__lsp.status` reported:

```text
- gopls: installed; source=user; extensions=.go
```

and later showed an active `gopls` client.

**What this taught:** installation state and daemon-resolution state are separate systems. When an agent says "installed," that is not proof the live daemon can execute the binary.

### The Third Failure: LSP Warnings Looked Like Go Errors But Weren't

Once `gopls` was active, diagnostics on files like:

- `cmd/macbridge/commands/provision.go`
- `internal/providers/providers.go`

showed:

```text
warning[go list] at 1:8: No active builds contain ...
```

That warning first looked like a repo-level breakage. It was not.

Direct toolchain verification from the module root showed:

```powershell
C:\Program Files\Go\bin\go.exe list ./...
C:\Program Files\Go\bin\go.exe test ./...
```

Both passed.

**Conclusion:** the repo was valid; the warning was a `gopls` workspace-root integration quirk in this environment, not a broken module.

This distinction mattered because it prevented a fake fix. The right response was to record the warning as non-blocking, not to change valid Go code to satisfy a transport artifact.

### The Fourth Failure: The Real Windows Blocker Was `provision.ps1`

The architectural audit of the Windows side surfaced the real operator-facing failure:

```text
provision.ps1 does not parse as valid PowerShell
```

The initial parser errors pointed at:

```powershell
& ssh -t @sshOpts "$User@$MacHost" "cd $RemoteDir && bash welcome.sh"
```

This looked like one bug. It was actually several overlapping bugs.

#### Failure mode 1: Invalid splatting form

PowerShell did not accept:

```powershell
& ssh -t @sshOpts ...
```

The `-t` flag and the splatted array had to be composed into one argument array.

#### Failure mode 2: Interpolation ambiguity

Strings like:

```powershell
"$User@$MacHost"
```

caused parse trouble under this host. They had to be normalized to explicit formatting or array-built arguments.

#### Failure mode 3: Literal `&&` in command strings

This was the least obvious one. Even apparently quoted strings containing:

```text
&&
```

were rejected by the local PowerShell parser in the way the script had been written. This affected lines such as:

```powershell
"cd $RemoteDir && bash welcome.sh"
```

and even user-facing summary strings showing example commands.

#### Failure mode 4: mojibake/encoding contamination

The file contained mixed Unicode/mojibake output from prior editing:
- smart punctuation
- box-drawing glyphs
- arrows
- emoji-like banner characters

That made line-by-line repair harder because parse errors did not always point at the true semantic issue.

### The Real Fix: Rewrite the Windows Bridge Cleanly

After several targeted repairs exposed new parser issues, the correct move was not another micro-patch. It was a clean rewrite of `provision.ps1` into a plain ASCII PowerShell script with:

- consistent `admin` default user
- argument-array based `ssh` and `scp` helpers
- explicit runtime failure paths
- session persistence to `~/.macbridge/session.json`
- optional `-Welcome`, `-Hardening`, and `-ReportTo`
- remote commands using `;` instead of `&&`

The final structure used helper functions:

```powershell
function Run-Ssh { ... }
function Run-Scp { ... }
function Fail-Step { ... }
```

and built all remote commands through those helpers instead of inline ad hoc invocations.

**Verification surface changed too:**
- before: the script failed at parse time
- after: it parsed cleanly and reached runtime validation, failing correctly on a fake key with:

```text
SSH key not found: C:\definitely-missing-key
```

That is a much more meaningful failure. It proves the script is executable and now fails only on real operator input.

### The Fifth Failure: Windows and Go Were Drifting Apart

The repo now had two provisioning surfaces:

1. `provision.ps1`
2. `macbridge provision`

Those surfaces were not aligned.

#### Drift 1: default SSH user

PowerShell used the local Windows username by default.

The Go CLI used:

```go
RootCmd.PersistentFlags().StringVar(&macUser, "user", "admin", ...)
```

That mismatch meant the same operator could be told two different defaults depending on entrypoint.

**Fix:** standardize the PowerShell script on `admin`.

#### Drift 2: `--report-to` was exposed but not propagated

The Go CLI had:

```go
RootCmd.PersistentFlags().StringVar(&reportTo, "report-to", "", ...)
```

but the manual provider plan ignored it.

That meant the CLI advertised centralized reporting while only the PowerShell path actually supported it.

**Fix:** extend `ProvisionRequest` with:

```go
ReportTo string
```

and thread it into the provider plan so the remote bootstrap command became:

```text
ssh ... 'cd ~/macbridge-bootstrap; bash bootstrap.sh --tier agent --report-to "https://..."'
```

instead of appending `--report-to` outside the remote quoted command, which would have been semantically wrong.

### The Sixth Failure: "Docs Done" and "Runtime Done" Were Not the Same Milestone

At this point the repo had two adjacent commits with very different meanings:

| Commit | Meaning |
|------|------|
| `c10834a` | The control-plane architecture is documented and explained |
| `022d75f` | The implementation, Windows bridge, provider seam, and public/docs surfaces are actually wired together |

This distinction matters.

The earlier commit was not "wrong." It accurately described the architecture. But it was ahead of the runtime proof for one critical surface: Windows provisioning.

The next commit was the one that made the docs true in practice.

### Exact Toolchain Used In This Pass

This pass was instructive because it was not solved by one language or one tool. It required cross-checking the same behavior through multiple surfaces.

#### Shell and script verification

- `bash -n bootstrap.sh verify.sh doctor.sh migrate.sh healthd.sh hardening.sh welcome.sh cleanup.sh lib/*.sh`
- `verify.sh --json --quick`
- `doctor.sh`

#### Go verification

- `C:\Program Files\Go\bin\go.exe version`
- `C:\Program Files\Go\bin\go.exe list ./...`
- `C:\Program Files\Go\bin\go.exe test ./...`
- `gofmt.exe -w ...`

#### PowerShell verification

- PowerShell parser checks through `System.Management.Automation.Language.Parser`
- `powershell -NoProfile -ExecutionPolicy Bypass -File provision.ps1 ...`

#### LSP and editor-surface verification

- `mcp__lsp.status`
- `mcp__lsp.diagnostics`
- `typescript-language-server`
- `bash-language-server`
- `@biomejs/biome`
- `gopls`

#### Git and release verification

- `git status`
- `git diff --staged --stat`
- `git show --stat`
- `git push origin master`
- GitHub combined status check on the relevant commit

### What This Changed

Before this pass:
- the repo had a credible architecture but an unreliable Windows operator surface,
- `gopls` was on disk but not visible to the live LSP daemon,
- LSP warnings were easy to misread as code failure,
- and the two provisioning entrypoints were not behaviorally aligned.

After this pass:
- the Codex LSP transport was valid again,
- Go LSP resolution was explicit and stable,
- PowerShell provisioning was parser-safe and runtime-safe,
- the Go manual-provider path propagated reporting correctly,
- the Windows default user was consistent,
- and the difference between architectural truth and runtime truth was recorded explicitly.

### The Operational Lesson

This act sharpened a final lesson that belongs next to the original 10 Phase 0 lessons:

> In infrastructure products, the last 5 percent is usually transport, path, quoting, encoding, and daemon state.  
> That 5 percent is not polish. It is the product becoming real.

---

## Act IX: MacBridge Radar, PACER Framing, and Turning Outbound Discovery Into an Internal Operator Tool

**Context:** After the Windows control plane was stabilized, the next question was not provisioning. It was growth:

> Can MacBridge detect people who already have the exact pain it solves, and help draft the right reply without becoming a spam bot?

That question produced a new subproject: `ops/radar/`.

The work moved through three distinct phases:

1. a PACER-based strategy note so the idea could be reasoned about clearly,
2. a Phase 1 listening-only prototype,
3. a Phase 2/3 review workflow with drafts and a local board.

### PACER Was the Right Lens

The PACER doc became the first learning artifact for this work:

- `LEAD_INTEL_PACER.md`

It explained the idea in beginner language and separated the concept into:

- `C` conceptual: the system listens for real pain signals
- `P` procedural: collect -> classify -> score -> draft -> approve -> post -> learn
- `A` analogous: Agent Reach is to web/platform access what Radar is to market listening
- `E` evidence: Agent Reach proves the access/fallback/doctor pattern works
- `R` reference: queries, templates, and exact commands belong in the operational layer

That distinction mattered because the system would otherwise collapse into one of two bad extremes:

- theory without an implementation path
- implementation without a clear operating model

PACER kept the work honest.

### Replymer Was Useful, But Not the Same Thing

The comparison target was `Replymer`.

What Replymer appears to do:

- monitor public conversations
- identify relevant posts
- draft replies
- in some cases offer managed posting or review workflows

What MacBridge Radar became:

- an internal founder tool
- a listening and triage system
- a reply-drafting system
- a review queue with explicit approval state
- a local board for human review

The difference is not cosmetic.

Replymer is closer to an outward-facing engagement service.
MacBridge Radar is a founder-controlled operator tool.

That choice was deliberate because the user-facing risk is real:

- blind auto-replies get ignored
- mass outreach gets flagged
- platform trust gets damaged quickly

So the implementation stayed on the safe side:

- listen automatically
- classify automatically
- draft automatically
- approve manually
- export only approved items

### Phase 1: Listening-Only Prototype

The first version lived under:

- `ops/radar/`

The inputs were intentionally simple:

- manual JSON lead files
- optional RSS/Atom feed URLs

The first pass used:

- `queries.json` for pain and intent buckets
- `sample/manual_leads.json` for local test leads
- `feeds.txt` for optional feed sources
- `schema/lead-item.schema.json` for the lead shape

The core scan command was:

```powershell
python ops/radar/radar.py scan --manual ops/radar/sample/manual_leads.json --out ops/radar/output
```

It generated:

- `radar-report.json`
- `radar-brief.md`
- `review-queue.json`

That first run proved the heuristic ranking behavior:

- the strongest X/Reddit pain posts scored highest
- the generic GitHub question scored low and became `no_reply`

That was the correct outcome.

### Phase 2: Review Queue and Draft Assist

The next step added explicit queue management:

- `review --list`
- `review --approve <id>`
- `review --reject <id>`
- `review --export-approved <file>`

This is where the system stopped being just a detector and became an operator aid.

The reviewed queue became the durable state:

- `pending_review`
- `approved`
- `rejected`
- `posted`

The first version also attached reply drafts per lead:

- `help_only`
- `help_plus_soft_mention`

This is important because the system is not about auto-selling.
It is about having the right answer ready when there is real intent.

### Phase 3: Review Board and Local Human Surface

The review queue was still too raw to use comfortably, so a local HTML board was added:

- `board --queue ... --out ops/radar/output/radar-board.html`

That board showed:

- score
- recommendation
- source platform
- author
- query matches
- review status
- both reply drafts

The board is read-only by design.
Review decisions stay explicit through the CLI.

### The Refactor Was Forced by the File-Size Discipline

The first Radar implementation was too large for the file-size rule.

That triggered the same lesson the shell control plane already taught:

> if the code is trying to do too much in one place, split it before adding more complexity

Radar was refactored into:

- `models.py`
- `sources.py`
- `engine.py`
- `review.py`
- `board.py`
- `radar.py`

That split made the system easier to test and reason about:

- `models.py` owns typed values and queue serialization
- `sources.py` owns manual-file and RSS ingestion
- `engine.py` owns scoring and draft generation
- `review.py` owns queue state transitions
- `board.py` owns the HTML review surface
- `radar.py` owns CLI dispatch

The split was not optional. It was the only way to keep the module honest.

### Exact Toolchain Used In This Pass

This pass used a different toolchain than the shell stack:

#### Python verification

- `python ops/radar/radar.py scan --manual ops/radar/sample/manual_leads.json --out ops/radar/output`
- `python ops/radar/radar.py review --queue ops/radar/output/review-queue.json --list`
- `python ops/radar/radar.py review --queue ops/radar/output/review-queue.json --approve ...`
- `python ops/radar/radar.py review --queue ops/radar/output/review-queue.json --reject ...`
- `python ops/radar/radar.py review --queue ops/radar/output/review-queue.json --export-approved ...`
- `python ops/radar/radar.py board --queue ops/radar/output/review-queue.json --out ops/radar/output/radar-board.html`
- `python -m py_compile ops/radar/models.py ops/radar/sources.py ops/radar/engine.py ops/radar/review.py ops/radar/board.py ops/radar/radar.py`

#### Docs verification

- `LEAD_INTEL_PACER.md` for the PACER framing
- `ops/radar/README.md` for the workflow

#### Content verification

- sample leads from `ops/radar/sample/manual_leads.json`
- heuristics from `ops/radar/queries.json`
- queue export from `ops/radar/output/approved-leads.json`
- HTML board from `ops/radar/output/radar-board.html`

### What This Changed

Before this pass:

- MacBridge had an operating control plane for provisioning
- there was no internal lead-intel workflow
- response drafting would have been ad hoc and manual

After this pass:

- Radar exists as a separate ops module
- discovery is separated from posting
- reply drafting is separated from approval
- the founder can inspect, triage, and export leads without turning the system into a bot

### The Operational Lesson

This act adds a new product lesson:

> The same discipline that keeps provisioning safe also keeps outbound growth safe.  
> Separate listening from posting, drafts from approvals, and evidence from assumptions.

---

## Act X: First Live Source Connector, Reddit Search RSS, and Why the Live Edge Still Needs Guardrails

**Context:** Radar had a clean local pipeline, but it was still only as real as the sample JSON we fed into it. The next step was to connect it to an actual public source and prove that the scan path could bring in fresh items without breaking the review queue or the scoring surface.

### The Connector Chosen

The first live connector is Reddit search RSS. It fits the product better than a blind API scrape because:

- it is publicly reachable
- it returns Atom/RSS that the existing parser can consume
- it surfaces the kind of technical pain MacBridge cares about
- it keeps the system in "listen first" mode instead of posting automatically

The live path is exposed through the Radar CLI as an optional scan flag, so local fixtures and live discovery can run together.

### What Was Implemented

- live search requests are built from the existing query buckets
- the connector uses `httpx2` with the production client defaults
- RSS/Atom parsing stays in the source layer, not the CLI
- live items are deduped before scoring
- HTTP 429 responses are handled as a soft failure so one bad request does not kill the whole scan
- the resulting live leads flow into the same `review-queue.json` / `radar-brief.md` surfaces as the manual leads

### What Broke On The Way

The first attempt used the wrong live source and turned into a dead-end:

- the HN API path returned no useful hits for this domain
- broad query expansion created too many requests and triggered rate limiting
- the scan aborted when 429s were not handled as a soft failure

The fix was not to pretend those were good results. The fix was to:

- switch to a source that actually returns relevant public discussion
- collapse query expansion into a smaller live search set
- treat rate limits as a warning, not a fatal error

### What This Proved

The Radar pipeline is now source-connected:

- it can start from manual leads
- it can bring in at least one live public lead source
- it can survive upstream throttling without losing the entire run
- it can still hand the founder a queue that is reviewable and exportable

The live edge is still best-effort, not magical. That is correct for a first connector.

---

## Act XI: The Audit Pass — CI Coverage, a Supply-Chain Catch, and Two Reversals Against Ground Truth

**Context:** This pass was not a build pass. It was an audit-and-harden pass over the repo as it stood after Act X. The goal was to understand the whole system, find the real gaps, and close the highest-leverage ones. The most important outcomes were not the code that got written — they were two moments where an earlier confident claim was checked against ground truth and had to be reversed. One of those reversals caught a typosquatted dependency that had already been committed into the codebase in Act X.

### The System, Read End to End

The read confirmed the shape the earlier Acts built:

- **Ring 1 — the product:** `bootstrap.sh` orchestrates five isolated layer processes (`bash "$script"` per layer, piped through `tee` to a per-run log). Each layer is `install → PATH-fix → verify → or-exit`. `layer4-project.sh` is the real gate: `flutter create → pub get → pod install → flutter build ios --debug --no-codesign`.
- **The spine:** `lib/status-contract.sh` is the single JSON emitter (`contract_version: "1"`, states `ready`/`degraded`/`blocked`). `verify.sh` produces it; `doctor.sh`, `healthd.sh`, the Go `status` command, and the Cloudflare receiver all consume that one shape. `verify.sh` is load-bearing for the entire operational story.
- **Ring 2 — control plane:** the Go CLI is an honest stub. `provision.go` literally prints "Phase 1 API integration is not implemented yet" and emits `scp` + `ssh bash bootstrap.sh` strings instead. The value is `internal/providers/providers.go`: a `Provider` interface with one `ManualProvider`, a seam staked out ahead of real cloud-Mac allocators.
- **Ring 3 — growth:** `ops/radar/` is the listening-only lead pipeline. `engine.py` scores heuristically and gates the product mention behind score ≥70 on a non-high-risk platform, so the safety policy from `LEAD_INTEL_PACER.md` is enforced in code, not just documented.

### The First Reversal: "The Binary Is Committed" Was Wrong

The initial observation was that `macbridge.exe` (6.5 MB) was committed — a build artifact in source control. That was stated as fact. It was checked before being acted on:

```
git ls-files --error-unmatch macbridge.exe
→ error: pathspec 'macbridge.exe' did not match any file(s) known to git
```

The binary is **gitignored** (`.gitignore` has `/macbridge.exe`), so it never shows in `git status` and is not tracked. The claim was retracted immediately. Lesson: a file's absence from `git status` does not mean it is committed — it can mean it is ignored. Verify tracking with `git ls-files`, not by eyeballing status output.

### The Real Gap: CI Tested None of the New Code

`.github/workflows/ci.yml` ran ShellCheck + `bash -n` syntax + the shell test harness, and its `paths:` trigger only fired on `**.sh` / `**.ps1`. That left **7 tracked Go files and the entire Python radar module with zero CI coverage** — no `go build`, `go vet`, `go test`, no `compileall`, no pytest. There was even an untracked `ops/radar/test_sources.py` that nothing ran.

The rule applied: never wire CI to a code path without first running it locally. Local verification, before touching the workflow:

```
go build ./...   → ok      (local Go 1.26.4; go.mod declares go 1.22)
go vet ./...     → ok
python -m pytest ops/radar/ -q   → 2 passed
```

### The Second Reversal: `httpx2` Is a Typosquat, Not a Package

This is the important one. `ops/radar/test_sources.py` and `ops/radar/sources.py` both `import httpx2`. First instinct was "typo for `httpx`." That instinct was then talked out of, incorrectly, by trusting `pip` metadata:

```
python -c "import httpx2; print(httpx2.__file__)"
→ httpx2 OK  ...\site-packages\httpx2\__init__.py

pip show httpx2
→ Name: httpx2   Version: 2.5.0
  Home-page: https://github.com/pydantic/httpx2
  Summary: The next generation HTTP client.
  Requires: anyio, httpcore2, idna, truststore
```

On that basis the package was accepted as "a real pydantic next-gen httpx" and CI was wired to install it. **That was the mistake.** Package metadata is self-reported by the author and is trivially forged. When the user pushed back — "make the correction of httpx2" — the signals were re-read as a set, and they are textbook typosquat:

- the name is a **version-suffixed clone** of a popular package (`httpx` → `httpx2`)
- the `Summary` is **httpx's own literal tagline**, "The next generation HTTP client"
- the `Home-page` claims `pydantic/httpx2`, a repo/product that **does not exist** — pydantic does not publish an httpx
- it depends on **`httpcore2`**, another version-suffixed clone of a real package (`httpcore`)
- every symbol the code actually used — `Client`, `MockTransport`, `HTTPTransport`, `Timeout`, `Limits`, `HTTPStatusError`, `Request`, `Response` — is the **exact real `httpx` API**, proving the code was written for `httpx` and the `2` was corruption (most likely an agent hallucinating the import name, which `pip` then resolved to a squatter that had registered the name)

The correction, verified against the genuine `httpx` already installed locally (0.28.1):

```
sed -i 's/httpx2/httpx/g' ops/radar/sources.py ops/radar/test_sources.py
# requirements.txt: httpx2>=2.5.0  →  httpx[http2]>=0.28
#   (the [http2] extra is required because create_hackernews_client() uses
#    HTTPTransport(http2=True))
rm -rf ops/radar/__pycache__          # drop stale bytecode compiled against the squatter
python -m compileall -q ops/radar     → ok
python -m pytest -q                   → 2 passed
```

The tests passed unchanged on real `httpx` because they only exercise `httpx.MockTransport` — pure API surface, no network — which is exactly why the API-match was such strong evidence.

### What Was Actually Built This Pass

- **CI `go` job:** `actions/setup-go@v5` (go 1.22, `cache-dependency-path: go.sum`) running `go build ./...`, `go vet ./...`, `go test ./...`.
- **CI `radar` job:** `actions/setup-python@v5` (Python **3.12** — chosen because real `httpx` needs ≥3.8 and the squatter had falsely claimed ≥3.10; 3.12 is safe and cached), `working-directory: ops/radar`, `pip install -r requirements.txt`, `python -m compileall .`, `python -m pytest -q`.
- **Widened `paths:`** filters to trigger on `**.go`, `**.py`, `go.mod`, `go.sum`, `ops/radar/requirements.txt`.
- **`ops/radar/requirements.txt`** created, then corrected to `httpx[http2]>=0.28` + `pytest>=8.0`.
- **`.gitignore` hardened:** added `__pycache__/`, `*.py[cod]`, `.pytest_cache/`, and `ops/radar/output/*` with a `!ops/radar/output/.gitkeep` negation so the directory persists but run artifacts do not.
- **Committed the previously-untracked work:** the whole `ops/radar/` module, `docs/`, `AGENTS.md`, `LEAD_INTEL_PACER.md` — satisfying the `AGENTS.md` documentation rule that a milestone is not closed until the docs are landed.
- **Agent-Reach documented as the Phase 4 collection seam** (not built): `github.com/Panniantong/Agent-Reach` is a read/search-only capability layer with ordered backends, automatic fallback, and an `agent-reach doctor` command — the same probe-and-degrade philosophy MacBridge already uses. It maps onto `sources.py` as the collection backend; the note records the adapter shape, a `--agent-reach` gating flag, fail-safe wrapping, and the preserved no-post safety boundary. Chosen: document the seam first, because Agent-Reach is not confirmed installed on target machines.

### Process Notes That Bit

- **Default-branch guardrail:** the repo was on `master` with a live `origin`. Work went onto `feat/ci-go-python-and-radar`, not straight to `master`.
- **Line endings:** every `git add` emitted `LF will be replaced by CRLF` warnings — the repo normalizes on a Windows checkout; harmless, git stores LF.
- **Shell cwd drift:** the Bash tool's working directory silently persisted into `ops/radar` after an earlier `cd`, so a later `git add ops/radar/sources.py` failed with `ops/radar/ops/radar/`. Fixed by driving git with an explicit repo root: `git -C "$R" add …`. Lesson: when a tool's cwd is stateful and you cannot see it, use `git -C <root>` (or absolute paths) instead of trusting relative paths.

### Exact Toolchain Used In This Pass

#### Investigation and verification

- `git ls-files --error-unmatch macbridge.exe` — proved the binary was ignored, not tracked
- `git ls-files | grep -E '\.(go|exe)$'` — enumerated tracked Go files
- `go build ./... && go vet ./... && go test ./...` — Go control plane (go 1.26.4 local / 1.22 module)
- `python -c "import httpx2; print(httpx2.__file__)"`, `pip show httpx2`, `importlib.metadata` Requires-Python — the metadata that first misled, then indicted
- `python -m compileall`, `python -m pytest -q` — radar verification on real `httpx` 0.28.1
- `python -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` — CI YAML validation
- `WebFetch` on `Agent-Reach/docs/README_en.md` — understood the Phase 4 backend before documenting it

#### Editing and delivery

- `sed -i 's/httpx2/httpx/g'` for the mechanical import correction
- `git checkout -b feat/ci-go-python-and-radar`, `git add -A`, `git -C "$R" commit`, `git push -u origin`
- three commits: `f52378a` (CI + committed module/docs), `a53df7c` (Agent-Reach Phase 4 docs), `49d92ca` (httpx typosquat fix)

### What This Changed

Before this pass:

- CI proved nothing about the Go control plane or the radar module
- the radar module, its test, and the required docs were uncommitted
- a typosquatted `httpx2` (and transitively `httpcore2`) sat in the source and in `requirements.txt`, having entered in Act X as "the connector uses `httpx2` with the production client defaults"

After this pass:

- Go and Python both have real CI gates, triggered by the file types that matter
- the module and docs are committed on a reviewable branch with clean gitignore hygiene
- the dependency is the genuine `httpx`, and the supply-chain risk is documented with a remediation (`pip uninstall -y httpx2 httpcore2` on any machine that ran the old requirements)

### The Operational Lesson

This act adds two lessons, both about trusting the right source of truth:

> A package's own metadata is not evidence that the package is legitimate.  
> `pip show` reports what the author typed. Verify a dependency against signals it cannot forge: does the name clone a popular one, does the homepage actually exist, does it pull in similarly-suffixed dependencies, and does the code use an API that belongs to a *different* package. When those line up, the "2" is not a version — it is bait.

> An auditor's job is to verify claims, including their own.  
> Two confident statements this pass — "the binary is committed" and "httpx2 is a real package" — were both wrong, and both were caught only by checking against ground truth (`git ls-files`, then the metadata signals read as a set). Being willing to reverse a stated conclusion is the job, not a failure of it.

---

*Built by Sisyphus at Maverix Labs. Source: Phase 0 provisioning on Macly M4 ($14.99/day). 813-line journal. 1,040-line terminal log. 10 lessons. 20 commits.*
