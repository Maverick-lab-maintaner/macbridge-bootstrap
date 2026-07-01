package commands

import "testing"

func TestParseAgentSelection(t *testing.T) {
	valid := map[string]string{
		"":               "claude,opencode,codex",
		"a":              "claude,opencode,codex",
		"ALL":            "claude,opencode,codex",
		"n":              "none",
		"none":           "none",
		"1":              "claude",
		"2":              "opencode",
		"3":              "codex",
		"1,3":            "claude,codex",
		"3,1":            "codex,claude",
		"claude":         "claude",
		"claude codex":   "claude,codex",
		"1, 2, 3":        "claude,opencode,codex",
		"claude,claude":  "claude", // dedupe
		"  2  ":          "opencode",
	}
	for in, want := range valid {
		got, err := parseAgentSelection(in)
		if err != nil {
			t.Errorf("parseAgentSelection(%q) unexpected error: %v", in, err)
			continue
		}
		if got != want {
			t.Errorf("parseAgentSelection(%q) = %q, want %q", in, got, want)
		}
	}

	invalid := []string{"4", "0", "gpt", "claude,4", "yes"}
	for _, in := range invalid {
		if got, err := parseAgentSelection(in); err == nil {
			t.Errorf("parseAgentSelection(%q) accepted invalid input -> %q", in, got)
		}
	}
}
