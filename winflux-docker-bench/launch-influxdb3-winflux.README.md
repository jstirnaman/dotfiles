# launch-influxdb3-winflux — Mac-side workflow

One-shot launcher for the InfluxDB 3 **Core and/or Enterprise** test stack
running on the **winflux** Windows host (Docker Desktop + WSL2 Ubuntu). Run it
from the Mac; it handles the SSH → WSL → Docker plumbing for you.

The canonical Windows-side runbook and the in-WSL scripts live in
[`jstirnaman/dotfiles/winflux-docker-bench`](https://github.com/jstirnaman/dotfiles/tree/master/winflux-docker-bench).
This script is the Mac-side companion to that repo's `bring_up_influx.sh`.

## What the script does

For each selected edition (Core, Enterprise, or both):

1. **Brings it up (non-interactive).** Runs the host's `~/bin/bring_up_influx.sh`
   inside WSL over SSH with the right compose services — no interactive shell, no
   manual `wsl` / `docker compose` steps.
2. **Pulls the token to the Mac.** Copies the edition's token file from the host
   (mode 600): Core's admin token (`~/.influxdb3-core-admin-token.json`) and/or
   Enterprise's permission tokens (`~/.influxdb3-enterprise-permission-tokens.json`).
3. **Opens an SSH tunnel.** Forwards the edition's port to the Mac so the
   `influxdb3` CLI and `curl` work locally without changing the Windows firewall.

Ports (host → container): Core `8282:8181`, Enterprise `8181:8181`. The tunnels
expose Core at `localhost:8282` and Enterprise at `localhost:8181` on the Mac.

## Usage

```bash
./launch-influxdb3-winflux.sh                # Core only (default)
./launch-influxdb3-winflux.sh --core         # Core only
./launch-influxdb3-winflux.sh --enterprise   # Enterprise only
./launch-influxdb3-winflux.sh --both          # Core + Enterprise
./launch-influxdb3-winflux.sh --down         # close all tunnels
```

### Enterprise prerequisites

Enterprise won't start unless these exist on the host first:

- `INFLUXDB3_ENTERPRISE_LICENSE_EMAIL` set in the compose `.env`.
- `~/.influxdb3-enterprise-permission-tokens.json` present (the compose secret).

Bring up Core first if you only have Core configured; add Enterprise once its
license email and permission-tokens file are in place.

After it runs, test from the Mac:

```bash
# The token file may be a bare token string or JSON; this grabs the token either way.
TOKEN="$(grep -ao 'apiv3_[A-Za-z0-9_-]*' ~/.influxdb3-core-admin-token.json | head -1)"

curl -s http://localhost:8282/health -H "Authorization: Bearer $TOKEN"

influxdb3 query \
  --host http://localhost:8282 \
  --token "$TOKEN" \
  --database <db> "SELECT 1"
```

## Configuration

Defaults assume the standard setup; override via environment if needed:

| Variable      | Default                              | Purpose                                   |
|---------------|--------------------------------------|-------------------------------------------|
| `HOST`        | `winflux`                            | `~/.ssh/config` alias for the Windows host |
| `DISTRO`      | `Ubuntu-24.04`                       | WSL distro name                            |
| `LOCAL_PORT`  | `8282`                               | Local + host port for Core                 |
| `ORG`         | `your-org`                           | Passed to the host's `bring_up_influx.sh`  |
| `STACK_REPO`  | `your-stack-repo`                    | Repo dir holding the compose file          |
| `TOKEN_FILE`  | `~/.influxdb3-core-admin-token.json` | Where the token lands on the Mac           |

## Prerequisites

- **SSH config** — `~/.ssh/config` has a `winflux` host alias (and optionally
  `winflux-wsl`). The launcher uses `ssh winflux '...'` directly rather than the
  `winflux-wsl` alias, because that alias forces an interactive TTY.

  ```
  Host winflux
    HostName winflux.local
    User <your-windows-user>
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60

  Host winflux-wsl
    HostName winflux.local
    User <your-windows-user>
    RemoteCommand wsl -d Ubuntu-24.04
    RequestTTY yes
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
  ```

- **Host setup** — `~/bin/bring_up_influx.sh` exists and is configured on the
  host (see the dotfiles repo). Docker Desktop WSL integration is enabled.
- **`winflux.local`** resolves over mDNS from the Mac.
- **Local tools** — `jq` (or `python3`) for token parsing; `nc` for the
  tunnel-reuse check. Both are standard on macOS / Homebrew.

## Troubleshooting

- **Bring-up step errors** — most often the host's `bring_up_influx.sh` is
  missing or still has placeholder `ORG`/`STACK_REPO` defaults. Override them:
  `ORG=your-org STACK_REPO=your-stack-repo ./launch-influxdb3-winflux.sh`.
- **`winflux.local` won't resolve** — try the host's LAN IP as `HostName`, or
  add a DHCP reservation so the IP doesn't rotate.
- **Token parse warning** — the host's token file can be either a bare
  `apiv3_...` string or JSON (`{"token": "apiv3_...", "name": "_admin"}`); both
  are fine. If it's missing, set `REMOTE_TOKEN_FILE=/path/to/token` to point at
  the real location.
- **Port already in use** — a previous tunnel is still up; the script reuses it.
  Use `--down` to close it first if you need a clean one.
