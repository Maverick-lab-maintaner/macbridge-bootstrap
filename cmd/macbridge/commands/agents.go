package commands

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// The agents MacBridge can set up. Order matters: it is the TUI display
// order and the number the user types.
var agentOptions = []struct {
	ID   string
	Name string
	Desc string
}{
	{"claude", "Claude Code", "deep code reasoning, long implementation loops (Anthropic key)"},
	{"opencode", "OpenCode", "command-line centered execution and orchestration"},
	{"codex", "Codex CLI", "fast implementation passes (OpenAI key)"},
}

// parseAgentSelection turns TUI input into the canonical --agents list.
// Accepts: "" (all), "a"/"all", "n"/"none", comma/space-separated numbers
// ("1,3") or names ("claude codex"). Pure for testability.
func parseAgentSelection(input string) (string, error) {
	input = strings.ToLower(strings.TrimSpace(input))
	switch input {
	case "", "a", "all":
		return "claude,opencode,codex", nil
	case "n", "none":
		return "none", nil
	}

	seen := map[string]bool{}
	var picked []string
	for _, tok := range strings.FieldsFunc(input, func(r rune) bool { return r == ',' || r == ' ' }) {
		var id string
		for i, opt := range agentOptions {
			if tok == opt.ID || tok == fmt.Sprint(i+1) {
				id = opt.ID
				break
			}
		}
		if id == "" {
			return "", fmt.Errorf("unknown agent %q (use numbers 1-3, names, 'all', or 'none')", tok)
		}
		if !seen[id] {
			seen[id] = true
			picked = append(picked, id)
		}
	}
	if len(picked) == 0 {
		return "", fmt.Errorf("no agents selected (use 'all' or 'none' to be explicit)")
	}
	return strings.Join(picked, ","), nil
}

// stdinIsTerminal reports whether we can ask the user questions.
func stdinIsTerminal() bool {
	info, err := os.Stdin.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

// pickAgents runs the interactive selection. Falls back to all agents on
// read errors; re-prompts on invalid input (max 3 tries, then all).
func pickAgents() string {
	fmt.Println()
	fmt.Println("Choose your AI agents (they run with YOUR provider keys — tokens are")
	fmt.Println("billed by your provider, never by MacBridge):")
	fmt.Println()
	for i, opt := range agentOptions {
		fmt.Printf("  %d. %-12s %s\n", i+1, opt.Name, opt.Desc)
	}
	fmt.Println()
	fmt.Println("  a. All of them (default)     n. None (toolchain only)")
	fmt.Println()

	reader := bufio.NewReader(os.Stdin)
	for tries := 0; tries < 3; tries++ {
		fmt.Print("Select [1-3, comma-separated / a / n]: ")
		line, err := reader.ReadString('\n')
		if err != nil {
			break
		}
		selection, perr := parseAgentSelection(line)
		if perr != nil {
			fmt.Printf("  %v\n", perr)
			continue
		}
		return selection
	}
	fmt.Println("  Defaulting to all agents.")
	return "claude,opencode,codex"
}
