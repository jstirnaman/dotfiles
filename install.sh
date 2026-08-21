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
#   __INFLUXDATA__  -> ${INFLUXDATA_DIR:-$HOME/Documents/github/influxdata}
# Re-run after editing a template to redeploy. Safe to re-run (idempotent).

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Base dir for the influxdata workspace; override by exporting INFLUXDATA_DIR.
INFLUXDATA_DIR="${INFLUXDATA_DIR:-$HOME/Documents/github/influxdata}"

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
      -e "s|__INFLUXDATA__|$INFLUXDATA_DIR|g" \
      "$src" > "$dst"
  echo "rendered $dst <- $src"
}

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  backup "$dst"
  ln -s "$src" "$dst"
  echo "linked $dst -> $src"
}

# Homebrew packages
# Insert the Brewfile block after the function definitions and before the 
# Zellij config renderers — the first thing that runs once the helpers exist.
# The reason for that position is ordering.
# ZELLIJ_BIN="$(command -v zellij ...)" is evaluated during setup, so on a fresh machine it falls back to the literal string zellij and gets baked into the rendered layout.
# Same class of problem with the prr block, which shells out to gh.
# Installing packages first means both resolve to real paths.
if command -v brew >/dev/null; then
  brew bundle install --file="$REPO/Brewfile"
else
  echo "WARN: brew not found; skipping Brewfile"
fi

# Compute ZELLIJ_BIN after the Brewfile runs
ZELLIJ_BIN="$(command -v zellij || echo zellij)"

# Zellij
render "$REPO/zellij/config.kdl"              "$CONFIG_HOME/zellij/config.kdl"
render "$REPO/zellij/layouts/workstreams.kdl" "$CONFIG_HOME/zellij/layouts/workstreams.kdl"

# Ghostty
render "$REPO/ghostty/config" "$CONFIG_HOME/ghostty/config"

# gh-dash (rendered so __INFLUXDATA__ / __HOME__ in repoPaths get substituted; re-run after edits)
render "$REPO/gh-dash/config.yml" "$CONFIG_HOME/gh-dash/config.yml"

# neovim (no secrets -> symlink the whole config dir so edits propagate live)
link "$REPO/nvim" "$CONFIG_HOME/nvim"

# mise global config (no secrets -> symlink so edits propagate live)
link "$REPO/mise/config.toml" "$CONFIG_HOME/mise/config.toml"

# prr-review wrapper -> ~/.local/bin (ensure this is on your PATH)
link "$REPO/bin/prr-review" "$HOME/.local/bin/prr-review"

# agent-box: trusted-interactive agent container launcher -> ~/.local/bin
link "$REPO/bin/agent-box" "$HOME/.local/bin/agent-box"

# prr config: rendered (NOT symlinked) because it holds a token.
# Token is pulled from `gh auth token` at install time; the repo only stores a
# placeholder. An existing real token is left untouched.
prr_dst="$CONFIG_HOME/prr/config.toml"
if [[ -f "$prr_dst" ]] && grep -q '^token' "$prr_dst" && ! grep -q '__GITHUB_TOKEN__' "$prr_dst"; then
  echo "prr config already present with a token -> leaving $prr_dst untouched"
else
  prr_token="$(gh auth token 2>/dev/null || true)"
  if [[ -z "$prr_token" ]]; then
    echo "WARN: 'gh auth token' returned nothing. Writing placeholder; edit $prr_dst by hand."
    prr_token="__GITHUB_TOKEN__"
  fi
  mkdir -p "$(dirname "$prr_dst")"
  backup "$prr_dst"
  sed -e "s|__HOME__|$HOME|g" \
      -e "s|__GITHUB_TOKEN__|$prr_token|g" \
      "$REPO/prr/config.toml.tmpl" > "$prr_dst"
  chmod 600 "$prr_dst"
  echo "rendered $prr_dst (chmod 600, token from gh)"
fi
mkdir -p "$HOME/reviews"

# Claude config (symlinked, self-contained)
if [[ -x "$REPO/claude/install.sh" ]]; then
  echo "running claude/install.sh ..."
  "$REPO/claude/install.sh"
fi

echo "done."
