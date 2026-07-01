#!/bin/bash
# =============================================================================
# MacBridge — Skill Library Installer
# =============================================================================
# Installs Flutter, Firebase, iOS, and deployment specialist skills onto the
# Mac so AI agents have domain knowledge out of the box. This is the
# differentiator — no competitor offers "Mac + pre-loaded Flutter skills."
#
# Architecture:
#   Skills live at ~/.agents/skills/ on the user's machine.
#   This script copies the most valuable Flutter/iOS skills to the Mac.
#   AI agents (Claude Code, OpenCode, Codex) load skills from this directory.
#
# Usage:
#   bash install-skills.sh                    # Install all skills (agent tier)
#   bash install-skills.sh --tier vanilla     # Core Flutter/iOS only (no AI-agent skills)
#   bash install-skills.sh --list             # Show what would be installed
#   bash install-skills.sh --from-local PATH  # Install from a local skills directory
# =============================================================================

set -euo pipefail

SKILLS_DIR="$HOME/.agents/skills"
TIER="agent"
SOURCE_DIR=""
LIST_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --tier) TIER="$2"; shift 2 ;;
        --from-local) SOURCE_DIR="$2"; shift 2 ;;
        --list) LIST_ONLY=true; shift ;;
        --help|-h)
            echo "Usage: bash install-skills.sh [--tier vanilla|agent] [--from-local PATH] [--list]"
            exit 0 ;;
        *) shift ;;
    esac
done

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ── Skill definitions ──────────────────────────────────────────────────────

# Tier 1: Ship Blockers — every Flutter iOS developer hits these
TIER1_SKILLS=(
    "dart-run-static-analysis"
    "dart-resolve-package-conflicts"
    "dart-fix-runtime-errors"
    "flutter-code-gen"
    "flutter-implement-json-serialization"
    "generating-freezed-models"
    "flutter-dio"
    "flutter-fix-layout-issues"
    "flutter-debugging"
)

# Tier 2: Platform — iOS-specific knowledge
TIER2_SKILLS=(
    "configuring-deep-links"
    "configuring-codemagic"
    "configuring-github-actions"
    "deploying-with-fastlane"
    "flutter-spm"
    "xcode-project-setup"
)

# Tier 3: Services — Firebase + backend integration
TIER3_SKILLS=(
    "integrating-firebase"
    "firebase-auth-basics"
    "firebase-firestore"
    "firebase-crashlytics"
    "firebase-remote-config-basics"
    "integrating-supabase"
    "integrating-sentry"
    "integrating-revenuecat"
    "integrating-google-ads"
)

# Tier 4: Architecture & Patterns
TIER4_SKILLS=(
    "flutter-apply-architecture-best-practices"
    "flutter-state-management"
    "implementing-riverpod"
    "implementing-flutter-bloc"
    "flutter-testing"
    "flutter-ui"
    "flutter-build-responsive-layout"
    "applying-effective-dart"
    "dart-use-pattern-matching"
)

# Tier 5: Agent skills — AI agent workflow (agent tier only)
TIER5_SKILLS=(
    "building-flutter-production-apps"
    "flutter-native"
    "flutter-security"
    "running-flutter-isolates"
    "persisting-data-with-drift"
    "managing-hive-storage"
    "managing-secure-storage"
    "managing-shared-preferences"
    "animating-flutter-widgets"
)

# All flattened
ALL_SKILLS=("${TIER1_SKILLS[@]}" "${TIER2_SKILLS[@]}" "${TIER3_SKILLS[@]}" "${TIER4_SKILLS[@]}")
AGENT_SKILLS=("${TIER5_SKILLS[@]}")

# ── Discover local skill source ────────────────────────────────────────────

discover_source() {
    if [ -n "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR" ]; then
        echo "$SOURCE_DIR"
        return 0
    fi

    # Common paths where user's agent skills live
    local paths=(
        "$HOME/.agents/skills"
        "$HOME/.claude/skills"
        "/mnt/c/Users/*/.agents/skills"  # WSL path to Windows
    )

    for p in "${paths[@]}"; do
        if ls "$p"/*/SKILL.md 2>/dev/null | head -1 > /dev/null 2>&1; then
            echo "$p"
            return 0
        fi
    done

    echo ""
    return 1
}

SOURCE=$(discover_source)

# ── List mode ──────────────────────────────────────────────────────────────

if [ "$LIST_ONLY" = true ]; then
    echo ""
    echo -e "${BOLD}MacBridge Skill Library — ${TIER} tier${NC}"
    echo "──────────────────────────────────────────────"
    echo ""

    list_tier() {
        local name="$1"; shift
        local skills=("$@")
        echo -e "${BOLD}${name}:${NC}"
        for s in "${skills[@]}"; do
            local found=""
            [ -n "$SOURCE" ] && [ -d "$SOURCE/$s" ] && found=" ${GREEN}(found)${NC}" || found=" ${YELLOW}(not on this machine)${NC}"
            echo "  - $s$found"
        done
        echo ""
    }

    list_tier "Tier 1 — Ship Blockers" "${TIER1_SKILLS[@]}"
    list_tier "Tier 2 — Platform (iOS)" "${TIER2_SKILLS[@]}"
    list_tier "Tier 3 — Services" "${TIER3_SKILLS[@]}"
    list_tier "Tier 4 — Architecture" "${TIER4_SKILLS[@]}"

    if [ "$TIER" = "agent" ]; then
        list_tier "Tier 5 — Agent Workflow" "${TIER5_SKILLS[@]}"
    fi

    echo -e "Total: ${#ALL_SKILLS[@]} vanilla skills"
    [ "$TIER" = "agent" ] && echo -e "Agent add-on: ${#AGENT_SKILLS[@]} additional skills"

    if [ -z "$SOURCE" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  No local skill source found. Run with --from-local PATH.${NC}"
    fi

    exit 0
fi

# ── Install ────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}📦 MacBridge — Skill Library Installer${NC}"
echo "──────────────────────────────────────────────"
echo ""

if [ -z "$SOURCE" ]; then
    echo -e "${RED}❌ No local skill source found.${NC}"
    echo ""
    echo "  Skills live on your local machine at ~/.agents/skills/"
    echo "  Copy them to the Mac and run:"
    echo "    bash install-skills.sh --from-local /path/to/skills"
    echo ""
    echo "  Or install them first on your local machine, then SCP to the Mac."
    exit 1
fi

echo -e "  Source: ${CYAN}${SOURCE}${NC}"
echo -e "  Target: ${CYAN}${SKILLS_DIR}${NC}"
echo -e "  Tier:   ${CYAN}${TIER}${NC}"
echo ""

mkdir -p "$SKILLS_DIR"
INSTALLED=0
SKIPPED=0
MISSING=0

install_skill() {
    local skill="$1"
    local src="$SOURCE/$skill"

    if [ ! -d "$src" ]; then
        echo -e "  ${YELLOW}⚠️${NC}  $skill — not found in source"
        ((MISSING++)) || true
        return
    fi

    if [ -d "$SKILLS_DIR/$skill" ]; then
        echo -e "  ${GREEN}✅${NC} $skill (already installed)"
        ((SKIPPED++)) || true
        return
    fi

    cp -r "$src" "$SKILLS_DIR/$skill"
    echo -e "  ${GREEN}→${NC}  $skill"
    ((INSTALLED++)) || true
}

echo -e "${BOLD}Installing skills...${NC}"
echo ""

for skill in "${ALL_SKILLS[@]}"; do
    install_skill "$skill"
done

if [ "$TIER" = "agent" ]; then
    for skill in "${AGENT_SKILLS[@]}"; do
        install_skill "$skill"
    done
fi

echo ""
echo "──────────────────────────────────────────────"
echo -e "  ${GREEN}Installed:${NC} $INSTALLED"
echo -e "  ${CYAN}Already present:${NC} $SKIPPED"
echo -e "  ${YELLOW}Not found in source:${NC} $MISSING"
echo ""

AGENT_SKILL_COUNT=0
if [ "$TIER" = "agent" ]; then
    AGENT_SKILL_COUNT=${#AGENT_SKILLS[@]}
fi
TOTAL_SKILLS=$(( ${#ALL_SKILLS[@]} + AGENT_SKILL_COUNT ))
echo -e "  ${BOLD}Agent skills available: ${GREEN}$((INSTALLED + SKIPPED))/$TOTAL_SKILLS${NC}"
echo ""

if [ "$MISSING" -gt 0 ]; then
    echo -e "  ${YELLOW}💡${NC}  Missing skills need to be installed on your local machine first."
    echo -e "  ${YELLOW}→${NC}   Run ${CYAN}find-skills${NC} on your local agent to discover and install them."
    echo ""
fi

echo -e "  ${GREEN}✅${NC}  AI agents on this Mac now have domain knowledge for:"
echo -e "      Flutter • Firebase • iOS • Deployment • Architecture"
echo ""
