#!/bin/bash
# =============================================================================
# MacBridge — Verify
# =============================================================================
# Independent health check script. Validates the entire MacBridge environment
# without making any changes. Can be run at any time to confirm the Mac is
# still in a ready state.
#
# Runs AFTER bootstrap to confirm success, or standalone to audit an existing
# Mac. Read-only — never installs, never modifies.
#
# Usage:
#   bash verify.sh          # Full verification
#   bash verify.sh --quick  # Fast check (critical paths only)
#   bash verify.sh --json   # Machine-readable JSON output
#
# Lessons encoded (Phase 0):
#   Lesson 8: Verification at every layer — this is the independent audit
#   Lesson 4: Ownership checks — catches silent permission breaks
# =============================================================================

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────

QUICK_MODE=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick) QUICK_MODE=true; shift ;;
        --json)  JSON_MODE=true; shift ;;
        --help|-h)
            echo "Usage: bash verify.sh [--quick] [--json]"
            exit 0
            ;;
        *) shift ;;
    esac
done

# Track results
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARN=0
declare -A CHECK_RESULTS

# ── Helpers ────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

check() {
    local name="$1"
    local command="$2"
    local label="${3:-$name}"

    if eval "$command" > /dev/null 2>&1; then
        CHECK_RESULTS["$name"]="PASS"
        ((CHECKS_PASSED++)) || true
        if [ "$JSON_MODE" = false ]; then
            printf "  ${GREEN}✅${NC} %-35s %s\n" "$label" "$(eval "$command" 2>/dev/null | head -1 || echo '')"
        fi
        return 0
    else
        CHECK_RESULTS["$name"]="FAIL"
        ((CHECKS_FAILED++)) || true
        if [ "$JSON_MODE" = false ]; then
            printf "  ${RED}❌${NC} %-35s %s\n" "$label" "NOT FOUND"
        fi
        return 1
    fi
}

check_version() {
    local name="$1"
    local command="$2"
    local min_version="$3"
    local label="${4:-$name}"

    if ! command -v "${command%% *}" > /dev/null 2>&1; then
        CHECK_RESULTS["$name"]="FAIL"
        ((CHECKS_FAILED++)) || true
        if [ "$JSON_MODE" = false ]; then
            printf "  ${RED}❌${NC} %-35s %s\n" "$label" "NOT FOUND"
        fi
        return 1
    fi

    local version
    version=$(eval "$command" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 || echo "0")
    if [ "$(printf '%s\n' "$min_version" "$version" | sort -V | head -1)" = "$min_version" ]; then
        CHECK_RESULTS["$name"]="PASS"
        ((CHECKS_PASSED++)) || true
        if [ "$JSON_MODE" = false ]; then
            printf "  ${GREEN}✅${NC} %-35s %s\n" "$label" "$version"
        fi
        return 0
    else
        CHECK_RESULTS["$name"]="WARN"
        ((CHECKS_WARN++)) || true
        if [ "$JSON_MODE" = false ]; then
            printf "  ${YELLOW}⚠️${NC}  %-35s %s (min: %s)\n" "$label" "$version" "$min_version"
        fi
        return 0
    fi
}

# ── Banner ─────────────────────────────────────────────────────────────────

if [ "$JSON_MODE" = false ]; then
    echo ""
    echo -e "${BOLD}${CYAN}🔍 MacBridge — Environment Verification${NC}"
    echo "──────────────────────────────────────────────"
    echo ""
fi

# ── System checks ──────────────────────────────────────────────────────────

if [ "$JSON_MODE" = false ]; then
    echo -e "${BOLD}System:${NC}"
fi

check "os"          "uname -s | grep Darwin"                                    "macOS"
check "disk_50gb"   "[ \$(df -g / 2>/dev/null | awk 'NR==2 {print \$4}') -gt 50 ]"  "Disk >50GB free"
check "network"     "ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1"                   "Network reachable"
check "home_write"  "[ -w \$HOME ]"                                              "HOME writable"

if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── Apple toolchain ────────────────────────────────────────────────────────

if [ "$JSON_MODE" = false ]; then
    echo -e "${BOLD}Apple Toolchain:${NC}"
fi

check "xcode_app"   "[ -d /Applications/Xcode.app ]"                             "Xcode installed"
check "xcodebuild"  "xcodebuild -version"                                        "xcodebuild"
check "xcode_clt"   "xcode-select -p"                                            "Command Line Tools"

if [ "$QUICK_MODE" = false ]; then
    check "simulator"   "xcrun simctl list runtimes 2>/dev/null | grep -q iOS"   "iOS Simulator runtime"
else
    if [ "$JSON_MODE" = false ]; then
        printf "  ${YELLOW}⏭️${NC}  %-35s %s\n" "iOS Simulator" "(skipped — quick mode)"
    fi
fi

if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── Development tools ──────────────────────────────────────────────────────

if [ "$JSON_MODE" = false ]; then
    echo -e "${BOLD}Development Tools:${NC}"
fi

check       "homebrew"      "brew --version"                          "Homebrew"
check       "git"           "git --version"                           "Git"
check       "gh_cli"        "gh --version"                            "GitHub CLI"
check       "ssh_key"       "[ -f \$HOME/.ssh/id_ed25519 ]"           "SSH key (ed25519)"

# Flutter check with version display
if [ "$QUICK_MODE" = false ]; then
    check   "flutter"       "flutter --version"                       "Flutter SDK"

    if command -v flutter > /dev/null 2>&1; then
        if [ "$JSON_MODE" = false ]; then
            FLUTTER_CHANNEL=$(flutter channel 2>/dev/null | grep '*' | awk '{print $2}' || echo "unknown")
            printf "  ${CYAN}  →${NC} %-33s %s\n" "Flutter channel:" "$FLUTTER_CHANNEL"
        fi
    fi
else
    check   "flutter"       "flutter --version 2>/dev/null | head -1" "Flutter SDK"
fi

# Ruby check (Lesson 2: must be >= 3.0 for CocoaPods)
check_version "ruby"    "ruby --version"    "3.0"  "Ruby"
check       "cocoapods" "pod --version"            "CocoaPods"

if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── AI agents ──────────────────────────────────────────────────────────────

if [ "$JSON_MODE" = false ]; then
    echo -e "${BOLD}AI Agents:${NC}"
fi

check       "node"      "node --version"                          "Node.js"
check       "npm"       "npm --version"                           "npm"

if [ "$QUICK_MODE" = false ]; then
    check   "claude"    "which claude"                            "Claude Code"
    check   "opencode"  "which opencode"                          "OpenCode"
    check   "codex"     "which codex"                             "Codex CLI"
else
    if [ "$JSON_MODE" = false ]; then
        printf "  ${YELLOW}⏭️${NC}  %-35s %s\n" "Agent CLIs" "(skipped — quick mode)"
    fi
fi

check       "tmux"      "tmux -V"                                 "tmux"

if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── Configuration checks ───────────────────────────────────────────────────

if [ "$QUICK_MODE" = false ] && [ "$JSON_MODE" = false ]; then
    echo -e "${BOLD}Configuration:${NC}"

    check "ssh_config"   "[ -f \$HOME/.ssh/config ]"                "SSH config"
    check "tmux_config"  "[ -f \$HOME/.tmux.conf ]"                 "tmux config"
    check "ssh_keepalive" "grep -q ServerAliveInterval \$HOME/.ssh/config 2>/dev/null" "SSH keepalive"

    # PATH check — are critical tools reachable in a fresh shell?
    check "brew_in_path" "echo \$PATH | grep -q homebrew"           "Homebrew in PATH"

    echo ""
fi

# ── WHOAMI ─────────────────────────────────────────────────────────────────

if [ "$JSON_MODE" = false ]; then
    echo -e "${BOLD}Environment:${NC}"
    echo -e "  User:     ${CYAN}$(whoami)${NC}"
    echo -e "  Hostname: ${CYAN}$(hostname -s 2>/dev/null || echo 'unknown')${NC}"
    echo -e "  macOS:    ${CYAN}$(sw_vers -productVersion 2>/dev/null || echo 'unknown')${NC}"
    echo -e "  Arch:     ${CYAN}$(uname -m)${NC}"
    echo ""
fi

# ── Summary ────────────────────────────────────────────────────────────────

if [ "$JSON_MODE" = true ]; then
    # JSON output
    echo "{"
    echo "  \"status\": \"$([ "$CHECKS_FAILED" -eq 0 ] && echo 'ready' || echo 'degraded')\","
    echo "  \"checks_passed\": $CHECKS_PASSED,"
    echo "  \"checks_failed\": $CHECKS_FAILED,"
    echo "  \"checks_warn\": $CHECKS_WARN,"
    echo "  \"results\": {"
    FIRST=true
    for key in "${!CHECK_RESULTS[@]}"; do
        if [ "$FIRST" = false ]; then echo ","; fi
        printf "    \"%s\": \"%s\"" "$key" "${CHECK_RESULTS[$key]}"
        FIRST=false
    done
    echo ""
    echo "  }"
    echo "}"
    exit $([ "$CHECKS_FAILED" -eq 0 ] && echo 0 || echo 1)
fi

echo "──────────────────────────────────────────────"
echo -e "${BOLD}Verification Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC} ${CHECKS_PASSED}"
echo -e "  ${RED}Failed:${NC} ${CHECKS_FAILED}"
echo -e "  ${YELLOW}Warnings:${NC} ${CHECKS_WARN}"
echo ""

if [ "$CHECKS_FAILED" -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✅ Environment ready${NC} — All critical checks passed."
    echo ""
    exit 0
else
    echo -e "${BOLD}${RED}❌ Environment degraded${NC} — ${CHECKS_FAILED} check(s) failed."
    echo ""
    echo -e "  Run ${CYAN}bash bootstrap.sh --from <layer>${NC} to fix failing layers."
    echo ""
    exit 1
fi
