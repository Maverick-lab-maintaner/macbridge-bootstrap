#!/bin/bash
# =============================================================================
# MacBridge — Test Harness
# =============================================================================
# Validates all MacBridge scripts for correctness without needing a Mac.
# Runs on CI (GitHub Actions) or locally on any machine with bash.
#
# Checks:
#   1. All .sh files parse without syntax errors
#   2. Key functions exist in each script (where applicable)
#   3. Required arguments produce --help output
#   4. Exit codes are correct
#
# Usage:
#   bash test/run-tests.sh          # Run all tests
#   bash test/run-tests.sh --quick  # Syntax only (no execution)
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

QUICK=false
while [[ $# -gt 0 ]]; do
    case $1 in --quick) QUICK=true; shift ;; *) shift ;; esac
done

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "  ${GREEN}✅${NC} $1"; ((PASS++)) || true; }
fail() { echo -e "  ${RED}❌${NC} $1"; ((FAIL++)) || true; }

echo ""
echo -e "${BOLD}${CYAN}🧪 MacBridge — Test Harness${NC}"
echo "──────────────────────────────────────────────"
echo ""

# ── Test 1: Syntax validation ──────────────────────────────────────────────

echo -e "${BOLD}Syntax Validation:${NC}"

while IFS= read -r -d '' script; do
    rel="${script#$ROOT_DIR/}"
    if bash -n "$script" 2>/dev/null; then
        pass "$rel"
    else
        fail "$rel — syntax error"
    fi
done < <(find "$ROOT_DIR" -name '*.sh' -not -path '*/.git/*' -not -path '*/.cache/*' -print0)

echo ""

if [ "$QUICK" = true ]; then
    echo -e "${BOLD}Results:${NC} ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
    echo ""
    [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi

# ── Test 2: Help output ────────────────────────────────────────────────────

echo -e "${BOLD}Help Output:${NC}"

check_help() {
    local script="$1"
    local rel="${script#$ROOT_DIR/}"

    # Skip library scripts (they're sourced, not run directly)
    if echo "$rel" | grep -qE '(layer[0-4]-|_utils)'; then
        return 0
    fi

    if bash "$script" --help > /dev/null 2>&1; then
        pass "$rel --help"
    else
        fail "$rel --help returned non-zero"
    fi
}

check_help "$ROOT_DIR/bootstrap.sh"
check_help "$ROOT_DIR/verify.sh"
check_help "$ROOT_DIR/cleanup.sh"
check_help "$ROOT_DIR/healthd.sh"
check_help "$ROOT_DIR/hardening.sh"
check_help "$ROOT_DIR/welcome.sh"
check_help "$ROOT_DIR/migrate.sh"
check_help "$ROOT_DIR/install-skills.sh"
check_help "$ROOT_DIR/tmux-launch.sh"
check_help "$ROOT_DIR/lib/watcher-xcode.sh"
check_help "$ROOT_DIR/lib/watcher-flutter.sh"

echo ""

# ── Test 3: Function existence ─────────────────────────────────────────────

echo -e "${BOLD}Function Checks:${NC}"

check_fn() {
    local script="$1"; local fn="$2"; local rel="${script#$ROOT_DIR/}"
    if grep -q "^${fn}()" "$script" 2>/dev/null || grep -q "function ${fn}" "$script" 2>/dev/null; then
        pass "$rel → $fn()"
    else
        fail "$rel → $fn() — not found"
    fi
}

check_fn "$ROOT_DIR/lib/_utils.sh" "ensure_path"
check_fn "$ROOT_DIR/lib/_utils.sh" "report_event"
check_fn "$ROOT_DIR/healthd.sh" "run_health_check"
check_fn "$ROOT_DIR/migrate.sh" "perform_upgrade"
check_fn "$ROOT_DIR/migrate.sh" "get_current_version"

echo ""

# ── Results ─────────────────────────────────────────────────────────────────

echo "──────────────────────────────────────────────"
echo -e "${BOLD}Results:${NC} ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed${NC}"
    exit 0
else
    echo -e "${RED}❌ ${FAIL} test(s) failed${NC}"
    exit 1
fi
