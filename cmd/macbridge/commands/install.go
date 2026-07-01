package commands

import (
	"fmt"
	"strconv"

	"github.com/spf13/cobra"
)

var installFromLayer int

// installCmd is the Studio entry point: turn the Mac this command runs on
// into a verified Flutter/iOS workspace using the embedded tooling.
var installCmd = &cobra.Command{
	Use:   "install",
	Short: "Provision this Mac into a verified iOS workspace (Studio)",
	Long: `Extracts the embedded MacBridge tooling to ~/.macbridge/tooling and runs
the layered bootstrap on this machine: verification at every layer, ending
with a real flutter build ios smoke test and a readiness verdict.

Free tier. Requires macOS with Xcode installed (the one GUI prerequisite).`,
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := requireDarwin("macbridge install"); err != nil {
			return err
		}

		bootstrapArgs := []string{"--tier", tier}
		if installFromLayer > 0 {
			bootstrapArgs = append(bootstrapArgs, "--from", strconv.Itoa(installFromLayer))
		}
		if reportTo != "" {
			bootstrapArgs = append(bootstrapArgs, "--report-to", reportTo)
		}

		fmt.Printf("MacBridge Studio %s — provisioning this Mac (tier: %s)\n\n", Version, tier)
		if err := runLocalScript("bootstrap.sh", bootstrapArgs...); err != nil {
			return fmt.Errorf("bootstrap failed — fix the failing layer, then re-run with --from N: %w", err)
		}
		return nil
	},
}

func init() {
	installCmd.Flags().IntVar(&installFromLayer, "from", 0, "Start bootstrap from layer N (resume after a fixed failure)")
}
