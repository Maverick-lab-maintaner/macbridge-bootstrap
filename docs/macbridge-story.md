# MacBridge Story

This page is the learning version of `HISTORY.md`.
The history file is the exact chronology.
This file explains why the repo changed, what broke, what got fixed, and which tools proved each step.

## The Core Idea

MacBridge is not a Mac rental business.
It is a control plane for turning a cloud Mac into a verified Flutter/iOS/agent workstation, then keeping it healthy, clean, and recoverable.

The real product is the encoded knowledge:

- how to provision safely
- how to verify every layer
- how to recover from failure
- how to keep the machine clean for the next session
- how to expose the same control plane from Windows, Go, shell, and later adjacent tools

## The Timeline

### 1. Phase 0 proved the hard truths

The project started with a real provisioning run on a cloud Mac.
That run exposed 10 non-negotiable lessons:

- Xcode needs GUI installation, not blind SSH automation
- system Ruby is too old for current CocoaPods
- PATH is part of provisioning, not a follow-up task
- root-owned directories like `~/.local` break later installs
- GitHub password auth is dead; SSH is the right path
- `flutter doctor` is not enough; actual build tests matter
- provisioning itself is the product, not the machine
- every layer must verify before the next layer starts
- the user should only see "ready" after all checks pass
- a single `bootstrap` entrypoint is better than 30 manual commands

Those lessons became the architecture instead of remaining anecdotes.

### 2. The shell control plane became the source of truth

The bootstrap flow was split into layers:

- `layer0-machine.sh` for machine reachability and ownership checks
- `layer1-apple.sh` for Apple toolchain readiness
- `layer2-dev.sh` for Homebrew, Ruby, Flutter, CocoaPods, Git, and SSH
- `layer3-agents.sh` for Claude Code, OpenCode, Codex, Node, and tmux
- `layer4-project.sh` for an actual iOS smoke test

That structure matters because it isolates failure.
If layer 2 fails, the problem is not Xcode or networking.
If layer 4 fails, the toolchain is present but the project smoke test exposed a real integration issue.

### 3. Verification became canonical

The repo treats verification as a first-class product feature:

- `bootstrap.sh` orchestrates install and resume
- `verify.sh` is read-only and can run independently
- `cleanup.sh` resets user state between sessions
- `healthd.sh` checks fleet health over time
- `hardening.sh` locks the machine down for shared-cloud use
- `welcome.sh` turns a ready machine into a usable first-login experience
- `migrate.sh` controls opt-in upgrades without forcing changes on users

This is why the repo reads like infrastructure, not a demo.
Every script exists because a failure mode was observed in practice.

### 4. The Windows side had to become real

The next problem was not "can we describe the system?"
It was "can a Windows operator actually run it?"

That is where `provision.ps1` mattered.

The Windows work uncovered a different class of problems:

- invalid PowerShell syntax in remote command construction
- quoting and interpolation issues
- shell operators like `&&` not surviving the parse path cleanly
- mixed encoding and mojibake in the file
- mismatch between the Go CLI defaults and the PowerShell defaults
- mismatch between advertised reporting and actual report propagation

The fix was to rewrite the script into a plain, explicit PowerShell bridge:

- build SSH and SCP commands with argument arrays
- keep the remote command strings simple
- persist session state in `~/.macbridge/session.json`
- standardize the default user
- thread `--report-to` through the actual remote bootstrap command

The lesson here is simple:
architecture does not count until the operator path runs.

### 5. LSP was part of runtime truth, not just editor convenience

The repo also hit a tooling failure on the Codex side:

- `mcp_servers.lsp` had an invalid transport definition
- `gopls` existed on disk but the live daemon could not resolve it
- `gopls` warnings made the code look broken when the module tests were actually fine

The fixes separated three concerns:

- Codex config transport
- daemon process PATH state
- actual Go source health

That separation prevented a false fix.
The repo did not need code changes to satisfy a toolchain artifact.
It needed explicit discovery and wiring.

### 6. The Go CLI became the small compiled control surface

Go exists here for reasons that are practical, not aesthetic:

- compiled binaries are easy to ship on Windows and macOS
- the provider seam is clearer in a typed CLI
- status and reporting surfaces are easier to test than shell text
- the tool can front the shell scripts without replacing them

Shell still does the machine work.
Go does the user-facing control plane.
That split is intentional.

### 7. Radar extended the product without contaminating the core

The outbound discovery idea became `ops/radar/`.
It started from a PACER framing doc and then moved into code.

PACER helped keep the idea honest:

- conceptual: this is a listening system, not a spam bot
- procedural: collect -> classify -> score -> draft -> approve -> post -> learn
- analogous: Agent Reach proves the access/fallback pattern, not auto-spam
- evidence: platform behavior and community norms constrain the design
- reference: exact queries, drafts, and commands belong in the operational layer

That became a three-phase workflow:

- listening-only scanning
- review queue with drafts
- local board for human approval

The implementation stayed founder-controlled:

- listen automatically
- draft automatically
- approve manually
- export only approved items

That is the safe version.

### 8. Radar now has a first live connector

The first live source is Reddit search RSS.
That matters because it proves the system is no longer just a local prototype with sample JSON.

The live edge now does three things:

- brings in public discussion from a real source
- feeds the same review queue as the manual leads
- degrades gracefully when Reddit rate-limits a query

That is the right shape for a first connector.
It is useful enough to prove the concept and constrained enough to stay safe.

## What Broke, and What It Taught

### Shell is good at orchestration

Shell scripts were the right starting point because they are close to the machine and easy to reason about in layers.
The downside is that shell is also easy to overgrow.
That is why the repo now separates shared utilities, layer scripts, and higher-level entrypoints.

### Go is good at a stable operator surface

Go is useful where the repo needs a compiled CLI, predictable behavior, and a durable provider seam.
It is not replacing the shell layers.
It is packaging and presenting them.

### Python was good for the first Radar prototype

Radar started in Python because the first problem was rapid data shaping:

- read lead items
- score them
- classify them
- export reviewable artifacts

That was the right tradeoff for discovery mode.

### PowerShell was necessary for Windows bridge work

The Windows operator path had to be native PowerShell.
That made parse safety, quoting, and argument handling part of the product.
It also made the repo honest about Windows as a first-class environment, not an afterthought.

### LSP was useful, but only after it was wired correctly

Editor tooling helped, but only once the live transport and the live server resolution were fixed.
That matters because a green-looking editor is not the same thing as a healthy runtime.

## Toolchain Used

The exact toolchain matters because each tool exposed a different kind of failure:

- shell: `bash`, `verify.sh`, `bootstrap.sh`, `cleanup.sh`, `welcome.sh`, `migrate.sh`, `healthd.sh`, `hardening.sh`
- Go: `go test ./...`, `go list ./...`, `gofmt`
- PowerShell: `provision.ps1`, parser checks, remote execution
- Python: `ops/radar/radar.py` and `python -m py_compile`
- LSP: `gopls`, `bash-language-server`, `typescript-language-server`, `biome`
- Git: status, diff, commit, push

The important point is not the list itself.
It is that no single tool gave the whole answer.
Each one surfaced a different class of problem.

## How To Read This Repo

If you are new here, read in this order:

1. `README.md` for the current project shape
2. `HISTORY.md` for the exact chronology
3. `LEAD_INTEL_PACER.md` for the market-listening idea
4. `docs/macbridge-story.md` for the learning narrative

That sequence gives you:

- the current architecture
- the exact evolution
- the adjacent growth system
- the plain-English explanation of why the repo looks the way it does

## Bottom Line

MacBridge works because it treats operational truth as product truth.

The project grew from:

- a shell bootstrap
- into a verified provisioning control plane
- into a Windows bridge
- into a health and hardening surface
- into a lead-intel and reply-assist module
- into a golden-image builder that codifies the "prepared studio" and shrinks the
  manual work to its irreducible core (install Xcode once, snapshot once)
- into a hardened Windows bring-up (a 35-minute bootstrap that survives a dropped SSH)
  and a read-only signing diagnoser that guides without ever touching the Apple account

The common rule across all of it is the same:

> if a step cannot be verified, it is not finished

And three more rules, each earned from a real twist:

> some of the product is un-codeable — so make the code shrink the manual part to
> exactly its core, and make everything around it reproducible and verifiable
> *(building the golden image)*

> read the business before writing the code, and let it tell you what not to build
> *(the Deploy A / Deploy B split, and the persistence-vs-multitenancy tension)*

> a quality gate you do not run is a gate that is already red
> *(ShellCheck was failing on master for weeks behind a path filter; a parse error
> was masking the warnings that hid behind it)*
