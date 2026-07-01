package commands

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestExtractToolingWritesTheEmbeddedTree(t *testing.T) {
	dir := t.TempDir()
	if err := extractTooling(dir); err != nil {
		t.Fatalf("extractTooling: %v", err)
	}

	// The product-critical files must exist after extraction.
	mustExist := []string{
		"bootstrap.sh",
		"verify.sh",
		"doctor.sh",
		"signing-doctor.sh",
		"readiness.sh",
		"golden-image.sh",
		"workspace-setup.sh",
		filepath.Join("lib", "_utils.sh"),
		filepath.Join("lib", "status-contract.sh"),
		filepath.Join("lib", "layer4-project.sh"),
		filepath.Join("lib", "doctor-rules.json"),
	}
	for _, rel := range mustExist {
		path := filepath.Join(dir, rel)
		info, err := os.Stat(path)
		if err != nil {
			t.Errorf("missing after extraction: %s", rel)
			continue
		}
		if info.Size() == 0 {
			t.Errorf("extracted empty: %s", rel)
		}
		// Scripts must be executable (POSIX only — Windows has no exec bit).
		if runtime.GOOS != "windows" && filepath.Ext(rel) == ".sh" && info.Mode()&0o100 == 0 {
			t.Errorf("not executable after extraction: %s", rel)
		}
	}
}

func TestEnsureToolingStampsAndSkipsReextraction(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("USERPROFILE", home)

	dir, err := ensureTooling()
	if err != nil {
		t.Fatalf("ensureTooling: %v", err)
	}

	stamp, err := os.ReadFile(filepath.Join(dir, ".version"))
	if err != nil {
		t.Fatalf("version stamp missing: %v", err)
	}
	if got := string(stamp); got != Version+"\n" {
		t.Errorf("stamp = %q, want %q", got, Version+"\n")
	}

	// A marker file must survive a second ensureTooling with the same
	// version (no needless re-extraction wiping the directory)...
	marker := filepath.Join(dir, "marker.txt")
	if err := os.WriteFile(marker, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := ensureTooling(); err != nil {
		t.Fatalf("second ensureTooling: %v", err)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Error("same-version ensureTooling re-extracted unnecessarily")
	}

	// ...and a version change must trigger re-extraction (stamp updates).
	old := Version
	Version = old + "-next"
	defer func() { Version = old }()
	if _, err := ensureTooling(); err != nil {
		t.Fatalf("ensureTooling after version bump: %v", err)
	}
	stamp, _ = os.ReadFile(filepath.Join(dir, ".version"))
	if got := string(stamp); got != Version+"\n" {
		t.Errorf("stamp after bump = %q, want %q", got, Version+"\n")
	}
}
