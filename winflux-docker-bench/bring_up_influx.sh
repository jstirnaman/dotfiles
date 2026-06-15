#!/usr/bin/env bash
# Bring up your stack's compose services (InfluxDB 3 Core) on the host.
# Run inside WSL2 Ubuntu (e.g., after `ssh dockerhost-wsl`).
# Idempotent: safe to run anytime; already-running services are left alone.
#
# Configure via environment (defaults are placeholders):
#   ORG         GitHub org/owner the stack repo was cloned under (default: your-org)
#   STACK_REPO  repo dir under ~/src/$ORG that holds the compose file (default: your-stack-repo)
#   SERVICE     compose service to bring up (default: influxdb3-core)
#
# Recommended placement: copy to ~/bin/bring_up_influx.sh once, then just
# run `bring_up_influx.sh` after reboots or whenever you need the stack.

set -euo pipefail

ORG="${ORG:-your-org}"
STACK_REPO="${STACK_REPO:-your-stack-repo}"
SERVICE="${SERVICE:-influxdb3-core}"

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
INFLUXDB3_NODE_IDENTIFIER_PREFIX=dockerhost-core
# Pin the Core image tag. Override to a specific tag for reproducibility.
INFLUXDB3_CORE_IMAGE=influxdb:3-core
ENV
    echo "Wrote $ENV_FILE"
fi

cd "$REPO"

echo ""
echo "Bringing up $SERVICE..."
docker compose up -d "$SERVICE"

echo ""
echo "Current state:"
docker compose ps

echo ""
echo "Recent logs:"
docker compose logs --tail=20 "$SERVICE"

# Inside-Ubuntu health probe
echo ""
echo "Health probe (from inside WSL):"
if curl -fsS --max-time 5 http://localhost:8282/health; then
    echo ""
    echo "OK: Core is responding on localhost:8282"
else
    echo "WARN: localhost:8282/health did not respond. Give it 10s and retry,"
    echo "      or check 'docker compose logs $SERVICE' for errors."
fi

echo ""
echo "From the Mac, test with:"
echo "    curl -s http://dockerhost.local:8282/health"
