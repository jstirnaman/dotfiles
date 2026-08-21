#!/usr/bin/env bash
set -euo pipefail

# Symlinks this repo's Claude config into ~/.claude so edits here propagate live.
# Backs up any existing real (non-symlink) files first. Safe to re-run (idempotent).

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude"
STAMP="$(date +%Y%m%d-%H%M%S)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"                                  # replace stale symlink
  elif [[ -e "$dst" ]]; then
    mv "$dst" "$dst.bak.$STAMP"                # preserve real file
    echo "backed up $dst -> $dst.bak.$STAMP"
  fi
  ln -s "$src" "$dst"
  echo "linked $dst -> $src"
}

# CLAUDE.md
link "$REPO/CLAUDE.md" "$DEST/CLAUDE.md"

# Each skill directory
for d in "$REPO"/skills/*/; do
  name="$(basename "$d")"
  link "$d" "$DEST/skills/$name"
done

# Disable mouse-click focus stealing in Claude Code TUI (~/.zshenv, read by every zsh)
ZSHENV="$HOME/.zshenv"
if ! grep -q '^export CLAUDE_CODE_DISABLE_MOUSE_CLICKS=' "$ZSHENV" 2>/dev/null; then
  echo 'export CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1' >> "$ZSHENV"
  echo "added CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1 to $ZSHENV"
fi

echo "done."
