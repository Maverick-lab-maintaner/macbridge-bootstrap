package commands

import "testing"

func TestBuildDoctorCommand(t *testing.T) {
	tests := []struct {
		name    string
		signing bool
		project string
		json    bool
		want    string
	}{
		{
			name: "default environment doctor",
			want: "cd ~/macbridge-bootstrap && bash doctor.sh --quick",
		},
		{
			name: "environment doctor json",
			json: true,
			want: "cd ~/macbridge-bootstrap && bash doctor.sh --quick --json",
		},
		{
			name:    "signing doctor",
			signing: true,
			want:    "cd ~/macbridge-bootstrap && bash signing-doctor.sh",
		},
		{
			name:    "signing doctor with project",
			signing: true,
			project: "~/myapp",
			want:    "cd ~/macbridge-bootstrap && bash signing-doctor.sh --project '~/myapp'",
		},
		{
			name:    "signing doctor json",
			signing: true,
			json:    true,
			want:    "cd ~/macbridge-bootstrap && bash signing-doctor.sh --json",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			doctorSigning, doctorProject, doctorJSON = tt.signing, tt.project, tt.json
			defer func() { doctorSigning, doctorProject, doctorJSON = false, "", false }()

			if got := buildDoctorCommand(); got != tt.want {
				t.Errorf("buildDoctorCommand() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestShellQuote(t *testing.T) {
	tests := map[string]string{
		"plain":            "'plain'",
		"with space":       "'with space'",
		"it's":             `'it'\''s'`,
	}
	for in, want := range tests {
		if got := shellQuote(in); got != want {
			t.Errorf("shellQuote(%q) = %q, want %q", in, got, want)
		}
	}
}
