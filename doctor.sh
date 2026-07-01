#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
RULES_FILE="${LIB_DIR}/doctor-rules.json"

[ -f "${LIB_DIR}/_utils.sh" ] && source "${LIB_DIR}/_utils.sh"

JSON_MODE=false
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --quick) QUICK_MODE=true; shift ;;
        --help|-h)
            echo "Usage: bash doctor.sh [--quick] [--json]"
            exit 0
            ;;
        *) shift ;;
    esac
done

VERIFY_ARGS=(--json)
[ "$QUICK_MODE" = true ] && VERIFY_ARGS+=(--quick)

VERIFY_JSON="$(bash "${SCRIPT_DIR}/verify.sh" "${VERIFY_ARGS[@]}" 2>/dev/null || true)"

if [ -z "$VERIFY_JSON" ]; then
    echo "doctor: verify.sh did not return JSON" >&2
    exit 1
fi

if [ "$JSON_MODE" = true ]; then
    python3 - "$RULES_FILE" "$VERIFY_JSON" <<'PY'
import json
import sys

rules_path = sys.argv[1]
report = json.loads(sys.argv[2])

with open(rules_path, "r", encoding="utf-8") as fh:
    rules = {rule["id"]: rule for rule in json.load(fh)}

issues = []
for check_id, check in report.get("checks", {}).items():
    if check.get("status") == "PASS":
        continue
    rule = rules.get(check_id, {})
    issues.append({
        "id": check_id,
        "label": check.get("label", check_id),
        "status": check.get("status", "UNKNOWN"),
        "severity": check.get("severity") or rule.get("severity", "unknown"),
        "value": check.get("value", ""),
        "title": rule.get("title", "No remediation guidance has been written yet."),
        "fix": rule.get("fix", [])
    })

print(json.dumps({
    "state": report.get("summary", {}).get("state", report.get("status", "unknown")),
    "issue_count": len(issues),
    "issues": issues
}, indent=2))
PY
    exit 0
fi

python3 - "$RULES_FILE" "$VERIFY_JSON" <<'PY'
import json
import sys

rules_path = sys.argv[1]
report = json.loads(sys.argv[2])

with open(rules_path, "r", encoding="utf-8") as fh:
    rules = {rule["id"]: rule for rule in json.load(fh)}

state = report.get("summary", {}).get("state", report.get("status", "unknown"))
issues = []
for check_id, check in report.get("checks", {}).items():
    if check.get("status") == "PASS":
        continue
    rule = rules.get(check_id, {})
    issues.append({
        "id": check_id,
        "label": check.get("label", check_id),
        "status": check.get("status", "UNKNOWN"),
        "severity": check.get("severity") or rule.get("severity", "unknown"),
        "value": check.get("value", ""),
        "title": rule.get("title", "No remediation guidance has been written yet."),
        "fix": rule.get("fix", [])
    })

print()
print("MacBridge Doctor")
print("----------------")
print(f"State: {state}")
print()

if not issues:
    print("No failing or warning checks were found.")
    print("The machine is ready.")
    sys.exit(0)

for index, issue in enumerate(issues, start=1):
    print(f"{index}. [{issue['severity']}] {issue['label']} ({issue['status']})")
    print(f"   {issue['title']}")
    if issue["value"]:
        print(f"   Current value: {issue['value']}")
    for step in issue["fix"]:
        print(f"   - {step}")
    print()
PY
