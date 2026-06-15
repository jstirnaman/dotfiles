#!/usr/bin/env bash
set -euo pipefail

# Top-level dotfiles installer.
#
# Claude config is symlinked live (see claude/install.sh).
#
# Zellij and Ghostty configs are *rendered* rather than symlinked: Zellij does
# not expand environment variables in layout `cwd` attributes
# (https://github.com/zellij-org/zellij/issues/2288), so the repo stores
# templated copies with placeholders that are substituted at install time:
#   __HOME__        -> $HOME
#   __ZELLIJ_BIN__  -> $(command -v zellij)
# Re-run after editing a template to redeploy. Safe to re-run (idempotent).

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

ZELLIJ_BIN="$(command -v zellij || echo zellij)"

backup() {
  local dst="$1"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "$dst.bak.$STAMP"
    echo "backed up $dst -> $dst.bak.$STAMP"
  fi
}

render() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  backup "$dst"
  sed -e "s|__HOME__|$HOME|g" \
      -e "s|__ZELLIJ_BIN__|$ZELLIJ_BIN|g" \
      "$src" > "$dst"
  echo "rendered $dst <- $src"
}

# Zellij
render "$REPO/zellij/config.kdl"              "$CONFIG_HOME/zellij/config.kdl"
render "$REPO/zellij/layouts/workstreams.kdl" "$CONFIG_HOME/zellij/layouts/workstreams.kdl"

# Ghostty
render "$REPO/ghostty/config" "$CONFIG_HOME/ghostty/config"

# Claude config (symlinked, self-contained)
if [[ -x "$REPO/claude/install.sh" ]]; then
  echo "running claude/install.sh ..."
  "$REPO/claude/install.sh"
fi

echo "done."
