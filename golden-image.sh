#!/bin/bash
# =============================================================================
# MacBridge — Golden Image Builder
# =============================================================================
# Codifies Stage 1 of the pipeline (MVP_BUILD_PLAN.md §6): turn a fresh Mac
# with Xcode GUI-installed into a verified, workspace-arranged image that is
# ready to snapshot. The one manual step — installing Xcode from the App Store
# and taking the provider snapshot — is guided, not automated.
#
#   build     bootstrap -> verify -> arrange workspace -> write manifest -> tag
#   manifest  print the current machine's version manifest (JSON)
#   verify    compare the current machine against a saved manifest (drift check)
#
# Usage:
#   bash golden-image.sh build --tier agent --version v3
#   bash golden-image.sh build --skip-bootstrap        # image already provisioned
#   sudo bash golden-image.sh manifest
#   bash golden-image.sh verify --manifest /etc/macbridge-manifest.json
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
export MACBRIDGE_LOG_DIR="${SCRIPT_DIR}/logs"

source "${LIB_DIR}/_utils.sh" || { echo "golden-image: missing lib/_utils.sh" >&2; exit 1; }

MANIFEST_FILE="/etc/macbridge-manifest.json"
TIER="agent"
IMAGE_VERSION=""
SKIP_BOOTSTRAP=false
MANIFEST_PATH="$MANIFEST_FILE"

CMD="${1:-}"; shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --tier) TIER="$2"; shift 2 ;;
        --version) IMAGE_VERSION="$2"; shift 2 ;;
        --skip-bootstrap) SKIP_BOOTSTRAP=true; shift ;;
        --manifest) MANIFEST_PATH="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ── Capture the current machine's versions as a manifest (JSON) ─────────────
first_line() { eval "$1" 2>/dev/null | head -1 || true; }

emit_manifest() {
    local macos xcode sim flutter_v pods ruby_v node_v
    macos="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
    xcode="$(first_line 'xcodebuild -version' )"
    sim="$(xcrun simctl list runtimes 2>/dev/null | grep -m1 iOS | sed -E 's/ \(.*//' | xargs 2>/dev/null || echo '')"
    flutter_v="$(first_line 'flutter --version')"
    pods="$(first_line 'pod --version')"
    ruby_v="$(first_line 'ruby --version')"
    node_v="$(first_line 'node --version')"

    cat <<EOF
{
  "image_version": $(json_string "${IMAGE_VERSION:-$(cat /etc/macbridge-version 2>/dev/null || echo unversioned)}"),
  "built_at": $(json_string "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"),
  "tier": $(json_string "$TIER"),
  "components": {
    "macos": $(json_string "$macos"),
    "xcode": $(json_string "$xcode"),
    "ios_simulator": $(json_string "$sim"),
    "flutter": $(json_string "$flutter_v"),
    "cocoapods": $(json_string "$pods"),
    "ruby": $(json_string "$ruby_v"),
    "node": $(json_string "$node_v")
  }
}
EOF
}

# ── build ───────────────────────────────────────────────────────────────────
do_build() {
    echo ""
    echo -e "${BOLD}${CYAN}MacBridge — Golden Image Build${NC}"
    echo "──────────────────────────────────────────────"
    echo ""

    if [ "$(uname -s)" != "Darwin" ]; then
        fail "Golden images are built on macOS. Current platform: $(uname -s)"
        exit 1
    fi

    # The one manual prerequisite: Xcode must be GUI-installed first.
    step "Checking Xcode (the one GUI prerequisite)..."
    if ! has xcodebuild || ! xcodebuild -version >/dev/null 2>&1; then
        fail "Xcode is not installed or usable."
        info "Install it once via the App Store (DeskIn GUI), then re-run this build."
        info "  https://apps.apple.com/app/xcode/id497799835"
        exit 1
    fi
    ok "Xcode present: $(first_line 'xcodebuild -version')"

    # Everything else is CLI-installable.
    if [ "$SKIP_BOOTSTRAP" = false ]; then
        step "Running bootstrap (--tier ${TIER})..."
        if ! bash "${SCRIPT_DIR}/bootstrap.sh" --tier "$TIER"; then
            fail "Bootstrap failed. Fix the failing layer and re-run."
            exit 1
        fi
    else
        info "Skipping bootstrap (--skip-bootstrap)."
    fi

    # Gate on a clean verification before we call it a golden image.
    step "Verifying environment..."
    local verify_json state
    verify_json="$(bash "${SCRIPT_DIR}/verify.sh" --json 2>/dev/null || true)"
    state="$(printf '%s' "$verify_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("summary",{}).get("state","unknown"))' 2>/dev/null || echo unknown)"
    if [ "$state" != "ready" ]; then
        fail "Environment is '${state}', not 'ready'. Run bash doctor.sh before snapshotting."
        exit 1
    fi
    ok "Environment verified: ready"

    # Arrange the prepared studio.
    step "Configuring the auto-arranged workspace..."
    bash "${SCRIPT_DIR}/workspace-setup.sh" || warn "Workspace setup reported an issue."

    # Write the manifest and tag the version.
    step "Writing manifest: ${MANIFEST_FILE}"
    emit_manifest | sudo tee "$MANIFEST_FILE" >/dev/null 2>&1 || {
        warn "Could not write ${MANIFEST_FILE} (run with sudo to persist it)."
        emit_manifest
    }

    if [ -n "$IMAGE_VERSION" ] && [ -f "${SCRIPT_DIR}/migrate.sh" ]; then
        step "Tagging image version: ${IMAGE_VERSION}"
        bash "${SCRIPT_DIR}/migrate.sh" --set-version "$IMAGE_VERSION" || warn "Version tag failed (needs sudo)."
    fi

    echo ""
    echo -e "${GREEN}✅ Golden image is ready to snapshot.${NC}"
    echo ""
    echo -e "  ${BOLD}Final manual step (provider-specific):${NC}"
    echo -e "  1. Stop or pause the Mac cleanly."
    echo -e "  2. Take a snapshot / create an image via your provider (Macly/VPSMAC) API or console."
    echo -e "  3. Name it after the manifest, e.g. ${CYAN}macbridge-golden-${IMAGE_VERSION:-vX}${NC}."
    echo -e "  4. Provision future Macs FROM this snapshot, then run only ${CYAN}bash verify.sh${NC}."
    echo ""
}

# ── verify (drift check against a saved manifest) ───────────────────────────
do_verify() {
    if [ ! -f "$MANIFEST_PATH" ]; then
        fail "No manifest at ${MANIFEST_PATH}. Build one with: sudo bash golden-image.sh manifest > file"
        exit 1
    fi
    local current
    current="$(emit_manifest)"
    echo ""
    echo -e "${BOLD}Golden Image Drift Check${NC}"
    echo "──────────────────────────────────────────────"
    python3 - "$current" "$MANIFEST_PATH" <<'PY'
import json, sys
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass
current = json.loads(sys.argv[1])
saved = json.load(open(sys.argv[2], encoding="utf-8"))
cc, sc = current.get("components", {}), saved.get("components", {})
keys = sorted(set(cc) | set(sc))
drift = 0
for k in keys:
    a, b = sc.get(k, "—"), cc.get(k, "—")
    mark = "ok  " if a == b else "DRIFT"
    if a != b:
        drift += 1
    print(f"  [{mark}] {k:<14} saved={a!r}  current={b!r}")
print()
print("  No drift — machine matches the golden manifest." if drift == 0
      else f"  {drift} component(s) drifted from the golden manifest.")
sys.exit(1 if drift else 0)
PY
}

case "$CMD" in
    build)    do_build ;;
    manifest) emit_manifest ;;
    verify)   do_verify ;;
    ""|--help|-h|help)
        echo "Usage: bash golden-image.sh {build|manifest|verify} [options]"
        echo ""
        echo "  build     bootstrap -> verify -> workspace -> manifest -> snapshot guidance"
        echo "  manifest  print this machine's version manifest as JSON"
        echo "  verify    drift-check this machine against a saved manifest (--manifest PATH)"
        echo ""
        echo "Options: --tier vanilla|agent, --version vN, --skip-bootstrap, --manifest PATH"
        ;;
    *)
        echo "golden-image: unknown command '$CMD' (try: build | manifest | verify | --help)" >&2
        exit 1
        ;;
esac
