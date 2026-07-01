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
	Short: "MacBridge - Provision and manage cloud Mac development environments",
	Long: `MacBridge gives Flutter developers a production-ready iOS build
environment in 60 seconds. Provision a cloud Mac, run bootstrap,
and start building without buying a Mac.`,
}

func init() {
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
