#!/bin/bash
# =============================================================================
# MacBridge — Bootstrap
# =============================================================================
# Provisions a macOS machine into a Flutter/iOS/AI-agent-ready development
# environment. Single command. Four layers. Verified at every step.
#
# Usage:
#   bash bootstrap.sh              # Run all layers
#   bash bootstrap.sh --tier agent # All layers, same as default
#   bash bootstrap.sh --from 2     # Start from layer 2 (skip machine + Apple)
#   bash bootstrap.sh --report-to https://dash.example.com/api/report  # Ship logs centrally
#
# Architecture:
#   Layer 0: Machine Reachable  — SSH, disk, ownership, networking
#   Layer 1: Apple Toolchain    — Xcode, license, Simulator runtime
#   Layer 2: Development Tools  — Homebrew, Flutter, Ruby, CocoaPods, Git
#   Layer 3: AI Agents          — Node.js, Claude Code, OpenCode, Codex, tmux
#   Layer 4: Smoke Test         — flutter create → build ios → verify
#
# Lessons encoded (Phase 0, 10 lessons):
#   Lesson 7:  This script IS the product — the Mac is commodity hardware
#   Lesson 8:  Verification at every layer — never assume
#   Lesson 9:  User never sees provisioning — runs before customer login
#   Lesson 10: One command does everything — `bootstrap`
#
# Prerequisites: macOS 14+ (Sonoma or later), internet connection
# =============================================================================

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Export paths for layer scripts
export MACBRIDGE_LIB_DIR="$LIB_DIR"
export MACBRIDGE_LOG_DIR="$LOG_DIR"

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Parse arguments ────────────────────────────────────────────────────────

START_LAYER=0
TIER="agent"
REPORT_URL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --from)
            START_LAYER="$2"
            shift 2
            ;;
        --tier)
            TIER="$2"
            shift 2
            ;;
        --report-to)
            REPORT_URL="$2"
            export MACBRIDGE_REPORT_URL="$REPORT_URL"
            shift 2
            ;;
        --help|-h)
            echo "Usage: bash bootstrap.sh [options]"
            echo ""
            echo "Options:"
            echo "  --from N      Start from layer N (0-4)"
            echo "  --tier TYPE   Provisioning tier: vanilla (no agents, \$19/mo) or agent (full, \$39/mo)"
            echo "  --report-to URL  Ship layer results to central endpoint (POST JSON)"
            echo "  --help        Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage."
            exit 1
            ;;
    esac
done

# ── Banner ─────────────────────────────────────────────────────────────────

clear 2>/dev/null || true
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                              ║${NC}"
echo -e "${BOLD}${CYAN}║              🏗️  MacBridge — Bootstrap                       ║${NC}"
echo -e "${BOLD}${CYAN}║              Flutter iOS Development Environment             ║${NC}"
echo -e "${BOLD}${CYAN}║                                                              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Started:${NC} $(date)"
echo -e "  ${CYAN}Log:${NC}     ${LOG_DIR}/bootstrap-${TIMESTAMP}.log"
echo -e "  ${CYAN}Tier:${NC}    ${TIER}"
echo ""

# ── Ensure log directory exists ────────────────────────────────────────────

mkdir -p "$LOG_DIR"

# ── Source shared utilities (centralized logging, webhook reporting) ───────

if [ -f "${LIB_DIR}/_utils.sh" ]; then
    source "${LIB_DIR}/_utils.sh"
    # Report bootstrap start to central endpoint if configured
    report_event "bootstrap_started" "info" "Bootstrap ${TIMESTAMP} starting from layer ${START_LAYER}" "" || true
fi

# ── Layer execution ────────────────────────────────────────────────────────

# Track results for summary
declare -A LAYER_STATUS
TOTAL_START=$(date +%s)

run_layer() {
    local num="$1"
    local name="$2"
    local script="$3"

    if [ "$num" -lt "$START_LAYER" ]; then
        echo -e "${YELLOW}⏭️  Skipping Layer ${num} (--from ${START_LAYER})${NC}"
        LAYER_STATUS[$num]="SKIPPED"
        return 0
    fi

    echo -e "${BOLD}${CYAN}━━━ Layer ${num}: ${name} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    LAYER_START=$(date +%s)

    if [ -f "$script" ]; then
        if bash "$script" 2>&1 | tee -a "${LOG_DIR}/bootstrap-${TIMESTAMP}.log"; then
            LAYER_END=$(date +%s)
            LAYER_DURATION=$((LAYER_END - LAYER_START))
            echo ""
            echo -e "${GREEN}✅ Layer ${num} passed (${LAYER_DURATION}s)${NC}"
            LAYER_STATUS[$num]="PASSED"
            report_event "bootstrap_layer" "pass" "Layer ${num}: ${name} — ${LAYER_DURATION}s" "$num" || true
            return 0
        else
            LAYER_END=$(date +%s)
            LAYER_DURATION=$((LAYER_END - LAYER_START))
            echo ""
            echo -e "${RED}❌ Layer ${num} FAILED (${LAYER_DURATION}s)${NC}"
            LAYER_STATUS[$num]="FAILED"
            report_event "bootstrap_layer" "fail" "Layer ${num}: ${name} — FAILED (${LAYER_DURATION}s)" "$num" || true
            return 1
        fi
    else
        echo -e "${RED}❌ Script not found: ${script}${NC}"
        LAYER_STATUS[$num]="MISSING"
        return 1
    fi
}

# ── Execute layers ─────────────────────────────────────────────────────────

FAILED_LAYER=0

run_layer 0 "Machine Reachable"  "${LIB_DIR}/layer0-machine.sh"  || FAILED_LAYER=0
run_layer 1 "Apple Toolchain"    "${LIB_DIR}/layer1-apple.sh"     || FAILED_LAYER=1
run_layer 2 "Development Tools"  "${LIB_DIR}/layer2-dev.sh"       || FAILED_LAYER=2

if [ "$TIER" = "vanilla" ]; then
    echo -e "${YELLOW}⏭️  Skipping Layer 3 (--tier vanilla — no AI agents)${NC}"
    echo ""
    LAYER_STATUS[3]="SKIPPED"
else
    run_layer 3 "AI Agents"      "${LIB_DIR}/layer3-agents.sh"    || FAILED_LAYER=3
fi

run_layer 4 "Smoke Test"         "${LIB_DIR}/layer4-project.sh"   || FAILED_LAYER=4

# ── Summary ────────────────────────────────────────────────────────────────

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))
TOTAL_MIN=$((TOTAL_DURATION / 60))
TOTAL_SEC=$((TOTAL_DURATION % 60))

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    Bootstrap Complete                        ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total time: ${TOTAL_MIN}m ${TOTAL_SEC}s"
echo ""
echo -e "  ${BOLD}Results:${NC}"

print_status() {
    local num="$1"
    local name="$2"
    local status="${LAYER_STATUS[$num]:-UNKNOWN}"

    case $status in
        PASSED)  echo -e "    ${GREEN}✅${NC} Layer ${num}: ${name}" ;;
        FAILED)  echo -e "    ${RED}❌${NC} Layer ${num}: ${name} — FAILED" ;;
        SKIPPED) echo -e "    ${YELLOW}⏭️${NC}  Layer ${num}: ${name} — skipped" ;;
        MISSING) echo -e "    ${RED}❓${NC} Layer ${num}: ${name} — script missing" ;;
        *)       echo -e "    ${YELLOW}❓${NC} Layer ${num}: ${name} — ${status}" ;;
    esac
}

print_status 0 "Machine Reachable"
print_status 1 "Apple Toolchain"
print_status 2 "Development Tools"
print_status 3 "AI Agents"
print_status 4 "Smoke Test"

echo ""

# ── Final verdict ──────────────────────────────────────────────────────────

if [ "$FAILED_LAYER" -eq 0 ] && \
   [ "${LAYER_STATUS[0]}" != "FAILED" ] && \
   [ "${LAYER_STATUS[1]}" != "FAILED" ] && \
   [ "${LAYER_STATUS[2]}" != "FAILED" ] && \
   [ "${LAYER_STATUS[4]}" != "FAILED" ]; then

    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║                                                              ║${NC}"
    echo -e "${BOLD}${GREEN}║  🟢 MAC READY — ${TIER} tier                                  ║${NC}"
    echo -e "${BOLD}${GREEN}║                                                              ║${NC}"
    echo -e "${BOLD}${GREEN}║  All layers passed. This Mac is provisioned for:             ║${NC}"
    echo -e "${BOLD}${GREEN}║  • Flutter iOS development                                   ║${NC}"

    if [ "$TIER" = "agent" ]; then
        echo -e "${BOLD}${GREEN}║  • AI coding agents (Claude Code, OpenCode, Codex)           ║${NC}"
        echo -e "${BOLD}${GREEN}║  • Session persistence via tmux                              ║${NC}"
    fi

    echo -e "${BOLD}${GREEN}║                                                              ║${NC}"
    echo -e "${BOLD}${GREEN}║  Next steps:                                                 ║${NC}"
    echo -e "${BOLD}${GREEN}║  1. Add SSH key to GitHub (printed in Layer 2)              ║${NC}"
    echo -e "${BOLD}${GREEN}║  2. Run: gh auth login (GitHub device flow)                  ║${NC}"
    echo -e "${BOLD}${GREEN}║  3. Clone your project: git clone git@github.com:...         ║${NC}"

    if [ "$TIER" = "agent" ]; then
        echo -e "${BOLD}${GREEN}║  4. Start coding: claude / opencode / codex                  ║${NC}"
    else
        echo -e "${BOLD}${GREEN}║  4. Start coding: flutter run / flutter build ios            ║${NC}"
    fi

    echo -e "${BOLD}${GREEN}║                                                              ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Run ${CYAN}bash verify.sh${NC} to re-check environment health anytime."
    echo ""
    report_event "bootstrap_complete" "pass" "All 5 layers passed — ${TOTAL_MIN}m ${TOTAL_SEC}s" "" || true
    exit 0

else
    echo -e "${BOLD}${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║                                                              ║${NC}"
    echo -e "${BOLD}${RED}║  ❌ MAC NOT READY                                            ║${NC}"
    echo -e "${BOLD}${RED}║                                                              ║${NC}"
    echo -e "${BOLD}${RED}║  One or more layers failed.                                  ║${NC}"
    echo -e "${BOLD}${RED}║  First failure: Layer ${FAILED_LAYER}                                        ║${NC}"
    echo -e "${BOLD}${RED}║                                                              ║${NC}"
    echo -e "${BOLD}${RED}║  Fix the failing layer, then re-run:                         ║${NC}"
    echo -e "${BOLD}${RED}║    bash bootstrap.sh --from ${FAILED_LAYER}                          ║${NC}"
    echo -e "${BOLD}${RED}║                                                              ║${NC}"
    echo -e "${BOLD}${RED}║  Logs: ${LOG_DIR}/bootstrap-${TIMESTAMP}.log                  ║${NC}"
    echo -e "${BOLD}${RED}║                                                              ║${NC}"
    echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    report_event "bootstrap_complete" "fail" "Layer ${FAILED_LAYER} failed" "" || true
    exit 1
fi
