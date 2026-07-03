# dockerhost — Agent & InfluxDB Docker Test Bench

A Windows 11 Pro laptop (16 GB RAM, quad-core Intel i7) configured as a
Docker / InfluxDB testing host, reachable from a MacBook Pro over the home LAN.

This README covers the whole bench: host setup (Windows PowerShell + WSL Ubuntu)
and the Mac-side daily workflow. If you only want to *use* an already-set-up
bench, jump to [Day-to-day operation](#day-to-day-operation) — the daily
driver is one script on the Mac.

> **Note:** These scripts are a sanitized template. Placeholders you must set
> for your own environment:
> - `dockerhost` — the hostname of your Windows test box (used throughout).
> - `youruser` — your Windows account name (the SSH login user).
> - `you@example.com` — your email / SSH key comment.
> - Tailscale IPs (`100.64.0.x`) and tailnet DNS (`<tailnet>.ts.net`) — yours.
> - `your-org` / the cloned repo names — the GitHub org and repos you work in.
> - The Mac's SSH public key, baked into `fix_ssh_access.ps1`.

## Contents

1. [The two machines](#the-two-machines)
2. [Current state](#current-state)
3. [Scripts: what runs where](#scripts-what-runs-where)
4. [Setup from scratch](#setup-from-scratch)
5. [Day-to-day operation](#day-to-day-operation)
6. [After a Windows reboot](#after-a-windows-reboot)
7. [Troubleshooting](#troubleshooting)
8. [SSH config on the Mac (reference)](#ssh-config-on-the-mac-reference)
9. [Auto-restart options](#auto-restart-options)
10. [Reverting to Tailscale (future)](#reverting-to-tailscale-future)

## The two machines

This bench spans two machines, and almost every "where do I run this?" question
comes down to telling them apart. Two names are used consistently throughout:

- **The host** — the Windows box (`dockerhost`), running Docker + WSL2 Ubuntu.
- **The Mac** — the MacBook you drive it from.

**Separation principle:** the host does the work; the Mac is the control surface.
Containers, volumes, and all stateful Docker work live on the host. The Mac never
runs Docker locally — it drives the host over SSH and reaches services through
tunnels. When in doubt: heavy or stateful → host; commands and control → Mac.

### The host (`dockerhost`)

- Runs Docker containers (InfluxDB 3 Core / Enterprise, InfluxDB 2, Hugo dev
  server, pytest stacks) so the Mac stays free of Docker pressure.
- Hosts WSL2 Ubuntu 24.04 as the Linux work surface; the Mac SSHes into it.
- Offloads container-heavy work from the Mac.

It does **not** (yet, by design):

- Expose any service to the public internet.
- Run a Tailscale-based management plane (deferred — see notes below).
- Run a persistent always-on agent runtime.

### The Mac

- Holds the SSH keys and `~/.ssh/config` aliases (`dockerhost`, `dockerhost-wsl`).
- Runs the daily launcher (`launch-influxdb3-winflux.sh`) — the only script you
  run here.
- Receives tokens pulled from the host and reaches Core/Enterprise over SSH tunnels.

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

## Scripts: what runs where

There are **three** places you run things. Keeping them straight is the whole game:

| Where | Scripts | When |
|---|---|---|
| **Your Mac** (terminal) | `launch-influxdb3-winflux.sh` | Daily: bring up Core/Enterprise + open tunnels |
| **Windows PowerShell** (on the host) | `phase0_baseline.ps1`, `phase1_install.ps1`, `fix_ssh_access.ps1`, `switch_to_lan_ssh.ps1`, `troubleshoot_ssh.ps1`, `test_tcp_path.ps1` | One-time setup + SSH troubleshooting |
| **WSL Ubuntu** (on the host) | `install.sh`, `phase2_inventory.sh`, `bring_up_influx.sh` | One-time host setup; manual bring-up |

### The daily driver (from the Mac)

99% of the time, this is all you run:

```bash
cd ~/path/to/dotfiles/winflux-docker-bench
./launch-influxdb3-winflux.sh            # Core only
./launch-influxdb3-winflux.sh --both     # Core + Enterprise
./launch-influxdb3-winflux.sh --down     # close tunnels
```

It SSHes to the host, brings up the selected services in WSL, pulls each token to
the Mac, and opens a tunnel so `influxdb3`/`curl` work against `localhost`
(Core `:8282`, Enterprise `:8181`). Full details in `launch-influxdb3-winflux.README.md`.

> **Rule of thumb:** `launch-influxdb3-winflux.sh` is the *only* script you run
> on the Mac. Everything else runs *on the host* — the `.ps1` files in Windows
> PowerShell, the other `.sh` files in WSL. Running the Mac launcher on the host
> just gives you `ssh: connect to host … Connection refused`.

### Per-file reference

| File | Runs on | Purpose |
|---|---|---|
| `launch-influxdb3-winflux.sh` | **Mac** | Daily one-shot: bring up Core/Enterprise on the host + pull token + open tunnel. Flags: `--core` (default), `--enterprise`, `--both`, `--down`. |
| `launch-influxdb3-winflux.README.md` | — | Full docs for the Mac launcher. |
| `install.sh` | **WSL** | Copies the WSL helper scripts into `~/bin` (run once after cloning or pulling the repo on the host). |
| `bring_up_influx.sh` | **WSL** | Brings up InfluxDB 3 services via compose; idempotent. Honors `SERVICES="influxdb3-core influxdb3-enterprise"`. Preflights secret files + Enterprise license email, and auto-applies `compose.quay-rc.yaml` for quay images. This is what the Mac launcher calls over SSH. |
| `compose.quay-rc.yaml` | **WSL** (overlay) | Compose overlay that clears the entrypoint so quay.io RC images run the base command verbatim. Auto-applied by `bring_up_influx.sh` when a quay image pin is detected. |
| `phase2_inventory.sh` | **WSL** | Clones your repos and catalogs compose files into a markdown report. |
| `phase0_baseline.ps1` | **Windows PS** | Captures hardware/OS/Docker/SSH/Tailscale state to a dated markdown. |
| `phase1_install.ps1` | **Windows PS (admin)** | Installs Ubuntu-24.04, `.wslconfig`, OpenSSH Server, key-only sshd_config, gh CLI. |
| `fix_ssh_access.ps1` | **Windows PS (admin)** | Bakes Mac pubkey into admin-keys file with correct ACLs; widens firewall profile. |
| `switch_to_lan_ssh.ps1` | **Windows PS (admin)** | Reconfigures sshd to listen on `0.0.0.0`; locks firewall to LAN `/24`. |
| `troubleshoot_ssh.ps1` | **Windows PS** | Captures sshd state, firewall, routing, admin-keys ACLs for debugging. |
| `test_tcp_path.ps1` | **Windows PS (admin)** | Opens a listener on a non-22 port to bisect TCP-vs-SSH failures. |

All scripts are idempotent: safe to re-run, won't duplicate state.

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

8. Install the WSL helper scripts into `~/bin`, then bring up InfluxDB 3:

   ```bash
   cd "$(wslpath 'C:\Users\youruser\dotfiles\winflux-docker-bench')"
   ./install.sh
   SERVICES="influxdb3-core influxdb3-enterprise" ~/bin/bring_up_influx.sh
   ```

   (Use just `influxdb3-core` in `SERVICES` if you don't need Enterprise yet.)

## Day-to-day operation

**The normal path: run the launcher from the Mac.** One command does bring-up,
token pull, and tunnel:

```bash
cd ~/path/to/dotfiles/winflux-docker-bench
./launch-influxdb3-winflux.sh            # Core only
./launch-influxdb3-winflux.sh --both     # Core + Enterprise
./launch-influxdb3-winflux.sh --down     # close tunnels when done
```

Then query over the tunnel from the Mac (Core `:8282`, Enterprise `:8181`):

```bash
TOKEN="$(grep -ao 'apiv3_[A-Za-z0-9_-]*' ~/.influxdb3-core-admin-token.json | head -1)"
curl -s http://localhost:8282/health -H "Authorization: Bearer $TOKEN"
```

**When you need to poke the host directly**, SSH in:

```bash
ssh dockerhost            # Windows shell on the host
ssh dockerhost-wsl        # straight into WSL Ubuntu
```

Inside WSL, drive compose by hand or call the helper directly:

```bash
cd ~/src/your-org/your-stack-repo
docker compose ps                                          # what's running
docker compose logs -f influxdb3-core                      # tail logs
SERVICES="influxdb3-core influxdb3-enterprise" ~/bin/bring_up_influx.sh
docker compose down                                        # stop the stack
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
services / login startup). To bring the stack back, just run the launcher from
the Mac:

```bash
./launch-influxdb3-winflux.sh --both
```

Or, on the host directly:

```bash
ssh dockerhost-wsl
~/bin/bring_up_influx.sh
```

The helper waits for the Docker engine, brings up the services, prints status +
recent logs, and runs a per-service health probe.

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

### `docker compose up` / `docker pull` fails looking for credentials

When you drive Docker inside WSL over a non-interactive SSH session (e.g.
`ssh dockerhost-wsl` from the Mac), Docker may try to invoke a credential
helper (the `credsStore` / `credHelpers` entries in `~/.docker/config.json`)
*before* pulling even a public image, and fail because the helper can't run
in that context. The error is about credentials, not the image itself.

Fix: give the WSL user a `~/.docker/config.json` with an empty `auths`
object and no credential helper, so Docker stops looking for credentials it
doesn't need (public images like `influxdb:3-core` require no auth):

```bash
# inside WSL Ubuntu
mkdir -p ~/.docker
echo '{"auths": {}}' > ~/.docker/config.json
```

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
