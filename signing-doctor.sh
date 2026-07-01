#!/bin/bash
# =============================================================================
# MacBridge — Signing Doctor
# =============================================================================
# Read-only diagnosis of iOS code-signing readiness. Inspects signing
# identities and provisioning profiles, and (optionally) a project's declared
# bundle identifier and development team, then explains what to fix.
#
# BOUNDARY (by design — see HONEST_ASSESSMENT.md Gap 2):
#   This tool NEVER creates certificates or provisioning profiles, NEVER
#   touches your Apple Developer account, and NEVER stores credentials.
#   It only reads local state and links you to Apple's own guides.
#
# Usage:
#   bash signing-doctor.sh                  # diagnose identities + profiles
#   bash signing-doctor.sh --project PATH   # also read a project's bundle id / team
#   bash signing-doctor.sh --json           # machine-readable status contract
#   bash signing-doctor.sh --help
# =============================================================================

set -uo pipefail   # deliberately not -e: diagnosis must survive failing checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

source "${LIB_DIR}/_utils.sh" || { echo "signing-doctor: missing lib/_utils.sh" >&2; exit 1; }
source "${LIB_DIR}/status-contract.sh" || { echo "signing-doctor: missing lib/status-contract.sh" >&2; exit 1; }

JSON_MODE=false
PROJECT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --project) PROJECT="${2:-}"; shift 2 ;;
        --help|-h)
            echo "Usage: bash signing-doctor.sh [--project PATH] [--json]"
            echo ""
            echo "Read-only. Diagnoses iOS code-signing readiness and links to Apple's guides."
            echo "Never creates certificates/profiles, never touches your Apple Developer account."
            exit 0
            ;;
        *) shift ;;
    esac
done

status_contract_init "signing"

# Track which guidance blocks to print at the end (human mode only).
G_IDENTITY=false
G_EXPIRED=false
G_PROFILES=false
G_TEAM_UNSET=false
G_TEAM_MISMATCH=false

hr() { [ "$JSON_MODE" = false ] && echo "$@"; }

# ── Platform gate ───────────────────────────────────────────────────────────
if ! has security; then
    status_record_fail "signing_platform" "macOS signing tools" "critical" "unavailable"
    if [ "$JSON_MODE" = true ]; then status_emit_json; exit 1; fi
    hr ""
    hr "MacBridge Signing Doctor"
    hr "------------------------"
    hr "  ❌ The 'security' tool is unavailable — signing can only be diagnosed on macOS."
    hr ""
    exit 1
fi

hr ""
hr "MacBridge Signing Doctor  (read-only — never touches your Apple account)"
hr "======================================================================="
hr ""

# ── 1. Signing identities ───────────────────────────────────────────────────
valid_out="$(security find-identity -v -p codesigning 2>/dev/null || true)"
all_out="$(security find-identity -p codesigning 2>/dev/null || true)"
valid_count="$(printf '%s\n' "$valid_out" | grep -cE '^[[:space:]]+[0-9]+\)' || true)"
all_count="$(printf '%s\n' "$all_out" | grep -cE '^[[:space:]]+[0-9]+\)' || true)"
expired_count=$(( all_count - valid_count ))
[ "$expired_count" -lt 0 ] && expired_count=0

if [ "$valid_count" -eq 0 ]; then
    status_record_fail "signing_identity" "Code-signing identity" "critical" "none found"
    hr "  ❌ Code-signing identity: none found"
    G_IDENTITY=true
else
    status_record_pass "signing_identity" "Code-signing identity" "critical" "${valid_count} valid"
    hr "  ✅ Code-signing identity: ${valid_count} valid"
    # Show the identity names (already public, no secrets)
    if [ "$JSON_MODE" = false ]; then
        printf '%s\n' "$valid_out" | grep -E '^[[:space:]]+[0-9]+\)' | sed -E 's/^[[:space:]]+[0-9]+\)[[:space:]]+[0-9A-Fa-f]+[[:space:]]+/       • /' || true
    fi
fi

if [ "$expired_count" -gt 0 ]; then
    status_record_warn "signing_identity_expired" "Expired/invalid certificates" "advisory" "${expired_count}"
    hr "  ⚠️  Expired or invalid certificates present: ${expired_count}"
    G_EXPIRED=true
fi

# ── 2. Provisioning profiles ────────────────────────────────────────────────
prof_count=0
for d in "$HOME/Library/MobileDevice/Provisioning Profiles" \
         "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
    if [ -d "$d" ]; then
        n=$(ls "$d"/*.mobileprovision "$d"/*.provisionprofile 2>/dev/null | wc -l | tr -d ' ')
        prof_count=$(( prof_count + n ))
    fi
done

if [ "$prof_count" -eq 0 ]; then
    status_record_warn "provisioning_profile" "Provisioning profiles" "advisory" "none"
    hr "  ⚠️  Provisioning profiles: none installed"
    G_PROFILES=true
else
    status_record_pass "provisioning_profile" "Provisioning profiles" "advisory" "${prof_count} installed"
    hr "  ✅ Provisioning profiles: ${prof_count} installed"
fi

# ── 3. Project bundle id / team (optional) ──────────────────────────────────
# Auto-detect a project if none was passed and the CWD looks like one.
if [ -z "$PROJECT" ]; then
    if [ -d "./ios/Runner.xcodeproj" ] || ls ./*.xcodeproj >/dev/null 2>&1; then
        PROJECT="."
    fi
fi

if [ -n "$PROJECT" ]; then
    pbx=""
    if [ -f "$PROJECT/ios/Runner.xcodeproj/project.pbxproj" ]; then
        pbx="$PROJECT/ios/Runner.xcodeproj/project.pbxproj"           # Flutter
    else
        pbx="$(ls "$PROJECT"/*.xcodeproj/project.pbxproj 2>/dev/null | head -1 || true)"
    fi

    if [ -z "$pbx" ] || [ ! -f "$pbx" ]; then
        status_record_warn "project" "Xcode project" "advisory" "not found under $PROJECT"
        hr "  ⚠️  No Xcode project found under: $PROJECT"
    else
        bundle="$(grep -m1 -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;' "$pbx" 2>/dev/null | sed -E 's/PRODUCT_BUNDLE_IDENTIFIER = //; s/;$//' | tr -d ' "' || true)"
        team="$(grep -m1 -oE 'DEVELOPMENT_TEAM = [^;]+;' "$pbx" 2>/dev/null | sed -E 's/DEVELOPMENT_TEAM = //; s/;$//' | tr -d ' "' || true)"

        if [ -n "$bundle" ]; then
            status_record_pass "signing_bundle_id" "Project bundle identifier" "advisory" "$bundle"
            hr "  ✅ Bundle identifier: ${bundle}"
        else
            status_record_warn "signing_bundle_id" "Project bundle identifier" "advisory" "unset"
            hr "  ⚠️  Bundle identifier: not set in project"
        fi

        if [ -z "$team" ]; then
            status_record_warn "signing_team" "Development team" "advisory" "unset"
            hr "  ⚠️  Development team: not set (DEVELOPMENT_TEAM empty)"
            G_TEAM_UNSET=true
        elif printf '%s\n' "$valid_out" | grep -q "($team)"; then
            status_record_pass "signing_team" "Development team" "advisory" "$team matched"
            hr "  ✅ Development team: ${team} (matches an installed identity)"
        else
            status_record_warn "signing_team_match" "Development team" "advisory" "$team has no identity"
            hr "  ⚠️  Development team: ${team} has no matching signing identity in the keychain"
            G_TEAM_MISMATCH=true
        fi
    fi
fi

# ── JSON output ─────────────────────────────────────────────────────────────
if [ "$JSON_MODE" = true ]; then
    status_emit_json
    [ "$STATUS_FAIL" -eq 0 ] && exit 0 || exit 1
fi

# ── Human summary + targeted guidance ───────────────────────────────────────
echo ""
echo "State: $(status_state)   (passed ${STATUS_PASS}, warnings ${STATUS_WARN}, failed ${STATUS_FAIL})"
echo ""

if [ "$STATUS_FAIL" -eq 0 ] && [ "$STATUS_WARN" -eq 0 ]; then
    echo "  Signing looks ready. Nothing to fix."
    echo ""
    exit 0
fi

echo "What to check:"
echo ""

if [ "$G_IDENTITY" = true ]; then
    echo "  • No signing identity. You need an Apple Development (or Distribution)"
    echo "    certificate in your login keychain."
    echo "      1. Confirm your Apple Developer membership is active."
    echo "      2. In Xcode: Settings > Accounts > (Apple ID) > Manage Certificates > +."
    echo "      3. Or create/download one from the portal."
    echo "    Apple guide: https://developer.apple.com/help/account/certificates/create-certificates"
    echo ""
fi

if [ "$G_EXPIRED" = true ]; then
    echo "  • Expired/invalid certificates were found. Remove them and create a fresh one."
    echo "    List them: security find-identity -p codesigning"
    echo "    Apple guide: https://developer.apple.com/help/account/certificates/revoke-certificates"
    echo ""
fi

if [ "$G_PROFILES" = true ]; then
    echo "  • No provisioning profiles installed. If you use Xcode's"
    echo "    'Automatically manage signing', Xcode creates them on demand."
    echo "    Otherwise download from the portal."
    echo "    Apple guide: https://developer.apple.com/help/account/provisioning-profiles"
    echo ""
fi

if [ "$G_TEAM_UNSET" = true ]; then
    echo "  • The project has no development team. Open ios/Runner.xcworkspace in Xcode,"
    echo "    go to Signing & Capabilities, and select your team (or set DEVELOPMENT_TEAM)."
    echo ""
fi

if [ "$G_TEAM_MISMATCH" = true ]; then
    echo "  • The project's DEVELOPMENT_TEAM has no matching identity in this keychain."
    echo "    Add that team's Apple ID/certificate in Xcode, or switch the project to a"
    echo "    team you have a certificate for."
    echo ""
fi

echo "MacBridge diagnoses signing; it never creates certificates or touches your"
echo "Apple Developer account. Those steps stay in your control."
echo ""

[ "$STATUS_FAIL" -eq 0 ] && exit 0 || exit 1
