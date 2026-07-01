package commands

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	tooling "github.com/Maverick-lab-maintaner/macbridge-bootstrap"
)

// Version is stamped by the release workflow via
// -ldflags "-X .../commands.Version=v1.2.3". Dev builds show the default.
var Version = "0.1.0-dev"

// toolingDir returns ~/.macbridge/tooling, where the embedded scripts are
// extracted so the binary is self-contained (Studio: no git clone required).
func toolingDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolving home directory: %w", err)
	}
	return filepath.Join(home, ".macbridge", "tooling"), nil
}

// ensureTooling extracts the embedded tooling if it is missing or was
// extracted by a different CLI version (a .version stamp tracks this).
// It returns the extraction directory.
func ensureTooling() (string, error) {
	dir, err := toolingDir()
	if err != nil {
		return "", err
	}

	stampPath := filepath.Join(dir, ".version")
	if stamp, err := os.ReadFile(stampPath); err == nil && strings.TrimSpace(string(stamp)) == Version {
		return dir, nil
	}

	if err := extractTooling(dir); err != nil {
		return "", err
	}
	if err := os.WriteFile(stampPath, []byte(Version+"\n"), 0o644); err != nil {
		return "", fmt.Errorf("writing version stamp: %w", err)
	}
	return dir, nil
}

// extractTooling writes the embedded script tree into dir, marking shell
// scripts executable.
func extractTooling(dir string) error {
	return fs.WalkDir(tooling.Scripts, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		target := filepath.Join(dir, path)
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}

		data, err := tooling.Scripts.ReadFile(path)
		if err != nil {
			return fmt.Errorf("reading embedded %s: %w", path, err)
		}

		mode := os.FileMode(0o644)
		if strings.HasSuffix(path, ".sh") {
			mode = 0o755
		}
		if err := os.WriteFile(target, data, mode); err != nil {
			return fmt.Errorf("extracting %s: %w", path, err)
		}
		return nil
	})
}

// requireDarwin guards local execution: the tooling targets macOS. From
// Windows/Linux, drive a remote Mac with --host instead.
// MACBRIDGE_ALLOW_NON_DARWIN=1 is an undocumented escape hatch for tests.
func requireDarwin(action string) error {
	if runtime.GOOS == "darwin" || os.Getenv("MACBRIDGE_ALLOW_NON_DARWIN") == "1" {
		return nil
	}
	return fmt.Errorf("%s runs on macOS (this is %s). From another OS, target a Mac with --host", action, runtime.GOOS)
}

// runLocalScript extracts the tooling if needed and executes one of the
// embedded scripts on this machine, streaming output.
func runLocalScript(script string, args ...string) error {
	dir, err := ensureTooling()
	if err != nil {
		return err
	}

	cmdArgs := append([]string{filepath.Join(dir, script)}, args...)
	cmd := exec.Command("bash", cmdArgs...)
	cmd.Dir = dir
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// runLocalScriptOutput is runLocalScript but captures stdout (for JSON
// contracts). A non-zero exit with output is not an error here: verify.sh
// exits 1 on a degraded machine while still emitting a valid contract.
func runLocalScriptOutput(script string, args ...string) ([]byte, error) {
	dir, err := ensureTooling()
	if err != nil {
		return nil, err
	}

	cmdArgs := append([]string{filepath.Join(dir, script)}, args...)
	cmd := exec.Command("bash", cmdArgs...)
	cmd.Dir = dir
	out, err := cmd.Output()
	if len(out) > 0 {
		return out, nil
	}
	return out, err
}
