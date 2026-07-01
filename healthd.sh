#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

[ -f "${LIB_DIR}/_utils.sh" ] && source "${LIB_DIR}/_utils.sh"
[ -f "${LIB_DIR}/status-contract.sh" ] && source "${LIB_DIR}/status-contract.sh"

WEBHOOK_URL=""
INTERVAL=0
INSTALL_CRON=false
ONCE=true
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --webhook) WEBHOOK_URL="$2"; export MACBRIDGE_REPORT_URL="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; ONCE=false; shift 2 ;;
        --install-cron) INSTALL_CRON=true; shift ;;
        --once) ONCE=true; shift ;;
        --quick) QUICK_MODE=true; shift ;;
        --help|-h)
            echo "Usage: bash healthd.sh [--webhook URL] [--interval SECS] [--install-cron] [--once] [--quick]"
            exit 0
            ;;
        *) shift ;;
    esac
done

run_health_check() {
    status_contract_init "healthd"
    export MACBRIDGE_PROVIDER_HOST="${MACBRIDGE_PROVIDER_HOST:-${HOSTNAME:-$(hostname -s 2>/dev/null || echo 'unknown')}}"

    local verify_args=(--json)
    [ "$QUICK_MODE" = true ] && verify_args+=(--quick)

    local report
    report="$(bash "${SCRIPT_DIR}/verify.sh" "${verify_args[@]}" 2>/dev/null || true)"

    if [ -z "$report" ]; then
        status_record_fail "verify" "verify.sh execution" "critical" "no report"
        report="$(status_emit_json)"
    fi

    printf '%s\n' "$report" | python3 -m json.tool 2>/dev/null || printf '%s\n' "$report"

    if [ -n "$WEBHOOK_URL" ]; then
        curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d "$report" \
            --connect-timeout 5 --max-time 10 > /dev/null 2>&1 || true
    fi
}

if [ "$INSTALL_CRON" = true ]; then
    SCRIPT_PATH="$(resolve_script_path "$0")"
    CRON_CMD="*/5 * * * * bash '$SCRIPT_PATH' --once"
    [ "$QUICK_MODE" = true ] && CRON_CMD="$CRON_CMD --quick"
    if [ -n "$WEBHOOK_URL" ]; then
        CRON_CMD="$CRON_CMD --webhook '$WEBHOOK_URL'"
    fi

    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
    fi

    (crontab -l 2>/dev/null || true; echo "$CRON_CMD") | crontab -
    echo "healthd cron installed"
    exit 0
fi

if [ "$ONCE" = true ] && [ "$INTERVAL" -eq 0 ]; then
    run_health_check
    exit 0
fi

echo "healthd running every ${INTERVAL}s"
while true; do
    run_health_check
    sleep "$INTERVAL"
done
