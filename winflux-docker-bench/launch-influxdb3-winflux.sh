#!/usr/bin/env bash
# launch-influxdb3-winflux.sh — Mac-side one-shot.
#
# 1. Brings up InfluxDB 3 Core on the winflux host (non-interactive) by driving
#    the host's ~/bin/bring_up_influx.sh inside WSL over SSH.
# 2. Pulls the Core admin token from the host to the Mac (mode 600).
# 3. Opens an SSH tunnel so `influxdb3 --host http://localhost:8282 ...` works
#    locally without touching the Windows firewall.
#
# Usage:
#   ./launch-influxdb3-winflux.sh           # bring up + pull token + tunnel
#   ./launch-influxdb3-winflux.sh --down    # tear down the tunnel
#
# Override any of these via the environment if your setup differs:
#   HOST=winflux  DISTRO=Ubuntu-24.04  LOCAL_PORT=8282
#   ORG=your-org  STACK_REPO=your-stack-repo
set -euo pipefail

HOST="${HOST:-winflux}"            # ~/.ssh/config alias for the Windows host
DISTRO="${DISTRO:-Ubuntu-24.04}"
LOCAL_PORT="${LOCAL_PORT:-8282}"   # Core is published as 8282:8181 on the host
ORG="${ORG:-your-org}"
STACK_REPO="${STACK_REPO:-your-stack-repo}"
REMOTE_TOKEN_FILE="${REMOTE_TOKEN_FILE:-\$HOME/.influxdb3-core-admin-token.json}"
TOKEN_FILE="${TOKEN_FILE:-$HOME/.influxdb3-core-admin-token.json}"

# --- tear-down -------------------------------------------------------------
if [[ "${1:-}" == "--down" ]]; then
  if pkill -f "ssh -f -N -L ${LOCAL_PORT}:localhost:${LOCAL_PORT} ${HOST}" 2>/dev/null; then
    echo "Tunnel on :${LOCAL_PORT} closed."
  else
    echo "No matching tunnel found."
  fi
  exit 0
fi

# --- 1. bring up Core (non-interactive) ------------------------------------
echo "==> Bringing up influxdb3-core on ${HOST} (WSL: ${DISTRO}) ..."
ssh "$HOST" "wsl -d ${DISTRO} -- bash -lc \
  'ORG=${ORG} STACK_REPO=${STACK_REPO} ~/bin/bring_up_influx.sh'"

# --- 2. pull the admin token to the Mac ------------------------------------
echo "==> Pulling Core admin token to ${TOKEN_FILE} ..."
umask 077
ssh "$HOST" "wsl -d ${DISTRO} -- bash -lc 'cat ${REMOTE_TOKEN_FILE}'" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

# Extract the raw token (jq preferred, python3 fallback) for convenience.
if command -v jq >/dev/null 2>&1; then
  TOKEN="$(jq -r '.token' "$TOKEN_FILE")"
elif command -v python3 >/dev/null 2>&1; then
  TOKEN="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["token"])' "$TOKEN_FILE")"
else
  TOKEN=""
fi
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "WARN: could not parse token from ${TOKEN_FILE}; check the file contents." >&2
fi

# --- 3. open the tunnel ----------------------------------------------------
echo "==> Opening tunnel localhost:${LOCAL_PORT} -> ${HOST}:${LOCAL_PORT} ..."
if nc -z localhost "$LOCAL_PORT" 2>/dev/null; then
  echo "    port ${LOCAL_PORT} already open; reusing existing tunnel."
else
  ssh -f -N -L "${LOCAL_PORT}:localhost:${LOCAL_PORT}" "$HOST"
  echo "    tunnel started in background."
fi

# --- ready -----------------------------------------------------------------
cat <<EOF

Core is up and reachable at http://localhost:${LOCAL_PORT}

Quick checks from the Mac:
  curl -s http://localhost:${LOCAL_PORT}/health

  influxdb3 query \\
    --host http://localhost:${LOCAL_PORT} \\
    --token "\$(jq -r .token ${TOKEN_FILE})" \\
    --database <db> "SELECT 1"

Tear down the tunnel when done:
  $0 --down
EOF
