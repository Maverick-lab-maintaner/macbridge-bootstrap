#!/bin/bash
# =============================================================================
# MacBridge — Layer 2: Development Tools
# =============================================================================
# Installs and verifies the Flutter development toolchain:
# Homebrew, Flutter SDK, Ruby, CocoaPods, Git, and GitHub CLI.
#
# Lessons encoded (Phase 0):
#   Lesson 2: System Ruby 2.6 rejects CocoaPods → always brew install ruby first
#   Lesson 3: PATH is part of provisioning, not an afterthought
#   Lesson 5: GitHub password auth dead → generate SSH keys, verify connectivity
#   Lesson 8: Verification at every layer → every install followed by which check
#
# Prerequisites: Layer 0 (machine reachable) + Layer 1 (Apple toolchain)
# =============================================================================

set -euo pipefail

LAYER="Layer 2"
LOG_FILE="${MACBRIDGE_LOG_DIR:-logs}/layer2-dev.log"

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
echo -e "${BOLD}${CYAN}🛠️  ${LAYER}: Development Tools${NC}"
echo "──────────────────────────────────────────────"
echo ""

# ── Helper: ensure in PATH ────────────────────────────────────────────────
# Lesson 3: PATH is part of provisioning. Every tool gets PATH verification.
ensure_path() {
    local dir="$1"
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        echo "export PATH=\"$dir:\$PATH\"" >> "$HOME/.zprofile"
        export PATH="$dir:$PATH"
    fi
}

# ── 1. Install/Verify Homebrew ────────────────────────────────────────────
step "Checking Homebrew..."

if command -v brew > /dev/null 2>&1; then
    BREW_VERSION=$(brew --version 2>/dev/null | head -1)
    ok "Homebrew installed: ${BREW_VERSION}"
else
    step "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null || true

    # Homebrew installs to different paths on Intel vs Apple Silicon
    if [ -f "/opt/homebrew/bin/brew" ]; then
        ensure_path "/opt/homebrew/bin"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        ensure_path "/usr/local/bin"
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if command -v brew > /dev/null 2>&1; then
        ok "Homebrew installed and in PATH"
    else
        fail "Homebrew installation failed"
        exit 1
    fi
fi

# Ensure Homebrew is in shell profile for future sessions
if ! grep -q "homebrew" "$HOME/.zprofile" 2>/dev/null; then
    if [ -f "/opt/homebrew/bin/brew" ]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    elif [ -f "/usr/local/bin/brew" ]; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
    fi
fi

# ── 2. Install/Verify Ruby (Homebrew Ruby, NOT system 2.6) ────────────────
# Lesson 2: System Ruby 2.6 rejects CocoaPods. Always brew ruby first.
step "Checking Ruby..."

RUBY_NEEDS_INSTALL=false
if command -v ruby > /dev/null 2>&1; then
    RUBY_VERSION=$(ruby --version 2>/dev/null | awk '{print $2}')
    RUBY_MAJOR=$(echo "$RUBY_VERSION" | cut -d. -f1)

    if [ "$RUBY_MAJOR" -ge 3 ]; then
        ok "Ruby ${RUBY_VERSION} (>= 3.0 required)"
    else
        warn "Ruby ${RUBY_VERSION} is too old (need >= 3.0 for CocoaPods)"
        RUBY_NEEDS_INSTALL=true
    fi
else
    RUBY_NEEDS_INSTALL=true
fi

if [ "$RUBY_NEEDS_INSTALL" = true ]; then
    step "Installing Ruby via Homebrew..."
    brew install ruby 2>/dev/null || true

    # Add Homebrew Ruby to PATH (takes precedence over system Ruby)
    if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
        ensure_path "/opt/homebrew/opt/ruby/bin"
        export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
    elif [ -d "/usr/local/opt/ruby/bin" ]; then
        ensure_path "/usr/local/opt/ruby/bin"
        export PATH="/usr/local/opt/ruby/bin:$PATH"
    fi

    if command -v ruby > /dev/null 2>&1; then
        RUBY_VERSION=$(ruby --version 2>/dev/null | awk '{print $2}')
        ok "Ruby ${RUBY_VERSION} installed via Homebrew"
    else
        fail "Ruby installation failed"
        exit 1
    fi
fi

# ── 3. Install/Verify Flutter SDK ─────────────────────────────────────────
step "Checking Flutter SDK..."

if command -v flutter > /dev/null 2>&1; then
    FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1)
    ok "Flutter installed: ${FLUTTER_VERSION}"
else
    step "Installing Flutter via Homebrew..."
    brew install --cask flutter 2>/dev/null || true

    if command -v flutter > /dev/null 2>&1; then
        FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1)
        ok "Flutter installed: ${FLUTTER_VERSION}"
    else
        fail "Flutter installation failed"
        exit 1
    fi
fi

# ── 4. Run flutter doctor (informational, not blocking) ───────────────────
step "Running flutter doctor..."
flutter doctor -v 2>&1 | head -30 || true
echo ""
# flutter doctor may show Android/Chrome warnings — these are expected on macOS
# Only Xcode and iOS toolchain matter for MacBridge.
ok "flutter doctor executed (Android/Chrome warnings expected — iOS is what matters)"

# ── 5. Install/Verify CocoaPods ───────────────────────────────────────────
# Lesson 2: Must use Homebrew Ruby, not system Ruby.
step "Checking CocoaPods..."

# CocoaPods gem bin directory (varies by Ruby version)
GEM_BIN_DIR=""
for dir in "/opt/homebrew/lib/ruby/gems"/*/bin "/usr/local/lib/ruby/gems"/*/bin; do
    if [ -d "$dir" ]; then
        GEM_BIN_DIR="$dir"
        break
    fi
done

if command -v pod > /dev/null 2>&1; then
    POD_VERSION=$(pod --version 2>/dev/null)
    ok "CocoaPods installed: ${POD_VERSION}"
else
    step "Installing CocoaPods..."
    gem install cocoapods --no-document 2>/dev/null || \
        sudo gem install cocoapods --no-document 2>/dev/null || true

    # Lesson 3: PATH fix for CocoaPods
    if [ -n "$GEM_BIN_DIR" ]; then
        ensure_path "$GEM_BIN_DIR"
        export PATH="$GEM_BIN_DIR:$PATH"
    fi

    # Also check standard gem paths
    if ! command -v pod > /dev/null 2>&1; then
        GEM_PATHS=$(gem environment gemdir 2>/dev/null)
        GEM_BIN="${GEM_PATHS}/bin"
        if [ -d "$GEM_BIN" ]; then
            ensure_path "$GEM_BIN"
            export PATH="$GEM_BIN:$PATH"
        fi
    fi

    if command -v pod > /dev/null 2>&1; then
        POD_VERSION=$(pod --version 2>/dev/null)
        ok "CocoaPods installed: ${POD_VERSION}"
    else
        fail "CocoaPods installation failed — PATH may need manual configuration"
        fail "Try: export PATH=\"\$(gem environment gemdir)/bin:\$PATH\""
        exit 1
    fi
fi

# ── 6. Install/Verify Git ─────────────────────────────────────────────────
step "Checking Git..."
if command -v git > /dev/null 2>&1; then
    GIT_VERSION=$(git --version 2>/dev/null | awk '{print $3}')
    ok "Git installed: ${GIT_VERSION}"
else
    step "Installing Git via Homebrew..."
    brew install git 2>/dev/null || true

    if command -v git > /dev/null 2>&1; then
        ok "Git installed"
    else
        fail "Git installation failed"
        exit 1
    fi
fi

# ── 7. Generate SSH key if missing ────────────────────────────────────────
# Lesson 5: GitHub password auth dead → SSH keys required.
step "Checking SSH keys..."
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    ok "SSH key exists: ~/.ssh/id_ed25519"
else
    step "Generating SSH key (ed25519)..."
    mkdir -p "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "macbridge" > /dev/null 2>&1
    ok "SSH key generated: ~/.ssh/id_ed25519"
fi

# Display public key for GitHub setup
echo ""
echo -e "  ${BOLD}🔑 SSH public key — add to GitHub → Settings → SSH and GPG keys:${NC}"
echo -e "  ${CYAN}$(cat "$HOME/.ssh/id_ed25519.pub")${NC}"
echo ""

# ── 8. Verify GitHub SSH connectivity ─────────────────────────────────────
step "Checking GitHub SSH connectivity..."
SSH_OUTPUT=$(ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 git@github.com 2>&1) || true
if echo "$SSH_OUTPUT" | grep -qE "successfully authenticated|but GitHub does not provide shell"; then
    ok "GitHub SSH: authenticated"
else
    warn "GitHub SSH not yet configured"
    echo -e "  ${YELLOW}→${NC} Add the SSH public key above to: https://github.com/settings/keys"
    echo -e "  ${YELLOW}→${NC} Then verify with: ssh -T git@github.com"
fi

# ── 9. Install GitHub CLI (for device flow auth) ──────────────────────────
step "Checking GitHub CLI..."
if command -v gh > /dev/null 2>&1; then
    GH_VERSION=$(gh --version 2>/dev/null | head -1)
    ok "GitHub CLI installed: ${GH_VERSION}"
else
    step "Installing GitHub CLI..."
    brew install gh 2>/dev/null || true

    if command -v gh > /dev/null 2>&1; then
        ok "GitHub CLI installed"
    else
        warn "GitHub CLI installation failed — user can still clone via SSH"
    fi
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ ${LAYER} complete${NC} — Development tools installed and verified (${PASS} checks passed)"
else
    echo -e "${RED}❌ ${LAYER} failed${NC} — ${FAIL} check(s) failed, ${PASS} passed"
    exit 1
fi
