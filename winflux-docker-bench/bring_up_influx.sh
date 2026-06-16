#!/usr/bin/env bash
# bring_up_influx.sh — bring up InfluxDB 3 compose services on the host (WSL2).
# Run inside WSL2 Ubuntu. Idempotent.
#
# Config via environment (defaults are placeholders):
#   ORG         GitHub org the stack repo was cloned under  (default: your-org)
#   STACK_REPO  repo dir under ~/src/$ORG with the compose   (default: your-stack-repo)
#   SERVICES    space-separated services to start            (default: influxdb3-core)
#               e.g. SERVICES="influxdb3-core influxdb3-enterprise"
#   SERVICE     deprecated single-service alias (still honored)
#
# Two preflight guards (the failures that cost the most time):
#   1. Every compose secret file must already exist as a regular file. If it's
#      missing, Docker silently creates a root-owned DIRECTORY in its place and
#      auth never works.
#   2. Enterprise needs a real INFLUXDB3_ENTERPRISE_LICENSE_EMAIL, not empty or a
#      placeholder, or the server fails to license and exits.
#
# Caution: `docker compose down -v` deletes the Enterprise license cache stored
# in the data volume — don't use it unless you mean to re-fetch a license.

set -euo pipefail

ORG="${ORG:-your-org}"
STACK_REPO="${STACK_REPO:-your-stack-repo}"
SERVICES="${SERVICES:-${SERVICE:-influxdb3-core}}"

REPO="$HOME/src/$ORG/$STACK_REPO"
[[ -d "$REPO" ]] || { echo "ERROR: $REPO not found. Run phase2_inventory.sh first." >&2; exit 1; }
cd "$REPO"

# Wait for the Docker engine (may still be starting at login).
for i in $(seq 1 10); do
    docker info >/dev/null 2>&1 && break
    echo "Waiting for Docker engine ($i/10)..."; sleep 3
done
docker info >/dev/null 2>&1 || { echo "ERROR: Docker engine not reachable. Is Docker Desktop running?" >&2; exit 1; }

# --- preflight: fail loudly BEFORE compose can fabricate phantom dirs ---------
preflight() {
    local cfg path email bad=0
    cfg="$(docker compose config 2>/dev/null)" || return 0   # best-effort

    # 1. Secret source files must exist as regular files.
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        path="${path/#\~/$HOME}"
        if [[ ! -e "$path" ]]; then
            echo "ERROR: compose secret file missing: $path" >&2
            echo "       Create the token file first — Docker would otherwise fabricate a directory." >&2
            bad=1
        elif [[ -d "$path" ]]; then
            echo "ERROR: compose secret path is a fabricated directory: $path" >&2
            echo "       Run: sudo rm -rf '$path'  then recreate the real token file." >&2
            bad=1
        fi
    done < <(printf '%s\n' "$cfg" | awk '/^secrets:/{s=1;next} /^[^[:space:]]/{s=0} s&&$1=="file:"{print $2}')

    # 2. Enterprise needs a real license email.
    if [[ " $SERVICES " == *" influxdb3-enterprise "* ]]; then
        email="$(printf '%s\n' "$cfg" | awk -F': ' '/INFLUXDB3_ENTERPRISE_LICENSE_EMAIL:/{gsub(/"/,"",$2);print $2;exit}')"
        if [[ -z "$email" || "$email" == *"<"* || "$email" == *example* ]]; then
            echo "ERROR: INFLUXDB3_ENTERPRISE_LICENSE_EMAIL is empty or a placeholder ('$email')." >&2
            echo "       Set a real licensed email in $REPO/.env before starting Enterprise." >&2
            bad=1
        fi
    fi

    [[ $bad -eq 0 ]] || { echo "Preflight failed — not starting compose." >&2; exit 1; }
}
preflight

# --- quay RC overlay: auto-apply when an image pin is quay-hosted -------------
# quay RC images' entrypoint already invokes `influxdb3`; the overlay clears the
# entrypoint so the base command runs verbatim. Lives next to this script
# (installed to ~/bin by install.sh).
compose_args=()
self_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" 2>/dev/null && pwd)"
overlay="$self_dir/compose.quay-rc.yaml"
if docker compose config 2>/dev/null | grep -q 'image:.*quay\.io'; then
    if [[ -f "$overlay" ]]; then
        compose_args=(-f docker-compose.yml -f "$overlay")
        echo "Detected quay.io image(s) — applying RC entrypoint overlay."
    else
        echo "WARN: quay.io image detected but overlay missing: $overlay" >&2
        echo "      Re-run install.sh on the host to install it." >&2
    fi
fi

# --- bring up -----------------------------------------------------------------
echo "Bringing up: $SERVICES"
# shellcheck disable=SC2086  # intentional word-splitting of the service list
docker compose "${compose_args[@]}" up -d $SERVICES
docker compose ps

# --- health (Core 8282, Enterprise 8181; 401 = up but auth-required) ----------
for s in $SERVICES; do
    case "$s" in
        influxdb3-core)       hp=8282 ;;
        influxdb3-enterprise) hp=8181 ;;
        *) continue ;;
    esac
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://localhost:${hp}/health" || echo 000)"
    case "$code" in
        200|401) echo "OK:   $s up on :$hp (HTTP $code)" ;;
        *)       echo "WARN: $s on :$hp returned '$code' — check 'docker compose logs $s'" ;;
    esac
done
