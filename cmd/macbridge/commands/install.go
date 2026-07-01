package commands

import (
	"fmt"
	"strconv"

	"github.com/spf13/cobra"
)

var (
	installFromLayer int
	installAgents    string
)

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

		// Agent tier: the user chooses which agents to install. The flag wins;
		// otherwise ask interactively when there's a terminal (never in CI).
		agents := installAgents
		if tier == "agent" && agents == "" && stdinIsTerminal() {
			agents = pickAgents()
		}
		if agents != "" {
			if parsed, err := parseAgentSelection(agents); err != nil {
				return err
			} else {
				agents = parsed
			}
		}

		bootstrapArgs := []string{"--tier", tier}
		if agents != "" {
			bootstrapArgs = append(bootstrapArgs, "--agents", agents)
		}
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
	installCmd.Flags().StringVar(&installAgents, "agents", "", "Agents to install: claude,opencode,codex, all, or none (agent tier; interactive if omitted)")
}
