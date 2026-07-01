#!/bin/bash
# =============================================================================
# MacBridge — Cleanup
# =============================================================================
# Returns the Mac to golden image state by removing all user data while
# preserving the pre-installed toolchain. Ready for the next user or reclaim.
#
# What gets WIPED:
#   - Project clones (user's code)
#   - SSH keys (GitHub access)
#   - Git config (user identity)
#   - Agent configs (API keys, tokens, preferences)
#   - Shell history (command history — privacy)
#   - npm cache (may contain tokens)
#   - tmux sessions (user's agent sessions)
#   - known_hosts (server fingerprints from user's connections)
#   - Browser cache
#
# What gets PRESERVED (golden image state):
#   - Xcode, iOS Simulator
#   - Flutter SDK, CocoaPods, Ruby, Homebrew
#   - Node.js, agent CLI binaries
#   - macOS system
#
# Usage:
#   bash cleanup.sh              # Full cleanup
#   bash cleanup.sh --dry-run    # Show what would be cleaned (no changes)
#   bash cleanup.sh --force      # Skip confirmation prompt
#
# Lessons encoded (Phase 0):
#   Manual cleanup is error-prone → automate it
#   User data must not leak between customers
# =============================================================================

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --force)   FORCE=true; shift ;;
        --help|-h)
            echo "Usage: bash cleanup.sh [--dry-run] [--force]"
            echo ""
            echo "Options:"
            echo "  --dry-run  Preview what would be cleaned (no changes)"
            echo "  --force    Skip confirmation prompt"
            exit 0
            ;;
        *) shift ;;
    esac
done

# ── Banner ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${YELLOW}🧹 MacBridge — Session Cleanup${NC}"
echo "──────────────────────────────────────────────"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}  DRY RUN — no changes will be made${NC}"
    echo ""
fi

# ── Confirmation ───────────────────────────────────────────────────────────

if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}⚠️  This will remove ALL user data from this Mac:${NC}"
    echo ""
    echo "  • Project clones and source code"
    echo "  • SSH keys and GitHub access"
    echo "  • Git user configuration"
    echo "  • AI agent configurations (API keys, tokens)"
    echo "  • Shell history"
    echo "  • tmux sessions"
    echo ""
    echo -e "  ${GREEN}Preserved:${NC} Xcode, Flutter, CocoaPods, Ruby, Homebrew, Node.js, agent CLIs"
    echo ""
    read -r -p "  Are you sure? [y/N] " REPLY
    echo ""

    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}  Cleanup cancelled.${NC}"
        exit 0
    fi
fi

# ── Do cleanup ─────────────────────────────────────────────────────────────

CLEANED=0
SKIPPED=0

run_clean() {
    local name="$1"
    local command="$2"

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}→${NC} Would clean: ${name}"
        ((CLEANED++)) || true
        return 0
    fi

    echo -e "  ${CYAN}→${NC} Cleaning: ${name}..."
    if eval "$command" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} ${name} removed"
        ((CLEANED++)) || true
    else
        echo -e "  ${YELLOW}⚠️${NC}  ${name} — not found (already clean or skipped)"
        ((SKIPPED++)) || true
    fi
}

echo -e "${BOLD}User Data:${NC}"
echo ""

# ── Project clones ─────────────────────────────────────────────────────────
run_clean "Project directories" '
    rm -rf "$HOME/projects" 2>/dev/null
    rm -rf "$HOME/shiftflowr"* 2>/dev/null
    rm -rf "$HOME/test_app"* 2>/dev/null
    # Clean up any leftover smoke test directories
    rm -rf /tmp/macbridge-smoke-test-* 2>/dev/null
    true
'

# ── SSH keys ───────────────────────────────────────────────────────────────
run_clean "SSH keys" '
    rm -f "$HOME/.ssh/id_ed25519" 2>/dev/null
    rm -f "$HOME/.ssh/id_ed25519.pub" 2>/dev/null
    rm -f "$HOME/.ssh/id_rsa" 2>/dev/null
    rm -f "$HOME/.ssh/id_rsa.pub" 2>/dev/null
    true
'

# ── SSH known_hosts ────────────────────────────────────────────────────────
run_clean "SSH known_hosts" '
    rm -f "$HOME/.ssh/known_hosts" 2>/dev/null
    rm -f "$HOME/.ssh/known_hosts.old" 2>/dev/null
    true
'

# ── Git config ─────────────────────────────────────────────────────────────
run_clean "Git global config" '
    git config --global --unset user.name 2>/dev/null || true
    git config --global --unset user.email 2>/dev/null || true
    true
'

# ── Shell history ──────────────────────────────────────────────────────────
run_clean "Shell history" '
    rm -f "$HOME/.zsh_history" 2>/dev/null
    rm -f "$HOME/.bash_history" 2>/dev/null
    rm -f "$HOME/.bashrc_temp" 2>/dev/null
    rm -f "$HOME/.zprofile_temp" 2>/dev/null
    history -c 2>/dev/null || true
    true
'

echo ""
echo -e "${BOLD}AI Agent Configurations:${NC}"
echo ""

# ── Claude Code config ─────────────────────────────────────────────────────
run_clean "Claude Code config" '
    rm -f "$HOME/.claude.json" 2>/dev/null
    rm -rf "$HOME/.claude" 2>/dev/null
    rm -rf "$HOME/.config/claude" 2>/dev/null
    true
'

# ── OpenCode config ────────────────────────────────────────────────────────
run_clean "OpenCode config" '
    rm -f "$HOME/.opencode.json" 2>/dev/null
    rm -rf "$HOME/.opencode" 2>/dev/null
    rm -rf "$HOME/.config/opencode" 2>/dev/null
    true
'

# ── Codex config ───────────────────────────────────────────────────────────
run_clean "Codex CLI config" '
    rm -f "$HOME/.codex.json" 2>/dev/null
    rm -rf "$HOME/.config/codex" 2>/dev/null
    rm -rf "$HOME/.cache/codex" 2>/dev/null
    true
'

echo ""
echo -e "${BOLD}Caches & Sessions:${NC}"
echo ""

# ── npm cache ───────────────────────────────────────────────────────────────
run_clean "npm cache" '
    npm cache clean --force 2>/dev/null || true
    true
'

# ── tmux sessions ──────────────────────────────────────────────────────────
run_clean "tmux sessions" '
    tmux kill-server 2>/dev/null || true
    true
'

# ── Browser cache ──────────────────────────────────────────────────────────
run_clean "Browser cache" '
    rm -rf "$HOME/Library/Caches/com.apple.Safari" 2>/dev/null || true
    rm -rf "$HOME/Library/Caches/Google/Chrome" 2>/dev/null || true
    true
'

# ── Verify clean state ─────────────────────────────────────────────────────

echo ""
echo "──────────────────────────────────────────────"
echo -e "${BOLD}Verification:${NC}"
echo ""

if [ "$DRY_RUN" = false ]; then
    PROJECT_COUNT=$(ls "$HOME/projects" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    SSH_KEY_COUNT=$(ls "$HOME/.ssh/id_"* 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    TMUX_SESSIONS=$(tmux ls 2>/dev/null | wc -l | tr -d ' ' || echo "0")

    echo -e "  Projects remaining:   ${PROJECT_COUNT}"
    echo -e "  SSH keys remaining:   ${SSH_KEY_COUNT}"
    echo -e "  tmux sessions active: ${TMUX_SESSIONS}"

    # Verify toolchain is preserved
    echo ""
    echo -e "${BOLD}Preserved toolchain:${NC}"
    command -v flutter > /dev/null 2>&1  && echo -e "  ${GREEN}✅${NC} Flutter preserved"  || echo -e "  ${RED}❌${NC} Flutter missing!"
    command -v xcodebuild > /dev/null 2>&1 && echo -e "  ${GREEN}✅${NC} Xcode preserved"    || echo -e "  ${RED}❌${NC} Xcode missing!"
    command -v pod > /dev/null 2>&1       && echo -e "  ${GREEN}✅${NC} CocoaPods preserved" || echo -e "  ${RED}❌${NC} CocoaPods missing!"
    command -v brew > /dev/null 2>&1      && echo -e "  ${GREEN}✅${NC} Homebrew preserved"  || echo -e "  ${RED}❌${NC} Homebrew missing!"
    command -v node > /dev/null 2>&1      && echo -e "  ${GREEN}✅${NC} Node.js preserved"   || echo -e "  ${RED}❌${NC} Node.js missing!"
    command -v tmux > /dev/null 2>&1      && echo -e "  ${GREEN}✅${NC} tmux preserved"      || echo -e "  ${RED}❌${NC} tmux missing!"
fi

echo ""
echo "──────────────────────────────────────────────"

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}✅ Dry run complete${NC} — ${CLEANED} items would be cleaned, ${SKIPPED} already clean"
else
    echo -e "${GREEN}✅ Cleanup complete${NC} — ${CLEANED} items cleaned, ${SKIPPED} already clean"
    echo ""
    echo -e "  ${GREEN}Mac is ready for next user or reclaim.${NC}"
    echo -e "  Toolchain preserved. User data removed."
fi

echo ""
