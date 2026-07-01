package commands

import (
	"fmt"

	"github.com/Maverick-lab-maintaner/macbridge-bootstrap/internal/providers"
	"github.com/spf13/cobra"
)

var provisionCmd = &cobra.Command{
	Use:   "provision",
	Short: "Provision a new cloud Mac",
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := hostRequired(); err != nil {
			return fmt.Errorf("%w (e.g., macbridge provision --host 203.0.113.47)", err)
		}

		plan := providers.DefaultProvider().BuildProvisionPlan(providers.ProvisionRequest{
			Host:     macHost,
			User:     macUser,
			Tier:     tier,
			KeyPath:  keyPath,
			ReportTo: reportTo,
		})

		fmt.Printf("Provisioning Mac at %s\n", macHost)
		fmt.Printf("  Tier: %s\n", tier)
		fmt.Printf("  Provider: %s\n\n", plan.ProviderName)
		fmt.Println("Phase 1 API integration is not implemented yet.")
		fmt.Printf("  %s\n", plan.CopyCommand)
		fmt.Printf("  %s\n", plan.BootstrapCommand)
		for _, note := range plan.Notes {
			fmt.Printf("  Note: %s\n", note)
		}
		return nil
	},
}
