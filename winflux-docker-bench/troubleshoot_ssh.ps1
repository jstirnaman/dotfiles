# Troubleshoot SSH-over-Tailscale from the Mac to this Docker host.
# Run from a NORMAL (non-admin) PowerShell so we can see what the daemon
# reports for the logged-in user. Most steps don't need admin.
# A few steps (netstat-style listen ports, firewall queries) work either way.
#
# Writes a markdown report next to the script.

$ErrorActionPreference = 'Continue'
$date = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outFile = Join-Path $scriptDir "ssh-troubleshoot-$date.md"

$TailscaleIp = $env:TAILSCALE_IP
if (-not $TailscaleIp) { $TailscaleIp = '100.64.0.10' }  # placeholder - replace

function Section {
    param([string]$Title, [scriptblock]$Cmd)
    "## $Title" | Out-File -FilePath $outFile -Append -Encoding utf8
    '' | Out-File -FilePath $outFile -Append -Encoding utf8
    '```' | Out-File -FilePath $outFile -Append -Encoding utf8
    try {
        $r = & $Cmd 2>&1 | Out-String
        if ([string]::IsNullOrWhiteSpace($r)) {
            "(no output)" | Out-File -FilePath $outFile -Append -Encoding utf8
        } else {
            $r.TrimEnd() | Out-File -FilePath $outFile -Append -Encoding utf8
        }
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File -FilePath $outFile -Append -Encoding utf8
    }
    '```' | Out-File -FilePath $outFile -Append -Encoding utf8
    '' | Out-File -FilePath $outFile -Append -Encoding utf8
}

"# dockerhost SSH-over-Tailscale diagnostic - $date" | Out-File $outFile -Encoding utf8
'' | Out-File $outFile -Append -Encoding utf8
"User: $env:USERNAME  |  Host: $env:COMPUTERNAME" | Out-File $outFile -Append -Encoding utf8
'' | Out-File $outFile -Append -Encoding utf8

# -- TAILSCALE DAEMON STATE ---------------------------------------------------
Section 'Tailscale BackendState + Self (full JSON, untruncated)' {
    $j = tailscale status --json | ConvertFrom-Json
    [PSCustomObject]@{
        BackendState = $j.BackendState
        AuthURL      = $j.AuthURL
        HaveNodeKey  = $null -ne $j.Self.PublicKey
        Self_Online  = $j.Self.Online
        Self_TailscaleIPs = ($j.Self.TailscaleIPs -join ', ')
        Self_HostName    = $j.Self.HostName
        Self_DNSName     = $j.Self.DNSName
        Self_KeyExpiry   = $j.Self.KeyExpiry
        PeerCount    = ($j.Peer.PSObject.Properties | Measure-Object).Count
    } | Format-List
}

Section 'Tailscale netcheck' { tailscale netcheck }

Section 'Tailscale IPv4 (current)' { tailscale ip -4 }

Section 'Tailscale status (table form, head)' {
    $lines = tailscale status 2>$null
    if ($lines) { $lines | Select-Object -First 10 | Out-String } else { '(empty)' }
}

# -- ADAPTER / IP BINDING -----------------------------------------------------
Section 'Network adapters (Up) - confirm Tailscale alias' {
    Get-NetAdapter | Where-Object Status -eq 'Up' |
        Format-Table Name, InterfaceDescription, InterfaceAlias, MacAddress, LinkSpeed -AutoSize
}

Section 'IP addresses bound to Tailscale adapter' {
    Get-NetIPAddress -InterfaceAlias 'Tailscale' -ErrorAction SilentlyContinue |
        Format-Table InterfaceAlias, IPAddress, AddressFamily, PrefixLength -AutoSize
}

# -- SSHD LISTENER ------------------------------------------------------------
Section 'sshd service' {
    Get-Service sshd -ErrorAction SilentlyContinue | Format-List Name, Status, StartType
}

Section 'TCP listeners on port 22 (CRITICAL - what IP is sshd bound to?)' {
    Get-NetTCPConnection -State Listen -LocalPort 22 -ErrorAction SilentlyContinue |
        Format-Table LocalAddress, LocalPort, OwningProcess -AutoSize
}

Section 'netstat fallback (raw)' { netstat -ano | findstr :22 }

# -- SSHD CONFIG (EFFECTIVE) --------------------------------------------------
Section 'sshd_config - effective directives' {
    $cfg = 'C:\ProgramData\ssh\sshd_config'
    if (Test-Path $cfg) {
        # Show uncommented directives only (lines not starting with # or whitespace+#)
        Get-Content $cfg | Where-Object { $_ -match '^\s*[A-Za-z]' } | Sort-Object -Unique
    } else {
        "sshd_config not found at $cfg"
    }
}

Section 'sshd -T (sshd dumps effective config; requires admin)' {
    & 'C:\Windows\System32\OpenSSH\sshd.exe' -T 2>&1 | Select-String -Pattern '^(listenaddress|passwordauthentication|pubkeyauthentication|authorizedkeysfile|permitrootlogin|allowusers|denyusers)' -CaseSensitive:$false
}

# -- FIREWALL -----------------------------------------------------------------
Section 'Firewall - OpenSSH inbound rule' {
    Get-NetFirewallRule -DisplayName 'OpenSSH SSH Server (sshd)' -ErrorAction SilentlyContinue |
        Format-List DisplayName, Name, Enabled, Direction, Action, Profile
}

Section 'Firewall - interface filter on the rule' {
    $r = Get-NetFirewallRule -DisplayName 'OpenSSH SSH Server (sshd)' -ErrorAction SilentlyContinue
    if ($r) {
        $r | Get-NetFirewallInterfaceFilter | Format-List InterfaceAlias
        $r | Get-NetFirewallPortFilter | Format-List Protocol, LocalPort
    } else {
        '(rule not found)'
    }
}

# -- ADMIN USER QUIRK - THE BIG ONE -------------------------------------------
Section 'Is current user a member of Administrators?' {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    "Current shell is elevated: $isAdmin"
    "Members of local Administrators group:"
    try {
        Get-LocalGroupMember -Group 'Administrators' | Format-Table Name, ObjectClass, PrincipalSource -AutoSize
    } catch {
        net localgroup Administrators
    }
}

Section 'AuthorizedKeysFile resolution (admin-vs-regular user matters!)' {
    $userKeys  = Join-Path $env:USERPROFILE '.ssh\authorized_keys'
    $adminKeys = 'C:\ProgramData\ssh\administrators_authorized_keys'
    "User authorized_keys path : $userKeys"
    "  exists? " + (Test-Path $userKeys)
    if (Test-Path $userKeys) {
        "  size: " + (Get-Item $userKeys).Length + " bytes"
        "  ACL:"
        (Get-Acl $userKeys).AccessToString
    }
    ""
    "Administrators authorized_keys path : $adminKeys"
    "  exists? " + (Test-Path $adminKeys)
    if (Test-Path $adminKeys) {
        "  size: " + (Get-Item $adminKeys).Length + " bytes"
        "  ACL (must be Administrators+SYSTEM only):"
        (Get-Acl $adminKeys).AccessToString
    }
    ""
    "REMINDER: For users in Administrators, Windows OpenSSH reads the"
    "administrators_authorized_keys file by default, NOT %USERPROFILE%\.ssh\authorized_keys."
    "Owner must be SYSTEM or Administrators; only those two principals may have access."
}

# -- RECENT SSHD EVENT LOG ----------------------------------------------------
Section 'Recent sshd events (last 25, may need admin to read OpenSSH log)' {
    try {
        Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 25 -ErrorAction Stop |
            Select-Object TimeCreated, Id, LevelDisplayName, Message |
            Format-List
    } catch {
        "Could not read OpenSSH/Operational log: $($_.Exception.Message)"
        ""
        "Trying Application log filter as fallback..."
        try {
            Get-EventLog -LogName Application -Newest 10 -Source 'sshd' -ErrorAction Stop |
                Format-Table TimeGenerated, EntryType, Message -AutoSize -Wrap
        } catch {
            "No sshd events in Application log either: $($_.Exception.Message)"
        }
    }
}

# -- LOCAL LOOPBACK TEST ------------------------------------------------------
Section 'Local TCP test - can sshd be reached from the host itself?' {
    $taddr = (tailscale ip -4 2>$null) -replace "`r|`n", ''
    if ($taddr) {
        Test-NetConnection -ComputerName $taddr -Port 22 -InformationLevel Detailed
    } else {
        '(no Tailscale IP)'
    }
}

Write-Host ""
Write-Host "Diagnostic written to: $outFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: from the MacBook, run this and paste the LAST ~30 lines:" -ForegroundColor Cyan
Write-Host "  ssh -vv youruser@$TailscaleIp"
Write-Host ""
Write-Host "What 'ssh -vv' tells us:"
Write-Host "  'Connection refused'        -> sshd not listening on that IP (binding problem)"
Write-Host "  'Operation timed out'       -> firewall or Tailscale routing dropping packets"
Write-Host "  'Permission denied (publickey)' -> reachable, auth path wrong (likely admin-keys file)"
Write-Host "  'no matching host key type'  -> key algorithm mismatch (less likely)"
