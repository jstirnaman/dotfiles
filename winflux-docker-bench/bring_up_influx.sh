#!/usr/bin/env bash
# Bring up your stack's compose services (InfluxDB 3 Core / Enterprise) on the host.
# Run inside WSL2 Ubuntu (e.g., after `ssh dockerhost-wsl`).
# Idempotent: safe to run anytime; already-running services are left alone.
#
# Configure via environment (defaults are placeholders):
#   ORG         GitHub org/owner the stack repo was cloned under (default: your-org)
#   STACK_REPO  repo dir under ~/src/$ORG that holds the compose file (default: your-stack-repo)
#   SERVICES    space-separated compose services to bring up
#               (default: influxdb3-core; e.g. "influxdb3-core influxdb3-enterprise")
#   SERVICE     deprecated single-service alias, still honored for back-compat
#
# Recommended placement: copy to ~/bin/bring_up_influx.sh once, then just
# run `bring_up_influx.sh` after reboots or whenever you need the stack.

set -euo pipefail

ORG="${ORG:-your-org}"
STACK_REPO="${STACK_REPO:-your-stack-repo}"
SERVICES="${SERVICES:-${SERVICE:-influxdb3-core}}"

REPO="$HOME/src/$ORG/$STACK_REPO"
ENV_FILE="$REPO/.env"

if [[ ! -d "$REPO" ]]; then
    echo "ERROR: $REPO not found. Run phase2_inventory.sh first." >&2
    exit 1
fi

# Wait briefly for Docker Desktop to be ready, in case this ran at login
# before the engine finished starting.
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if docker info >/dev/null 2>&1; then break; fi
    echo "Waiting for Docker engine (attempt $attempt/10)..."
    sleep 3
done
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker engine still not reachable. Is Docker Desktop running?" >&2
    exit 1
fi

# Persistent compose env: docker compose reads .env in the project dir.
# Create only if missing so manual edits stick.
if [[ ! -f "$ENV_FILE" ]]; then
    cat > "$ENV_FILE" <<'ENV'
# Picked up automatically by docker compose in this directory.
INFLUXDB3_NODE_IDENTIFIER_PREFIX=influxdb3
# Pin image tags. Override to specific quay.io RC tags for pre-release testing.
INFLUXDB3_CORE_IMAGE=influxdb:3-core
INFLUXDB3_ENTERPRISE_IMAGE=influxdb:3-enterprise
ENV
    echo "Wrote $ENV_FILE"
fi

cd "$REPO"

echo ""
echo "Bringing up: $SERVICES"
# shellcheck disable=SC2086  # intentional word-splitting of the service list
docker compose up -d $SERVICES

echo ""
echo "Current state:"
docker compose ps

echo ""
echo "Recent logs:"
for s in $SERVICES; do
    echo "--- $s ---"
    docker compose logs --tail=20 "$s"
done

# Per-service health probe. Core is published on 8282, Enterprise on 8181.
# Auth is enabled, so an unauthenticated /health returns 401 — that still means
# the server is up, so 200 and 401 both count as healthy.
health_port() {
    case "$1" in
        influxdb3-core)       echo 8282 ;;
        influxdb3-enterprise) echo 8181 ;;
        *)                    echo "" ;;
    esac
}

echo ""
echo "Health (from inside WSL):"
for s in $SERVICES; do
    hp="$(health_port "$s")"
    if [[ -z "$hp" ]]; then
        echo "  $s: no known health port; skipping"
        continue
    fi
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://localhost:${hp}/health" || echo 000)"
    case "$code" in
        200) echo "  OK:   $s healthy on :$hp" ;;
        401) echo "  OK:   $s up on :$hp (401 = auth required, expected)" ;;
        000) echo "  WARN: $s on :$hp not responding yet; give it 10s and retry" ;;
        *)   echo "  WARN: $s on :$hp returned HTTP $code; check 'docker compose logs $s'" ;;
    esac
done
