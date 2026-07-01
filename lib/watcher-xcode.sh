#!/bin/bash
# =============================================================================
# MacBridge — Xcode Release Watcher
# =============================================================================
# Monitors Apple's Xcode releases feed and detects new versions.
# Runs as a cron job or CI step. When a new Xcode version is detected,
# flags it for golden image rebuild.
#
# Usage:
#   bash watcher-xcode.sh                 # Check for new Xcode versions
#   bash watcher-xcode.sh --json          # JSON output for programmatic use
#   bash watcher-xcode.sh --install-cron  # Install as weekly cron job
#
# Data sources:
#   - Apple Developer RSS: https://developer.apple.com/news/releases/rss/releases.rss
#   - xcodereleases.com JSON API: https://xcodereleases.com/data.json
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${SCRIPT_DIR}/../.cache/xcode-versions.txt"
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
    CRON_CMD="0 6 * * 1 bash '$SCRIPT_PATH'"
    (crontab -l 2>/dev/null || true; echo "$CRON_CMD") | crontab -
    echo "Xcode watcher cron installed (runs Mondays at 6am)"
    exit 0
fi

fetch_latest_xcode() {
    # Try xcodereleases.com JSON API (more reliable than RSS parsing)
    local result
    result=$(curl -s --connect-timeout 10 --max-time 30 \
        "https://xcodereleases.com/data.json" 2>/dev/null || echo "[]")

    # Extract latest release version
    echo "$result" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    # Filter for release (non-beta) versions, sort by date
    releases = [r for r in data if not r.get('version',{}).get('release',{}).get('beta', False)]
    releases.sort(key=lambda r: r.get('date',{}).get('year',0)*10000 + r.get('date',{}).get('month',0)*100 + r.get('date',{}).get('day',0), reverse=True)
    if releases:
        r = releases[0]
        ver = r.get('version',{}).get('number','unknown')
        build = r.get('version',{}).get('build','')
        name = r.get('name','')
        date_str = f\"{r.get('date',{}).get('year','')}-{r.get('date',{}).get('month','')}-{r.get('date',{}).get('day','')}\"
        print(json.dumps({'version': ver, 'build': build, 'name': name, 'date': date_str, 'source': 'xcodereleases.com'}))
except: print('{}')
" 2>/dev/null || echo "{}"
}

KNOWN_VERSION=""
[ -f "$STATE_FILE" ] && KNOWN_VERSION=$(head -1 "$STATE_FILE" 2>/dev/null || echo "")

LATEST_JSON=$(fetch_latest_xcode)
LATEST_VERSION=$(echo "$LATEST_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version','unknown'))" 2>/dev/null || echo "unknown")
LATEST_BUILD=$(echo "$LATEST_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('build',''))" 2>/dev/null || echo "")
LATEST_DATE=$(echo "$LATEST_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('date',''))" 2>/dev/null || echo "")

if [ "$JSON_MODE" = true ]; then
    echo "$LATEST_JSON"
    exit 0
fi

echo ""
echo "🍎 Xcode Release Watcher"
echo "──────────────────────────────────────────────"
echo -e "  Latest release:  ${LATEST_VERSION} (${LATEST_BUILD})"
echo -e "  Release date:    ${LATEST_DATE}"
echo -e "  Known version:   ${KNOWN_VERSION:-none tracked}"
echo ""

if [ -z "$KNOWN_VERSION" ]; then
    echo -e "  → First run. Recording ${LATEST_VERSION} as baseline."
    echo "$LATEST_VERSION" > "$STATE_FILE"
    echo "$LATEST_JSON" >> "$STATE_FILE"
elif [ "$LATEST_VERSION" != "$KNOWN_VERSION" ] && [ "$LATEST_VERSION" != "unknown" ]; then
    echo -e "  🔔 NEW XCODE RELEASE: ${KNOWN_VERSION} → ${LATEST_VERSION}"
    echo -e "  → Action required: rebuild golden image with new Xcode"
    echo -e "  → Run: provision fresh Mac → install new Xcode via GUI → snapshot"
    echo "$LATEST_VERSION" > "$STATE_FILE"
    echo "$LATEST_JSON" >> "$STATE_FILE"
else
    echo -e "  ✅ No new Xcode release since last check."
fi

echo ""
