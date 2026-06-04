# Fix SSH access from the Mac to this Docker host.
# Run in ELEVATED PowerShell:
#   Right-click PowerShell -> Run as administrator, then:
#   powershell -ExecutionPolicy Bypass -File .\fix_ssh_access.ps1
#
# Two surgical fixes:
#   1. OpenSSH firewall rule profile: Private  ->  Any
#      (rule is still pinned to InterfaceAlias=Tailscale, so safety unchanged)
#   2. Create C:\ProgramData\ssh\administrators_authorized_keys with the
#      Mac's pubkey baked in, ACL'd to Administrators+SYSTEM only,
#      inheritance disabled (per Microsoft OpenSSH docs).
# Then restart sshd and run a self-test.
#
# Idempotent: re-running won't duplicate the key or break ACLs.
#
# BEFORE RUNNING: set $MacPubKey below to the Mac's SSH public key
# (cat ~/.ssh/id_ed25519.pub on the Mac), and $TailscaleIp to this host's
# Tailscale IPv4 (tailscale ip -4).

$ErrorActionPreference = 'Stop'
$date = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptDir "fix-ssh-$date.log"

$TailscaleIp = $env:TAILSCALE_IP
if (-not $TailscaleIp) { $TailscaleIp = '100.64.0.10' }  # placeholder - replace

function Log {
    param([string]$msg, [string]$level='INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 's'), $level, $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

# --- elevation gate --------------------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p  = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: must run in an elevated PowerShell." -ForegroundColor Red
    Write-Host "Right-click PowerShell -> Run as administrator, then re-run:"
    Write-Host "  cd `"$scriptDir`""
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\fix_ssh_access.ps1"
    exit 1
}

Log "Starting SSH access fix. Log: $logFile"

# --- the Mac's pubkey (baked in) -------------------------------------------
# Replace with your Mac's public key: `cat ~/.ssh/id_ed25519.pub` on the Mac.
$macPubKey = 'ssh-ed25519 AAAA...REPLACE_WITH_YOUR_PUBLIC_KEY you@example.com'
if ($macPubKey -match 'REPLACE_WITH_YOUR_PUBLIC_KEY') {
    Log "Edit this script and set \$macPubKey to your real Mac public key first." 'ERROR'
    throw "Placeholder public key not replaced"
}

# --- 1. Widen firewall rule profile ----------------------------------------
Log "Step 1/3: widening OpenSSH firewall rule profile to Any (still Tailscale-only)"
$ruleName = 'OpenSSH-Server-In-TCP'
$rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if (-not $rule) {
    Log "Firewall rule $ruleName not found. Aborting." 'ERROR'
    throw "Firewall rule missing"
}
$beforeProfile = $rule.Profile
Set-NetFirewallRule -Name $ruleName -Profile Any
$afterProfile = (Get-NetFirewallRule -Name $ruleName).Profile
Log "  Profile: $beforeProfile -> $afterProfile"

# Re-assert interface filter just to be sure (safety belt)
$rule | Set-NetFirewallRule -InterfaceAlias 'Tailscale'
$iface = ($rule | Get-NetFirewallInterfaceFilter).InterfaceAlias
Log "  InterfaceAlias confirmed: $iface"

# --- 2. administrators_authorized_keys file with ACLs ----------------------
Log "Step 2/3: administrators_authorized_keys"
$keyFile = 'C:\ProgramData\ssh\administrators_authorized_keys'

# Ensure parent dir exists (it should)
$parent = Split-Path -Parent $keyFile
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Log "  Created $parent"
}

# Determine whether key is already present (avoid duplicates)
$keyAlreadyPresent = $false
if (Test-Path $keyFile) {
    $existing = Get-Content $keyFile -ErrorAction SilentlyContinue
    # Match on the key body (middle field), since comment field may differ
    $newKeyBody = ($macPubKey -split '\s+')[1]
    foreach ($line in $existing) {
        $parts = $line -split '\s+'
        if ($parts.Count -ge 2 -and $parts[1] -eq $newKeyBody) {
            $keyAlreadyPresent = $true
            break
        }
    }
}

if ($keyAlreadyPresent) {
    Log "  Mac pubkey already present in $keyFile. No change to file content."
} else {
    if (Test-Path $keyFile) {
        Add-Content -Path $keyFile -Value $macPubKey -Encoding ascii
        Log "  Appended Mac pubkey to existing $keyFile"
    } else {
        Set-Content -Path $keyFile -Value $macPubKey -Encoding ascii
        Log "  Created $keyFile with Mac pubkey"
    }
}

# ACL: inheritance off, only Administrators and SYSTEM with FullControl.
Log "  Applying Microsoft-recommended ACL (Administrators + SYSTEM only, inheritance off)"
# Use icacls because it's what Microsoft's OpenSSH docs use and it's surgical.
# /inheritance:r removes inherited ACEs and any explicit non-listed ACEs after grants.
& icacls $keyFile /inheritance:r 2>&1 | ForEach-Object { Log "    icacls: $_" }
& icacls $keyFile /grant 'Administrators:F' 2>&1 | ForEach-Object { Log "    icacls: $_" }
& icacls $keyFile /grant 'SYSTEM:F' 2>&1 | ForEach-Object { Log "    icacls: $_" }
# Remove any other ACEs that may have existed (e.g., the creating user's ACL)
& icacls $keyFile /remove 'Users' 2>&1 | Out-Null
& icacls $keyFile /remove "$env:USERDOMAIN\$env:USERNAME" 2>&1 | Out-Null

# Show final ACL for the log
$aclSummary = (& icacls $keyFile) -join "`n"
Log "  Final ACL:`n$aclSummary"

# --- 3. Restart sshd and verify --------------------------------------------
Log "Step 3/3: restart sshd and self-test"
Restart-Service sshd
Start-Sleep -Seconds 2
$svc = Get-Service sshd
Log "  sshd status: $($svc.Status), startup: $($svc.StartType)"

# Local TCP test (should still pass)
$localTest = Test-NetConnection -ComputerName $TailscaleIp -Port 22 -InformationLevel Quiet
Log "  Local TCP ${TailscaleIp}:22 reachable: $localTest"

# --- summary --------------------------------------------------------------
Log "Fix complete."
Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "Now test from the MacBook:" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  ssh youruser@$TailscaleIp"
Write-Host ''
Write-Host 'Expected: a Windows command prompt (or PowerShell, depending'
Write-Host 'on the default shell). If you see "Permission denied (publickey)"'
Write-Host "paste the verbose output (ssh -vv youruser@$TailscaleIp) and dig in."
Write-Host ''
Write-Host "If you want SSH to drop straight into WSL Ubuntu, add to ~/.ssh/config on the Mac:"
Write-Host ''
Write-Host '  Host dockerhost'
Write-Host "    HostName $TailscaleIp"
Write-Host '    User youruser'
Write-Host '    IdentityFile ~/.ssh/id_ed25519'
Write-Host ''
Write-Host '  Host dockerhost-wsl'
Write-Host "    HostName $TailscaleIp"
Write-Host '    User youruser'
Write-Host '    RemoteCommand wsl -d Ubuntu-24.04'
Write-Host '    RequestTTY yes'
Write-Host ''
Write-Host "Log: $logFile"
