#!/bin/bash
# =============================================================================
# MacBridge — Layer 4: Smoke Test
# =============================================================================
# Creates a test Flutter project and builds for iOS to verify the entire
# toolchain works end-to-end. This is the final gate before marking the
# Mac as "Ready."
#
# Lessons encoded (Phase 0):
#   Lesson 6: SPM breaks some plugins → smoke test catches build failures
#   Lesson 8: flutter doctor green ≠ build succeeds → actual build required
#   Lesson 9: User never sees provisioning → this runs before customer login
#
# Prerequisites: Layer 0-3 (machine, Apple toolchain, dev tools, agents)
# =============================================================================

set -euo pipefail

LAYER="Layer 4"
LOG_FILE="${MACBRIDGE_LOG_DIR:-logs}/layer4-project.log"

# Source shared utilities
if [ -f "${MACBRIDGE_LIB_DIR:-lib}/_utils.sh" ]; then
    source "${MACBRIDGE_LIB_DIR:-lib}/_utils.sh"
else
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
    PASS=0; FAIL=0
    step()  { echo -e "${CYAN}  →${NC} $1"; }
    ok()    { echo -e "  ${GREEN}✅${NC} $1"; ((PASS++)) || true; }
    warn()  { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
    fail()  { echo -e "  ${RED}❌${NC} $1"; ((FAIL++)) || true; }
fi

PASS=0; FAIL=0

echo ""
echo -e "${BOLD}${CYAN}🧪 ${LAYER}: Smoke Test${NC}"
echo "──────────────────────────────────────────────"
echo ""

# ── 1. Create test Flutter project ────────────────────────────────────────
step "Creating test Flutter project..."
# Underscores, not hyphens: flutter create uses the directory name as the Dart
# package name, and hyphens are invalid ("macbridge-smoke-test-123" is rejected).
# Found live on the macOS runner — the smoke test could never pass with a hyphen.
TEST_DIR="/tmp/macbridge_smoke_test_$$"

# Clean up any previous test
rm -rf "$TEST_DIR" 2>/dev/null || true

CREATE_OUTPUT=$(flutter create --org com.macbridge "$TEST_DIR" 2>&1) || CREATE_FAILED=true

if [ "${CREATE_FAILED:-false}" = false ]; then
    ok "Flutter project created: $TEST_DIR"
else
    fail "Failed to create Flutter test project — Flutter SDK may be broken"
    echo ""
    echo -e "  ${YELLOW}flutter create output (last 20 lines):${NC}"
    echo "$CREATE_OUTPUT" | tail -20
    exit 1
fi

# ── 2. Run flutter pub get ────────────────────────────────────────────────
step "Running flutter pub get..."
cd "$TEST_DIR"

if flutter pub get > /dev/null 2>&1; then
    ok "Dependencies resolved"
else
    fail "flutter pub get failed"
    exit 1
fi

# ── 3. Run pod install (CocoaPods integration test) ────────────────────────
step "Running pod install..."
if [ -d "ios" ]; then
    cd ios
    if pod install > /dev/null 2>&1; then
        ok "CocoaPods integration successful"
    else
        warn "pod install failed — this may be expected for default projects"
        warn "  CocoaPods is installed but the default Flutter template may not need it"
    fi
    cd "$TEST_DIR"
else
    warn "No ios/ directory found in test project"
fi

# ── 4. Build iOS (debug, no codesign) — THE REAL TEST ─────────────────────
# Lesson 6: Actual build catches issues flutter doctor misses.
step "Building iOS (debug, no codesign)..."
echo -e "  ${CYAN}→${NC} This verifies the full Flutter→iOS pipeline..."
echo ""

BUILD_OUTPUT=$(flutter build ios --debug --no-codesign 2>&1) || BUILD_FAILED=true

if [ "${BUILD_FAILED:-false}" = false ]; then
    ok "iOS build succeeded — Flutter → iOS pipeline verified"

    # Check for the built app
    if [ -d "build/ios/iphoneos" ] || [ -d "build/ios/iphonesimulator" ]; then
        ok "Build artifact found"
    fi
else
    # Build failed — this is the critical gate
    fail "iOS build failed — Flutter toolchain is not production-ready"
    echo ""
    echo -e "  ${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${RED}║  SMOKE TEST FAILED                                          ║${NC}"
    echo -e "  ${RED}║  The Flutter → iOS build pipeline is not working.            ║${NC}"
    echo -e "  ${RED}║  Common causes:                                              ║${NC}"
    echo -e "  ${RED}║  - Xcode incomplete (missing Simulator runtime)              ║${NC}"
    echo -e "  ${RED}║  - CocoaPods not in PATH                                     ║${NC}"
    echo -e "  ${RED}║  - Ruby version too old (< 3.0)                              ║${NC}"
    echo -e "  ${RED}║  - SPM/CocoaPods plugin conflict                              ║${NC}"
    echo -e "  ${RED}║                                                              ║${NC}"
    echo -e "  ${RED}║  Run diagnostics: flutter doctor -v                           ║${NC}"
    echo -e "  ${RED}║  Check logs:     ${LOG_FILE}                                  ║${NC}"
    echo -e "  ${RED}╚══════════════════════════════════════════════════════════════╝${NC}"

    # Show the last 30 lines of build output for debugging
    echo ""
    echo -e "  ${YELLOW}Last build output:${NC}"
    echo "$BUILD_OUTPUT" | tail -30

    exit 1
fi

# ── 5. Clean up test project ──────────────────────────────────────────────
step "Cleaning up smoke test..."
rm -rf "$TEST_DIR"
ok "Test project removed"

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ ${LAYER} complete${NC} — Smoke test passed. Flutter → iOS pipeline verified (${PASS} checks passed)"
else
    echo -e "${RED}❌ ${LAYER} failed${NC} — ${FAIL} check(s) failed, ${PASS} passed"
    exit 1
fi
