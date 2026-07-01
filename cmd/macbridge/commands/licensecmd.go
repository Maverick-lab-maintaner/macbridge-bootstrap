package commands

import (
	"fmt"

	"github.com/Maverick-lab-maintaner/macbridge-bootstrap/internal/license"
	"github.com/spf13/cobra"
)

var activateCmd = &cobra.Command{
	Use:   "activate <license-key>",
	Short: "Activate a MacBridge Studio Pro license",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		rec, err := license.Activate(args[0])
		if err != nil {
			return err
		}
		fmt.Printf("License activated: %s\n", rec.Key)
		fmt.Println("Tier: Pro — signing diagnosis, workspace, golden image, and updates unlocked.")
		return nil
	},
}

var licenseCmd = &cobra.Command{
	Use:   "license",
	Short: "Show the current license status",
	RunE: func(cmd *cobra.Command, args []string) error {
		tier, reason := license.Status()
		fmt.Printf("Tier:   %s\n", tier)
		fmt.Printf("Status: %s\n", reason)
		if tier == license.TierFree {
			fmt.Println()
			fmt.Println("Free includes: install (bootstrap), verify, readiness, basic doctor.")
			fmt.Println("Pro adds: signing diagnosis, prepared-studio workspace, golden image, updates.")
			fmt.Println("Activate with: macbridge activate MB-XXXX-XXXX-XXXX-XXXX")
		}
		return nil
	},
}

// requirePro gates a Pro feature, with a friendly upgrade path instead of a
// hard wall. Enforcement is deliberately soft (docs/STUDIO_PACKAGING.md): the
// durable value is the updates/knowledge channel, not DRM.
func requirePro(feature string) error {
	tier, reason := license.Status()
	if tier == license.TierPro {
		return nil
	}
	return fmt.Errorf("%s is a Studio Pro feature (%s). Activate with: macbridge activate <key>", feature, reason)
}
