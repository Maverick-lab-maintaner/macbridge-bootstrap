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
	Short: "Check Mac environment health",
	Long:  `Checks the health of a provisioned Mac by running verify.sh remotely.`,
	Run: func(cmd *cobra.Command, args []string) {
		if macHost == "" {
			fmt.Println("Error: --host is required")
			return
		}

		fmt.Printf("Checking Mac at %s...\n", macHost)
		sshCmd := exec.Command("ssh",
			"-o", "StrictHostKeyChecking=accept-new",
			"-o", "ConnectTimeout=10",
			fmt.Sprintf("%s@%s", macUser, macHost),
			"cd ~/macbridge-bootstrap && bash verify.sh --quick",
		)
		sshCmd.Stdout = os.Stdout
		sshCmd.Stderr = os.Stderr
		if err := sshCmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Health check failed: %v\n", err)
		}
	},
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
