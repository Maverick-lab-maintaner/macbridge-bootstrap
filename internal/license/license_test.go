package license

import (
	"strings"
	"testing"
)

func TestGenerateProducesValidKeys(t *testing.T) {
	for i := 0; i < 50; i++ {
		key, err := Generate()
		if err != nil {
			t.Fatalf("Generate() error: %v", err)
		}
		if err := Validate(key); err != nil {
			t.Errorf("Generate() produced invalid key %q: %v", key, err)
		}
		if !strings.HasPrefix(key, "MB-") || len(key) != len("MB-XXXX-XXXX-XXXX-XXXX") {
			t.Errorf("Generate() produced malformed key %q", key)
		}
	}
}

func TestValidateRejectsBadKeys(t *testing.T) {
	good, err := Generate()
	if err != nil {
		t.Fatal(err)
	}

	// Tamper with one payload character (swap to a different alphabet char).
	tampered := []byte(good)
	if tampered[3] == 'A' {
		tampered[3] = 'B'
	} else {
		tampered[3] = 'A'
	}

	cases := map[string]string{
		"empty":              "",
		"wrong prefix":       "XX-AAAA-BBBB-CCCC-DDDD",
		"too few groups":     "MB-AAAA-BBBB-CCCC",
		"bad character":      "MB-AAA0-BBBB-CCCC-DDDD", // 0 not in alphabet
		"short group":        "MB-AAA-BBBB-CCCC-DDDD",
		"tampered checksum":  good[:len(good)-1] + flip(good[len(good)-1]),
		"tampered payload":   string(tampered),
		"random but shaped":  "MB-AAAA-BBBB-CCCC-DDDD",
	}

	for name, key := range cases {
		if err := Validate(key); err == nil {
			t.Errorf("%s: Validate(%q) accepted an invalid key", name, key)
		}
	}
}

// flip returns a different valid-alphabet character.
func flip(c byte) string {
	if c == 'A' {
		return "B"
	}
	return "A"
}

func TestValidateNormalizes(t *testing.T) {
	key, err := Generate()
	if err != nil {
		t.Fatal(err)
	}
	lower := "  " + strings.ToLower(key) + "  "
	if err := Validate(lower); err != nil {
		t.Errorf("Validate should normalize case/whitespace, got: %v", err)
	}
}

func TestActivateAndStatus(t *testing.T) {
	// Redirect the record into a temp HOME so the test never touches the
	// real ~/.macbridge.
	t.Setenv("HOME", t.TempDir())
	t.Setenv("USERPROFILE", t.TempDir()) // Windows

	tier, _ := Status()
	if tier != TierFree {
		t.Fatalf("expected Free before activation, got %s", tier)
	}

	key, err := Generate()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := Activate(key); err != nil {
		t.Fatalf("Activate(%q) error: %v", key, err)
	}

	tier, reason := Status()
	if tier != TierPro {
		t.Fatalf("expected Pro after activation, got %s (%s)", tier, reason)
	}

	if _, err := Activate("MB-AAAA-BBBB-CCCC-DDDD"); err == nil {
		t.Error("Activate accepted a key with a bad checksum")
	}
}
