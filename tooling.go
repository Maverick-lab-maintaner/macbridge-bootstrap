// Package tooling embeds the MacBridge shell tooling into the Go binary so
// the macbridge CLI is a self-contained install target (Studio P0): a single
// binary that carries bootstrap, verify, doctor, signing, readiness, and the
// doctor-rules knowledge base, and extracts them on the customer's Mac.
package tooling

import "embed"

// Scripts is the embedded tooling tree: every top-level script plus lib/.
//
//go:embed *.sh lib/*.sh lib/doctor-rules.json
var Scripts embed.FS
