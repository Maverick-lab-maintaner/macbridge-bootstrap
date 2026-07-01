package providers

import "fmt"

type ProvisionRequest struct {
	Host     string
	User     string
	Tier     string
	KeyPath  string
	ReportTo string
}

type ProvisionPlan struct {
	ProviderName     string
	CopyCommand      string
	BootstrapCommand string
	Notes            []string
}

type Provider interface {
	Name() string
	BuildProvisionPlan(req ProvisionRequest) ProvisionPlan
}

type ManualProvider struct{}

func DefaultProvider() Provider {
	return ManualProvider{}
}

func (ManualProvider) Name() string {
	return "manual"
}

func (ManualProvider) BuildProvisionPlan(req ProvisionRequest) ProvisionPlan {
	sshProgram := "ssh"
	scpProgram := "scp"
	if req.KeyPath != "" {
		sshProgram = fmt.Sprintf("ssh -i %s", req.KeyPath)
		scpProgram = fmt.Sprintf("scp -i %s", req.KeyPath)
	}

	remoteBootstrap := fmt.Sprintf("cd ~/macbridge-bootstrap; bash bootstrap.sh --tier %s", req.Tier)
	if req.ReportTo != "" {
		remoteBootstrap = fmt.Sprintf("%s --report-to \"%s\"", remoteBootstrap, req.ReportTo)
	}
	bootstrapCommand := fmt.Sprintf("%s %s@%s '%s'", sshProgram, req.User, req.Host, remoteBootstrap)

	return ProvisionPlan{
		ProviderName:     "manual",
		CopyCommand:      fmt.Sprintf("%s -r . %s@%s:~/macbridge-bootstrap", scpProgram, req.User, req.Host),
		BootstrapCommand: bootstrapCommand,
		Notes: []string{
			"API-driven providers are not implemented yet.",
			"This seam exists so Macly, VPSMac, or a custom allocator can be added without rewriting the CLI surface.",
		},
	}
}
