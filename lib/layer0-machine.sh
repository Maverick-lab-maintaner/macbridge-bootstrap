#!/bin/bash
# =============================================================================
# MacBridge — Layer 0: Machine Reachable
# =============================================================================
# Verifies the machine is accessible, has sufficient resources, and that
# critical directories are properly owned before any installation begins.
#
# Lessons encoded (Phase 0):
#   Lesson 4: ~/.local ownership breaks silently → verify permissions early
#   Lesson 8: Verification at every layer → never assume
#   Lesson 1: Xcode requires GUI → note: golden image handles this
#
# Prerequisites: macOS with SSH access
# =============================================================================

set -euo pipefail

LAYER="Layer 0"

# Source shared utilities if available
if [ -f "${MACBRIDGE_LIB_DIR:-lib}/_utils.sh" ]; then
    source "${MACBRIDGE_LIB_DIR:-lib}/_utils.sh"
else
    # Minimal fallback color definitions
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
    PASS=0; FAIL=0
    step()  { echo -e "${CYAN}  →${NC} $1"; }
    ok()    { echo -e "  ${GREEN}✅${NC} $1"; ((PASS++)) || true; }
    warn()  { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
    fail()  { echo -e "  ${RED}❌${NC} $1"; ((FAIL++)) || true; }
    info()  { echo -e "  ${CYAN}🔑${NC} $1"; }
fi

PASS=0; FAIL=0

echo ""
echo -e "${BOLD}${CYAN}🔧 ${LAYER}: Machine Reachable${NC}"
echo "──────────────────────────────────────────────"
echo ""

# ── 1. Verify we're on macOS ──────────────────────────────────────────────
step "Checking operating system..."
if [[ "$(uname -s)" == "Darwin" ]]; then
    ok "macOS confirmed ($(sw_vers -productVersion 2>/dev/null || echo 'unknown version'))"
else
    fail "This script requires macOS. Detected: $(uname -s)"
    exit 1
fi

# ── 2. Verify disk space (need >50GB for Xcode + Flutter + projects) ──────
step "Checking disk space..."
DISK_GB=$(df -g . 2>/dev/null | awk 'NR==2 {print $4}')
if [ -z "$DISK_GB" ]; then
    DISK_GB=$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')
fi

if [ -n "$DISK_GB" ] && [ "$DISK_GB" -gt 50 ]; then
    ok "Disk: ${DISK_GB}GB available (need >50GB)"
elif [ -n "$DISK_GB" ]; then
    fail "Disk: only ${DISK_GB}GB available — need >50GB for Xcode + Flutter + Simulator"
    exit 1
else
    warn "Could not determine disk space — proceeding anyway"
fi

# ── 3. Verify network connectivity ────────────────────────────────────────
step "Checking network connectivity..."
if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
    ok "Network is reachable"
elif ping -c 1 -W 5 1.1.1.1 > /dev/null 2>&1; then
    ok "Network is reachable (Cloudflare DNS)"
else
    fail "No network connectivity — cannot reach 8.8.8.8 or 1.1.1.1"
    exit 1
fi

# ── 4. Verify HOME directory is writable ──────────────────────────────────
step "Checking HOME directory permissions..."
if [ -w "$HOME" ]; then
    ok "HOME directory writable: $HOME"
else
    fail "HOME directory not writable: $HOME"
    exit 1
fi

# ── 5. Verify critical directory ownership ────────────────────────────────
# Lesson 4: ~/.local owned by root from earlier sudo install broke everything silently.
step "Verifying directory ownership..."

FIXED_OWNERSHIP=0
for dir in "$HOME/.local" "$HOME/.ssh" "$HOME/.config"; do
    if [ -d "$dir" ]; then
        OWNER=$(stat -f '%Su' "$dir" 2>/dev/null || echo "unknown")
        if [ "$OWNER" != "$USER" ]; then
            warn "$dir owned by '$OWNER' (should be '$USER') — fixing..."
            sudo chown -R "$USER":staff "$dir" 2>/dev/null || {
                warn "Could not fix ownership of $dir (may need manual intervention)"
            }
            ((FIXED_OWNERSHIP++)) || true
        fi
    fi
done

if [ "$FIXED_OWNERSHIP" -eq 0 ]; then
    ok "Directory ownership verified ($USER owns .local, .ssh, .config)"
else
    ok "Directory ownership fixed ($FIXED_OWNERSHIP directories corrected)"
fi

# ── 6. Ensure critical directories exist ──────────────────────────────────
step "Ensuring critical directories exist..."
for dir in "$HOME/.local/bin" "$HOME/.ssh" "$HOME/.config"; do
    mkdir -p "$dir"
done
ok "Critical directories present (.local/bin, .ssh, .config)"

# ── 7. Enable SSH (remote login) ─────────────────────────────────────────
step "Enabling SSH remote login..."
if sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
    ok "SSH remote login already enabled"
else
    sudo systemsetup -setremotelogin on 2>/dev/null || true
    if sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
        ok "SSH remote login enabled"
    else
        warn "Could not enable SSH remote login (may already be handled by provider)"
    fi
fi

# ── 8. Configure SSH keepalive (prevents idle disconnection) ──────────────
step "Configuring SSH keepalive..."
mkdir -p "$HOME/.ssh"
if ! grep -q "ServerAliveInterval" "$HOME/.ssh/config" 2>/dev/null; then
    cat >> "$HOME/.ssh/config" << 'SSHCONFIG'
# MacBridge: keepalive config (prevents idle disconnection)
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking accept-new
SSHCONFIG
    ok "SSH keepalive configured (ServerAliveInterval 60)"
else
    ok "SSH keepalive already configured"
fi

# ── 9. Check VNC / Screen Sharing status ─────────────────────────────────
# Lesson 3: GUI is only needed for App Store, Xcode download, Simulator, signing dialogs.
step "Checking VNC / Screen Sharing..."
if pgrep -f "AppleVNCServer" > /dev/null 2>&1; then
    ok "VNC server running (Screen Sharing available)"
elif sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -status 2>/dev/null | grep -q "Running"; then
    ok "VNC server running (Remote Management active)"
else
    warn "VNC not running — GUI access unavailable (needed for App Store, Xcode, Simulator)"
fi

# ── 10. Display system info ───────────────────────────────────────────────
step "System info:"
echo -e "  $(system_profiler SPHardwareDataType 2>/dev/null | grep -E 'Model Name|Model Identifier|Chip|Memory' | sed 's/^/    /')"

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ ${LAYER} complete${NC} — Machine reachable and verified (${PASS} checks passed)"
else
    echo -e "${RED}❌ ${LAYER} failed${NC} — ${FAIL} check(s) failed, ${PASS} passed"
    exit 1
fi
