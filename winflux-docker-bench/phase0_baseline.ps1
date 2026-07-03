# Phase 0 baseline capture for the Docker test host.
# Writes a markdown report to the same folder as this script.
# Safe to re-run; overwrites the dated file.

$ErrorActionPreference = 'Continue'
$date = Get-Date -Format 'yyyy-MM-dd'
$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outFile = Join-Path $outDir "dockerhost-baseline-$date.md"

function Capture {
    param(
        [string]$Title,
        [scriptblock]$Cmd
    )
    "## $Title" | Out-File -FilePath $outFile -Append -Encoding utf8
    '' | Out-File -FilePath $outFile -Append -Encoding utf8
    '```' | Out-File -FilePath $outFile -Append -Encoding utf8
    try {
        $result = & $Cmd 2>&1 | Out-String
        if ([string]::IsNullOrWhiteSpace($result)) {
            "(no output)" | Out-File -FilePath $outFile -Append -Encoding utf8
        } else {
            $result.TrimEnd() | Out-File -FilePath $outFile -Append -Encoding utf8
        }
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File -FilePath $outFile -Append -Encoding utf8
    }
    '```' | Out-File -FilePath $outFile -Append -Encoding utf8
    '' | Out-File -FilePath $outFile -Append -Encoding utf8
}

# Header
"# dockerhost baseline - $date" | Out-File -FilePath $outFile -Encoding utf8
'' | Out-File -FilePath $outFile -Append -Encoding utf8
"Captured by phase0_baseline.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')" | Out-File -FilePath $outFile -Append -Encoding utf8
'' | Out-File -FilePath $outFile -Append -Encoding utf8
"Hostname: $env:COMPUTERNAME  |  User: $env:USERNAME" | Out-File -FilePath $outFile -Append -Encoding utf8
'' | Out-File -FilePath $outFile -Append -Encoding utf8

# 1. Hardware + OS
Capture 'Hardware + OS (systeminfo highlights)' {
    systeminfo | Select-String 'OS Name', 'OS Version', 'Total Physical Memory', 'System Type', 'System Manufacturer', 'System Model', 'Processor'
}

Capture 'CPU detail (Get-CimInstance Win32_Processor)' {
    Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Format-List
}

Capture 'Memory detail' {
    $os = Get-CimInstance Win32_OperatingSystem
    [PSCustomObject]@{
        TotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        FreeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    } | Format-List
}

# 2. WSL state
Capture 'WSL status' { wsl --status }
Capture 'WSL list (verbose)' { wsl --list --verbose }
Capture 'WSL version' { wsl --version }

# 3. Docker
Capture 'Docker version' { docker --version }
Capture 'Docker where' { where.exe docker }
Capture 'Docker info (engine)' { docker info --format 'Server Version: {{.ServerVersion}}`nOS/Arch: {{.OSType}}/{{.Architecture}}`nKernel: {{.KernelVersion}}`nCgroup: {{.CgroupDriver}}`nContainers: {{.Containers}} (running: {{.ContainersRunning}})' }
Capture 'Docker contexts' { docker context ls }
Capture 'Docker Desktop service' { Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue | Format-List Name, Status, StartType }

# 4. SSH server
Capture 'sshd service' { Get-Service -Name sshd -ErrorAction SilentlyContinue | Format-List Name, Status, StartType }
Capture 'OpenSSH capabilities' { Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*' | Format-Table Name, State -AutoSize }
Capture 'sshd_config ListenAddress (if present)' {
    $cfg = 'C:\ProgramData\ssh\sshd_config'
    if (Test-Path $cfg) {
        Select-String -Path $cfg -Pattern '^\s*(ListenAddress|PasswordAuthentication|PubkeyAuthentication)' -SimpleMatch:$false
    } else {
        "sshd_config not found at $cfg"
    }
}

# 5. Tailscale
Capture 'Tailscale status' { tailscale status }
Capture 'Tailscale IPv4' { tailscale ip -4 }
Capture 'Tailscale where' { where.exe tailscale }

# 6. Git / GitHub CLI / winget (handy to know now)
Capture 'git version' { git --version }
Capture 'gh version' { gh --version }
Capture 'winget version' { winget --version }

# 7. Network interfaces (useful for confirming Tailscale adapter name for firewall rules)
Capture 'Network adapters (Up)' {
    Get-NetAdapter | Where-Object Status -eq 'Up' | Format-Table Name, InterfaceDescription, MacAddress, LinkSpeed -AutoSize
}

Write-Host ""
Write-Host "Baseline written to: $outFile"
Write-Host ""
Write-Host "Next: review the file, then proceed to phase1_install.ps1."
