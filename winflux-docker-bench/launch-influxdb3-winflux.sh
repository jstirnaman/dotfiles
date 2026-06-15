#!/usr/bin/env bash
# launch-influxdb3-winflux.sh — Mac-side one-shot for Core and/or Enterprise.
#
# Brings up InfluxDB 3 on the winflux host (non-interactive) by driving the
# host's ~/bin/bring_up_influx.sh inside WSL over SSH, pulls each edition's
# token to the Mac, and opens an SSH tunnel per edition so the influxdb3 CLI
# works against localhost (no Windows firewall changes).
#
# Usage:
#   ./launch-influxdb3-winflux.sh                # Core only (default)
#   ./launch-influxdb3-winflux.sh --core         # Core only
#   ./launch-influxdb3-winflux.sh --enterprise   # Enterprise only
#   ./launch-influxdb3-winflux.sh --both         # Core + Enterprise
#   ./launch-influxdb3-winflux.sh --down         # tear down all tunnels
#
# Env overrides:
#   HOST=winflux  DISTRO=Ubuntu-24.04  ORG=your-org  STACK_REPO=your-stack-repo
set -euo pipefail

HOST="${HOST:-winflux}"            # ~/.ssh/config alias for the Windows host
DISTRO="${DISTRO:-Ubuntu-24.04}"
ORG="${ORG:-your-org}"
STACK_REPO="${STACK_REPO:-your-stack-repo}"

# Per-edition config (host port == Mac tunnel port; token file basename is the
# same on host and Mac, under $HOME).
CORE_PORT=8282
CORE_TOKEN="$HOME/.influxdb3-core-admin-token.json"
ENT_PORT=8181
ENT_TOKEN="$HOME/.influxdb3-enterprise-permission-tokens.json"

svc()  { [[ "$1" == core ]] && echo influxdb3-core      || echo influxdb3-enterprise; }
port() { [[ "$1" == core ]] && echo "$CORE_PORT"        || echo "$ENT_PORT"; }
tok()  { [[ "$1" == core ]] && echo "$CORE_TOKEN"       || echo "$ENT_TOKEN"; }

# --- parse the mode ---
MODE="core"
case "${1:-}" in
    ""|--core)    MODE="core" ;;
    --enterprise) MODE="enterprise" ;;
    --both)       MODE="both" ;;
    --down)       MODE="down" ;;
    *) echo "usage: $0 [--core|--enterprise|--both|--down]" >&2; exit 2 ;;
esac

# --- tear-down: close every tunnel we might have opened ---
if [[ "$MODE" == down ]]; then
    closed=0
    for p in "$CORE_PORT" "$ENT_PORT"; do
        if pkill -f "ssh -f -N -L ${p}:localhost:${p} ${HOST}" 2>/dev/null; then
            echo "Tunnel on :${p} closed."
            closed=1
        fi
    done
    [[ "$closed" -eq 0 ]] && echo "No matching tunnels found."
    exit 0
fi

# selected editions
case "$MODE" in
    core)       EDITIONS=(core) ;;
    enterprise) EDITIONS=(enterprise) ;;
    both)       EDITIONS=(core enterprise) ;;
esac

# --- 1. bring up the selected services (non-interactive) -------------------
SERVICES=""
for e in "${EDITIONS[@]}"; do SERVICES+="$(svc "$e") "; done
SERVICES="${SERVICES% }"

echo "==> Bringing up [${SERVICES}] on ${HOST} (WSL: ${DISTRO}) ..."
ssh "$HOST" "wsl -d ${DISTRO} -- bash -lc \
  'ORG=${ORG} STACK_REPO=${STACK_REPO} SERVICES=\"${SERVICES}\" ~/bin/bring_up_influx.sh'"

# --- 2. per edition: pull token (best-effort) + open tunnel ----------------
umask 077
for e in "${EDITIONS[@]}"; do
    p="$(port "$e")"
    tf="$(tok "$e")"
    remote="\$HOME/$(basename "$tf")"

    echo "==> [${e}] pulling token to ${tf} ..."
    tmp="$(mktemp)"
    if ssh "$HOST" "wsl -d ${DISTRO} -- bash -c 'cat ${remote}'" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        mv "$tmp" "$tf"
        chmod 600 "$tf"
        echo "    token saved to ${tf}"
    else
        rm -f "$tmp"
        echo "WARN: could not read ${remote} on ${HOST}; continuing without it." >&2
    fi

    echo "==> [${e}] tunnel localhost:${p} -> ${HOST}:${p} ..."
    if nc -z localhost "$p" 2>/dev/null; then
        echo "    port ${p} already open; reusing existing tunnel."
    else
        ssh -f -N -L "${p}:localhost:${p}" "$HOST"
        echo "    tunnel started in background."
    fi
done

# --- ready -----------------------------------------------------------------
echo ""
echo "Ready. Quick checks from the Mac:"
for e in "${EDITIONS[@]}"; do
    p="$(port "$e")"
    tf="$(tok "$e")"
    echo ""
    echo "  ${e}  ->  http://localhost:${p}"
    echo "    TOKEN=\"\$(grep -ao 'apiv3_[A-Za-z0-9_-]*' ${tf} | head -1)\""
    echo "    curl -s http://localhost:${p}/health -H \"Authorization: Bearer \$TOKEN\""
    echo "    influxdb3 query --host http://localhost:${p} --token \"\$TOKEN\" --database <db> 'SELECT 1'"
done
echo ""
echo "Tear down tunnels when done:"
echo "  $0 --down"
