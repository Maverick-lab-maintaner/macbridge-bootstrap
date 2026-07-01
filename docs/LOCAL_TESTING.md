# Testing MacBridge Without Renting a Mac

> How to validate the product before spending a cent on cloud Macs — using WSL/Windows for
> the portable logic and **GitHub Actions macOS runners** for the real Mac path.

**The headline:** you do **not** need a macOS VM. GitHub Actions gives you **free, license-clean,
real Apple hardware** on demand — better than a VM on every axis. Use it.

---

## Three test surfaces

### 1. WSL / Linux / Git Bash (Windows) — the portable logic

A lot of MacBridge is platform-portable and can be exercised on WSL/Linux/Git Bash today (much
of it already was during development):

| What you can test here | How |
|------------------------|-----|
| Status-contract JSON shape | feed a mock contract to `readiness.sh --json FILE` |
| Readiness screen rendering | `bash readiness.sh --json mock-ready.json` (ready) / a degraded mock |
| Doctor remediation mapping | `bash doctor.sh --json` logic (needs a verify JSON) |
| Signing-doctor logic | mock a `security` binary on `PATH` + a fake `project.pbxproj`, run `signing-doctor.sh --project` |
| golden-image drift logic | `golden-image.sh manifest` + `golden-image.sh verify --manifest saved.json` |
| Radar (Python) | `cd ops/radar && python -m pytest` |
| Go CLI | `go build ./... && go vet ./... && go test ./...` |
| Every script parses | `bash -n *.sh lib/*.sh` |

**What you cannot test here:** anything that calls a macOS-only tool — `sw_vers`, `xcodebuild`,
`xcrun`, `security`, `launchctl`, `pod`, `brew`. So `bootstrap.sh` / `verify.sh` won't *pass* on
WSL, but their **logic** (arg parsing, contract emission, control flow) does run. WSL is for
"does the logic hold," not "does the Mac path work."

> Note on WSL specifically: run the shell tests inside WSL's bash, and the **Windows** side
> (`provision.ps1`) in PowerShell on the host — WSL is Linux, so it validates the shell scripts,
> not the PowerShell bridge. Validate `provision.ps1` with the PowerShell AST parser (see below).

```powershell
# provision.ps1 parse check (Windows PowerShell) — no Mac needed
$e=$null;$t=$null
[System.Management.Automation.Language.Parser]::ParseFile("provision.ps1",[ref]$t,[ref]$e)|Out-Null
if($e){$e|%{$_.Message}}else{"provision.ps1 parses OK"}
```

### 2. GitHub Actions macOS runners — the real Mac path, free and legal

This is the one that matters. A `macos-latest` runner is **real Apple hardware** with **Xcode,
Homebrew, Ruby, and CocoaPods preinstalled**, and it is **free for public repos** and included
minutes for private ones. It is fully Apple-license-clean (Apple's own CI infrastructure runs on
Apple hardware).

The repo ships a workflow for exactly this: **`.github/workflows/macos-smoke.yml`** (manual —
`workflow_dispatch`). It runs `verify.sh`, `doctor.sh`, `signing-doctor.sh`, `readiness.sh`, and
`golden-image.sh manifest` on real macOS and asserts each emits a valid status contract. Trigger
it from the Actions tab ("Run workflow"), and read the state each tool reports — all without
renting anything.

To also exercise `bootstrap.sh` end-to-end on macOS for free, extend that workflow to install
Flutter (`brew install --cask flutter`) and run `bash bootstrap.sh --from 2 --tier vanilla` on
the runner. That is the closest thing to a rented Mac, at $0.

### 3. macOS VM — read the license first

| Where you run the VM | Allowed? | Verdict |
|----------------------|:---:|---------|
| **On Apple hardware you own** (an old Mac, Mac mini) | ✅ Yes — SLA §2B(iii) permits **2 VMs** for software development/testing on Apple hardware you own | Fine for local testing |
| **On Windows / non-Apple hardware** (QEMU/OSX-KVM, VMware unlocker) | ❌ **No** — SLA §2B: macOS may run only on **Apple-branded hardware** | Technically possible, **license-violating**; don't use it |

So: if you have *any* Mac, a local VM is a legitimate test bed. On Windows, **don't** spin up a
hackintosh VM — use the **GitHub Actions macOS runner** instead. It's free, legal, real hardware,
and reproducible.

---

## Recommended pre-spend test plan

1. **On Windows now:** `bash -n` all scripts; run the Radar pytest and the Go tests; parse-check
   `provision.ps1`; render the readiness screen from mock contracts. (All doable today, no Mac.)
2. **In CI now:** run `macos-smoke.yml` (`workflow_dispatch`) — prove the whole tooling suite runs
   on real macOS and emits valid contracts.
3. **Before renting:** extend `macos-smoke.yml` to install Flutter and run a `bootstrap --from 2`
   smoke — this validates the actual provisioning path on Apple hardware for free.
4. **Only then**, when you want a *persistent, interactive* Mac (DeskIn, real-device signing,
   TestFlight upload), rent one — by that point everything script-level is already proven.

The point: **almost everything can be validated for $0.** You should only pay for a cloud Mac
once you need the interactive/GUI/real-device parts that CI can't give you.
