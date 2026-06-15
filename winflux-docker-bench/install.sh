#!/usr/bin/env bash
# install.sh — host-side setup for winflux-docker-bench.
#
# Run this inside WSL2 Ubuntu on the Docker host (not on the Mac, not in the
# Windows shell). It installs the WSL-side helper scripts into ~/bin so the
# Mac launcher can call them over SSH.
#
#   ssh dockerhost-wsl
#   cd ~/dotfiles/winflux-docker-bench && ./install.sh
#
# Idempotent: re-running just refreshes the copies.
set -euo pipefail

# Guard: these scripts target Linux/WSL, not Windows or macOS.
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: run this inside WSL2 Ubuntu on the host, not $(uname -s)." >&2
    exit 1
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/bin"
SCRIPTS=(bring_up_influx.sh phase2_inventory.sh)

mkdir -p "$BIN_DIR"

for s in "${SCRIPTS[@]}"; do
    if [[ -f "$SRC_DIR/$s" ]]; then
        install -m 0755 "$SRC_DIR/$s" "$BIN_DIR/$s"
        echo "installed $BIN_DIR/$s"
    else
        echo "WARN: $SRC_DIR/$s not found; skipped." >&2
    fi
done

# PATH hint (the Mac launcher calls the full path, so this is only for
# convenience when running the scripts by name on the host).
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo ""; echo "Note: $BIN_DIR is not on your PATH. Add to ~/.bashrc:"
       echo '      export PATH="$HOME/bin:$PATH"' ;;
esac

echo ""
echo "Done. Bring up the stack with:"
echo "    ORG=<org> STACK_REPO=<repo> ~/bin/bring_up_influx.sh"
