package commands

import (
	"fmt"

	"github.com/spf13/cobra"
)

var sshCmd = &cobra.Command{
	Use:   "ssh",
	Short: "Open SSH connection to Mac",
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := hostRequired(); err != nil {
			return err
		}
		return runSSHCommand("", true, "-o", "ServerAliveInterval=60")
	},
}

var stopCmd = &cobra.Command{
	Use:   "stop",
	Short: "Stop a running Mac (auto-cleanup)",
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := hostRequired(); err != nil {
			return err
		}
		fmt.Printf("Stopping Mac at %s...\n", macHost)
		if err := runSSHCommand(
			"cd ~/macbridge-bootstrap && bash cleanup.sh --force",
			false,
			"-o", "ConnectTimeout=10",
		); err != nil {
			return fmt.Errorf("cleanup failed: %w", err)
		}
		fmt.Println("Mac cleaned. Ready for reclaim.")
		return nil
	},
}
