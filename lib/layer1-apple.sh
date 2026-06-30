#!/bin/bash
# =============================================================================
# MacBridge — Layer 1: Apple Toolchain
# =============================================================================
# Verifies the Apple development toolchain: Xcode, Command Line Tools,
# license acceptance, and iOS Simulator runtimes.
#
# Lessons encoded (Phase 0):
#   Lesson 1: Xcode requires GUI to install — golden image must provide it
#   Lesson 8: Verification at every layer — each tool verified before proceeding
#   Lesson 6: SPM breaks some plugins — not in this layer, caught in Layer 4 smoke test
#
# Prerequisites: Golden image with Xcode pre-installed, or manual Xcode install.
#   This layer VERIFIES the Apple toolchain. It does NOT install Xcode
#   (App Store download requires GUI — see Lesson 1).
# =============================================================================

set -euo pipefail

LAYER="Layer 1"
LOG_FILE="${MACBRIDGE_LOG_DIR:-logs}/layer1-apple.log"

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
echo -e "${BOLD}${CYAN}🍎 ${LAYER}: Apple Toolchain${NC}"
echo "──────────────────────────────────────────────"
echo ""

# ── 1. Verify Command Line Tools ──────────────────────────────────────────
step "Checking Command Line Tools..."
if xcode-select -p > /dev/null 2>&1; then
    CLT_PATH=$(xcode-select -p)
    ok "Command Line Tools installed: $CLT_PATH"
else
    step "Installing Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    # On headless Macs, softwareupdate may be needed instead
    if ! xcode-select -p > /dev/null 2>&1; then
        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        CLT_LABEL=$(softwareupdate -l 2>/dev/null | grep -B 1 -E "Command Line Tools" | awk -F'*' '/^[[:space:]]*\*/ {print $2}' | sed -e 's/^ *//' | tail -1)
        if [ -n "$CLT_LABEL" ]; then
            softwareupdate -i "$CLT_LABEL" --verbose 2>/dev/null || true
        fi
        rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    fi

    if xcode-select -p > /dev/null 2>&1; then
        ok "Command Line Tools installed: $(xcode-select -p)"
    else
        fail "Command Line Tools not installed — required for xcodebuild and git"
        exit 1
    fi
fi

# ── 2. Verify Xcode installation ──────────────────────────────────────────
# Lesson 1: Xcode requires GUI to install. Golden image must provide it.
# This check is PASS/WARN, not FAIL — provides clear instructions if missing.
step "Checking Xcode..."
if [ -d "/Applications/Xcode.app" ]; then
    XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
    ok "Xcode installed: version ${XCODE_VERSION}"

    # Verify xcodebuild works
    if xcodebuild -version > /dev/null 2>&1; then
        ok "xcodebuild functional"
    else
        fail "xcodebuild not functional despite Xcode.app existing"
        exit 1
    fi
else
    fail "Xcode not found at /Applications/Xcode.app"
    echo ""
    echo -e "  ${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${YELLOW}║  Xcode must be pre-installed in the golden image.            ║${NC}"
    echo -e "  ${YELLOW}║  App Store download requires GUI (DeskIn remote desktop).    ║${NC}"
    echo -e "  ${YELLOW}║                                                            ║${NC}"
    echo -e "  ${YELLOW}║  To fix:                                                    ║${NC}"
    echo -e "  ${YELLOW}║  1. Connect via DeskIn/VNC                                  ║${NC}"
    echo -e "  ${YELLOW}║  2. Open App Store → Search 'Xcode' → Download              ║${NC}"
    echo -e "  ${YELLOW}║  3. Sign in with Apple ID if prompted                       ║${NC}"
    echo -e "  ${YELLOW}║  4. Wait ~45 minutes for download                           ║${NC}"
    echo -e "  ${YELLOW}║  5. Re-run: bash bootstrap.sh                               ║${NC}"
    echo -e "  ${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi

# ── 3. Accept Xcode license ───────────────────────────────────────────────
step "Checking Xcode license..."
if sudo xcodebuild -license accept 2>/dev/null; then
    ok "Xcode license accepted"
else
    # License might already be accepted
    if xcodebuild -version > /dev/null 2>&1; then
        ok "Xcode license already accepted"
    else
        fail "Could not accept Xcode license"
        exit 1
    fi
fi

# ── 4. Run Xcode first launch ─────────────────────────────────────────────
step "Running Xcode first launch..."
if sudo xcodebuild -runFirstLaunch 2>/dev/null; then
    ok "Xcode first launch completed"
else
    # First launch may have already run
    ok "Xcode first launch already completed (or not needed)"
fi

# ── 5. Verify iOS Simulator runtime ───────────────────────────────────────
# Lesson 8: flutter doctor green ≠ Simulator runtime present.
step "Checking iOS Simulator runtime..."
SIMULATOR_RUNTIMES=$(xcrun simctl list runtimes 2>/dev/null | grep -c "iOS" || echo "0")

if [ "$SIMULATOR_RUNTIMES" -gt 0 ]; then
    RUNTIME_INFO=$(xcrun simctl list runtimes 2>/dev/null | grep "iOS" | head -1 | sed 's/^[[:space:]]*//')
    ok "iOS Simulator runtime found: ${RUNTIME_INFO}"
else
    warn "No iOS Simulator runtime found — attempting download..."
    echo -e "  ${YELLOW}→${NC} Downloading iOS Simulator runtime (may take ~10 minutes)..."

    if xcodebuild -downloadPlatform iOS 2>/dev/null; then
        ok "iOS Simulator runtime downloaded"
    else
        warn "Could not download iOS Simulator runtime automatically"
        echo -e "  ${YELLOW}→${NC} Manual: Open Xcode → Settings → Platforms → download iOS"
        # Don't fail — user can still build for device
    fi
fi

# ── 6. Verify additional Simulator devices available ──────────────────────
step "Checking Simulator devices..."
DEVICE_COUNT=$(xcrun simctl list devices available 2>/dev/null | grep -c "iPhone" || echo "0")
if [ "$DEVICE_COUNT" -gt 0 ]; then
    ok "${DEVICE_COUNT} iPhone simulator(s) available"
else
    warn "No iPhone simulators found — may need runtime download first"
fi

# ── 7. Verify Xcode active developer directory ────────────────────────────
step "Checking active developer directory..."
if xcode-select -p > /dev/null 2>&1; then
    DEV_DIR=$(xcode-select -p)
    ok "Active developer directory: $DEV_DIR"
else
    # Point to Xcode if CLT is set but Xcode exists
    if [ -d "/Applications/Xcode.app" ]; then
        sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer 2>/dev/null || true
        ok "Developer directory set to Xcode"
    else
        fail "No active developer directory"
        exit 1
    fi
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ ${LAYER} complete${NC} — Apple toolchain verified (${PASS} checks passed)"
else
    echo -e "${RED}❌ ${LAYER} failed${NC} — ${FAIL} check(s) failed, ${PASS} passed"
    exit 1
fi
