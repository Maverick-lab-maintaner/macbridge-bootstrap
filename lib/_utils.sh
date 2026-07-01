#!/bin/bash
# =============================================================================
# MacBridge — Shared Utilities
# =============================================================================
# Sourced by all MacBridge scripts. Provides consistent color output,
# logging, webhook reporting, and utility functions.
#
# Usage:
#   source "${MACBRIDGE_LIB_DIR:-lib}/_utils.sh"
#   # All functions and variables now available
# =============================================================================

# ── Color & Style ──────────────────────────────────────────────────────────

if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

# ── Counters ───────────────────────────────────────────────────────────────

PASS=0; FAIL=0; WARN=0

# ── Output Helpers ─────────────────────────────────────────────────────────

step()  { echo -e "${CYAN}  →${NC} $1"; }
ok()    { echo -e "  ${GREEN}✅${NC} $1"; ((PASS++)) || true; }
warn()  { echo -e "  ${YELLOW}⚠️${NC}  $1"; ((WARN++)) || true; }
fail()  { echo -e "  ${RED}❌${NC} $1"; ((FAIL++)) || true; }
info()  { echo -e "  ${CYAN}💡${NC} $1"; }
header(){ echo -e "${BOLD}${CYAN}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── Logging ────────────────────────────────────────────────────────────────

MACBRIDGE_REPORT_URL="${MACBRIDGE_REPORT_URL:-}"
MACBRIDGE_USAGE_LOG="${MACBRIDGE_USAGE_LOG:-${MACBRIDGE_LOG_DIR:-logs}/usage-events.ndjson}"

# Log a line to both stdout and the log file
log() {
    local msg="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $msg"
    if [ -n "${LOG_FILE:-}" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Ship a JSON payload to the central reporting endpoint
report_to_webhook() {
    local payload="$1"
    if [ -z "$MACBRIDGE_REPORT_URL" ]; then
        return 0
    fi
    curl -s -X POST "$MACBRIDGE_REPORT_URL" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --connect-timeout 5 --max-time 10 \
        > /dev/null 2>&1 || true
}

record_usage_event() {
    local payload="$1"
    local usage_dir
    usage_dir="$(dirname "$MACBRIDGE_USAGE_LOG")"
    mkdir -p "$usage_dir" 2>/dev/null || true
    printf '%s\n' "$payload" >> "$MACBRIDGE_USAGE_LOG" 2>/dev/null || true
}

json_string() {
    perl -MJSON::PP -e 'print encode_json($ARGV[0])' -- "${1-}"
}

# Send a structured event (layer pass/fail, health check result)
report_event() {
    local event_type="$1"  # bootstrap_layer, health_check, cleanup
    local status="$2"      # pass, fail, warn
    local detail="${3:-}"
    local layer="${4:-}"

    local hostname="${HOSTNAME:-$(hostname -s 2>/dev/null || echo 'unknown')}"
    local machine_id="${MACBRIDGE_MACHINE_ID:-$hostname}"

    local payload
    payload=$(cat <<EOF
{
  "machine_id": $(json_string "$machine_id"),
  "hostname": $(json_string "$hostname"),
  "event_type": $(json_string "$event_type"),
  "status": $(json_string "$status"),
  "detail": $(json_string "$detail"),
  "layer": $(json_string "$layer"),
  "timestamp": $(json_string "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"),
  "user": $(json_string "$(whoami)")
}
EOF
)
    record_usage_event "$payload"
    report_to_webhook "$payload"
}

version_ge() {
    local min_version="${1:-0}"
    local version="${2:-0}"
    local IFS=.
    local i
    local -a min_parts=() version_parts=()

    read -r -a min_parts <<< "$min_version"
    read -r -a version_parts <<< "$version"

    local max_len=${#min_parts[@]}
    if [ "${#version_parts[@]}" -gt "$max_len" ]; then
        max_len=${#version_parts[@]}
    fi

    for ((i = 0; i < max_len; i++)); do
        local min_part="${min_parts[i]:-0}"
        local version_part="${version_parts[i]:-0}"

        if ((10#$version_part > 10#$min_part)); then
            return 0
        fi
        if ((10#$version_part < 10#$min_part)); then
            return 1
        fi
    done

    return 0
}

resolve_script_path() {
    local target="${1:-$0}"
    (
        cd "$(dirname "$target")" >/dev/null 2>&1 || exit 1
        printf '%s/%s\n' "$(pwd)" "$(basename "$target")"
    )
}

# ── Utility Functions ──────────────────────────────────────────────────────

# Ensure a directory is in PATH (persists via .zprofile)
ensure_path() {
    local dir="$1"
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        echo "export PATH=\"$dir:\$PATH\"" >> "$HOME/.zprofile"
        export PATH="$dir:$PATH"
    fi
}

# Check if a command exists
has() {
    command -v "$1" > /dev/null 2>&1
}

# Get a version string from a command
version_of() {
    local cmd="$1"
    if has "$cmd"; then
        eval "$cmd --version 2>/dev/null" | head -1 || echo "unknown"
    else
        echo "not installed"
    fi
}

# Check disk space (returns GB available, or 0)
disk_free_gb() {
    df -g . 2>/dev/null | awk 'NR==2 {print $4}' || df -g / 2>/dev/null | awk 'NR==2 {print $4}' || echo "0"
}

# Check memory usage percentage
memory_usage_pct() {
    local used free
    used=$(vm_stat 2>/dev/null | awk '/Pages active/ {print $3}' | tr -d '.')
    free=$(vm_stat 2>/dev/null | awk '/Pages free/ {print $3}' | tr -d '.')
    if [ -n "$used" ] && [ -n "$free" ]; then
        local total=$((used + free))
        if [ "$total" -gt 0 ]; then
            echo $((used * 100 / total))
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Generate a unique machine ID if one doesn't exist
ensure_machine_id() {
    if [ -z "${MACBRIDGE_MACHINE_ID:-}" ]; then
        if [ -f /etc/machine-id ]; then
            MACBRIDGE_MACHINE_ID=$(cat /etc/machine-id)
        elif [ -f /var/db/dhcpd_leases ]; then
            MACBRIDGE_MACHINE_ID=$(hostname -s 2>/dev/null)-$(uuidgen 2>/dev/null | cut -c1-8 || echo "unknown")
        else
            MACBRIDGE_MACHINE_ID="mac-$(hostname -s 2>/dev/null || echo 'unknown')-$(date +%s | tail -c5)"
        fi
        export MACBRIDGE_MACHINE_ID
    fi
}

# ── Banner ─────────────────────────────────────────────────────────────────

print_banner() {
    local title="${1:-MacBridge}"
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              ${title}                       ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ── Summary Output ─────────────────────────────────────────────────────────

print_summary() {
    local layer_name="${1:-}"
    echo ""
    echo "──────────────────────────────────────────────"
    if [ "$FAIL" -eq 0 ]; then
        echo -e "${GREEN}✅ ${layer_name} complete${NC} — ${PASS} checks passed"
    else
        echo -e "${RED}❌ ${layer_name} failed${NC} — ${FAIL} failed, ${PASS} passed"
    fi
}

# ── Initialization ─────────────────────────────────────────────────────────

# Create required directories
mkdir -p "${MACBRIDGE_LOG_DIR:-logs}" 2>/dev/null || true
ensure_machine_id
