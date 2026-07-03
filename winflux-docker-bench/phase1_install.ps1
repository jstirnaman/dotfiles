# Phase 1 install for the Docker test host.
# Idempotent. Run in an ELEVATED PowerShell.
#   Right-click PowerShell -> Run as administrator, then:
#   powershell -ExecutionPolicy Bypass -File .\phase1_install.ps1
#
# What it does:
#   1. Installs Ubuntu-24.04 under WSL2 (if missing)
#   2. Writes %USERPROFILE%\.wslconfig (12 GB memory cap, 6 procs, 4 GB swap)
#   3. Installs OpenSSH Server capability
#   4. Backs up sshd_config and prepends host overrides:
#        ListenAddress <this-host-tailscale-ip>   (Tailscale only)
#        PasswordAuthentication no
#        PubkeyAuthentication yes
#   5. Starts sshd, sets startup to Automatic
#   6. Restricts the OpenSSH-Server-In-TCP firewall rule to the Tailscale interface
#   7. Installs GitHub CLI (gh) via winget
#
# Writes a log next to this script: phase1-install-<date>.log
# Pure ASCII to avoid PowerShell 5.x encoding parse issues.

$ErrorActionPreference = 'Stop'
$date = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptDir "phase1-install-$date.log"

# Set this to this host's Tailscale IPv4 (run `tailscale ip -4` to find it).
$TailscaleIp = $env:TAILSCALE_IP
if (-not $TailscaleIp) { $TailscaleIp = '100.64.0.10' }  # placeholder - replace

function Log {
    param([string]$msg, [string]$level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 's'), $level, $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

function Require-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log "Not running as Administrator. Exiting." 'ERROR'
        Write-Host ""
        Write-Host "Re-run from an elevated PowerShell:" -ForegroundColor Yellow
        Write-Host "  Right-click PowerShell -> Run as administrator"
        Write-Host "  cd `"$scriptDir`""
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\phase1_install.ps1"
        exit 1
    }
}

Require-Admin
Log "Starting Phase 1 install. Log: $logFile"
Log "Host: $env:COMPUTERNAME  User: $env:USERNAME"

# ---------------------------------------------------------------------------
# 1. Ubuntu-24.04 under WSL2
# ---------------------------------------------------------------------------
Log "Step 1/7: Ubuntu-24.04 under WSL2"
$wslList = (wsl --list --quiet) 2>$null
# wsl prints UTF-16; normalize to plain string for matching.
$wslListPlain = -join ($wslList -replace "`0", "")
if ($wslListPlain -match 'Ubuntu-24\.04') {
    Log "Ubuntu-24.04 already installed. Skipping."
} else {
    Log "Installing Ubuntu-24.04 (this downloads ~500 MB)..."
    try {
        wsl --install -d Ubuntu-24.04 --no-launch
        Log "wsl --install completed."
    } catch {
        Log "wsl --install failed: $($_.Exception.Message)" 'ERROR'
        throw
    }
    Log "NOTE: First Ubuntu launch will prompt for a UNIX username and password."
    Log "      Run 'wsl -d Ubuntu-24.04' from a normal (non-admin) PowerShell after this script finishes."
}

# ---------------------------------------------------------------------------
# 2. .wslconfig
# ---------------------------------------------------------------------------
Log "Step 2/7: .wslconfig"
$wslConfigPath = Join-Path $env:USERPROFILE '.wslconfig'
$wslConfigDesired = @'
[wsl2]
memory=12GB
processors=6
swap=4GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
'@

$writeWslConfig = $true
if (Test-Path $wslConfigPath) {
    $current = Get-Content -Path $wslConfigPath -Raw -ErrorAction SilentlyContinue
    if ($current -and $current.Trim() -eq $wslConfigDesired.Trim()) {
        Log ".wslconfig already matches desired content. Skipping."
        $writeWslConfig = $false
    } else {
        $backup = "$wslConfigPath.bak.$date"
        Copy-Item -Path $wslConfigPath -Destination $backup
        Log "Backed up existing .wslconfig -> $backup"
    }
}
if ($writeWslConfig) {
    Set-Content -Path $wslConfigPath -Value $wslConfigDesired -Encoding ascii
    Log "Wrote $wslConfigPath"
    Log "NOTE: Run 'wsl --shutdown' (from non-admin shell) to apply the new resource caps."
}

# ---------------------------------------------------------------------------
# 3. OpenSSH Server capability
# ---------------------------------------------------------------------------
Log "Step 3/7: OpenSSH Server"
$sshCap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($null -eq $sshCap) {
    Log "Could not query OpenSSH.Server capability. Aborting." 'ERROR'
    throw "OpenSSH.Server capability not found"
}
if ($sshCap.State -eq 'Installed') {
    Log "OpenSSH.Server already installed."
} else {
    Log "Installing $($sshCap.Name) (1-3 minutes)..."
    Add-WindowsCapability -Online -Name $sshCap.Name | Out-Null
    Log "OpenSSH.Server installed."
}

# ---------------------------------------------------------------------------
# 4. sshd_config overrides (prepend so first-match-wins favors us)
# ---------------------------------------------------------------------------
Log "Step 4/7: sshd_config overrides"
$sshdCfg = 'C:\ProgramData\ssh\sshd_config'
$marker = '# === dockerhost phase1 overrides (managed) ==='
$endMarker = '# === end dockerhost phase1 overrides ==='
$overrideBlock = @"
$marker
ListenAddress $TailscaleIp
PasswordAuthentication no
PubkeyAuthentication yes
$endMarker

"@

if (-not (Test-Path $sshdCfg)) {
    # Capability install creates this on first sshd start. Start sshd briefly to materialize the file.
    Log "sshd_config not present yet; starting sshd briefly to materialize default config..."
    try { Start-Service sshd -ErrorAction Stop } catch { }
    Start-Sleep -Seconds 2
    if (-not (Test-Path $sshdCfg)) {
        Log "sshd_config still missing at $sshdCfg. Aborting." 'ERROR'
        throw "sshd_config missing"
    }
}

$cfgBackup = "$sshdCfg.bak.$date"
Copy-Item -Path $sshdCfg -Destination $cfgBackup
Log "Backed up sshd_config -> $cfgBackup"

$cfgContent = Get-Content -Path $sshdCfg -Raw
if ($cfgContent -match [regex]::Escape($marker)) {
    # Replace existing managed block
    $pattern = [regex]::Escape($marker) + '.*?' + [regex]::Escape($endMarker) + '\r?\n'
    $cfgNew = [regex]::Replace($cfgContent, $pattern, $overrideBlock, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    Log "Replaced existing managed override block."
} else {
    $cfgNew = $overrideBlock + $cfgContent
    Log "Prepended new managed override block."
}
# Write as ASCII (sshd reads byte-by-byte; no BOM, plain ASCII is safest)
Set-Content -Path $sshdCfg -Value $cfgNew -Encoding ascii
Log "Updated $sshdCfg"

# ---------------------------------------------------------------------------
# 5. Start sshd and set Automatic
# ---------------------------------------------------------------------------
Log "Step 5/7: Start sshd and set Automatic"
Set-Service -Name sshd -StartupType Automatic
Restart-Service -Name sshd -Force
$svc = Get-Service -Name sshd
Log "sshd status: $($svc.Status), startup: $($svc.StartType)"
if ($svc.Status -ne 'Running') {
    Log "sshd did not reach Running state. Check $sshdCfg syntax." 'ERROR'
}

# Also ensure ssh-agent for key auth (not strictly required for server, but commonly expected)
$sshAgent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if ($sshAgent) {
    if ($sshAgent.StartType -ne 'Automatic') {
        Set-Service -Name ssh-agent -StartupType Automatic
        Log "ssh-agent set to Automatic."
    }
}

# ---------------------------------------------------------------------------
# 6. Firewall: restrict OpenSSH inbound to the Tailscale interface
# ---------------------------------------------------------------------------
Log "Step 6/7: Firewall - restrict OpenSSH-Server-In-TCP to Tailscale interface"
$rules = Get-NetFirewallRule -DisplayName 'OpenSSH SSH Server (sshd)' -ErrorAction SilentlyContinue
if (-not $rules) {
    $rules = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
}
if (-not $rules) {
    Log "Could not locate OpenSSH inbound rule. Creating one bound to Tailscale interface." 'WARN'
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
        -DisplayName 'OpenSSH SSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow `
        -LocalPort 22 -Program 'C:\Windows\System32\OpenSSH\sshd.exe' `
        -InterfaceAlias 'Tailscale' | Out-Null
    Log "Created firewall rule."
} else {
    foreach ($r in $rules) {
        Set-NetFirewallRule -Name $r.Name -Enabled True -Direction Inbound -Action Allow -Protocol TCP
        Get-NetFirewallPortFilter -AssociatedNetFirewallRule $r | Out-Null
        # Restrict to Tailscale interface
        $r | Set-NetFirewallRule -InterfaceAlias 'Tailscale'
        Log "Updated rule '$($r.DisplayName)' to InterfaceAlias=Tailscale only."
    }
}

# ---------------------------------------------------------------------------
# 7. GitHub CLI via winget
# ---------------------------------------------------------------------------
Log "Step 7/7: GitHub CLI"
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    Log "gh already installed at $($gh.Source)."
} else {
    try {
        winget install --id GitHub.cli --silent --accept-package-agreements --accept-source-agreements
        Log "gh installed via winget."
    } catch {
        Log "winget install GitHub.cli failed: $($_.Exception.Message)" 'WARN'
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Log "Phase 1 install complete."
Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS (do these from a NORMAL non-admin PowerShell):" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  1. wsl --shutdown                 # apply new .wslconfig caps"
Write-Host "  2. wsl -d Ubuntu-24.04            # complete first-run user setup"
Write-Host "  3. From your Mac, push your SSH key:"
Write-Host "       ssh-copy-id -i ~/.ssh/id_ed25519.pub youruser@$TailscaleIp"
Write-Host "     (or use the Tailscale magic-DNS name once you confirm it)"
Write-Host "  4. Test from Mac:"
Write-Host "       ssh youruser@$TailscaleIp -- wsl -d Ubuntu-24.04 -- uname -a"
Write-Host ""
Write-Host "Log written to: $logFile"
