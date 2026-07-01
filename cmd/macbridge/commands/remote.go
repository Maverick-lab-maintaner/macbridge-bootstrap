package commands

import (
	"fmt"
	"os"
	"os/exec"
)

func hostRequired() error {
	if macHost == "" {
		return fmt.Errorf("--host is required")
	}
	return nil
}

func sshArgs(extraArgs ...string) []string {
	args := []string{"-o", "StrictHostKeyChecking=accept-new"}
	if keyPath != "" {
		args = append(args, "-i", keyPath)
	}
	args = append(args, extraArgs...)
	args = append(args, fmt.Sprintf("%s@%s", macUser, macHost))
	return args
}

func newSSHCommand(remoteCommand string, extraArgs ...string) *exec.Cmd {
	args := sshArgs(extraArgs...)
	if remoteCommand != "" {
		args = append(args, remoteCommand)
	}
	return exec.Command("ssh", args...)
}

func runSSHCommand(remoteCommand string, interactive bool, extraArgs ...string) error {
	cmd := newSSHCommand(remoteCommand, extraArgs...)
	if interactive {
		cmd.Stdin = os.Stdin
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runSSHOutput(remoteCommand string, extraArgs ...string) ([]byte, error) {
	return newSSHCommand(remoteCommand, extraArgs...).Output()
}
