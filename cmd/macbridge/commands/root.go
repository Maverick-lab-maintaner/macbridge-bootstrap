package commands

import "github.com/spf13/cobra"

var (
	macHost  string
	macUser  string
	keyPath  string
	tier     string
	reportTo string
)

var RootCmd = &cobra.Command{
	Use:   "macbridge",
	Short: "MacBridge - The continuously verified iOS development workspace",
	Long: `MacBridge Studio turns a Mac you provide — cloud or one you own — into a
verified Flutter/iOS workspace: layered bootstrap, health verification,
doctor remediation, signing diagnosis, and an agent-ready environment.

Run it on the Mac itself (Studio), or drive a remote Mac with --host.`,
	// main.go prints the error once; don't also dump usage on runtime errors.
	SilenceUsage:  true,
	SilenceErrors: true,
}

func init() {
	RootCmd.Version = Version

	RootCmd.AddCommand(installCmd)
	RootCmd.AddCommand(activateCmd)
	RootCmd.AddCommand(licenseCmd)
	RootCmd.AddCommand(provisionCmd)
	RootCmd.AddCommand(statusCmd)
	RootCmd.AddCommand(doctorCmd)
	RootCmd.AddCommand(sshCmd)
	RootCmd.AddCommand(stopCmd)

	RootCmd.PersistentFlags().StringVar(&macHost, "host", "", "Mac hostname or IP")
	RootCmd.PersistentFlags().StringVar(&macUser, "user", "admin", "SSH username")
	RootCmd.PersistentFlags().StringVar(&keyPath, "key", "", "SSH private key path")
	RootCmd.PersistentFlags().StringVar(&tier, "tier", "agent", "Provisioning tier (vanilla|agent)")
	RootCmd.PersistentFlags().StringVar(&reportTo, "report-to", "", "Centralized log shipping URL")
}
