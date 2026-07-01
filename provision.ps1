<#
.SYNOPSIS
    MacBridge — Windows Provisioning Tool
.DESCRIPTION
    Copies the macbridge-bootstrap scripts to a cloud Mac via SCP,
    executes bootstrap.sh remotely via SSH, and streams output to
    the Windows terminal. Saves session info for reconnection.

    This is the bridge between your Windows machine and the cloud Mac.
    No more manual SCP + SSH + copy-paste.

.PARAMETER MacHost
    The cloud Mac's IP address or hostname (required).

.PARAMETER User
    SSH username (default: the local username, or 'admin' for Macly).

.PARAMETER KeyPath
    Path to SSH private key (default: ~\.ssh\id_ed25519).

.PARAMETER BootstrapDir
    Local path to macbridge-bootstrap directory (default: current directory).

.PARAMETER RemoteDir
    Directory on the Mac to copy bootstrap to (default: ~/macbridge-bootstrap).

.PARAMETER Tier
    Provisioning tier — "agent" for full setup, or specific layer (default: agent).

.PARAMETER ReportTo
    Webhook URL for centralized log shipping during bootstrap.

.PARAMETER Welcome
    Run welcome.sh after bootstrap completes.

.PARAMETER Hardening
    Run hardening.sh after bootstrap completes.

.EXAMPLE
    .\provision.ps1 -MacHost 203.0.113.47

.EXAMPLE
    .\provision.ps1 -MacHost 203.0.113.47 -KeyPath ~\.ssh\macly_key -Welcome -Hardening

.EXAMPLE
    .\provision.ps1 -MacHost 203.0.113.47 -ReportTo https://dash.example.com/api/report
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$MacHost,

    [string]$User = $env:USERNAME,

    [string]$KeyPath = "$HOME\.ssh\id_ed25519",

    [string]$BootstrapDir = (Get-Location).Path,

    [string]$RemoteDir = "~/macbridge-bootstrap",

    [string]$Tier = "agent",

    [string]$ReportTo = "",

    [switch]$Welcome,

    [switch]$Hardening
)

$ErrorActionPreference = "Stop"

# ── Validation ─────────────────────────────────────────────────────────────

if (-not (Test-Path $KeyPath)) {
    Write-Host "❌ SSH key not found: $KeyPath" -ForegroundColor Red
    Write-Host "   Generate one: ssh-keygen -t ed25519 -f $KeyPath"
    exit 1
}

if (-not (Test-Path "$BootstrapDir\bootstrap.sh")) {
    Write-Host "❌ bootstrap.sh not found in $BootstrapDir" -ForegroundColor Red
    Write-Host "   Run this script from the macbridge-bootstrap directory."
    exit 1
}

# ── Banner ─────────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              🏗️  MacBridge — Provision                         ║" -ForegroundColor Cyan
Write-Host "║              Windows → Cloud Mac                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Mac:    $MacHost" -ForegroundColor Cyan
Write-Host "  User:   $User" -ForegroundColor Cyan
Write-Host "  Tier:   $Tier" -ForegroundColor Cyan
if ($ReportTo) {
    Write-Host "  Report: $ReportTo" -ForegroundColor Cyan
}
Write-Host ""

# ── SSH options ────────────────────────────────────────────────────────────

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

# ── Step 1: Test SSH connectivity ──────────────────────────────────────────

Write-Host "→ Testing SSH connection..." -ForegroundColor Cyan
try {
    $testResult = & ssh @sshOpts "$User@$MacHost" "echo 'CONNECTED'" 2>&1
    if ($testResult -match "CONNECTED") {
        Write-Host "  ✅ SSH connection established" -ForegroundColor Green
    } else {
        Write-Host "  ❌ SSH connection failed: $testResult" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ❌ SSH connection failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ── Step 2: SCP bootstrap to Mac ───────────────────────────────────────────

Write-Host "→ Copying bootstrap scripts to Mac..." -ForegroundColor Cyan
try {
    & scp @scpOpts "$BootstrapDir" "$User@$MacHost`:$RemoteDir" 2>&1 | Out-Null
    Write-Host "  ✅ Scripts copied to $RemoteDir" -ForegroundColor Green
} catch {
    Write-Host "  ❌ SCP failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ── Step 3: Run bootstrap ──────────────────────────────────────────────────

$bootstrapCmd = "cd $RemoteDir && bash bootstrap.sh --tier $Tier"
if ($ReportTo) {
    $bootstrapCmd += " --report-to '$ReportTo'"
}

Write-Host "→ Running bootstrap on Mac..." -ForegroundColor Cyan
Write-Host "  This may take ~35 minutes. Output streams below."
Write-Host ""
Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$bootstrapExit = 0
try {
    & ssh @sshOpts "$User@$MacHost" $bootstrapCmd 2>&1
    $bootstrapExit = $LASTEXITCODE
} catch {
    Write-Host "❌ Bootstrap execution failed: $_" -ForegroundColor Red
    $bootstrapExit = 1
}

Write-Host ""
Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

if ($bootstrapExit -eq 0) {
    Write-Host "✅ Bootstrap completed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Bootstrap failed (exit code: $bootstrapExit)" -ForegroundColor Red
    Write-Host "   Check logs on Mac: cat $RemoteDir/logs/bootstrap-*.log"
    exit $bootstrapExit
}

# ── Step 4: Optional Harden ────────────────────────────────────────────────

if ($Hardening) {
    Write-Host ""
    Write-Host "→ Running firewall hardening..." -ForegroundColor Cyan
    $hardenCmd = "cd $RemoteDir && bash hardening.sh"

    $hardenExit = 0
    try {
        & ssh @sshOpts "$User@$MacHost" $hardenCmd 2>&1
        $hardenExit = $LASTEXITCODE
    } catch {
        $hardenExit = 1
    }

    if ($hardenExit -eq 0) {
        Write-Host "  ✅ Firewall hardened — only SSH (22) + VNC (5900) open" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Hardening reported issues — check output above" -ForegroundColor Yellow
    }
}

# ── Step 5: Optional Welcome Wizard ────────────────────────────────────────

if ($Welcome) {
    Write-Host ""
    Write-Host "→ Running Welcome Wizard..." -ForegroundColor Cyan
    Write-Host "  (interactive — you will be prompted for API keys)" -ForegroundColor Yellow
    Write-Host ""

    & ssh -t @sshOpts "$User@$MacHost" "cd $RemoteDir && bash welcome.sh"
}

# ── Step 6: Save session info ──────────────────────────────────────────────

$sessionDir = "$HOME\.macbridge"
$sessionFile = "$sessionDir\session.json"

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

Set-Content -Path $sessionFile -Value $session

# ── Summary ────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              🟢  Provisioning Complete                        ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  SSH:     ssh -i $KeyPath $User@$MacHost" -ForegroundColor Cyan
Write-Host "  Session: $sessionFile" -ForegroundColor Cyan
Write-Host ""

if (-not $Welcome) {
    Write-Host "  Next on the Mac:" -ForegroundColor Cyan
    Write-Host "    cd $RemoteDir && bash welcome.sh" -ForegroundColor White
}

if ($ReportTo) {
    Write-Host ""
    Write-Host "  Health checks streaming to: $ReportTo" -ForegroundColor Cyan
}
