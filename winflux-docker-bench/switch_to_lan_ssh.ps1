# Switch the host's SSH from Tailscale-only to LAN-only access.
#
# Run in ELEVATED PowerShell:
#   Right-click PowerShell -> Run as administrator, then:
#   powershell -ExecutionPolicy Bypass -File .\switch_to_lan_ssh.ps1
#
# What it does (idempotent):
#   1. Rewrites the managed override block in C:\ProgramData\ssh\sshd_config
#      to listen on 0.0.0.0 (was: the Tailscale IP / Tailscale-only).
#      Backs up the file first.
#   2. Rewrites the OpenSSH firewall rule:
#        InterfaceAlias: Tailscale -> Any
#        RemoteAddress:  -> <detected LAN /24>  (LAN-only, no public exposure)
#        Profile:        Any (unchanged)
#   3. Restarts sshd.
#   4. Self-test: local TCP probe to the LAN IP on port 22.
#
# Tailscale itself is left running (idle). Re-running this script is safe.

$ErrorActionPreference = 'Stop'
$date = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptDir "switch-to-lan-ssh-$date.log"

function Log {
    param([string]$msg, [string]$level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 's'), $level, $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

# --- elevation gate -------------------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p  = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: must run elevated. Right-click PowerShell -> Run as administrator." -ForegroundColor Red
    exit 1
}

Log "Starting LAN SSH switch. Log: $logFile"

# Detect the host's LAN IPv4 (skip loopback and Tailscale)
$lanInfo = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.InterfaceAlias -notlike 'Tailscale*' -and
        $_.InterfaceAlias -notlike 'vEthernet*' -and  # Hyper-V / WSL virtual switches
        $_.InterfaceAlias -notlike 'Loopback*' -and
        $_.IPAddress      -notlike '127.*' -and
        $_.IPAddress      -notlike '169.254.*' -and
        $_.IPAddress      -notlike '172.1[6-9].*' -and  # docker / hyper-v defaults
        $_.IPAddress      -notlike '172.2[0-9].*' -and
        $_.IPAddress      -notlike '172.3[0-1].*' -and
        $_.PrefixOrigin    -in @('Dhcp', 'Manual')
    } |
    Sort-Object { $_.PrefixOrigin -eq 'Manual' } -Descending |
    Select-Object -First 1

if (-not $lanInfo) {
    Log "Could not detect a LAN IPv4 (non-Tailscale, non-loopback). Aborting." 'ERROR'
    throw "No LAN IPv4 detected"
}
$lanIp     = $lanInfo.IPAddress
$lanIface  = $lanInfo.InterfaceAlias
Log "Detected LAN IP: $lanIp on interface '$lanIface'"

# Derive /24 subnet from the LAN IP for the firewall RemoteAddress filter.
$octets = $lanIp -split '\.'
$lanSubnet = "{0}.{1}.{2}.0/24" -f $octets[0], $octets[1], $octets[2]
Log "LAN subnet for firewall RemoteAddress: $lanSubnet"

# --- 1. sshd_config: rewrite the managed override block -------------------
Log "Step 1/3: sshd_config"
$sshdCfg = 'C:\ProgramData\ssh\sshd_config'
if (-not (Test-Path $sshdCfg)) {
    Log "sshd_config not found at $sshdCfg. Aborting." 'ERROR'
    throw "sshd_config missing"
}

$startMarker = '# === dockerhost phase1 overrides (managed) ==='
$endMarker   = '# === end dockerhost phase1 overrides ==='
$newBlock = @"
$startMarker
ListenAddress 0.0.0.0
PasswordAuthentication no
PubkeyAuthentication yes
$endMarker

"@

$cfg = Get-Content $sshdCfg -Raw
$cfgBackup = "$sshdCfg.bak.$date"
Copy-Item $sshdCfg $cfgBackup
Log "  Backup: $cfgBackup"

if ($cfg -match [regex]::Escape($startMarker)) {
    $pattern = [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker) + '\r?\n'
    $cfgNew = [regex]::Replace($cfg, $pattern, $newBlock, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    Log "  Replaced existing managed block; ListenAddress now 0.0.0.0"
} else {
    # First time through (no Phase 1 marker present) - prepend.
    $cfgNew = $newBlock + $cfg
    Log "  Prepended managed block (no prior marker found)"
}

Set-Content -Path $sshdCfg -Value $cfgNew -Encoding ascii
Log "  Wrote $sshdCfg"

# --- 2. Firewall rule: LAN subnet only ------------------------------------
Log "Step 2/3: firewall rule"
$ruleName = 'OpenSSH-Server-In-TCP'
$rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if (-not $rule) {
    Log "Firewall rule $ruleName not found. Aborting." 'ERROR'
    throw "Missing firewall rule"
}

# Snapshot before
$beforeIface  = ($rule | Get-NetFirewallInterfaceFilter).InterfaceAlias
$beforeRemote = ($rule | Get-NetFirewallAddressFilter).RemoteAddress
Log "  Before: InterfaceAlias=$beforeIface  RemoteAddress=$beforeRemote  Profile=$($rule.Profile)"

# Apply: no interface restriction, remote-address restricted to LAN /24
$rule | Set-NetFirewallRule -InterfaceAlias 'Any' -RemoteAddress $lanSubnet -Profile Any

# Snapshot after
$rule = Get-NetFirewallRule -Name $ruleName
$afterIface  = ($rule | Get-NetFirewallInterfaceFilter).InterfaceAlias
$afterRemote = ($rule | Get-NetFirewallAddressFilter).RemoteAddress
Log "  After:  InterfaceAlias=$afterIface  RemoteAddress=$afterRemote  Profile=$($rule.Profile)"

# --- 3. Restart sshd, self-test -------------------------------------------
Log "Step 3/3: restart sshd"
Restart-Service sshd
Start-Sleep -Seconds 2
$svc = Get-Service sshd
Log "  sshd status: $($svc.Status), startup: $($svc.StartType)"
if ($svc.Status -ne 'Running') {
    Log "  sshd did NOT reach Running. Likely sshd_config syntax error." 'ERROR'
    Log "  Check: Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 5" 'ERROR'
}

# Confirm listeners
Log "  Active TCP listeners on port 22:"
Get-NetTCPConnection -State Listen -LocalPort 22 -ErrorAction SilentlyContinue |
    ForEach-Object { Log ("    {0}:{1}  pid {2}" -f $_.LocalAddress, $_.LocalPort, $_.OwningProcess) }

# Local probe to the LAN IP
$probe = Test-NetConnection -ComputerName $lanIp -Port 22 -InformationLevel Quiet -WarningAction SilentlyContinue
Log "  Local probe to ${lanIp}:22 reachable: $probe"

# --- Summary --------------------------------------------------------------
Log "Done."
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "From your MacBook, test:" -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "  ssh youruser@$lanIp"
Write-Host "  # or, with mDNS (Windows 11 has the responder built in):"
Write-Host "  ssh youruser@dockerhost.local"
Write-Host ""
Write-Host "Recommended ~/.ssh/config entry on the Mac:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Host dockerhost"
Write-Host "    HostName dockerhost.local"
Write-Host "    User youruser"
Write-Host "    IdentityFile ~/.ssh/id_ed25519"
Write-Host "    ServerAliveInterval 60"
Write-Host ""
Write-Host "If dockerhost.local does not resolve, fall back to the IP:" -ForegroundColor Cyan
Write-Host "    HostName $lanIp"
Write-Host ""
Write-Host "DHCP tip: set a reservation for this host's MAC in your router"
Write-Host "so the IP doesn't rotate. Otherwise rely on mDNS."
Write-Host ""
Write-Host "Log: $logFile"
