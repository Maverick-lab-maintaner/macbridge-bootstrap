#!/bin/bash
# =============================================================================
# MacBridge — Readiness Screen
# =============================================================================
# Renders the "🟢 MacBridge Ready" screen from the status contract. This is
# the psychological promise (HONEST_ASSESSMENT.md): instead of a bare shell
# prompt, the user sees a prepared, verified workspace.
#
# It is a display over verify.sh's JSON — it never installs or changes anything.
#
# Usage:
#   bash readiness.sh                 # run verify.sh --json and render
#   bash readiness.sh --quick         # faster verify (skips slow checks)
#   bash readiness.sh --json FILE     # render a saved contract (for testing)
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JSON_FILE=""
QUICK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_FILE="${2:-}"; shift 2 ;;
        --quick) QUICK="--quick"; shift ;;
        --help|-h)
            echo "Usage: bash readiness.sh [--quick] [--json FILE]"
            exit 0
            ;;
        *) shift ;;
    esac
done

if [ -n "$JSON_FILE" ]; then
    CONTRACT="$(cat "$JSON_FILE" 2>/dev/null || true)"
else
    CONTRACT="$(bash "${SCRIPT_DIR}/verify.sh" --json $QUICK 2>/dev/null || true)"
fi

if [ -z "$CONTRACT" ]; then
    echo "readiness: no status data (is verify.sh present and runnable?)" >&2
    exit 1
fi

python3 - "$CONTRACT" <<'PY'
import json, sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

try:
    report = json.loads(sys.argv[1])
except Exception:
    print("readiness: could not parse status contract", file=sys.stderr)
    sys.exit(1)

checks = report.get("checks", {})
state = report.get("summary", {}).get("state", report.get("status", "unknown"))

# The rows shown on the readiness screen, in order: (check id, label)
ROWS = [
    ("flutter", "Flutter"),
    ("xcodebuild", "Xcode"),
    ("simulator", "Simulator"),
    ("cocoapods", "CocoaPods"),
    ("ruby", "Ruby"),
    ("node", "Node.js"),
    ("gh_cli", "GitHub CLI"),
    ("claude", "Claude Code"),
    ("opencode", "OpenCode"),
    ("codex", "Codex"),
    ("tmux", "tmux"),
]

GREEN, YELLOW, RED, DIM, CYAN, BOLD, NC = (
    "\033[0;32m", "\033[1;33m", "\033[0;31m", "\033[0;90m",
    "\033[0;36m", "\033[1m", "\033[0m",
)

def icon(status):
    return {"PASS": f"{GREEN}✅{NC}", "WARN": f"{YELLOW}⚠️ {NC}",
            "FAIL": f"{RED}❌{NC}"}.get(status, f"{DIM}··{NC}")

header = {
    "ready":   (GREEN,  "🟢 MacBridge Ready"),
    "degraded":(YELLOW, "🟡 MacBridge — degraded"),
    "blocked": (RED,    "🔴 MacBridge — not ready"),
}.get(state, (CYAN, f"MacBridge — {state}"))

bar = "═" * 46
print()
print(f"  {header[0]}{bar}{NC}")
print(f"  {header[0]}{BOLD}   {header[1]}{NC}")
print(f"  {header[0]}{bar}{NC}")

for cid, label in ROWS:
    check = checks.get(cid)
    if check is None:
        continue  # not part of this tier / not measured
    value = check.get("value", "") or ""
    if len(value) > 22:
        value = value[:21] + "…"
    print(f"    {label:<13} {icon(check.get('status',''))}  {DIM}{value}{NC}")

print(f"  {header[0]}{bar}{NC}")

summary = report.get("summary", {})
counts = f"pass {summary.get('checks_passed',0)}  warn {summary.get('checks_warn',0)}  fail {summary.get('checks_failed',0)}"
if state == "ready":
    tail = f"{CYAN}Type{NC} {BOLD}macbridge{NC} {CYAN}to begin.{NC}"
else:
    tail = f"{CYAN}Run{NC} {BOLD}bash doctor.sh{NC} {CYAN}to see what to fix.{NC}"
print(f"    {DIM}{counts}{NC}    {tail}")
print()

sys.exit(0 if state == "ready" else 1)
PY
