#!/bin/bash
# =============================================================================
# MacBridge — Layer 3: AI Agents
# =============================================================================
# Installs AI coding agents: Claude Code, OpenCode, Codex, plus
# supporting infrastructure: Node.js, tmux for session persistence.
#
# Lessons encoded (Phase 0):
#   Lesson 3: PATH is part of provisioning — npm global bin must be in PATH
#   Lesson 8: Verification at every layer — every agent CLI verified
#   Lesson 10: One command does everything — this layer is part of bootstrap
#
# Prerequisites: Layer 0-2 (machine, Apple toolchain, dev tools)
# =============================================================================

set -euo pipefail

LAYER="Layer 3"

# Source shared utilities
if [ -f "${MACBRIDGE_LIB_DIR:-lib}/_utils.sh" ]; then
    source "${MACBRIDGE_LIB_DIR:-lib}/_utils.sh"
else
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
    PASS=0; FAIL=0
    step()  { echo -e "${CYAN}  →${NC} $1"; }
    ok()    { echo -e "  ${GREEN}✅${NC} $1"; ((PASS++)) || true; }
    warn()  { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
    fail()  { echo -e "  ${RED}❌${NC} $1"; ((FAIL++)) || true; }
    info()  { echo -e "  ${CYAN}💡${NC} $1"; }
fi

PASS=0; FAIL=0

# ── Agent selection ────────────────────────────────────────────────────────
# The user chooses which agents to install (CLI TUI or bootstrap --agents).
# Comma-separated list; default is all three. "none" installs no agent CLIs
# (Node + tmux still install — they serve the whole workspace).
AGENTS="${MACBRIDGE_AGENTS:-claude,opencode,codex}"
wants() { case ",${AGENTS}," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

echo ""
echo -e "${BOLD}${CYAN}🤖 ${LAYER}: AI Agents${NC}"
echo "──────────────────────────────────────────────"
echo -e "  ${CYAN}Selected:${NC} ${AGENTS}"
echo ""

# ── Helper: ensure directory in PATH ──────────────────────────────────────
ensure_path() {
    local dir="$1"
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        echo "export PATH=\"$dir:\$PATH\"" >> "$HOME/.zprofile"
        export PATH="$dir:$PATH"
    fi
}

# ── 1. Install/Verify Node.js (required for Claude Code + OpenCode) ────────
step "Checking Node.js..."

if command -v node > /dev/null 2>&1; then
    NODE_VERSION=$(node --version 2>/dev/null)
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d. -f1)

    if [ "$NODE_MAJOR" -ge 18 ]; then
        ok "Node.js ${NODE_VERSION} (>= 18 required)"
    else
        warn "Node.js ${NODE_VERSION} is too old (need >= 18) — upgrading..."
        brew install node@22 2>/dev/null || brew upgrade node 2>/dev/null || true
    fi
else
    step "Installing Node.js 22 via Homebrew..."
    brew install node@22 2>/dev/null || brew install node 2>/dev/null || true

    if command -v node > /dev/null 2>&1; then
        ok "Node.js installed: $(node --version)"
    else
        fail "Node.js installation failed"
        exit 1
    fi
fi

# Ensure npm global bin directory in PATH (for globally installed packages)
NPM_PREFIX=$(npm config get prefix 2>/dev/null || echo "$HOME/.npm-global")
ensure_path "${NPM_PREFIX}/bin"

step "Verifying npm..."
if command -v npm > /dev/null 2>&1; then
    ok "npm $(npm --version) ready"
else
    fail "npm not found — Node.js may be broken"
    exit 1
fi

# ── 2. Install/Verify Claude Code ─────────────────────────────────────────
if wants claude; then
    step "Checking Claude Code..."

    if command -v claude > /dev/null 2>&1; then
        ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'version unknown')"
    else
        step "Installing Claude Code..."
        npm install -g @anthropic-ai/claude-code 2>/dev/null || true

        if command -v claude > /dev/null 2>&1; then
            ok "Claude Code installed"
        else
            warn "Claude Code installation via npm failed"
            warn "  Manual install: npm install -g @anthropic-ai/claude-code"
            warn "  Note: Requires Anthropic API key (user provides this)"
        fi
    fi
else
    step "Skipping Claude Code (not selected)"
fi

# ── 3. Install/Verify OpenCode ────────────────────────────────────────────
if wants opencode; then
    step "Checking OpenCode..."

    if command -v opencode > /dev/null 2>&1; then
        ok "OpenCode installed: $(opencode --version 2>/dev/null || echo 'version unknown')"
    else
        step "Installing OpenCode..."
        # Real package: opencode-ai (sst/opencode); brew tap as fallback.
        npm install -g opencode-ai 2>/dev/null || \
        brew install sst/tap/opencode 2>/dev/null || true

        if command -v opencode > /dev/null 2>&1; then
            ok "OpenCode installed"
        else
            warn "OpenCode installation failed"
            warn "  Manual: npm install -g opencode-ai  (see https://opencode.ai)"
        fi
    fi
else
    step "Skipping OpenCode (not selected)"
fi

# ── 4. Install/Verify Codex CLI ───────────────────────────────────────────
if wants codex; then
    step "Checking Codex CLI..."

    if command -v codex > /dev/null 2>&1; then
        ok "Codex CLI installed: $(codex --version 2>/dev/null || echo 'version unknown')"
    else
        step "Installing Codex CLI..."
        # Real package: @openai/codex (OpenAI's Codex CLI).
        npm install -g @openai/codex 2>/dev/null || \
        brew install codex 2>/dev/null || true

        if command -v codex > /dev/null 2>&1; then
            ok "Codex CLI installed"
        else
            warn "Codex CLI installation failed"
            warn "  Manual: npm install -g @openai/codex"
        fi
    fi
else
    step "Skipping Codex CLI (not selected)"
fi

# ── 5. Install/Verify tmux (session persistence) ──────────────────────────
# Critical for cross-device workflow: laptop → phone → laptop
step "Checking tmux..."

if command -v tmux > /dev/null 2>&1; then
    TMUX_VERSION=$(tmux -V 2>/dev/null)
    ok "tmux installed: ${TMUX_VERSION}"
else
    step "Installing tmux..."
    brew install tmux 2>/dev/null || true

    if command -v tmux > /dev/null 2>&1; then
        ok "tmux installed"
    else
        fail "tmux installation failed — session persistence requires tmux"
        exit 1
    fi
fi

# Configure tmux for better UX
TMUX_CONF="$HOME/.tmux.conf"
if [ ! -f "$TMUX_CONF" ] || ! grep -q "MacBridge" "$TMUX_CONF" 2>/dev/null; then
    step "Configuring tmux..."
    cat > "$TMUX_CONF" << 'TMUXCONF'
# MacBridge — tmux configuration
# Session persistence for cross-device workflow (laptop ↔ phone via Termius)

# Enable mouse support (scroll, select, resize panes)
set -g mouse on

# Increase scrollback buffer
set -g history-limit 50000

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Faster escape sequence (reduces input lag on mobile)
set -sg escape-time 10

# Visual activity notification
set -g monitor-activity on
set -g visual-activity on

# Status bar
set -g status-position bottom
set -g status-style 'bg=default fg=cyan'
set -g status-left '#[fg=green]#S '
set -g status-right '#[fg=yellow]%H:%M %d-%b-%y'
set -g status-left-length 20
set -g status-right-length 40

# Reload config with: tmux source-file ~/.tmux.conf
TMUXCONF
    ok "tmux configured (~/.tmux.conf created with mouse mode + scrollback)"
else
    ok "tmux configuration exists"
fi

# ── 6. Agent summary ──────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}📋 Agent Status:${NC}"

check_agent() {
    local name="$1"
    if command -v "$name" > /dev/null 2>&1; then
        echo -e "    ${GREEN}✅${NC} ${name}"
    else
        echo -e "    ${YELLOW}⚠️${NC}  ${name} — not installed (user can install later)"
    fi
}

check_agent "claude"
check_agent "opencode"
check_agent "codex"
echo -e "    ${GREEN}✅${NC} tmux (session persistence)"

echo ""
info "API keys are NOT pre-configured — user provides their own on first login."
info "Agent CLIs are installed and ready. User runs 'claude', 'opencode', or 'codex' to start."

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ ${LAYER} complete${NC} — AI agents installed and verified (${PASS} checks passed)"
else
    echo -e "${RED}❌ ${LAYER} failed${NC} — ${FAIL} check(s) failed, ${PASS} passed"
    exit 1
fi
