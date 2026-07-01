// mbkeygen generates MacBridge Studio Pro license keys.
//
// VENDOR-ONLY TOOL: build and run locally (`go run ./cmd/mbkeygen [count]`).
// The release workflow builds ONLY ./cmd/macbridge — this generator must
// never ship in release artifacts, or keys become worthless.
package main

import (
	"fmt"
	"os"
	"strconv"

	"github.com/Maverick-lab-maintaner/macbridge-bootstrap/internal/license"
)

func main() {
	count := 1
	if len(os.Args) > 1 {
		n, err := strconv.Atoi(os.Args[1])
		if err != nil || n < 1 || n > 1000 {
			fmt.Fprintln(os.Stderr, "usage: mbkeygen [count 1-1000]")
			os.Exit(1)
		}
		count = n
	}

	for i := 0; i < count; i++ {
		key, err := license.Generate()
		if err != nil {
			fmt.Fprintf(os.Stderr, "mbkeygen: %v\n", err)
			os.Exit(1)
		}
		fmt.Println(key)
	}
}
