# Changelog

All notable changes to MacBridge golden images and bootstrap scripts.

---

## [v2] — 2026-07-01

### Added
- **Firewall hardening** — `hardening.sh` applies PF rules, only SSH (22) + VNC (5900) open
- **Fleet health agent** — `healthd.sh` runs 19 checks, ships JSON to webhook, cron support
- **Centralized logging** — `--report-to` flag on bootstrap reports every layer pass/fail
- **Shared utilities** — `lib/_utils.sh` provides logging, webhook, and helper functions
- **Two-tier pricing** — `--tier vanilla` skips AI agents, `--tier agent` includes them
- **Welcome Wizard** — `welcome.sh` guides first login through GitHub + AI key setup
- **Golden image migration** — `migrate.sh` checks version, offers opt-in upgrades
- **Windows provisioning** — `provision.ps1` SCPs bootstrap to Mac, streams output
- **Skill library installer** — `install-skills.sh` installs 30+ Flutter/Firebase/iOS skills
- **tmux auto-launcher** — `tmux-launch.sh` auto-attaches session on SSH login
- **Landing page** — Two-tier pricing, Maverix Labs design system
- **Cloudflare Worker** — `dashboard/health-receiver.js` receives healthd reports, fleet dashboard
- **Brand design system** — `DESIGN.md` with product frame, colors, typography, components
- **Release watchers** — `lib/watcher-xcode.sh` + `lib/watcher-flutter.sh` monitor new versions
- **GitHub Actions CI** — ShellCheck linting + syntax validation on push
- **Test harness** — `test/run-tests.sh` validates all scripts

### Golden Image
- macOS 15 Sequoia
- Xcode 26.6
- iOS 26.5 Simulator runtime
- Flutter 3.44.4 (stable)
- CocoaPods 1.16.2
- Ruby 4.x (Homebrew)
- Node.js 22 LTS
- Homebrew (latest)
- GitHub CLI (gh)
- Claude Code, OpenCode, Codex CLI (agent tier)
- tmux (agent tier)
- Hardened firewall (PF rules applied)

---

## [v1] — 2026-06-29

### Initial Release
- **Bootstrap script** — 5-layer provisioning (machine, Apple, dev tools, agents, smoke test)
- **Health verification** — `verify.sh` with 20+ checks, `--quick` and `--json` modes
- **Session cleanup** — `cleanup.sh` wipes user data, preserves toolchain
- **10 Phase 0 lessons** — Every known failure mode encoded as automated checks

### Golden Image
- macOS 15 Sequoia
- Xcode 26.6
- iOS 26.5 Simulator runtime
- Flutter 3.44.4 (stable)
- CocoaPods 1.16.2
- Ruby 4.x (Homebrew)
- Node.js 22 LTS
- Homebrew (latest)
- GitHub CLI (gh)
- Claude Code, OpenCode, Codex CLI
- tmux + mouse mode
