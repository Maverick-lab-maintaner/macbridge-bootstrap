<#
.SYNOPSIS
    MacBridge Windows provisioning tool.
.DESCRIPTION
    Stages the macbridge-bootstrap scripts (excluding .git, logs, and build
    artifacts), copies them to a cloud Mac via SCP, launches bootstrap.sh
    remotely as a detached process so a dropped SSH connection does not abort
    provisioning, streams output to the Windows terminal, and saves session
    info for reconnection.
.PARAMETER MacHost
    The cloud Mac IP address or hostname.
.PARAMETER User
    SSH username. Defaults to admin.
.PARAMETER KeyPath
    Path to the SSH private key.
.PARAMETER BootstrapDir
    Local path to the macbridge-bootstrap directory.
.PARAMETER RemoteDir
    Destination directory on the Mac.
.PARAMETER Tier
    Provisioning tier. Defaults to agent.
.PARAMETER ReportTo
    Optional webhook URL for centralized log shipping.
.PARAMETER FromLayer
    Start bootstrap from this layer (passed through as bootstrap.sh --from N).
.PARAMETER Resume
    Re-attach to a bootstrap that is already running on the Mac (skips staging,
    copy, and launch; just streams the live log and reads the result).
.PARAMETER Welcome
    Run welcome.sh after bootstrap completes.
.PARAMETER Hardening
    Run hardening.sh after bootstrap completes.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$MacHost,

    [string]$User = "admin",

    [string]$KeyPath = "$HOME\.ssh\id_ed25519",

    [string]$BootstrapDir = (Get-Location).Path,

    [string]$RemoteDir = "~/macbridge-bootstrap",

    [string]$Tier = "agent",

    [string]$ReportTo = "",

    [int]$FromLayer = 0,

    [switch]$Resume,

    [switch]$Welcome,

    [switch]$Hardening
)

$ErrorActionPreference = "Stop"

function Fail-Step {
    param(
        [string]$Message,
        [int]$Code = 1
    )

    Write-Host $Message -ForegroundColor Red
    exit $Code
}

function Run-Ssh {
    param(
        [string[]]$ExtraArgs = @(),
        [string]$Command
    )

    $args = @() + $script:sshOpts + $ExtraArgs + @("${User}@${MacHost}", $Command)
    & ssh @args 2>&1
    return $LASTEXITCODE
}

function Run-Scp {
    param(
        [string]$Source,
        [string]$Destination
    )

    $args = @() + $script:scpOpts + @($Source, $Destination)
    & scp @args 2>&1
    return $LASTEXITCODE
}

# W3 — Preflight: the Windows OpenSSH client must be present.
foreach ($tool in @("ssh", "scp")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Fail-Step "Required tool '$tool' not found on PATH. Install the Windows OpenSSH Client (Settings > System > Optional Features > OpenSSH Client)."
    }
}

# Guard against a destructive RemoteDir before any remote rm -rf.
if ($RemoteDir -notmatch "/") {
    Fail-Step "RemoteDir must be a directory path (got '$RemoteDir'). Refusing to continue."
}

if (-not (Test-Path -LiteralPath $KeyPath)) {
    Fail-Step "SSH key not found: $KeyPath"
}

if (-not $Resume) {
    if (-not (Test-Path -LiteralPath (Join-Path $BootstrapDir "bootstrap.sh"))) {
        Fail-Step "bootstrap.sh not found in $BootstrapDir"
    }
}

Clear-Host
Write-Host ""
Write-Host "MacBridge Provision" -ForegroundColor Cyan
Write-Host "Windows to Cloud Mac" -ForegroundColor Cyan
Write-Host ""
Write-Host ("  Mac:    {0}" -f $MacHost) -ForegroundColor Cyan
Write-Host ("  User:   {0}" -f $User) -ForegroundColor Cyan
Write-Host ("  Tier:   {0}" -f $Tier) -ForegroundColor Cyan
if ($FromLayer -gt 0) {
    Write-Host ("  From:   layer {0}" -f $FromLayer) -ForegroundColor Cyan
}
if ($Resume) {
    Write-Host "  Mode:   resume (re-attaching to running bootstrap)" -ForegroundColor Cyan
}
if ($ReportTo) {
    Write-Host ("  Report: {0}" -f $ReportTo) -ForegroundColor Cyan
}
Write-Host ""

$sshOpts = @(
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ServerAliveInterval=60",
    "-o", "ConnectTimeout=10"
)

$scpOpts = @(
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ConnectTimeout=10",
    "-r"
)

Write-Host "-> Testing SSH connection..." -ForegroundColor Cyan
$testOutput = Run-Ssh -Command "echo CONNECTED"
if ($LASTEXITCODE -ne 0 -or ($testOutput -notmatch "CONNECTED")) {
    Fail-Step ("SSH connection failed: {0}" -f ($testOutput | Out-String).Trim())
}
Write-Host "  OK SSH connection established" -ForegroundColor Green
Write-Host ""

if (-not $Resume) {
    # W1 — Stage only what the Mac needs: top-level *.sh + lib/. This excludes
    # .git/, logs/, macbridge.exe (a Windows binary), and every other artifact.
    Write-Host "-> Staging bootstrap scripts (excluding .git, logs, binaries)..." -ForegroundColor Cyan
    $staging = Join-Path $env:TEMP ("macbridge-stage-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    try {
        Copy-Item -Path (Join-Path $BootstrapDir "*.sh") -Destination $staging -Force
        $libSrc = Join-Path $BootstrapDir "lib"
        if (Test-Path -LiteralPath $libSrc) {
            Copy-Item -Path $libSrc -Destination $staging -Recurse -Force
        }

        Write-Host "-> Copying staged scripts to Mac..." -ForegroundColor Cyan
        Run-Ssh -Command "rm -rf $RemoteDir" | Out-Null
        $scpTarget = "{0}@{1}:{2}" -f $User, $MacHost, $RemoteDir
        $scpOutput = Run-Scp -Source $staging -Destination $scpTarget
        if ($LASTEXITCODE -ne 0) {
            Fail-Step ("SCP failed: {0}" -f ($scpOutput | Out-String).Trim())
        }
        Write-Host ("  OK Scripts copied to {0}" -f $RemoteDir) -ForegroundColor Green
        Write-Host ""
    }
    finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }

    # W2 — Launch bootstrap detached so a dropped SSH does not abort it. The
    # remote process writes a live log and, on exit, its return code to a file.
    $fromArg = ""
    if ($FromLayer -gt 0) { $fromArg = "--from $FromLayer" }
    $reportArg = ""
    if ($ReportTo) { $reportArg = "--report-to '$ReportTo'" }

    Write-Host "-> Launching bootstrap on Mac (detached, survives disconnects)..." -ForegroundColor Cyan
    $launchCmd = "cd $RemoteDir && rm -f bootstrap.rc bootstrap-live.log && nohup sh -c 'bash bootstrap.sh --tier $Tier $fromArg $reportArg > bootstrap-live.log 2>&1; echo `$? > bootstrap.rc' >/dev/null 2>&1 & echo LAUNCHED"
    $launchOut = Run-Ssh -Command $launchCmd
    if ($launchOut -notmatch "LAUNCHED") {
        Fail-Step ("Failed to launch bootstrap: {0}" -f ($launchOut | Out-String).Trim())
    }
    Write-Host "  OK Bootstrap launched" -ForegroundColor Green
    Write-Host ""
}

Write-Host "-> Streaming bootstrap output..." -ForegroundColor Cyan
Write-Host "  This may take about 35 minutes. If your connection drops, re-run with -Resume." -ForegroundColor Yellow
Write-Host ""

# Stream the live log until the return-code file appears, then stop tailing.
$streamCmd = "cd $RemoteDir && ( tail -n +1 -F bootstrap-live.log & TP=`$!; while [ ! -f bootstrap.rc ]; do sleep 2; done; sleep 1; kill `$TP 2>/dev/null )"
& ssh @script:sshOpts "${User}@${MacHost}" $streamCmd 2>&1

# Read the real bootstrap exit code from the Mac.
$rcRaw = & ssh @script:sshOpts "${User}@${MacHost}" "cat $RemoteDir/bootstrap.rc 2>/dev/null"
$bootstrapExit = 1
if ("$rcRaw".Trim() -match "(\d+)") { $bootstrapExit = [int]$Matches[1] }

if ($bootstrapExit -ne 0) {
    Fail-Step ("Bootstrap failed (exit code: {0}). Fix the failing layer, then re-run with -FromLayer N." -f $bootstrapExit) $bootstrapExit
}
Write-Host ""
Write-Host "OK Bootstrap completed successfully" -ForegroundColor Green

if ($Hardening) {
    Write-Host ""
    Write-Host "-> Running firewall hardening..." -ForegroundColor Cyan
    $hardenExit = Run-Ssh -Command "cd $RemoteDir; bash hardening.sh"
    if ($hardenExit -eq 0) {
        Write-Host "  OK Firewall hardening completed" -ForegroundColor Green
    } else {
        Write-Host "  WARN Hardening reported issues. Check the output above." -ForegroundColor Yellow
    }
}

if ($Welcome) {
    Write-Host ""
    Write-Host "-> Running Welcome Wizard..." -ForegroundColor Cyan
    Write-Host "  Interactive: you will be prompted for API keys." -ForegroundColor Yellow
    Write-Host ""

    $welcomeExit = Run-Ssh -ExtraArgs @("-t") -Command "cd $RemoteDir; bash welcome.sh"
    if ($welcomeExit -ne 0) {
        Fail-Step ("Welcome Wizard failed (exit code: {0})" -f $welcomeExit) $welcomeExit
    }
}

$sessionDir = Join-Path $HOME ".macbridge"
$sessionFile = Join-Path $sessionDir "session.json"
New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null

$session = @{
    host = $MacHost
    user = $User
    keyPath = $KeyPath
    remoteDir = $RemoteDir
    tier = $Tier
    provisionedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    reportTo = $ReportTo
} | ConvertTo-Json

# W4 — UTF-8 so any downstream JSON reader can parse it (PS 5.1 defaults to UTF-16).
Set-Content -LiteralPath $sessionFile -Value $session -Encoding utf8

Write-Host ""
Write-Host "Provisioning complete" -ForegroundColor Green
Write-Host ("  SSH:     ssh -i {0} {1}@{2}" -f $KeyPath, $User, $MacHost) -ForegroundColor Cyan
Write-Host ("  Session: {0}" -f $sessionFile) -ForegroundColor Cyan

if (-not $Welcome) {
    Write-Host ""
    Write-Host "  Next on the Mac:" -ForegroundColor Cyan
    Write-Host ("    cd {0}; bash welcome.sh" -f $RemoteDir) -ForegroundColor White
}

if ($ReportTo) {
    Write-Host ""
    Write-Host ("  Health checks streaming to: {0}" -f $ReportTo) -ForegroundColor Cyan
}
