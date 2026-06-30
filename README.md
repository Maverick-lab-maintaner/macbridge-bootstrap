# MacBridge Bootstrap

> **The product isn't the Mac. The bootstrap script is the product.**
> The Mac is interchangeable commodity hardware. The knowledge encoded in these scripts — the provisioning sequence, the verification at every layer, the 10 Phase 0 lessons — is what MacBridge sells.

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

## Quick Start

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
├── bootstrap.sh            # Master orchestrator (~200 lines)
├── cleanup.sh              # Session wipe (~200 lines)
├── verify.sh               # Health checks (~200 lines)
├── README.md               # This file
├── lib/
│   ├── layer0-machine.sh   # Machine reachability (~120 lines)
│   ├── layer1-apple.sh     # Apple toolchain (~130 lines)
│   ├── layer2-dev.sh       # Development tools (~190 lines)
│   ├── layer3-agents.sh    # AI agents (~180 lines)
│   └── layer4-project.sh   # Smoke test (~120 lines)
└── logs/                   # Bootstrap run logs
```

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

## Prerequisites

- macOS 14+ (Sonoma or later)
- Internet connection
- Xcode pre-installed (via golden image) or installed manually via DeskIn GUI first
- 50GB+ free disk space

## Related Docs

- [MACBRIDGE_PLAN.md](../Obsidian/KnowledgeBase/MacBridge/MACBRIDGE_PLAN.md) — Full 5-pillar build plan + business plan
- [MVP_BUILD_PLAN.md](../Obsidian/KnowledgeBase/MacBridge/MVP_BUILD_PLAN.md) — Exact build order + networking architecture
- [LESSONS_LEARNED.md](../Obsidian/KnowledgeBase/MacBridge/LESSONS_LEARNED.md) — 10 Phase 0 provisioning lessons
- [PHASE0_FIRST_IOS_BUILD.md](../Obsidian/KnowledgeBase/MacBridge/PHASE0_FIRST_IOS_BUILD.md) — First iOS build milestone
- [POST_PHASE0_SYNTHESIS.md](../Obsidian/KnowledgeBase/MacBridge/POST_PHASE0_SYNTHESIS.md) — Strategy shift post-provisioning

---

**Maverix Labs** | Phase 0-validated | June 2026
