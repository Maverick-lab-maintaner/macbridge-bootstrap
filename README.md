# MacBridge Bootstrap

> **The product isn't the Mac. The product is the continuously verified development workspace** — bootstrap, doctor, recovery, readiness, signing, AI-agent readiness, updates, and the golden image, together.
> The Mac is interchangeable commodity hardware (cloud *or* a physical Mac you already own). The knowledge encoded in these scripts — the provisioning sequence, the verification at every layer, the doctor rules that grow over time — is what MacBridge sells. See [`docs/BUSINESS_MODELS.md`](docs/BUSINESS_MODELS.md) for the software-first (Studio) direction.

## What This Is

MacBridge Bootstrap provisions a macOS machine into a Flutter/iOS/AI-agent-ready development environment. One command. Four layers. Verified at every step. Built from 10 hard-earned lessons provisioning a cloud Mac from scratch.

## What You Get

After bootstrap completes, the Mac has:

| Component | Status |
|-----------|:---:|
| Xcode 26+ | ✅ Verified |
| Command Line Tools | ✅ Verified |
| iOS Simulator runtime | ✅ Verified |
| Homebrew + PATH | ✅ Configured |
| Flutter SDK (stable) | ✅ Verified |
| Ruby 4.x (Homebrew) | ✅ Verified |
| CocoaPods + PATH | ✅ Verified |
| Git + SSH config | ✅ Configured |
| GitHub CLI (`gh`) | ✅ Installed |
| Node.js 22 | ✅ Installed |
| Claude Code | ✅ Installed |
| OpenCode | ✅ Installed |
| Codex CLI | ✅ Installed |
| tmux (session persistence) | ✅ Configured |
| SSH keepalive | ✅ Configured |

## Quick Start — Studio CLI (the product)

The `macbridge` binary is self-contained: it embeds the entire tooling and extracts it on
first use, so a customer never clones this repo.

```bash
# On the Mac (yours or a cloud one):
macbridge install --tier vanilla    # bootstrap -> verify -> flutter build ios smoke
macbridge status                    # health TUI for THIS Mac (add --host for a remote one)
macbridge doctor                    # remediation guidance

# Studio Pro (signing diagnosis, workspace, golden image, updates):
macbridge activate MB-XXXX-XXXX-XXXX-XXXX
macbridge doctor --signing --project ~/myapp
```

Free tier: `install`, `status`/verify, readiness, basic `doctor`. Pro adds signing diagnosis,
the prepared-studio workspace, golden image, and the updates channel. Distribution: GitHub
Releases on tags (`.github/workflows/release.yml`) + a Homebrew formula template
(`dist/homebrew/macbridge.rb`). See [docs/STUDIO_PACKAGING.md](docs/STUDIO_PACKAGING.md).

## Quick Start — from source

```bash
# Clone this repo on a fresh macOS machine
git clone https://github.com/Maverick-lab-maintaner/macbridge-bootstrap.git
cd macbridge-bootstrap

# Run bootstrap (all layers, ~35 minutes)
bash bootstrap.sh

# If a layer fails, fix and resume from that layer
bash bootstrap.sh --from 2

# Verify environment health anytime
bash verify.sh

# Clean up user data between sessions
bash cleanup.sh
```

## Architecture

```
bootstrap.sh          # Master orchestrator
  │
  ├── Layer 0: Machine Reachable
  │   ├── macOS check
  │   ├── Disk >50GB free
  │   ├── Network connectivity
  │   ├── Directory ownership (catches root-owned .local)
  │   ├── SSH enable + keepalive config
  │   └── VNC status check
  │
  ├── Layer 1: Apple Toolchain
  │   ├── Command Line Tools
  │   ├── Xcode version + xcodebuild
  │   ├── License acceptance
  │   ├── First launch
  │   └── iOS Simulator runtime
  │
  ├── Layer 2: Development Tools
  │   ├── Homebrew + PATH
  │   ├── Ruby 4.x (NOT system 2.6)
  │   ├── Flutter SDK + flutter doctor
  │   ├── CocoaPods + PATH fix
  │   ├── Git + SSH keygen
  │   ├── GitHub SSH verification
  │   └── GitHub CLI
  │
  ├── Layer 3: AI Agents
  │   ├── Node.js 22
  │   ├── Claude Code
  │   ├── OpenCode
  │   ├── Codex CLI
  │   └── tmux + configuration
  │
  └── Layer 4: Smoke Test
      ├── flutter create test_app
      ├── flutter pub get
      ├── pod install
      ├── flutter build ios --debug --no-codesign
      └── ✅ MAC READY or ❌ FAILED
```

## Key Design Decisions

### Why Layers?
Each layer is independently verified before the next begins. If Layer 2 fails, you know the problem is in development tools — not networking, not Xcode. Debugging is trivial because failure is isolated.

### Why Verification at Every Step?
Phase 0 taught us that tools install silently but don't work. `flutter doctor` green ≠ build succeeds. CocoaPods installs but `pod` isn't in PATH. Every install step is followed by a `which` check. Every tool is verified before proceeding.

### Why Homebrew Ruby (Not System Ruby)?
macOS ships with Ruby 2.6. CocoaPods 1.16+ requires Ruby 3+. System Ruby rejects CocoaPods with an opaque error. Homebrew Ruby is installed first, PATH is configured, and the version is verified before CocoaPods installation.

### Why `--no-codesign` on Smoke Test?
Code signing requires an Apple Developer account ($99/yr) with certificates and provisioning profiles — all tied to a specific developer's identity. The smoke test verifies the build pipeline works without requiring signing. Actual signing happens when the user configures their own Apple Developer account.

## File Structure

```
macbridge-bootstrap/
├── bootstrap.sh            # Master orchestrator (~260 lines)
├── cleanup.sh              # Session wipe (~220 lines)
├── verify.sh               # Health checks (~220 lines)
├── welcome.sh              # Stage 3: Welcome Wizard — first-login setup (~200 lines)
├── healthd.sh              # Fleet health agent — cron, JSON, webhook (~190 lines)
├── hardening.sh            # Firewall lockdown — PF rules, port isolation (~220 lines)
├── migrate.sh              # Golden image version check + opt-in upgrade (~180 lines)
├── provision.ps1           # Windows → Mac provisioning (PowerShell, ~160 lines)
├── README.md               # This file
├── landing/                # MacBridge landing page (Cloudflare Pages)
│   └── index.html
├── lib/
│   ├── _utils.sh           # Shared logging, color, webhook reporting
│   ├── layer0-machine.sh   # Machine reachability
│   ├── layer1-apple.sh     # Apple toolchain
│   ├── layer2-dev.sh       # Development tools
│   ├── layer3-agents.sh    # AI agents
│   └── layer4-project.sh   # Smoke test
└── logs/                   # Bootstrap run logs
```

## Provisioning Pipeline (3 Stages)

```
Stage 1: Golden Image  →  Manual (GUI once, snapshot)
Stage 2: Bootstrap     →  bash bootstrap.sh          (this repo)
Stage 3: Welcome Wizard →  bash welcome.sh           (this repo)
```

### Stage 3: Welcome Wizard

Runs on first login after bootstrap. Turns a verified Mac into a working dev environment.

```bash
bash welcome.sh                                          # Full interactive wizard
bash welcome.sh --skip-github                            # GitHub already configured
bash welcome.sh --repo git@github.com:user/repo.git      # Auto-clone project
```

Guides through: GitHub Device Flow (`gh auth login`), Claude/OpenCode/Codex API key setup, project clone, tmux session creation.

### Golden Image Migration

```bash
bash migrate.sh                    # Check version, offer upgrade if available
bash migrate.sh --check            # Version check only
bash migrate.sh --list             # List available golden images
sudo bash migrate.sh --set-version v1  # Tag current Mac
```

Never force-updates. Preserves user data. Backs up configs before upgrade. Opt-in only.

### Windows Provisioning (PowerShell)

```bash
.\provision.ps1 -MacHost 203.0.113.47
.\provision.ps1 -MacHost 203.0.113.47 -Welcome -Hardening
.\provision.ps1 -MacHost 203.0.113.47 -ReportTo https://dash.example.com/api/report
```

SCPs bootstrap scripts to Mac, executes remotely, streams output to Windows terminal. Saves session info to `~/.macbridge/session.json` for reconnection.

## DevOps Toolchain

Beyond provisioning, these scripts handle the operational side of running a Mac fleet:

### Fleet Health Monitoring

```bash
# One-shot health check (JSON output)
bash healthd.sh

# Ship to a central dashboard every 5 minutes
bash healthd.sh --install-cron --webhook https://dash.example.com/api/health

# Continuous daemon mode
bash healthd.sh --interval 300 --webhook https://dash.example.com/api/health
```

Health checks: disk, memory, load, Xcode, Flutter, CocoaPods, Ruby, Git, SSH keys, Node.js, all 3 agent CLIs, tmux, network, GitHub connectivity. Outputs structured JSON with machine ID, timestamp, and overall status.

### Firewall Hardening

```bash
# Lock down: only SSH (22) + VNC (5900) open
bash hardening.sh

# Preview without applying
bash hardening.sh --dry-run

# Check current firewall state
bash hardening.sh --verify
```

Configures PF (Packet Filter), enables Application Firewall + stealth mode, disables unused services (AFP, SMB, FTP, Telnet), persists rules across reboots via LaunchDaemon.

### Centralized Log Shipping

```bash
# Ship bootstrap layer results to your dashboard
bash bootstrap.sh --report-to https://dash.example.com/api/report
```

Every layer pass/fail is reported as a structured JSON event. The `_utils.sh` library provides `report_event()` and `report_to_webhook()` that all scripts can use. Set `MACBRIDGE_REPORT_URL` to enable fleet-wide telemetry.

## The 10 Lessons This Code Encodes

These aren't comments. They're architecture decisions hardcoded into the scripts. Each was earned through a real failure during Phase 0 provisioning.

| # | Lesson | Where It's Encoded |
|---|--------|-------------------|
| 1 | Xcode requires GUI to install | `layer1-apple.sh` — verifies existence, provides GUI instructions if missing |
| 2 | System Ruby 2.6 rejects CocoaPods | `layer2-dev.sh` — `brew install ruby` before CocoaPods, version check |
| 3 | PATH is part of provisioning | Every layer — `ensure_path()` after every install, `.zprofile` updates |
| 4 | `~/.local` ownership breaks silently | `layer0-machine.sh` — ownership check before any installation |
| 5 | GitHub password auth dead | `layer2-dev.sh` — SSH keygen + GitHub connectivity test |
| 6 | SPM breaks some plugins | `layer4-project.sh` — actual `flutter build ios` smoke test |
| 7 | Provisioning IS the product | `bootstrap.sh` — the entire architecture |
| 8 | Verification at every layer | Every script — `install → verify → continue` pattern |
| 9 | User never sees provisioning | All scripts run before "MAC READY" — summary output only |
| 10 | One command does everything | `bootstrap.sh` — single entry point with `--from` resume |

## Verification (verify.sh)

Independent from bootstrap. Read-only. Never installs. Validates the Mac is still in a ready state.

```bash
bash verify.sh              # Full verification
bash verify.sh --quick      # Critical paths only (~5s)
bash verify.sh --json       # Machine-readable output
```

## Cleanup (cleanup.sh)

Returns Mac to golden image state. Preserves toolchain. Removes ALL user data.

```bash
bash cleanup.sh              # Full cleanup (with confirmation)
bash cleanup.sh --force      # Skip confirmation
bash cleanup.sh --dry-run    # Preview without changes
```

## Golden Image (golden-image.sh)

Stage 1 of the pipeline, codified. Turns a fresh Mac with Xcode GUI-installed into a verified, workspace-arranged image that is ready to snapshot. The one manual step — installing Xcode from the App Store and taking the provider snapshot — is guided, not automated.

```bash
bash golden-image.sh build --tier agent --version v3   # bootstrap → verify → workspace → manifest → snapshot guidance
sudo bash golden-image.sh manifest                     # print this machine's version manifest (JSON)
bash golden-image.sh verify --manifest /etc/macbridge-manifest.json  # drift-check against a saved manifest
```

`build` refuses to declare the image ready unless `verify.sh` reports `ready`. It writes `/etc/macbridge-manifest.json` (exact component versions) and tags `/etc/macbridge-version` (via `migrate.sh`), so `golden-image.sh verify` can later detect drift.

### The prepared studio (workspace-setup.sh + readiness.sh)

`workspace-setup.sh` makes first login feel like walking into a studio that was prepared before you arrived: a LaunchAgent opens Terminal and boots the Simulator on login, and a `~/.zprofile` hook greets every login shell (Terminal window or SSH session) with the readiness screen.

```bash
bash workspace-setup.sh                 # install (device auto-picked)
bash workspace-setup.sh --dry-run       # preview without changes
bash workspace-setup.sh --uninstall     # remove the configuration
```

`readiness.sh` renders the "🟢 MacBridge Ready" screen from the same status contract as `verify.sh` — a green checklist of Flutter/Xcode/Simulator/CocoaPods/agents with the machine state, instead of a bare shell prompt.

```bash
bash readiness.sh            # verify and render
bash readiness.sh --quick    # faster
```

## Signing Diagnosis (signing-doctor.sh)

Read-only diagnosis of iOS code-signing readiness. It inspects signing identities and provisioning profiles, and — given a project — its bundle identifier and development team, then explains what to fix. It **never** creates certificates or provisioning profiles, never touches your Apple Developer account, and never stores credentials.

```bash
bash signing-doctor.sh                  # identities + profiles
bash signing-doctor.sh --project .      # also read a project's bundle id / team
bash signing-doctor.sh --json           # machine-readable status contract
```

Detects: no signing identity, expired/invalid certificates, no provisioning profiles, unset development team, and a project team with no matching identity in the keychain. Emits the same status-contract JSON as `verify.sh`/`doctor.sh`.

From the Go CLI it runs remotely over SSH via the `doctor` command:

```bash
macbridge doctor --host <ip> --signing                       # signing diagnosis
macbridge doctor --host <ip> --signing --project ~/myapp      # inspect a project
macbridge doctor --host <ip> --signing --json                # machine-readable
```

## Prerequisites

- macOS 14+ (Sonoma or later)
- Internet connection
- Xcode pre-installed (via golden image) or installed manually via DeskIn GUI first
- 50GB+ free disk space

## Related Docs

**In this repo** (start at the [docs index](docs/README.md)):

- [docs/BUSINESS_MODELS.md](docs/BUSINESS_MODELS.md) — the software-first (Studio) decision and why
- [docs/PRICING_STRATEGY.md](docs/PRICING_STRATEGY.md) — compliant tiers + unit economics
- [docs/APPLE_LICENSE_COMPLIANCE.md](docs/APPLE_LICENSE_COMPLIANCE.md) — what Apple's macOS SLA permits and forbids
- [docs/PERSONAS.md](docs/PERSONAS.md) — the three target personas under software-first
- [docs/STUDIO_PACKAGING.md](docs/STUDIO_PACKAGING.md) — the build path to ship the software product
- [docs/GO_TO_MARKET.md](docs/GO_TO_MARKET.md) — the Radar lead funnel into the compliant tiers
- [docs/LOCAL_TESTING.md](docs/LOCAL_TESTING.md) — validate for $0 on WSL + free GitHub macOS runners
- [docs/macbridge-story.md](docs/macbridge-story.md) — learning-oriented chronology of the repo, failures, and fixes
- [HISTORY.md](HISTORY.md) — the exact build chronicle · [shortlist.md](shortlist.md) — what's done and what's left

**In the KnowledgeBase** (local, not in this repo):

- [MACBRIDGE_PLAN.md](../Obsidian/KnowledgeBase/MacBridge/MACBRIDGE_PLAN.md) — Full 5-pillar build plan + business plan
- [MVP_BUILD_PLAN.md](../Obsidian/KnowledgeBase/MacBridge/MVP_BUILD_PLAN.md) — Exact build order + networking architecture
- [LESSONS_LEARNED.md](../Obsidian/KnowledgeBase/MacBridge/LESSONS_LEARNED.md) — 10 Phase 0 provisioning lessons
- [PHASE0_FIRST_IOS_BUILD.md](../Obsidian/KnowledgeBase/MacBridge/PHASE0_FIRST_IOS_BUILD.md) — First iOS build milestone
- [POST_PHASE0_SYNTHESIS.md](../Obsidian/KnowledgeBase/MacBridge/POST_PHASE0_SYNTHESIS.md) — Strategy shift post-provisioning
---

**Maverix Labs** | Phase 0-validated | June 2026
