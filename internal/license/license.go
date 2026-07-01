// Package license implements the Studio P0 entitlement gate: offline-checkable
// license keys with a local activation record and a grace window.
//
// Enforcement is deliberately soft (see docs/STUDIO_PACKAGING.md): the key
// format is verifiable offline via a checksum group, activation is recorded
// locally, and the real recurring value lives in the updates/knowledge channel
// (P1), which is where server-side entitlement checks will attach.
package license

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"hash/fnv"
	"math/big"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Key format: MB-XXXX-XXXX-XXXX-CCCC
// Three payload groups plus a checksum group derived from the payload, using
// an alphabet without ambiguous characters (no I, L, O, U, 0, 1).
const alphabet = "ABCDEFGHJKMNPQRSTVWXYZ23456789"

const (
	groupLen  = 4
	numGroups = 3 // payload groups, excluding the checksum group
	prefix    = "MB"
)

// GraceDays is how long an activation stays trusted without re-verification.
// P0 validation is fully offline, so this only becomes load-bearing when the
// P1 updates channel starts refreshing LastVerified on successful sync.
const GraceDays = 30

// Record is the local activation state stored in ~/.macbridge/license.json.
type Record struct {
	Key          string    `json:"key"`
	ActivatedAt  time.Time `json:"activated_at"`
	LastVerified time.Time `json:"last_verified"`
}

// checksum derives the 4-char checksum group from the payload portion
// ("MB-XXXX-XXXX-XXXX") using FNV-1a.
func checksum(payload string) string {
	h := fnv.New32a()
	h.Write([]byte(payload))
	sum := h.Sum32()

	out := make([]byte, groupLen)
	for i := range out {
		out[i] = alphabet[sum%uint32(len(alphabet))]
		sum /= uint32(len(alphabet))
	}
	return string(out)
}

// Generate creates a new valid license key from crypto/rand. It lives in this
// package for testability; the release binary must not expose a generator
// command (cmd/mbkeygen is a local-only tool, excluded from release builds).
func Generate() (string, error) {
	groups := make([]string, 0, numGroups+1)
	for g := 0; g < numGroups; g++ {
		chars := make([]byte, groupLen)
		for i := range chars {
			n, err := rand.Int(rand.Reader, big.NewInt(int64(len(alphabet))))
			if err != nil {
				return "", fmt.Errorf("generating key: %w", err)
			}
			chars[i] = alphabet[n.Int64()]
		}
		groups = append(groups, string(chars))
	}

	payload := prefix + "-" + strings.Join(groups, "-")
	return payload + "-" + checksum(payload), nil
}

// Normalize uppercases and trims a user-supplied key.
func Normalize(key string) string {
	return strings.ToUpper(strings.TrimSpace(key))
}

// Validate reports whether a key is well-formed and its checksum group
// matches. This is an offline structural check, not a server entitlement
// check (that is P1, attached to the updates channel).
func Validate(key string) error {
	key = Normalize(key)

	parts := strings.Split(key, "-")
	if len(parts) != numGroups+2 { // prefix + payload groups + checksum
		return fmt.Errorf("license key must look like %s-XXXX-XXXX-XXXX-XXXX", prefix)
	}
	if parts[0] != prefix {
		return fmt.Errorf("license key must start with %s-", prefix)
	}
	for _, group := range parts[1:] {
		if len(group) != groupLen {
			return fmt.Errorf("each key group must be %d characters", groupLen)
		}
		for _, c := range group {
			if !strings.ContainsRune(alphabet, c) {
				return fmt.Errorf("invalid character %q in license key", c)
			}
		}
	}

	payload := strings.Join(parts[:numGroups+1], "-")
	if checksum(payload) != parts[numGroups+1] {
		return fmt.Errorf("license key checksum does not match — check for typos")
	}
	return nil
}

// recordPath returns ~/.macbridge/license.json (same directory the Windows
// bridge uses for session.json).
func recordPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolving home directory: %w", err)
	}
	return filepath.Join(home, ".macbridge", "license.json"), nil
}

// Activate validates a key and writes the local activation record.
func Activate(key string) (*Record, error) {
	key = Normalize(key)
	if err := Validate(key); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	rec := &Record{Key: key, ActivatedAt: now, LastVerified: now}

	path, err := recordPath()
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, fmt.Errorf("creating %s: %w", filepath.Dir(path), err)
	}

	data, err := json.MarshalIndent(rec, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := os.WriteFile(path, data, 0o600); err != nil {
		return nil, fmt.Errorf("writing license record: %w", err)
	}
	return rec, nil
}

// Load returns the stored activation record, or nil if none exists.
func Load() (*Record, error) {
	path, err := recordPath()
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var rec Record
	if err := json.Unmarshal(data, &rec); err != nil {
		return nil, fmt.Errorf("license record is corrupt (%s): %w", path, err)
	}
	return &rec, nil
}

// Tier is the entitlement level the CLI gates on.
type Tier string

const (
	// TierFree covers bootstrap, verify, readiness, and the basic doctor.
	TierFree Tier = "free"
	// TierPro adds signing diagnosis, workspace, golden image, and updates.
	TierPro Tier = "pro"
)

// Status resolves the current entitlement: Pro when a structurally valid,
// unexpired-grace activation record exists; Free otherwise. The reason string
// is human-readable context for `macbridge license`.
func Status() (Tier, string) {
	rec, err := Load()
	if err != nil {
		return TierFree, fmt.Sprintf("license record unreadable (%v) — running as Free", err)
	}
	if rec == nil {
		return TierFree, "no license activated — running as Free"
	}
	if err := Validate(rec.Key); err != nil {
		return TierFree, "stored license key is invalid — running as Free"
	}
	if time.Since(rec.LastVerified) > GraceDays*24*time.Hour {
		return TierFree, fmt.Sprintf("license grace period (%d days) expired — run `macbridge activate` again", GraceDays)
	}
	return TierPro, fmt.Sprintf("Pro — activated %s", rec.ActivatedAt.Format("2006-01-02"))
}
