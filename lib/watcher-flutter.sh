#!/bin/bash
# =============================================================================
# MacBridge — Flutter Release Watcher
# =============================================================================
# Monitors Flutter's stable releases. Detects new versions and flags
# for golden image rebuild. Runs as cron job or CI step.
#
# Usage:
#   bash watcher-flutter.sh                 # Check for new Flutter versions
#   bash watcher-flutter.sh --json          # JSON output
#   bash watcher-flutter.sh --install-cron  # Install as weekly cron job
#
# Data source: Flutter releases JSON (official)
#   https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${SCRIPT_DIR}/../.cache/flutter-versions.txt"
JSON_MODE=false; INSTALL_CRON=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --install-cron) INSTALL_CRON=true; shift ;;
        *) shift ;;
    esac
done

mkdir -p "$(dirname "$STATE_FILE")"

if [ "$INSTALL_CRON" = true ]; then
    SCRIPT_PATH="$(realpath "$0")"
    CRON_CMD="0 7 * * 1 bash '$SCRIPT_PATH'"
    (crontab -l 2>/dev/null || true; echo "$CRON_CMD") | crontab -
    echo "Flutter watcher cron installed (runs Mondays at 7am)"
    exit 0
fi

fetch_latest_flutter() {
    local result
    result=$(curl -s --connect-timeout 10 --max-time 30 \
        "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json" 2>/dev/null || echo "{}")

    echo "$result" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    releases = data.get('releases', [])
    # Filter for stable channel
    stable = [r for r in releases if r.get('channel') == 'stable']
    # Sort by release date
    stable.sort(key=lambda r: r.get('release_date', ''), reverse=True)
    if stable:
        r = stable[0]
        print(json.dumps({
            'version': r.get('version', 'unknown'),
            'channel': r.get('channel', 'stable'),
            'dart_version': r.get('dart_sdk_version', ''),
            'release_date': r.get('release_date', ''),
            'source': 'flutter.dev'
        }))
    else:
        print('{}')
except: print('{}')
" 2>/dev/null || echo "{}"
}

KNOWN_VERSION=""
[ -f "$STATE_FILE" ] && KNOWN_VERSION=$(head -1 "$STATE_FILE" 2>/dev/null || echo "")

LATEST_JSON=$(fetch_latest_flutter)
LATEST_VERSION=$(echo "$LATEST_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version','unknown'))" 2>/dev/null || echo "unknown")
LATEST_DART=$(echo "$LATEST_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('dart_version',''))" 2>/dev/null || echo "")
LATEST_DATE=$(echo "$LATEST_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('release_date',''))" 2>/dev/null || echo "")

if [ "$JSON_MODE" = true ]; then
    echo "$LATEST_JSON"
    exit 0
fi

echo ""
echo "💙 Flutter Release Watcher"
echo "──────────────────────────────────────────────"
echo -e "  Latest stable:   ${LATEST_VERSION}"
echo -e "  Dart SDK:        ${LATEST_DART}"
echo -e "  Release date:    ${LATEST_DATE}"
echo -e "  Known version:   ${KNOWN_VERSION:-none tracked}"
echo ""

if [ -z "$KNOWN_VERSION" ]; then
    echo -e "  → First run. Recording ${LATEST_VERSION} as baseline."
    echo "$LATEST_VERSION" > "$STATE_FILE"
    echo "$LATEST_JSON" >> "$STATE_FILE"
elif [ "$LATEST_VERSION" != "$KNOWN_VERSION" ] && [ "$LATEST_VERSION" != "unknown" ]; then
    echo -e "  🔔 NEW FLUTTER RELEASE: ${KNOWN_VERSION} → ${LATEST_VERSION}"
    echo -e "  → Action: rebuild golden image within 48 hours"
    echo -e "  → Run: provision fresh Mac → run bootstrap → verify → snapshot"
    echo "$LATEST_VERSION" > "$STATE_FILE"
    echo "$LATEST_JSON" >> "$STATE_FILE"
else
    echo -e "  ✅ No new Flutter release since last check."
fi

echo ""
