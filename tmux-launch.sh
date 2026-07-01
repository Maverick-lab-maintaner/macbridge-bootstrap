#!/bin/bash
# =============================================================================
# MacBridge — tmux Session Launcher
# =============================================================================
# Auto-launches a tmux session on SSH login. If a macbridge session exists,
# attaches to it. If not, creates one and optionally starts the user's
# preferred AI agent.
#
# Architecture:
#   Added to ~/.zprofile so it runs on every SSH login.
#   Detached sessions persist across disconnects — laptop → phone → laptop.
#   The agent keeps working while you're away.
#
# Usage:
#   bash tmux-launch.sh                         # Run once (added to .zprofile)
#   bash tmux-launch.sh --install               # Add to .zprofile for auto-launch
#   bash tmux-launch.sh --uninstall             # Remove from .zprofile
#   bash tmux-launch.sh --agent claude          # Auto-start Claude Code on session create
#   bash tmux-launch.sh --agent opencode        # Auto-start OpenCode
#   bash tmux-launch.sh --agent codex           # Auto-start Codex
#   bash tmux-launch.sh --agent ask             # Ask which agent on first launch
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; YELLOW='\033[1;33m'; NC='\033[0m'

SESSION_NAME="macbridge"
PREFERRED_AGENT="${MACBRIDGE_AGENT:-ask}"
INSTALL=false; UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --install)   INSTALL=true; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        --agent)     PREFERRED_AGENT="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: bash tmux-launch.sh [--install|--uninstall] [--agent claude|opencode|codex|ask]"
            exit 0 ;;
        *) shift ;;
    esac
done

# ── Install / Uninstall ────────────────────────────────────────────────────

ZPROFILE="$HOME/.zprofile"
LAUNCHER_MARKER="# MacBridge tmux launcher"

if [ "$UNINSTALL" = true ]; then
    if grep -qF "$LAUNCHER_MARKER" "$ZPROFILE" 2>/dev/null; then
        grep -vF "$LAUNCHER_MARKER" "$ZPROFILE" > "${ZPROFILE}.tmp" && mv "${ZPROFILE}.tmp" "$ZPROFILE"
        # Also remove the adjacent source line
        sed -i.bak '/tmux-launcher\.sh/d' "$ZPROFILE" 2>/dev/null || true
        rm -f "${ZPROFILE}.bak"
        echo "✅ tmux auto-launch removed from .zprofile"
    else
        echo "tmux auto-launch not installed in .zprofile"
    fi
    exit 0
fi

if [ "$INSTALL" = true ]; then
    # Remove old install first
    if grep -qF "$LAUNCHER_MARKER" "$ZPROFILE" 2>/dev/null; then
        grep -vF "$LAUNCHER_MARKER" "$ZPROFILE" > "${ZPROFILE}.tmp" && mv "${ZPROFILE}.tmp" "$ZPROFILE"
    fi

    cat >> "$ZPROFILE" << ZPROFILE_ENTRY

$LAUNCHER_MARKER
if [ -f "\$HOME/macbridge-bootstrap/tmux-launch.sh" ]; then
    bash "\$HOME/macbridge-bootstrap/tmux-launch.sh"
fi
ZPROFILE_ENTRY

    echo "✅ tmux auto-launch installed in .zprofile"
    echo "   On next SSH login, you'll auto-attach to tmux session 'macbridge'."
    echo "   Preferred agent: ${PREFERRED_AGENT}"
    echo "   Change with: export MACBRIDGE_AGENT=<agent> && bash tmux-launch.sh --install"
    exit 0
fi

# ── Launcher logic ─────────────────────────────────────────────────────────

# Don't run inside an existing tmux session (prevents nesting)
if [ -n "${TMUX:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

# If not in an interactive SSH session, skip (e.g., SCP, rsync)
if [ -z "${SSH_TTY:-}" ] && [ -z "${TERM_PROGRAM:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

# ── Determine preferred agent ──────────────────────────────────────────────

detect_agents() {
    local available=""
    command -v claude > /dev/null 2>&1   && available="$available claude"
    command -v opencode > /dev/null 2>&1 && available="$available opencode"
    command -v codex > /dev/null 2>&1    && available="$available codex"

    if [ -z "$available" ]; then
        echo "none"
    else
        echo "$available" | tr ' ' '\n' | head -3 | tr '\n' ' '
    fi
}

pick_agent() {
    if [ "$PREFERRED_AGENT" != "ask" ]; then
        if command -v "$PREFERRED_AGENT" > /dev/null 2>&1; then
            echo "$PREFERRED_AGENT"
            return 0
        fi
    fi

    local agents; agents=$(detect_agents)
    local first; first=$(echo "$agents" | awk '{print $1}')

    if [ "$agents" = "none" ]; then
        echo ""
        return 0
    fi

    # If only one agent installed, use it
    local count; count=$(echo "$agents" | wc -w | tr -d ' ')
    if [ "$count" -eq 1 ]; then
        echo "$first"
        return 0
    fi

    # Multiple agents — use first available (user can change with --agent)
    echo "$first"
}

AGENT=$(pick_agent)

# ── Session management ─────────────────────────────────────────────────────

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # Session exists — attach
    echo ""
    echo -e "  ${GREEN}→${NC} Attaching to existing session: ${BOLD}${SESSION_NAME}${NC}"
    echo -e "  ${CYAN}💡${NC}  Detach: Ctrl+B then D"
    echo -e "  ${CYAN}💡${NC}  Reconnect from phone: install Termius → add SSH key → tmux attach -t ${SESSION_NAME}"
    echo ""
    sleep 1
    exec tmux attach-session -t "$SESSION_NAME"
else
    # Create new session
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              🟢  MacBridge — Session Ready                   ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Create the session with a welcome pane
    tmux new-session -d -s "$SESSION_NAME" -n "main" 2>/dev/null || true

    # Send welcome message
    tmux send-keys -t "$SESSION_NAME" "clear" C-m 2>/dev/null || true
    tmux send-keys -t "$SESSION_NAME" "echo ''" C-m 2>/dev/null || true
    tmux send-keys -t "$SESSION_NAME" "echo '  MacBridge session started. Your agent is ready.'" C-m 2>/dev/null || true
    tmux send-keys -t "$SESSION_NAME" "echo ''" C-m 2>/dev/null || true

    # Auto-start preferred agent if available
    if [ -n "$AGENT" ] && [ "$AGENT" != "none" ]; then
        tmux send-keys -t "$SESSION_NAME" "echo '  Starting ${AGENT}...'" C-m 2>/dev/null || true
        if [ "$AGENT" = "codex" ]; then
            tmux send-keys -t "$SESSION_NAME" "codex" C-m 2>/dev/null || true
        else
            tmux send-keys -t "$SESSION_NAME" "$AGENT" C-m 2>/dev/null || true
        fi
    else
        echo -e "  ${YELLOW}⚠️${NC}  No AI agents found. Type 'claude', 'opencode', or 'codex' when ready."
        echo ""
    fi

    echo -e "  ${GREEN}→${NC} Creating new session: ${BOLD}${SESSION_NAME}${NC}"
    echo -e "  ${CYAN}→${NC} Agent: ${AGENT:-none selected}"
    echo -e "  ${CYAN}💡${NC}  Detach: Ctrl+B then D"
    echo -e "  ${CYAN}💡${NC}  Change agent: export MACBRIDGE_AGENT=claude"
    echo ""
    sleep 1
    exec tmux attach-session -t "$SESSION_NAME"
fi
