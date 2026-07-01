package main

import (
	"fmt"
	"os"

	"github.com/Maverick-lab-maintaner/macbridge-bootstrap/cmd/macbridge/commands"
)

func main() {
	if err := commands.RootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "macbridge: %v\n", err)
		os.Exit(1)
	}
}
