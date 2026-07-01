#!/bin/bash
# =============================================================================
# MacBridge — Golden Image Migration
# =============================================================================
# Checks the current Mac's golden image version against the latest available.
# Offers opt-in upgrades. Never forces. Preserves user data.
#
# Update policy (decided in Phase 0):
#   - Freeze the golden image a customer is on
#   - Offer updates as opt-in
#   - Never force-update a running customer environment
#   - Security issues: notify, give 7 days, then update with notice
#
# Usage:
#   bash migrate.sh                    # Check version, offer upgrade if available
#   bash migrate.sh --check            # Check version only (no upgrade prompt)
#   bash migrate.sh --upgrade          # Apply latest upgrade (skip prompt)
#   bash migrate.sh --set-version v2   # Tag current Mac with version (admin)
#   bash migrate.sh --list             # List available golden image versions
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
export MACBRIDGE_LOG_DIR="${SCRIPT_DIR}/logs"

[ -f "${LIB_DIR}/_utils.sh" ] && source "${LIB_DIR}/_utils.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

VERSION_FILE="/etc/macbridge-version"
BACKUP_DIR="$HOME/.macbridge/backups"
MODE="interactive"

while [[ $# -gt 0 ]]; do
    case $1 in
        --check)       MODE="check"; shift ;;
        --upgrade)     MODE="upgrade"; shift ;;
        --set-version) TARGET_VERSION="$2"; MODE="set"; shift 2 ;;
        --list)        MODE="list"; shift ;;
        --help|-h)
            echo "Usage: bash migrate.sh [--check|--upgrade|--set-version vN|--list]"
            exit 0 ;;
        *) shift ;;
    esac
done

# ── Available golden images ────────────────────────────────────────────────

# In production, this would query an API or read from a central registry.
# For now, versions are declared here. Bump when you rebuild the golden image.
declare -A GOLDEN_IMAGES
GOLDEN_IMAGES["v1"]="macOS 15 Sequoia | Xcode 26.6 | iOS 26.5 Sim | Flutter 3.44.4 | CocoaPods 1.16.2 | Ruby 4.x | Node 22"
GOLDEN_IMAGES["v2"]="macOS 15 Sequoia | Xcode 26.6 | iOS 26.5 Sim | Flutter 3.44.4 | CocoaPods 1.16.2 | Ruby 4.x | Node 22 | harden.sh applied"

LATEST_VERSION="v2"

# ── Lists available versions ───────────────────────────────────────────────

list_versions() {
    echo ""
    echo -e "${BOLD}Available Golden Images:${NC}"
    echo ""

    for ver in $(echo "${!GOLDEN_IMAGES[@]}" | tr ' ' '\n' | sort -V); do
        local marker=""
        [ "$ver" = "$LATEST_VERSION" ] && marker=" ${GREEN}(latest)${NC}"
        [ "$ver" = "$(get_current_version)" ] && marker="$marker ${CYAN}(current)${NC}"
        echo -e "  ${BOLD}${ver}${NC}$marker"
        echo -e "    ${GOLDEN_IMAGES[$ver]}"
        echo ""
    done
}

# ── Get/set current version ────────────────────────────────────────────────

get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

set_current_version() {
    local ver="$1"
    echo "$ver" | sudo tee "$VERSION_FILE" > /dev/null 2>&1 || {
        echo -e "${YELLOW}⚠️${NC}  Could not write version file (run with sudo)" >&2
        return 1
    }
    echo -e "${GREEN}✅${NC} Mac tagged as ${BOLD}${ver}${NC}"
}

# ── Check mode ─────────────────────────────────────────────────────────────

check_version() {
    local current; current=$(get_current_version)

    echo ""
    echo -e "${BOLD}MacBridge Golden Image${NC}"
    echo "──────────────────────────────────────────────"
    echo -e "  Current: ${CYAN}${current}${NC}"
    echo -e "  Latest:  ${GREEN}${LATEST_VERSION}${NC}"
    echo ""

    if [ "$current" = "unknown" ]; then
        echo -e "  ${YELLOW}⚠️${NC}  This Mac has no golden image tag."
        echo -e "  ${CYAN}→${NC}   Run: ${BOLD}sudo bash migrate.sh --set-version v1${NC}"
        echo -e "  ${CYAN}→${NC}   This tags the Mac without changing anything."
        return 0
    fi

    if [ "$current" = "$LATEST_VERSION" ]; then
        echo -e "  ${GREEN}✅${NC} You are on the latest golden image."
        return 0
    fi

    # Show what's changed
    echo -e "  ${YELLOW}⚠️${NC}  Update available: ${current} → ${LATEST_VERSION}"
    echo ""
    echo -e "  ${BOLD}Changes in ${LATEST_VERSION}:${NC}"
    echo -e "  ${GOLDEN_IMAGES[$LATEST_VERSION]}"
    echo ""

    if [ "$MODE" = "interactive" ]; then
        echo -e "  ${CYAN}→${NC}   Upgrade? Your project files, SSH keys, and configs will be preserved."
        echo -e "  ${CYAN}→${NC}   Only the toolchain is updated."
        echo ""
        read -r -p "  Upgrade to ${LATEST_VERSION}? [y/N] " REPLY
        echo ""

        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
            perform_upgrade "$LATEST_VERSION"
        else
            echo -e "  ${CYAN}Upgrade skipped. Check again with: bash migrate.sh${NC}"
        fi
    fi

    return 0
}

# ── Perform upgrade ────────────────────────────────────────────────────────

perform_upgrade() {
    local target="$1"
    local current; current=$(get_current_version)

    echo ""
    echo -e "${BOLD}${CYAN}⬆️  Upgrading golden image: ${current} → ${target}${NC}"
    echo "──────────────────────────────────────────────"
    echo ""

    # Backup user configs before touching anything
    step "Backing up user configuration..."
    mkdir -p "$BACKUP_DIR/${current}-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path; backup_path=$(ls -td "$BACKUP_DIR"/* | head -1)

    cp "$HOME/.zprofile" "$backup_path/.zprofile" 2>/dev/null || true
    cp "$HOME/.ssh/config" "$backup_path/ssh_config" 2>/dev/null || true
    cp "$HOME/.tmux.conf" "$backup_path/tmux.conf" 2>/dev/null || true
    ok "User config backed up to $backup_path"

    # Run hardening if upgrading to v2+
    if [[ "$target" =~ v[2-9] ]] && [ -f "${SCRIPT_DIR}/hardening.sh" ]; then
        step "Applying firewall hardening (new in v2)..."
        FORCE=1 bash "${SCRIPT_DIR}/hardening.sh" 2>&1 || warn "Hardening failed — continuing anyway"
    fi

    # Re-run bootstrap verification
    if [ -f "${SCRIPT_DIR}/verify.sh" ]; then
        step "Verifying environment after upgrade..."
        if bash "${SCRIPT_DIR}/verify.sh" --quick 2>&1; then
            ok "Environment verified"
        else
            warn "Some checks failed — environment may need attention"
        fi
    fi

    # Tag with new version
    set_current_version "$target"

    echo ""
    echo -e "${GREEN}✅ Upgrade complete${NC} — Mac is now on ${BOLD}${target}${NC}"
    echo -e "  Backup: ${backup_path}"
    echo -e "  Restore configs if needed: cp ${backup_path}/.zprofile ~/"
    echo ""
}

# ── Main ────────────────────────────────────────────────────────────────────

case $MODE in
    list)
        list_versions
        ;;
    check)
        check_version
        ;;
    set)
        set_current_version "$TARGET_VERSION"
        ;;
    upgrade)
        check_version
        perform_upgrade "$LATEST_VERSION"
        ;;
    *)
        check_version
        ;;
esac
