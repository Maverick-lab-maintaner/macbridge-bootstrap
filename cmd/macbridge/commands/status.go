package commands

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/spf13/cobra"
)

type statusCheck struct {
	Label    string `json:"label"`
	Status   string `json:"status"`
	Severity string `json:"severity"`
	Value    string `json:"value"`
}

type statusReport struct {
	MachineID   string                 `json:"machine_id"`
	Hostname    string                 `json:"hostname"`
	Overall     string                 `json:"overall"`
	FailedCount int                    `json:"failed_count"`
	Checks      map[string]statusCheck `json:"checks"`
	Summary     struct {
		State      string `json:"state"`
		ChecksPass int    `json:"checks_passed"`
		ChecksFail int    `json:"checks_failed"`
		ChecksWarn int    `json:"checks_warn"`
		NextAction string `json:"next_action"`
	} `json:"summary"`
	Provider struct {
		Name string `json:"name"`
		Kind string `json:"kind"`
		Host string `json:"host"`
	} `json:"provider"`
}

type dashboardItem struct {
	Key   string
	Label string
	Value string
	State string
}

func checkValue(report statusReport, key string) string {
	check, ok := report.Checks[key]
	if !ok || check.Value == "" {
		return "-"
	}
	return check.Value
}

func checkOK(report statusReport, key string) string {
	check, ok := report.Checks[key]
	if !ok {
		return "SKIP"
	}
	return check.Status
}

func supportsANSI() bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}

	info, err := os.Stdout.Stat()
	if err != nil {
		return false
	}

	return (info.Mode() & os.ModeCharDevice) != 0
}

func paint(enabled bool, code, text string) string {
	if !enabled {
		return text
	}
	return code + text + "\033[0m"
}

func badge(enabled bool, state string) string {
	switch state {
	case "PASS", "READY":
		return paint(enabled, "\033[38;5;78m", "[READY]")
	case "WARN", "DEGRADED":
		return paint(enabled, "\033[38;5;220m", "[WARN ]")
	case "FAIL", "BLOCKED":
		return paint(enabled, "\033[38;5;203m", "[FAIL ]")
	case "SKIP":
		return paint(enabled, "\033[38;5;245m", "[SKIP ]")
	default:
		return paint(enabled, "\033[38;5;245m", "["+state+"]")
	}
}

func detailLine(label, value string) string {
	return fmt.Sprintf("  %-12s %s", label, value)
}

func section(title string) {
	fmt.Println("  " + title)
	fmt.Println("  " + strings.Repeat("-", len(title)))
}

func labelForCheck(report statusReport, key, fallback string) string {
	check, ok := report.Checks[key]
	if ok && check.Label != "" {
		return check.Label
	}
	return fallback
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return "-"
}

func collectIssues(report statusReport) []dashboardItem {
	items := make([]dashboardItem, 0)
	for key, check := range report.Checks {
		if check.Status == "WARN" || check.Status == "FAIL" {
			items = append(items, dashboardItem{
				Key:   key,
				Label: check.Label,
				Value: firstNonEmpty(check.Value, "missing"),
				State: check.Status,
			})
		}
	}

	sort.Slice(items, func(i, j int) bool {
		if items[i].State != items[j].State {
			return items[i].State == "FAIL"
		}
		return strings.ToLower(items[i].Label) < strings.ToLower(items[j].Label)
	})

	return items
}

func printItem(enabled bool, label, value, state string) {
	fmt.Printf("  %-14s %s %s\n", label, badge(enabled, state), value)
}

var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "Check Mac environment health",
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := hostRequired(); err != nil {
			return err
		}

		raw, err := runSSHOutput(
			"cd ~/macbridge-bootstrap && bash verify.sh --json --quick",
			"-o", "ConnectTimeout=10",
		)
		if err != nil && len(raw) == 0 {
			return fmt.Errorf("status check failed: %w", err)
		}

		var report statusReport
		if err := json.Unmarshal(raw, &report); err != nil {
			return fmt.Errorf("invalid status JSON: %w", err)
		}

		renderTUI(report, macHost)
		return nil
	},
}

func renderTUI(report statusReport, host string) {
	color := supportsANSI()
	state := report.Summary.State
	if state == "" {
		state = report.Overall
	}
	if state == "" {
		state = "unknown"
	}
	stateUpper := strings.ToUpper(state)

	providerName := firstNonEmpty(report.Provider.Name, report.Provider.Kind)
	providerHost := firstNonEmpty(report.Provider.Host, host)
	nextAction := firstNonEmpty(report.Summary.NextAction, "No guidance available.")

	fmt.Println()
	fmt.Println("  MACBRIDGE STATUS")
	fmt.Println("  =================")
	fmt.Println()

	section("Connection")
	fmt.Println(detailLine("Machine", firstNonEmpty(report.MachineID, "-")))
	fmt.Println(detailLine("SSH", fmt.Sprintf("%s@%s", macUser, host)))
	fmt.Println(detailLine("Hostname", firstNonEmpty(report.Hostname, "-")))
	fmt.Println(detailLine("Provider", providerName))
	fmt.Println(detailLine("Provider host", providerHost))
	fmt.Println(detailLine("State", badge(color, stateUpper)))
	fmt.Println(detailLine("Counts", fmt.Sprintf("pass=%d fail=%d warn=%d", report.Summary.ChecksPass, report.Summary.ChecksFail, report.Summary.ChecksWarn)))
	fmt.Println()

	section("Core toolchain")
	printItem(color, labelForCheck(report, "flutter", "Flutter"), checkValue(report, "flutter"), checkOK(report, "flutter"))
	printItem(color, labelForCheck(report, "xcodebuild", "Xcode"), checkValue(report, "xcodebuild"), checkOK(report, "xcodebuild"))
	printItem(color, labelForCheck(report, "ruby", "Ruby"), checkValue(report, "ruby"), checkOK(report, "ruby"))
	printItem(color, labelForCheck(report, "cocoapods", "CocoaPods"), checkValue(report, "cocoapods"), checkOK(report, "cocoapods"))
	printItem(color, labelForCheck(report, "node", "Node.js"), checkValue(report, "node"), checkOK(report, "node"))
	printItem(color, labelForCheck(report, "disk_50gb", "Disk"), checkValue(report, "disk_50gb"), checkOK(report, "disk_50gb"))
	fmt.Println()

	section("Agent surface")
	printItem(color, labelForCheck(report, "claude", "Claude"), checkValue(report, "claude"), checkOK(report, "claude"))
	printItem(color, labelForCheck(report, "opencode", "OpenCode"), checkValue(report, "opencode"), checkOK(report, "opencode"))
	printItem(color, labelForCheck(report, "codex", "Codex"), checkValue(report, "codex"), checkOK(report, "codex"))
	printItem(color, labelForCheck(report, "tmux", "tmux"), checkValue(report, "tmux"), checkOK(report, "tmux"))
	fmt.Println()

	issues := collectIssues(report)
	section("Attention")
	if len(issues) == 0 {
		fmt.Println("  No failing or warning checks in this snapshot.")
	} else {
		for _, item := range issues {
			printItem(color, item.Label, item.Value, item.State)
		}
	}
	fmt.Println()

	section("Next action")
	fmt.Println("  " + nextAction)
	fmt.Println()
}

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Run remote remediation guidance",
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := hostRequired(); err != nil {
			return err
		}
		return runSSHCommand(
			"cd ~/macbridge-bootstrap && bash doctor.sh --quick",
			false,
			"-o", "ConnectTimeout=10",
		)
	},
}
