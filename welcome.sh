#!/bin/bash
# =============================================================================
# MacBridge — Welcome Wizard (Stage 3)
# =============================================================================
# Runs on first login after bootstrap completes. Guides the user through
# GitHub authentication, AI provider setup, and project cloning.
#
# Architecture:
#   Stage 1: Golden Image  (built once, manual GUI)
#   Stage 2: Bootstrap     (bootstrap.sh — ✅ built)
#   Stage 3: Welcome Wizard (this script — runs on first login)
#
# The Mac is verified. The tools are installed. The user needs:
#   1. GitHub access        → gh auth login (Device Flow)
#   2. AI provider keys     → Claude / OpenCode / Codex
#   3. Their project        → git clone
#   4. Session persistence  → tmux
#
# Usage:
#   bash welcome.sh                    # Full interactive wizard
#   bash welcome.sh --skip-github      # GitHub already configured
#   bash welcome.sh --repo git@github.com:user/repo.git  # Auto-clone
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
export MACBRIDGE_LOG_DIR="${SCRIPT_DIR}/logs"

[ -f "${LIB_DIR}/_utils.sh" ] && source "${LIB_DIR}/_utils.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SKIP_GITHUB=false; REPO_URL=""; TIER="agent"

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-github) SKIP_GITHUB=true; shift ;;
        --repo) REPO_URL="$2"; shift 2 ;;
        --tier) TIER="$2"; shift 2 ;;
        *) shift ;;
    esac
done

clear 2>/dev/null || true

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                              ║${NC}"
echo -e "${BOLD}${CYAN}║              👋  Welcome to MacBridge                        ║${NC}"
echo -e "${BOLD}${CYAN}║              Your Mac is ready. Let's get you coding.        ║${NC}"
echo -e "${BOLD}${CYAN}║                                                              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Estimated setup: ~3 minutes${NC}"
echo ""

# ── Step 0: Verify environment is ready ────────────────────────────────────

echo -e "${BOLD}[0/4] Verifying environment...${NC}"
echo ""

CHECKS_OK=true

check_tool() {
    local name="$1"
    if command -v "$name" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} $name"
    else
        echo -e "  ${RED}❌${NC} $name — NOT FOUND"
        CHECKS_OK=false
    fi
}

check_tool "flutter"
check_tool "xcodebuild"
check_tool "pod"
check_tool "node"
check_tool "gh"
check_tool "tmux"

echo ""
if [ "$CHECKS_OK" = false ]; then
    echo -e "${RED}Some tools are missing. Run: bash bootstrap.sh${NC}"
    exit 1
fi

echo -e "${GREEN}Environment verified. All tools present.${NC}"
echo ""

# ── Step 1: GitHub Authentication ──────────────────────────────────────────

if [ "$SKIP_GITHUB" = false ]; then
    echo -e "${BOLD}[1/4] GitHub Authentication${NC}"
    echo ""

    # Check if already authenticated
    if gh auth status > /dev/null 2>&1; then
        GH_USER=$(gh auth status 2>&1 | grep -oE 'Logged in to github.com as [^ ]+' | sed 's/Logged in to github.com as //' || echo "unknown")
        echo -e "  ${GREEN}✅${NC} Already authenticated as ${CYAN}${GH_USER}${NC}"
    else
        echo -e "  ${CYAN}→${NC} Starting GitHub Device Flow..."
        echo -e "  ${CYAN}→${NC} A browser will open. Enter the code shown in your terminal."
        echo ""

        if gh auth login --hostname github.com --web --git-protocol ssh 2>/dev/null; then
            echo ""
            echo -e "  ${GREEN}✅${NC} GitHub authenticated"
        else
            echo ""
            echo -e "  ${YELLOW}⚠️${NC}  GitHub auth skipped. You can run 'gh auth login' later."
            echo -e "  ${YELLOW}→${NC}   Without GitHub auth, you won't be able to clone private repos."
        fi
    fi

    echo ""
fi

# ── Step 2: AI Provider API Keys (agent tier only) ──────────────────────────

PROVIDERS_CONFIGURED=0

if [ "$TIER" = "vanilla" ]; then
    echo -e "${BOLD}[2/4] AI Provider Setup${NC}"
    echo ""
    echo -e "  ${YELLOW}⏭️${NC}  Skipped — vanilla tier does not include AI agents."
    echo -e "  ${CYAN}→${NC}   Upgrade to agent tier ($39/mo) for Claude Code, OpenCode, and Codex."
    echo ""
else
    echo -e "${BOLD}[2/4] AI Provider Setup${NC}"
    echo ""

setup_claude() {
    echo -e "  ${BOLD}Claude Code (Anthropic)${NC}"
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo -e "  ${GREEN}✅${NC} ANTHROPIC_API_KEY found in environment"
        ((PROVIDERS_CONFIGURED++)) || true
        return 0
    fi

    echo -e "  ${CYAN}→${NC} Get your API key: ${CYAN}https://console.anthropic.com/settings/keys${NC}"
    echo ""
    read -r -p "  Paste your Anthropic API key (or press Enter to skip): " API_KEY
    echo ""

    if [ -n "$API_KEY" ]; then
        echo "export ANTHROPIC_API_KEY=\"$API_KEY\"" >> "$HOME/.zprofile"
        export ANTHROPIC_API_KEY="$API_KEY"
        echo -e "  ${GREEN}✅${NC} Claude Code configured"
        ((PROVIDERS_CONFIGURED++)) || true
    else
        echo -e "  ${YELLOW}⚠️${NC}  Skipped. Run 'export ANTHROPIC_API_KEY=...' to configure later."
    fi
}

setup_opencode() {
    echo -e "  ${BOLD}OpenCode${NC}"
    if [ -n "${OPENAI_API_KEY:-}" ] || [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo -e "  ${GREEN}✅${NC} API key available (OpenCode uses existing keys)"
        ((PROVIDERS_CONFIGURED++)) || true
        return 0
    fi

    echo -e "  ${CYAN}→${NC} OpenCode uses your existing OpenAI or Anthropic API keys."
    echo -e "  ${CYAN}→${NC} Set OPENAI_API_KEY or ANTHROPIC_API_KEY in your environment."
    echo ""

    read -r -p "  Paste your OpenAI API key (or press Enter to skip): " API_KEY
    echo ""

    if [ -n "$API_KEY" ]; then
        echo "export OPENAI_API_KEY=\"$API_KEY\"" >> "$HOME/.zprofile"
        export OPENAI_API_KEY="$API_KEY"
        echo -e "  ${GREEN}✅${NC} OpenCode configured"
        ((PROVIDERS_CONFIGURED++)) || true
    else
        echo -e "  ${YELLOW}⚠️${NC}  Skipped. You can configure this later."
    fi
}

setup_codex() {
    echo -e "  ${BOLD}Codex CLI${NC}"
    if [ -n "${OPENAI_API_KEY:-}" ]; then
        echo -e "  ${GREEN}✅${NC} OPENAI_API_KEY available (Codex inherits)"
        ((PROVIDERS_CONFIGURED++)) || true
        return 0
    fi

    echo -e "  ${CYAN}→${NC} Codex uses your OpenAI API key. Already configured if OPENAI_API_KEY is set."
    echo -e "  ${YELLOW}⚠️${NC}  No API key found. Run 'export OPENAI_API_KEY=...' to configure."
    echo ""
}

setup_claude
echo ""
setup_opencode
echo ""
setup_codex

echo ""
fi

# ── Step 3: Clone Project ──────────────────────────────────────────────────

echo -e "${BOLD}[3/4] Project Setup${NC}"
echo ""

if [ -n "$REPO_URL" ]; then
    echo -e "  ${CYAN}→${NC} Cloning: ${REPO_URL}"
    git clone "$REPO_URL" "$HOME/project" 2>/dev/null && \
        echo -e "  ${GREEN}✅${NC} Project cloned to ~/project" || \
        echo -e "  ${RED}❌${NC} Clone failed — check repository URL and GitHub auth"
else
    echo -e "  ${CYAN}→${NC} Clone your Flutter project:"
    echo ""
    echo -e "    ${BOLD}git clone git@github.com:your-username/your-repo.git ~/project${NC}"
    echo ""
    echo -e "  ${YELLOW}💡${NC}  Tip: re-run with ${CYAN}--repo git@github.com:user/repo.git${NC} to auto-clone"
fi

echo ""

# ── Step 4: Start tmux Session ─────────────────────────────────────────────

echo -e "${BOLD}[4/4] Session Persistence${NC}"
echo ""

if tmux has-session -t macbridge 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} tmux session 'macbridge' already running"
    echo -e "  ${CYAN}→${NC} Attach: ${BOLD}tmux attach -t macbridge${NC}"
else
    tmux new-session -d -s macbridge 2>/dev/null || true
    echo -e "  ${GREEN}✅${NC} tmux session 'macbridge' started"
    echo -e "  ${CYAN}→${NC} Attach: ${BOLD}tmux attach -t macbridge${NC}"
fi

echo ""

# ── Summary ────────────────────────────────────────────────────────────────

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    🟢  You're Ready                          ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Quick reference:${NC}"
echo ""
echo -e "  ${CYAN}Attach session:${NC}     tmux attach -t macbridge"

if [ "$TIER" = "agent" ]; then
    echo -e "  ${CYAN}Start Claude:${NC}       claude"
    echo -e "  ${CYAN}Start OpenCode:${NC}     opencode"
    echo -e "  ${CYAN}Start Codex:${NC}       codex"
else
    echo -e "  ${CYAN}Start coding:${NC}      flutter run / flutter build ios"
fi

echo -e "  ${CYAN}Build iOS:${NC}         cd ~/project && flutter build ios"
echo -e "  ${CYAN}Health check:${NC}      bash verify.sh"
echo ""

if [ "$TIER" = "agent" ] && [ "$PROVIDERS_CONFIGURED" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠️  No AI providers configured. Set API keys to use agents.${NC}"
    echo ""
fi

if [ "$TIER" = "vanilla" ]; then
    echo -e "  ${GREEN}✅${NC} Vanilla tier — Flutter iOS toolchain only"
    echo -e "  ${CYAN}💡${NC}  Upgrade to agent tier ($39/mo): pre-installed AI agents + skill library"
    echo ""
fi

echo -e "  ${GREEN}✅${NC} GitHub: $(gh auth status 2>&1 | grep -oE 'Logged in to github.com as [^ ]+' || echo 'not configured')"
echo -e "  ${GREEN}✅${NC} tmux session: macbridge"

if [ "$TIER" = "agent" ]; then
    echo -e "  ${GREEN}✅${NC} AI providers: ${PROVIDERS_CONFIGURED}/3 configured"
fi

echo ""

if [ "$TIER" = "agent" ]; then
    echo -e "  ${CYAN}💡${NC}  From your phone: install Termius → add SSH key → tmux attach -t macbridge"
    echo -e "  ${CYAN}💡${NC}  Agent keeps working. You switch devices. Session stays alive."
else
    echo -e "  ${CYAN}💡${NC}  Need AI agents? Re-provision with: bash bootstrap.sh --tier agent"
fi
echo ""
