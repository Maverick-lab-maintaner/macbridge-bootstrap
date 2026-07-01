#!/bin/bash
# =============================================================================
# MacBridge — Health Daemon (healthd)
# =============================================================================
# Fleet health agent. Runs MacBridge environment checks and reports status
# to a central endpoint. Designed to run via cron every 5 minutes.
#
# Architecture:
#   Every Mac runs healthd on a cron schedule.
#   healthd runs verify checks, outputs JSON, ships to a webhook.
#   Central dashboard consumes webhook data to show fleet status.
#
# Usage:
#   bash healthd.sh                        # Run once, print JSON to stdout
#   bash healthd.sh --webhook <url>        # Run once, ship JSON to endpoint
#   bash healthd.sh --interval 300         # Run every 300s (for daemon mode)
#   bash healthd.sh --install-cron         # Install a cron job to run every 5 min
#
# Cron installation (on each Mac):
#   bash healthd.sh --install-cron --webhook https://your-dashboard.app/api/health
#
# Lessons encoded (Phase 0):
#   Lesson 8: Verification at every layer — healthd is the fleet-wide verify
#   Lesson 9: User never sees provisioning — healthd is invisible until needed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
LOG_DIR="${SCRIPT_DIR}/logs"

# Source shared utilities (fallback to standalone if not present)
if [ -f "${LIB_DIR}/_utils.sh" ]; then
    source "${LIB_DIR}/_utils.sh"
else
    GREEN=''; RED=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

# ── Parse arguments ────────────────────────────────────────────────────────

WEBHOOK_URL=""
INTERVAL=0
INSTALL_CRON=false
ONCE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --webhook)    WEBHOOK_URL="$2"; export MACBRIDGE_REPORT_URL="$2"; shift 2 ;;
        --interval)   INTERVAL="$2"; ONCE=false; shift 2 ;;
        --install-cron) INSTALL_CRON=true; shift ;;
        --once)       ONCE=true; shift ;;
        --help|-h)
            echo "Usage: bash healthd.sh [options]"
            echo ""
            echo "Options:"
            echo "  --webhook URL      Report results to this endpoint (POST JSON)"
            echo "  --interval SECS    Run continuously every SECS seconds"
            echo "  --install-cron     Install a cron job to run every 5 minutes"
            echo "  --once             Run once and exit (default)"
            exit 0
            ;;
        *) shift ;;
    esac
done

# ── Health Check Engine ────────────────────────────────────────────────────

run_health_check() {
    local hostname="${HOSTNAME:-$(hostname -s 2>/dev/null || echo 'unknown')}"
    local machine_id="${MACBRIDGE_MACHINE_ID:-$hostname}"
    local timestamp; timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local checks_json=""; local overall="healthy"; local failed_count=0

    record() {
        local key="$1"; local label="$2"; local status="$3"; local value="${4:-}"
        [ "$status" = "FAIL" ] && ((failed_count++)) || true
        [ "$status" = "FAIL" ] && overall="degraded"
        checks_json="${checks_json}$([ -n "$checks_json" ] && echo ",")
    \"$key\": {\"label\":\"$label\",\"status\":\"$status\",\"value\":\"$value\"}"
    }

    check_ver() {
        local key="$1"; local label="$2"; local cmd="$3"
        if command -v "${cmd%% *}" > /dev/null 2>&1; then
            local ver; ver=$(eval "$cmd" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 || echo "unknown")
            record "$key" "$label" "PASS" "$ver"
        else
            record "$key" "$label" "FAIL" "not found"
        fi
    }

    check_ex() {
        local key="$1"; local label="$2"; local check="$3"; local value="${4:-}"
        if eval "$check" > /dev/null 2>&1; then
            record "$key" "$label" "PASS" "$value"
        else
            record "$key" "$label" "FAIL" "missing"
        fi
    }

    # System
    local disk; disk=$(df -g / 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [ "$disk" -gt 50 ] 2>/dev/null; then record "disk" "Disk free" "PASS" "${disk}GB"
    else record "disk" "Disk free" "FAIL" "${disk}GB"; fi

    local load; load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || echo "0")
    record "load" "System load" "PASS" "$load"

    # Apple Toolchain
    check_ex "xcode_app"  "Xcode"         "[ -d /Applications/Xcode.app ]"
    check_ver "xcodebuild" "xcodebuild"   "xcodebuild -version 2>/dev/null"
    check_ex "simulator"  "iOS Simulator" "xcrun simctl list runtimes 2>/dev/null | grep -q iOS"

    # Dev Tools
    check_ver "homebrew"  "Homebrew"     "brew --version 2>/dev/null"
    check_ver "flutter"   "Flutter SDK"  "flutter --version 2>/dev/null"
    check_ver "ruby"      "Ruby"         "ruby --version 2>/dev/null"
    check_ver "cocoapods" "CocoaPods"    "pod --version 2>/dev/null"
    check_ver "git"       "Git"          "git --version 2>/dev/null"
    check_ex "ssh_key"    "SSH key"      "[ -f \$HOME/.ssh/id_ed25519 ]"
    check_ex "gh_cli"     "GitHub CLI"   "which gh > /dev/null 2>&1"

    # Agents
    check_ver "node"     "Node.js"      "node --version 2>/dev/null"
    check_ex  "claude"   "Claude Code"  "which claude > /dev/null 2>&1"
    check_ex  "opencode" "OpenCode"     "which opencode > /dev/null 2>&1"
    check_ex  "codex"    "Codex CLI"    "which codex > /dev/null 2>&1"
    check_ex  "tmux"     "tmux"         "which tmux > /dev/null 2>&1"

    # Connectivity
    if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then record "network" "Network" "PASS" "reachable"
    else record "network" "Network" "FAIL" "unreachable"; fi

    if ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 git@github.com 2>&1 | grep -qE "successfully authenticated|does not provide shell"; then
        record "github_ssh" "GitHub SSH" "PASS" "authenticated"
    else
        record "github_ssh" "GitHub SSH" "WARN" "not configured"
    fi

    # Assemble and output
    local json
    json=$(printf '{"machine_id":"%s","hostname":"%s","timestamp":"%s","overall":"%s","failed_count":%d,"checks":{%s}}' \
        "$machine_id" "$hostname" "$timestamp" "$overall" "$failed_count" "$checks_json")

    echo "$json" | python3 -m json.tool 2>/dev/null || echo "$json"

    if [ -n "$WEBHOOK_URL" ]; then
        curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d "$json" \
            --connect-timeout 5 --max-time 10 > /dev/null 2>&1 || true
    fi
}

# ── Install cron ───────────────────────────────────────────────────────────

if [ "$INSTALL_CRON" = true ]; then
    SCRIPT_PATH="$(realpath "$0")"
    CRON_CMD="*/5 * * * * bash '$SCRIPT_PATH' --once"
    if [ -n "$WEBHOOK_URL" ]; then
        CRON_CMD="$CRON_CMD --webhook '$WEBHOOK_URL'"
    fi

    # Check if already installed
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        echo "healthd cron already installed. Replacing..."
        crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
    fi

    (crontab -l 2>/dev/null || true; echo "$CRON_CMD") | crontab -
    echo "✅ healthd cron installed (runs every 5 minutes)"
    echo "   View with: crontab -l"
    echo "   Remove with: crontab -l | grep -v healthd | crontab -"
    exit 0
fi

# ── Run mode ───────────────────────────────────────────────────────────────

if [ "$ONCE" = true ] && [ "$INTERVAL" -eq 0 ]; then
    run_health_check
    exit 0
fi

# Daemon mode
echo "healthd running every ${INTERVAL}s. Press Ctrl+C to stop."
while true; do
    run_health_check
    sleep "$INTERVAL"
done
