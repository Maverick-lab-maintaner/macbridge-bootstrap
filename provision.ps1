<#
.SYNOPSIS
    MacBridge Windows provisioning tool.
.DESCRIPTION
    Copies the macbridge-bootstrap scripts to a cloud Mac via SCP,
    executes bootstrap.sh remotely via SSH, and streams output to
    the Windows terminal. Saves session info for reconnection.
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

if (-not (Test-Path -LiteralPath $KeyPath)) {
    Fail-Step "SSH key not found: $KeyPath"
}

if (-not (Test-Path -LiteralPath (Join-Path $BootstrapDir "bootstrap.sh"))) {
    Fail-Step "bootstrap.sh not found in $BootstrapDir"
}

Clear-Host
Write-Host ""
Write-Host "MacBridge Provision" -ForegroundColor Cyan
Write-Host "Windows to Cloud Mac" -ForegroundColor Cyan
Write-Host ""
Write-Host ("  Mac:    {0}" -f $MacHost) -ForegroundColor Cyan
Write-Host ("  User:   {0}" -f $User) -ForegroundColor Cyan
Write-Host ("  Tier:   {0}" -f $Tier) -ForegroundColor Cyan
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

Write-Host "-> Copying bootstrap scripts to Mac..." -ForegroundColor Cyan
$scpTarget = "{0}@{1}:{2}" -f $User, $MacHost, $RemoteDir
$scpOutput = Run-Scp -Source $BootstrapDir -Destination $scpTarget
if ($LASTEXITCODE -ne 0) {
    Fail-Step ("SCP failed: {0}" -f ($scpOutput | Out-String).Trim())
}
Write-Host ("  OK Scripts copied to {0}" -f $RemoteDir) -ForegroundColor Green
Write-Host ""

$bootstrapCmd = "cd $RemoteDir; bash bootstrap.sh --tier $Tier"
if ($ReportTo) {
    $bootstrapCmd += " --report-to '$ReportTo'"
}

Write-Host "-> Running bootstrap on Mac..." -ForegroundColor Cyan
Write-Host "  This may take about 35 minutes. Output streams below."
Write-Host ""

$bootstrapExit = Run-Ssh -Command $bootstrapCmd
if ($bootstrapExit -ne 0) {
    Fail-Step ("Bootstrap failed (exit code: {0})" -f $bootstrapExit) $bootstrapExit
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

Set-Content -LiteralPath $sessionFile -Value $session

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
