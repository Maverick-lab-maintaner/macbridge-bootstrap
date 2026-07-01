package commands

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

var (
	macHost  string
	macUser  string
	keyPath  string
	tier     string
	reportTo string
)

// RootCmd is the entry point for the macbridge CLI.
var RootCmd = &cobra.Command{
	Use:   "macbridge",
	Short: "MacBridge — Provision and manage cloud Mac development environments",
	Long: `MacBridge gives Flutter developers a production-ready iOS build
environment in 60 seconds. Provision a cloud Mac, run bootstrap,
and start building — no Mac purchase required.`,
}

func init() {
	RootCmd.AddCommand(provisionCmd)
	RootCmd.AddCommand(statusCmd)
	RootCmd.AddCommand(sshCmd)
	RootCmd.AddCommand(stopCmd)

	RootCmd.PersistentFlags().StringVar(&macHost, "host", "", "Mac hostname or IP")
	RootCmd.PersistentFlags().StringVar(&macUser, "user", "admin", "SSH username")
	RootCmd.PersistentFlags().StringVar(&keyPath, "key", "", "SSH private key path")
	RootCmd.PersistentFlags().StringVar(&tier, "tier", "agent", "Provisioning tier (vanilla|agent)")
	RootCmd.PersistentFlags().StringVar(&reportTo, "report-to", "", "Centralized log shipping URL")
}

var provisionCmd = &cobra.Command{
	Use:   "provision",
	Short: "Provision a new cloud Mac",
	Long:  `Provisions a new cloud Mac, copies bootstrap scripts via SCP, and runs the full provisioning pipeline.`,
	Run: func(cmd *cobra.Command, args []string) {
		if macHost == "" {
			fmt.Println("Error: --host is required (e.g., macbridge provision --host 203.0.113.47)")
			return
		}

		fmt.Printf("Provisioning Mac at %s...\n", macHost)
		fmt.Printf("  Tier: %s\n", tier)

		// Phase 1 stub — currently delegates to provision.ps1 / manual SSH
		// Full implementation requires Macly/VPSMac API integration
		fmt.Println("\nPhase 1: API integration not yet implemented.")
		fmt.Println("Use provision.ps1 on Windows or manual SSH:")
		fmt.Printf("  scp -r . %s@%s:~/macbridge-bootstrap\n", macUser, macHost)
		fmt.Printf("  ssh %s@%s 'cd ~/macbridge-bootstrap && bash bootstrap.sh --tier %s'\n", macUser, macHost, tier)
	},
}

var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "Check Mac environment health with a TUI dashboard",
	Long:  `Runs verify.sh remotely and renders a terminal dashboard with box-drawn ANSI output.`,
	Run: func(cmd *cobra.Command, args []string) {
		if macHost == "" {
			fmt.Println("Error: --host is required")
			return
		}

		// Fetch health data via SSH
		raw, err := exec.Command("ssh",
			"-o", "StrictHostKeyChecking=accept-new",
			"-o", "ConnectTimeout=10",
			fmt.Sprintf("%s@%s", macUser, macHost),
			"cd ~/macbridge-bootstrap && bash healthd.sh 2>/dev/null",
		).Output()

		if err != nil {
			// Fallback: run verify.sh --quick
			verifyCmd := exec.Command("ssh",
				"-o", "StrictHostKeyChecking=accept-new",
				"-o", "ConnectTimeout=10",
				fmt.Sprintf("%s@%s", macUser, macHost),
				"cd ~/macbridge-bootstrap && bash verify.sh --quick",
			)
			verifyCmd.Stdout = os.Stdout
			verifyCmd.Stderr = os.Stderr
			if err := verifyCmd.Run(); err != nil {
				fmt.Fprintf(os.Stderr, "Health check failed: %v\n", err)
			}
			return
		}

		// Parse JSON and render TUI
		renderTUI(string(raw), macHost)
	},
}

func renderTUI(rawJSON string, host string) {
	// Simple ANSI parser — extract key fields from healthd JSON output
	// Falls back gracefully if JSON parse fails
	extract := func(key string) string {
		// Crude grep — works without a JSON parser dependency
		grep := fmt.Sprintf(`"%s":"([^"]*)"`, key)
		for _, line := range splitLines(rawJSON) {
			if matches(line, grep) {
				return extractValue(line)
			}
		}
		return "—"
	}

	extractNested := func(parent, key string) string {
		inParent := false
		for _, line := range splitLines(rawJSON) {
			if contains(line, `"`+parent+`":`) {
				inParent = true
				continue
			}
			if inParent && contains(line, `"`+key+`":`) {
				return extractValue(line)
			}
		}
		return "—"
	}

	flVer := extractNested("flutter", "value")
	xcVer := extractNested("xcodebuild", "value")
	rubyVer := extractNested("ruby", "value")
	podVer := extractNested("cocoapods", "value")
	nodeVer := extractNested("node", "value")
	disk := extractNested("disk", "value")
	overall := extract("overall")
	failed := extract("failed_count")
	hostname := extract("hostname")
	machineID := extract("machine_id")

	statusIcon := "🟢"
	statusText := "healthy"
	if overall == "degraded" {
		statusIcon = "🔴"
		statusText = "degraded"
	}

	// Agents
	claude := "❌"
	opencode := "❌"
	codex := "❌"
	if extractNested("claude", "status") == "PASS" { claude = "✅" }
	if extractNested("opencode", "status") == "PASS" { opencode = "✅" }
	if extractNested("codex", "status") == "PASS" { codex = "✅" }

	fmt.Println()
	fmt.Printf("  ┌─────────────────────────────────────────────────┐\n")
	fmt.Printf("  │  %s Mac:    %-12s (%s)          │\n", statusIcon, machineID, statusText)
	fmt.Printf("  │  SSH:    %-30s           │\n", fmt.Sprintf("%s@%s", macUser, host))
	fmt.Printf("  │  Host:   %-30s           │\n", hostname)
	fmt.Printf("  │                                                 │\n")
	fmt.Printf("  │  Flutter:    %-12s %s                        │\n", flVer, checkMark(flVer))
	fmt.Printf("  │  Xcode:      %-12s %s                        │\n", xcVer, checkMark(xcVer))
	fmt.Printf("  │  Ruby:       %-12s %s                        │\n", rubyVer, checkMark(rubyVer))
	fmt.Printf("  │  CocoaPods:  %-12s %s                        │\n", podVer, checkMark(podVer))
	fmt.Printf("  │  Node.js:    %-12s %s                        │\n", nodeVer, checkMark(nodeVer))
	fmt.Printf("  │  Disk:       %-12s %s                        │\n", disk, checkMark(disk))
	fmt.Printf("  │                                                 │\n")
	fmt.Printf("  │  Claude:  %s  OpenCode: %s  Codex: %s                    │\n", claude, opencode, codex)
	fmt.Printf("  │                                                 │\n")
	fmt.Printf("  │  Health:  %s (%s failed checks)                  │\n", statusText, failed)
	fmt.Printf("  └─────────────────────────────────────────────────┘\n")
	fmt.Println()
}

func checkMark(val string) string {
	if val == "" || val == "—" || val == "not found" || val == "missing" {
		return "❌"
	}
	return "✅"
}

func splitLines(s string) []string {
	var lines []string
	current := ""
	for _, ch := range s {
		if ch == '\n' {
			lines = append(lines, current)
			current = ""
		} else {
			current += string(ch)
		}
	}
	if current != "" {
		lines = append(lines, current)
	}
	return lines
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && searchString(s, substr)
}

func searchString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

func matches(s, pattern string) bool {
	// Simple pattern match: "key":"value"
	// Pattern format: "key":"([^"]*)"
	return contains(s, pattern[:len(pattern)-len(`([^"]*)"`)]) || contains(s, pattern[1:len(pattern)-len(`([^"]*)"`)])
}

func extractValue(line string) string {
	// Extract value from "key":"value" pair
	start := -1
	for i, ch := range line {
		if ch == '"' {
			if start == -1 {
				start = i
			}
		}
	}
	// Find last quoted value
	lastQuote := -1
	for i := len(line) - 1; i >= 0; i-- {
		if line[i] == '"' {
			if lastQuote == -1 {
				lastQuote = i
			} else {
				return line[i+1 : lastQuote]
			}
		}
	}
	return ""
}

var sshCmd = &cobra.Command{
	Use:   "ssh",
	Short: "Open SSH connection to Mac",
	Long:  `Opens an interactive SSH session to the provisioned Mac.`,
	Run: func(cmd *cobra.Command, args []string) {
		if macHost == "" {
			fmt.Println("Error: --host is required")
			return
		}

		sshArgs := []string{
			"-o", "StrictHostKeyChecking=accept-new",
			"-o", "ServerAliveInterval=60",
		}
		if keyPath != "" {
			sshArgs = append(sshArgs, "-i", keyPath)
		}
		sshArgs = append(sshArgs, fmt.Sprintf("%s@%s", macUser, macHost))

		sshCmd := exec.Command("ssh", sshArgs...)
		sshCmd.Stdin = os.Stdin
		sshCmd.Stdout = os.Stdout
		sshCmd.Stderr = os.Stderr
		if err := sshCmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "SSH failed: %v\n", err)
		}
	},
}

var stopCmd = &cobra.Command{
	Use:   "stop",
	Short: "Stop a running Mac (auto-cleanup)",
	Long:  `Runs cleanup.sh on the Mac and stops the instance.`,
	Run: func(cmd *cobra.Command, args []string) {
		if macHost == "" {
			fmt.Println("Error: --host is required")
			return
		}

		fmt.Printf("Stopping Mac at %s...\n", macHost)
		sshCmd := exec.Command("ssh",
			"-o", "StrictHostKeyChecking=accept-new",
			"-o", "ConnectTimeout=10",
			fmt.Sprintf("%s@%s", macUser, macHost),
			"cd ~/macbridge-bootstrap && bash cleanup.sh --force",
		)
		sshCmd.Stdout = os.Stdout
		sshCmd.Stderr = os.Stderr
		if err := sshCmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Cleanup failed: %v\n", err)
			return
		}
		fmt.Println("✅ Mac cleaned. Ready for reclaim.")
	},
}
