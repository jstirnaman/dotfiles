# launch-influxdb3-winflux — Mac-side workflow

One-shot launcher for the InfluxDB 3 Core test stack running on the **winflux**
Windows host (Docker Desktop + WSL2 Ubuntu). Run it from the Mac; it handles the
SSH → WSL → Docker plumbing for you.

The canonical Windows-side runbook and the in-WSL scripts live in
[`jstirnaman/dotfiles/winflux-docker-bench`](https://github.com/jstirnaman/dotfiles/tree/master/winflux-docker-bench).
This script is the Mac-side companion to that repo's `bring_up_influx.sh`.

## What the script does

1. **Brings up Core (non-interactive).** Runs the host's
   `~/bin/bring_up_influx.sh` inside WSL over SSH — no interactive shell, no
   manual `wsl` / `docker compose` steps.
2. **Pulls the admin token to the Mac.** Copies the Core admin token JSON from
   the host to `~/.influxdb3-core-admin-token.json` (mode 600). Core runs
   token-authenticated, so the CLI needs this.
3. **Opens an SSH tunnel.** Forwards `localhost:8282` on the Mac to Core on the
   host, so the `influxdb3` CLI and `curl` work locally without changing the
   Windows firewall.

Core publishes `8282:8181` on the host (host `8282` → container `8181`).

## Usage

```bash
./launch-influxdb3-winflux.sh          # bring up Core, pull token, open tunnel
./launch-influxdb3-winflux.sh --down   # close the tunnel
```

After it runs, test from the Mac:

```bash
curl -s http://localhost:8282/health

influxdb3 query \
  --host http://localhost:8282 \
  --token "$(jq -r .token ~/.influxdb3-core-admin-token.json)" \
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
- **Token parse warning** — confirm `~/.influxdb3-core-admin-token.json` on the
  host is valid JSON of the form `{"token": "apiv3_...", "name": "_admin"}`.
- **Port already in use** — a previous tunnel is still up; the script reuses it.
  Use `--down` to close it first if you need a clean one.
