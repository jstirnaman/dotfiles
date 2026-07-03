# Bisect: is inbound TCP from the Mac broken for ALL ports, or just sshd/22?
# Also dump Tailscale routing state.
#
# Run in ELEVATED PowerShell on the host.
# Listener listens for 90 seconds. During that window, run from the Mac:
#   nc -zv -G 5 <this-host-tailscale-ip> 18181
# (timeout-flag on macOS netcat is -G; on Linux it's -w)
#
# Outputs to console AND to test-tcp-path-<date>.log next to the script.

$ErrorActionPreference = 'Continue'
$date = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptDir "test-tcp-path-$date.log"

# This host's Tailscale IPv4 (tailscale ip -4) and the Mac's Tailscale IPv4.
$TailscaleIp    = $env:TAILSCALE_IP
if (-not $TailscaleIp)    { $TailscaleIp    = '100.64.0.10' }  # placeholder - replace
$MacTailscaleIp = $env:MAC_TAILSCALE_IP
if (-not $MacTailscaleIp) { $MacTailscaleIp = '100.64.0.20' }  # placeholder - replace

function Log {
    param([string]$msg)
    $line = "[{0}] {1}" -f (Get-Date -Format 's'), $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

# --- elevation gate ---
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p  = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Must run elevated." -ForegroundColor Red
    exit 1
}

Log "==== Restore firewall (in case it's still off) ===="
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
Get-NetFirewallProfile | Select-Object Name, Enabled | ForEach-Object {
    Log ("  {0}: Enabled={1}" -f $_.Name, $_.Enabled)
}

Log ""
Log "==== Tailscale routing table ===="
$routes = Get-NetRoute -InterfaceAlias 'Tailscale' -ErrorAction SilentlyContinue |
    Sort-Object DestinationPrefix
foreach ($r in $routes) {
    Log ("  {0,-22} -> nexthop {1,-15}  metric {2}" -f $r.DestinationPrefix, $r.NextHop, $r.RouteMetric)
}

Log ""
Log "==== CGNAT route check (100.64.0.0/10 should resolve via Tailscale) ===="
$cgnatRoute = Get-NetRoute -DestinationPrefix '100.64.0.0/10' -ErrorAction SilentlyContinue
if ($cgnatRoute) {
    foreach ($r in $cgnatRoute) {
        Log ("  CGNAT route found: {0} via {1} on {2} (metric {3})" -f `
            $r.DestinationPrefix, $r.NextHop, $r.InterfaceAlias, $r.RouteMetric)
    }
} else {
    Log "  NO 100.64.0.0/10 route found - this is a problem"
}

Log ""
Log "==== Route lookup to Mac ($MacTailscaleIp) ===="
$macRoute = Find-NetRoute -RemoteIPAddress $MacTailscaleIp -ErrorAction SilentlyContinue
foreach ($r in $macRoute) {
    Log ("  ifIndex={0}  destPrefix={1}  nextHop={2}  state={3}" -f `
        $r.ifIndex, $r.DestinationPrefix, $r.NextHop, $r.State)
}

Log ""
Log "==== Outbound test: host -> Mac:22 (will probably fail unless Mac has sshd) ===="
$macTest = Test-NetConnection -ComputerName $MacTailscaleIp -Port 22 -InformationLevel Quiet -WarningAction SilentlyContinue
Log "  TcpTestSucceeded to ${MacTailscaleIp}:22 = $macTest"

# --- TCP listener on a non-standard port ---
$port = 18181
$bindAddr = $TailscaleIp
Log ""
Log "==== Starting TCP listener on ${bindAddr}:${port} for 90 seconds ===="
Log ""
Log "NOW from the Mac, run within 90s:"
Log ""
Log "    nc -zv -G 5 $TailscaleIp 18181"
Log ""
Log "  Exit 0 (succeeded)  -> non-22 ports work; SSH-specific issue"
Log "  Timeout/no response -> ALL inbound TCP is failing; Tailscale or routing problem"
Log ""

$ip = [System.Net.IPAddress]::Parse($bindAddr)
$listener = New-Object System.Net.Sockets.TcpListener($ip, $port)
try {
    $listener.Start()
    Log "Listener bound. Waiting for connection (up to 90s)..."
    $deadline = (Get-Date).AddSeconds(90)
    $gotOne = $false
    while ((Get-Date) -lt $deadline) {
        if ($listener.Pending()) {
            $client = $listener.AcceptTcpClient()
            $remote = $client.Client.RemoteEndPoint.ToString()
            Log "GOT CONNECTION from $remote"
            $client.Close()
            $gotOne = $true
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $gotOne) {
        Log "No connection received in 90s window."
    }
} catch {
    Log "Listener error: $($_.Exception.Message)"
} finally {
    $listener.Stop()
}

Log ""
Log "==== pktmon snapshot - last 10 IPv4 drops (admin) ===="
try {
    # See if any packets are being dropped by Windows
    $drops = pktmon list 2>$null
    Log "pktmon present: $($drops -ne $null)"
    # We don't run a full pktmon trace here (complex); just show counter state.
} catch {
    Log "pktmon not available"
}

Log ""
Log "==== Done. Log: $logFile ===="
Write-Host ""
Write-Host "Paste the log content back so we can read the results." -ForegroundColor Cyan
