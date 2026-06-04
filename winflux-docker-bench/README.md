# dockerhost — Agent & InfluxDB Docker Test Bench

A Windows 11 Pro laptop (16 GB RAM, quad-core Intel i7) configured as a
Docker / InfluxDB testing host, reachable from a MacBook Pro over the home LAN.

This README is the **Windows-side runbook**. Mac steps appear only where
needed to make the Windows side useful.

> **Note:** These scripts are a sanitized template. Placeholders you must set
> for your own environment:
> - `dockerhost` — the hostname of your Windows test box (used throughout).
> - `youruser` — your Windows account name (the SSH login user).
> - `you@example.com` — your email / SSH key comment.
> - Tailscale IPs (`100.64.0.x`) and tailnet DNS (`<tailnet>.ts.net`) — yours.
> - `your-org` / the cloned repo names — the GitHub org and repos you work in.
> - The Mac's SSH public key, baked into `fix_ssh_access.ps1`.

## Contents

1. [What this machine does](#what-this-machine-does)
2. [Current state](#current-state)
3. [Files in this folder](#files-in-this-folder)
4. [Setup from scratch](#setup-from-scratch)
5. [Day-to-day operation](#day-to-day-operation)
6. [After a Windows reboot](#after-a-windows-reboot)
7. [Troubleshooting](#troubleshooting)
8. [SSH config on the Mac (reference)](#ssh-config-on-the-mac-reference)
9. [Auto-restart options](#auto-restart-options)
10. [Reverting to Tailscale (future)](#reverting-to-tailscale-future)

## What this machine does

- Runs Docker containers (InfluxDB 3 Core / Enterprise, InfluxDB 2, Hugo dev
  server, pytest stacks) so the MacBook can stay free of Docker pressure.
- Hosts WSL2 Ubuntu 24.04 as the Linux work surface; the Mac SSHes into it.
- Offloads docs-tooling / docs work from the upstream docs repos.

What it does **not** do (yet, by design):

- No public internet exposure of any service.
- No Tailscale-based management plane (deferred — see notes below).
- No persistent always-on agent runtime.

## Current state

| Component | Status | Notes |
|---|---|---|
| OS | Windows 11 Pro, build 26100 (24H2) | |
| WSL kernel | 2.7.3.0 | |
| WSL distro | Ubuntu-24.04 | First-run user setup complete |
| `.wslconfig` | `~/.wslconfig` | 12 GB / 6 procs / 4 GB swap |
| Docker Desktop | 4.72.0 (engine 29.4.2) | WSL Integration enabled for Ubuntu-24.04 |
| OpenSSH Server | Running, `Automatic` | Listening on `0.0.0.0:22`, key-only auth |
| Firewall rule (sshd) | `OpenSSH-Server-In-TCP` | LAN `/24` only |
| Admin keys file | `C:\ProgramData\ssh\administrators_authorized_keys` | ACL: Administrators + SYSTEM only |
| Tailscale | Installed, running, **idle** | Managed tailnet ACL drops TCP between peers; LAN is the management plane instead |
| `gh` CLI | Installed (winget) | |

Mac side:

- `~/.ssh/config` aliases `dockerhost` and `dockerhost-wsl` pointing at `dockerhost.local`.
- Ed25519 public key copied into the admin-keys file on the host.

## Files in this folder

| File | Run as | Purpose |
|---|---|---|
| `phase0_baseline.ps1` | normal PS | Captures hardware/OS/Docker/SSH/Tailscale state to a dated markdown |
| `phase1_install.ps1` | **admin PS** | Installs Ubuntu-24.04, `.wslconfig`, OpenSSH Server, key-only sshd_config, gh CLI |
| `troubleshoot_ssh.ps1` | normal PS | Captures everything needed to debug SSH (sshd state, firewall, routing, admin-keys ACLs) |
| `fix_ssh_access.ps1` | **admin PS** | Bakes Mac pubkey into admin-keys file with correct ACLs, widens firewall profile |
| `switch_to_lan_ssh.ps1` | **admin PS** | Reconfigures sshd to listen on `0.0.0.0`, locks firewall to LAN `/24` |
| `test_tcp_path.ps1` | **admin PS** | Used during troubleshooting; opens a listener on a non-22 port to bisect TCP-vs-SSH failures |
| `phase2_inventory.sh` | bash in WSL | Clones your docs repos and catalogs all compose files into a markdown report |
| `bring_up_influx.sh` | bash in WSL | Brings up InfluxDB 3 Core via compose; writes `.env` on first run; idempotent |

All scripts are idempotent: safe to re-run, won't duplicate state. They write
dated logs / output markdown next to themselves.

## Setup from scratch

If rebuilding from a clean Win 11 install:

1. Connect to the home network. Verify with `ipconfig`.
2. Install Tailscale and join the tailnet (optional in this configuration but kept for future use). Confirm tray UI shows "Connected".
3. Open elevated PowerShell:

   ```powershell
   cd "$env:USERPROFILE\dotfiles\winflux-docker-bench"
   powershell -ExecutionPolicy Bypass -File .\phase0_baseline.ps1
   powershell -ExecutionPolicy Bypass -File .\phase1_install.ps1
   powershell -ExecutionPolicy Bypass -File .\fix_ssh_access.ps1
   powershell -ExecutionPolicy Bypass -File .\switch_to_lan_ssh.ps1
   ```

4. From a non-admin PowerShell, complete the Ubuntu first-run user setup:

   ```powershell
   wsl --shutdown
   wsl -d Ubuntu-24.04
   ```

   Pick a UNIX username and password when prompted, then optionally:

   ```bash
   sudo apt update && sudo apt -y full-upgrade
   exit
   ```

5. Open **Docker Desktop** → Settings → Resources → WSL Integration → enable
   for `Ubuntu-24.04` → Apply & Restart. Then `wsl --shutdown` and re-open Ubuntu.

6. From the Mac, set up the SSH config (see [SSH config on the Mac](#ssh-config-on-the-mac-reference) below) and verify:

   ```bash
   ssh dockerhost             # Windows shell
   ssh dockerhost-wsl         # Ubuntu shell
   ```

7. Inside WSL Ubuntu, run Phase 2 (set `ORG`/`REPOS` first if not using the defaults):

   ```bash
   ORG=your-org REPOS="repo-one repo-two" \
     bash "$(wslpath 'C:\Users\youruser\dotfiles\winflux-docker-bench')/phase2_inventory.sh"
   ```

   The script handles `gh auth` (interactive), clones the repos over HTTPS,
   and writes a compose inventory markdown.

8. Bring up InfluxDB 3 Core:

   ```bash
   bash "$(wslpath 'C:\Users\youruser\dotfiles\winflux-docker-bench')/bring_up_influx.sh"
   ```

## Day-to-day operation

Almost everything happens from the Mac via SSH. Two patterns:

```bash
# Drop into the Windows shell on the host
ssh dockerhost

# Drop directly into WSL Ubuntu on the host
ssh dockerhost-wsl
```

Inside Ubuntu:

```bash
cd ~/src/your-org/your-stack-repo
docker compose ps                         # what's running
docker compose logs -f influxdb3-core     # tail logs
docker compose down                       # stop the stack
docker compose up -d influxdb3-core       # start it again
```

From the Mac (after Core is up), poke its HTTP API:

```bash
curl -s http://dockerhost.local:8282/health
```

Docker context over SSH (so `docker` on the Mac talks to the host engine):

```bash
# On the Mac (one-time setup)
docker context create dockerhost --docker "host=ssh://youruser@dockerhost.local"
docker context use dockerhost
docker ps   # should list host containers

# Switch back any time
docker context use default
```

## After a Windows reboot

`sshd`, Tailscale, and Docker Desktop come back on their own (Automatic
services / login startup). What you usually need to do:

```bash
# From the Mac
ssh dockerhost-wsl
~/bin/bring_up_influx.sh
```

That's it. The helper script waits for the Docker engine, brings up Core,
prints status + recent logs, and runs a local health probe.

If you set up Task Scheduler auto-bring-up (see
[Auto-restart options](#auto-restart-options)), even those two commands
become optional.

## Troubleshooting

### "Operation timed out" SSH from the Mac

Run on the host:

```powershell
cd "$env:USERPROFILE\dotfiles\winflux-docker-bench"
powershell -ExecutionPolicy Bypass -File .\troubleshoot_ssh.ps1
```

The output markdown captures everything needed to diagnose. Common causes:

- **Firewall scope wrong** — if the LAN IP rotated or `RemoteAddress` no
  longer covers it. Inspect the rule and reset:

  ```powershell
  Get-NetFirewallRule -Name OpenSSH-Server-In-TCP |
      Get-NetFirewallAddressFilter | Format-List RemoteAddress
  ```

- **DHCP gave the host a new LAN IP** — re-run `switch_to_lan_ssh.ps1`; it
  re-derives the LAN `/24` from whatever the current adapter has.

- **`dockerhost.local` doesn't resolve from the Mac** — mDNS responder
  hiccup. Test with the IP directly:

  ```bash
  ssh youruser@<lan-ip>
  ```

  And consider a DHCP reservation for the host's MAC in your router so the
  IP doesn't rotate.

### "Permission denied (publickey)"

The Mac's key isn't in `C:\ProgramData\ssh\administrators_authorized_keys`
or the ACL is wrong. Re-run `fix_ssh_access.ps1` (idempotent). Check ACL:

```powershell
icacls C:\ProgramData\ssh\administrators_authorized_keys
```

Should list `BUILTIN\Administrators:(F)` and `NT AUTHORITY\SYSTEM:(F)` only.

### Docker socket "permission denied" inside WSL

Docker Desktop WSL Integration isn't enabled (or got disabled). Open
Docker Desktop → Settings → Resources → WSL Integration → enable for
Ubuntu-24.04 → Apply & Restart. Then `wsl --shutdown` and re-open Ubuntu.

### InfluxDB Core port unreachable from the Mac

`localhost:8282` works from inside WSL but `dockerhost.local:8282` hangs
from the Mac → Windows firewall is blocking inbound on `8282`. Add a
LAN-only rule (replace the subnet with your own LAN `/24`):

```powershell
New-NetFirewallRule -Name 'InfluxDB3-Core-In-TCP' `
  -DisplayName 'InfluxDB 3 Core (LAN only)' `
  -Direction Inbound -Action Allow -Protocol TCP `
  -LocalPort 8282 -RemoteAddress '192.168.0.0/24' `
  -Profile Any
```

Same pattern (LAN subnet only) as the SSH rule.

### Tailscale shows "Drop: TCP ... no rules matched" in its logs

The managed tailnet ACL is doing its job — peer-to-peer TCP is
filtered. This is why we use the LAN management plane. No action needed
unless you want to revisit Tailscale; see
[Reverting to Tailscale](#reverting-to-tailscale-future).

## SSH config on the Mac (reference)

`~/.ssh/config`:

```
Host dockerhost
  HostName dockerhost.local
  User youruser
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60

Host dockerhost-wsl
  HostName dockerhost.local
  User youruser
  RemoteCommand wsl -d Ubuntu-24.04
  RequestTTY yes
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60
```

No SSH restart needed after editing — `ssh` reads the config on each invocation.

## Auto-restart options

Three layers of "stays-up-after-reboot," progressively more hands-off:

1. **Compose restart policy** — edit your stack's `docker-compose.yml` and add
   `restart: unless-stopped` under the `influxdb3-core:` service.
   Once the container is created with that policy, Docker Desktop
   restarts it automatically on engine startup.

2. **Docker Desktop autostart on login** — already default. Confirm in
   Docker Desktop → Settings → General → "Start Docker Desktop when you
   sign in".

3. **Task Scheduler at login** — runs `bring_up_influx.sh` automatically
   right after you log into Windows. Useful if you want zero-touch
   recovery. A `register_autostart.ps1` is a one-liner with
   `Register-ScheduledTask` if you go this route.

For most uses, (1) and (2) together are sufficient.

## Reverting to Tailscale (future)

If the managed tailnet ACL is changed to allow user-owned device
peers to talk to each other (or this device moves to a personal tailnet):

1. Revert `sshd_config`:

   ```
   ListenAddress <this-host-tailscale-ip>
   PasswordAuthentication no
   PubkeyAuthentication yes
   ```

   Restart sshd.

2. Re-narrow the firewall rule:

   ```powershell
   $r = Get-NetFirewallRule -Name OpenSSH-Server-In-TCP
   $r | Set-NetFirewallRule -InterfaceAlias 'Tailscale' -RemoteAddress 'Any'
   ```

3. Update the Mac's `~/.ssh/config` `HostName` to either the Tailscale
   IP or the magic-DNS name (`dockerhost.<tailnet>.ts.net`).

A cloud VM (e.g. a small Hetzner instance) is the fallback if Windows
reboots / policy / mobility ever make the local box impractical.
