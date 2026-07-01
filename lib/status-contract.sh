#!/bin/bash

STATUS_SOURCE=""
STATUS_MACHINE_ID=""
STATUS_HOSTNAME=""
STATUS_TIMESTAMP=""
STATUS_PASS=0
STATUS_FAIL=0
STATUS_WARN=0
STATUS_CRITICAL_FAIL=0
STATUS_NAMES=()
STATUS_LABELS=()
STATUS_STATES=()
STATUS_SEVERITIES=()
STATUS_VALUES=()

status_contract_init() {
    STATUS_SOURCE="${1:-verify}"
    STATUS_MACHINE_ID="${MACBRIDGE_MACHINE_ID:-${HOSTNAME:-$(hostname -s 2>/dev/null || echo 'unknown')}}"
    STATUS_HOSTNAME="${HOSTNAME:-$(hostname -s 2>/dev/null || echo 'unknown')}"
    STATUS_TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    STATUS_PASS=0
    STATUS_FAIL=0
    STATUS_WARN=0
    STATUS_CRITICAL_FAIL=0
    STATUS_NAMES=()
    STATUS_LABELS=()
    STATUS_STATES=()
    STATUS_SEVERITIES=()
    STATUS_VALUES=()
    MACBRIDGE_SESSION_ID="${MACBRIDGE_SESSION_ID:-$(date +%s)-$$}"
    export MACBRIDGE_SESSION_ID
}

status_append() {
    local name="$1"
    local label="$2"
    local state="$3"
    local severity="${4:-critical}"
    local value="${5:-}"
    local idx="${#STATUS_NAMES[@]}"

    STATUS_NAMES[$idx]="$name"
    STATUS_LABELS[$idx]="$label"
    STATUS_STATES[$idx]="$state"
    STATUS_SEVERITIES[$idx]="$severity"
    STATUS_VALUES[$idx]="$value"

    case "$state" in
        PASS) STATUS_PASS=$((STATUS_PASS + 1)) ;;
        WARN) STATUS_WARN=$((STATUS_WARN + 1)) ;;
        FAIL)
            STATUS_FAIL=$((STATUS_FAIL + 1))
            if [ "$severity" = "critical" ]; then
                STATUS_CRITICAL_FAIL=$((STATUS_CRITICAL_FAIL + 1))
            fi
            ;;
    esac
}

status_record_pass() { status_append "$1" "$2" "PASS" "${3:-critical}" "${4:-}"; }
status_record_warn() { status_append "$1" "$2" "WARN" "${3:-advisory}" "${4:-}"; }
status_record_fail() { status_append "$1" "$2" "FAIL" "${3:-critical}" "${4:-}"; }

status_state() {
    if [ "$STATUS_CRITICAL_FAIL" -gt 0 ]; then
        echo "blocked"
    elif [ "$STATUS_FAIL" -gt 0 ] || [ "$STATUS_WARN" -gt 0 ]; then
        echo "degraded"
    else
        echo "ready"
    fi
}

status_next_action() {
    case "$(status_state)" in
        ready) echo "No action required." ;;
        degraded) echo "Run bash doctor.sh to review advisory issues." ;;
        blocked) echo "Run bash doctor.sh and repair critical checks before reuse." ;;
    esac
}

status_emit_json() {
    local state overall checks_json="" comma=""
    local provider_name="${MACBRIDGE_PROVIDER_NAME:-manual}"
    local provider_kind="${MACBRIDGE_PROVIDER_KIND:-manual}"
    local provider_host="${MACBRIDGE_PROVIDER_HOST:-}"
    local usage_log="${MACBRIDGE_USAGE_LOG:-${MACBRIDGE_LOG_DIR:-logs}/usage-events.ndjson}"
    local i

    state="$(status_state)"
    overall="$state"

    for ((i = 0; i < ${#STATUS_NAMES[@]}; i++)); do
        checks_json="${checks_json}${comma}$(json_string "${STATUS_NAMES[$i]}"): {\"label\": $(json_string "${STATUS_LABELS[$i]}"), \"status\": $(json_string "${STATUS_STATES[$i]}"), \"severity\": $(json_string "${STATUS_SEVERITIES[$i]}"), \"value\": $(json_string "${STATUS_VALUES[$i]}")}"
        comma=","
    done

    cat <<EOF
{
  "contract_version": "1",
  "status": $(json_string "$state"),
  "overall": $(json_string "$overall"),
  "machine_id": $(json_string "$STATUS_MACHINE_ID"),
  "hostname": $(json_string "$STATUS_HOSTNAME"),
  "timestamp": $(json_string "$STATUS_TIMESTAMP"),
  "failed_count": $STATUS_FAIL,
  "provider": {
    "name": $(json_string "$provider_name"),
    "kind": $(json_string "$provider_kind"),
    "host": $(json_string "$provider_host")
  },
  "telemetry": {
    "source": $(json_string "$STATUS_SOURCE"),
    "session_id": $(json_string "$MACBRIDGE_SESSION_ID"),
    "usage_log": $(json_string "$usage_log")
  },
  "summary": {
    "state": $(json_string "$state"),
    "checks_passed": $STATUS_PASS,
    "checks_failed": $STATUS_FAIL,
    "checks_warn": $STATUS_WARN,
    "critical_failed": $STATUS_CRITICAL_FAIL,
    "next_action": $(json_string "$(status_next_action)")
  },
  "checks": {${checks_json}}
}
EOF
}
