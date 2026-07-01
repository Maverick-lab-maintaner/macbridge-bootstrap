#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

[ -f "${LIB_DIR}/_utils.sh" ] && source "${LIB_DIR}/_utils.sh"
[ -f "${LIB_DIR}/status-contract.sh" ] && source "${LIB_DIR}/status-contract.sh"

QUICK_MODE=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick) QUICK_MODE=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        --help|-h)
            echo "Usage: bash verify.sh [--quick] [--json]"
            exit 0
            ;;
        *) shift ;;
    esac
done

status_contract_init "verify"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

run_capture() {
    local command="$1"
    local output
    set +e
    output=$(eval "$command" 2>/dev/null)
    local rc=$?
    set -e
    printf '%s' "$output"
    return "$rc"
}

print_result() {
    local icon="$1"
    local color="$2"
    local label="$3"
    local value="$4"
    [ "$JSON_MODE" = true ] && return 0
    printf "  ${color}%s${NC} %-35s %s\n" "$icon" "$label" "$value"
}

record_check() {
    local name="$1"
    local label="$2"
    local command="$3"
    local severity="${4:-critical}"
    local empty_value="${5:-ok}"
    local output

    if output="$(run_capture "$command")"; then
        output="$(printf '%s' "$output" | head -1)"
        [ -z "$output" ] && output="$empty_value"
        status_record_pass "$name" "$label" "$severity" "$output"
        print_result "PASS" "$GREEN" "$label" "$output"
        return 0
    fi

    status_record_fail "$name" "$label" "$severity" "missing"
    print_result "FAIL" "$RED" "$label" "NOT FOUND"
    return 0
}

record_version_check() {
    local name="$1"
    local label="$2"
    local command="$3"
    local min_version="$4"
    local severity="${5:-critical}"
    local version

    version="$(run_capture "$command" | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 || true)"

    if [ -z "$version" ]; then
        status_record_fail "$name" "$label" "$severity" "missing"
        print_result "FAIL" "$RED" "$label" "NOT FOUND"
        return 0
    fi

    if version_ge "$min_version" "$version"; then
        status_record_pass "$name" "$label" "$severity" "$version"
        print_result "PASS" "$GREEN" "$label" "$version"
        return 0
    fi

    status_record_warn "$name" "$label" "$severity" "$version"
    [ "$JSON_MODE" = false ] && printf "  ${YELLOW}WARN${NC} %-35s %s (min: %s)\n" "$label" "$version" "$min_version"
    return 0
}

if [ "$JSON_MODE" = false ]; then
    echo ""
    echo -e "${BOLD}${CYAN}MacBridge Environment Verification${NC}"
    echo ""
    echo -e "${BOLD}System:${NC}"
fi

record_check "os" "macOS" "uname -s | grep Darwin" "critical" "Darwin"
record_check "disk_50gb" "Disk >50GB free" "[ \$(df -g / 2>/dev/null | awk 'NR==2 {print \$4}') -gt 50 ] && df -g / 2>/dev/null | awk 'NR==2 {print \$4 \"GB free\"}'" "critical" "ok"
record_check "network" "Network reachable" "ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1 && echo reachable" "critical" "reachable"
record_check "home_write" "HOME writable" "[ -w \$HOME ] && echo writable" "critical" "writable"

if [ "$JSON_MODE" = false ]; then
    echo ""
    echo -e "${BOLD}Apple Toolchain:${NC}"
fi

# NOTE: no `| head -1` inside check commands — under `set -o pipefail`, head
# closing the pipe early sends the tool SIGPIPE (exit 141) and records a false
# FAIL (seen live: xcodebuild "NOT FOUND" on a Mac where it worked). record_check
# already truncates output to the first line.
record_check "xcode_app" "Xcode installed" "[ -d /Applications/Xcode.app ] && echo installed" "critical" "installed"
record_check "xcodebuild" "xcodebuild" "xcodebuild -version" "critical" "available"
record_check "xcode_clt" "Command Line Tools" "xcode-select -p" "critical" "configured"

if [ "$QUICK_MODE" = false ]; then
    record_check "simulator" "iOS Simulator runtime" "xcrun simctl list runtimes | grep iOS" "critical" "installed"
elif [ "$JSON_MODE" = false ]; then
    printf "  ${YELLOW}SKIP${NC} %-35s %s\n" "iOS Simulator runtime" "(quick mode)"
fi

if [ "$JSON_MODE" = false ]; then
    echo ""
    echo -e "${BOLD}Development Tools:${NC}"
fi

record_check "homebrew" "Homebrew" "brew --version" "critical" "installed"
record_check "git" "Git" "git --version" "critical" "installed"
record_check "gh_cli" "GitHub CLI" "gh --version" "advisory" "installed"
record_check "ssh_key" "SSH key (ed25519)" "[ -f \$HOME/.ssh/id_ed25519 ] && echo present" "advisory" "present"
record_check "flutter" "Flutter SDK" "flutter --version" "critical" "installed"
record_version_check "ruby" "Ruby" "ruby --version" "3.0" "critical"
record_check "cocoapods" "CocoaPods" "pod --version" "critical" "installed"

if [ "$JSON_MODE" = false ]; then
    echo ""
    echo -e "${BOLD}AI Agents:${NC}"
fi

record_check "node" "Node.js" "node --version" "critical" "installed"
record_check "npm" "npm" "npm --version" "critical" "installed"

if [ "$QUICK_MODE" = false ]; then
    record_check "claude" "Claude Code" "which claude" "advisory" "installed"
    record_check "opencode" "OpenCode" "which opencode" "advisory" "installed"
    record_check "codex" "Codex CLI" "which codex" "advisory" "installed"
elif [ "$JSON_MODE" = false ]; then
    printf "  ${YELLOW}SKIP${NC} %-35s %s\n" "Agent CLIs" "(quick mode)"
fi

record_check "tmux" "tmux" "tmux -V" "advisory" "installed"

if [ "$QUICK_MODE" = false ]; then
    if [ "$JSON_MODE" = false ]; then
        echo ""
        echo -e "${BOLD}Configuration:${NC}"
    fi
    record_check "ssh_config" "SSH config" "[ -f \$HOME/.ssh/config ] && echo present" "advisory" "present"
    record_check "tmux_config" "tmux config" "[ -f \$HOME/.tmux.conf ] && echo present" "advisory" "present"
    record_check "ssh_keepalive" "SSH keepalive" "grep -q ServerAliveInterval \$HOME/.ssh/config 2>/dev/null && echo configured" "advisory" "configured"
    record_check "brew_in_path" "Homebrew in PATH" "echo \$PATH | grep homebrew" "advisory" "configured"
fi

if [ "$JSON_MODE" = true ]; then
    status_emit_json
    [ "$STATUS_FAIL" -eq 0 ] && exit 0 || exit 1
fi

echo ""
echo -e "${BOLD}Environment:${NC}"
echo -e "  User:     ${CYAN}$(whoami)${NC}"
echo -e "  Hostname: ${CYAN}$(hostname -s 2>/dev/null || echo 'unknown')${NC}"
echo -e "  macOS:    ${CYAN}$(sw_vers -productVersion 2>/dev/null || echo 'unknown')${NC}"
echo -e "  Arch:     ${CYAN}$(uname -m)${NC}"
echo ""
echo -e "${BOLD}Verification Summary:${NC}"
echo -e "  State:    ${CYAN}$(status_state)${NC}"
echo -e "  Passed:   ${GREEN}${STATUS_PASS}${NC}"
echo -e "  Failed:   ${RED}${STATUS_FAIL}${NC}"
echo -e "  Warnings: ${YELLOW}${STATUS_WARN}${NC}"
echo ""
echo -e "  ${CYAN}Next:${NC} $(status_next_action)"
echo ""

[ "$STATUS_FAIL" -eq 0 ] && exit 0 || exit 1
