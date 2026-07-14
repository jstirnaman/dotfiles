#!/usr/bin/env bash
#
# install-skills.sh — install the agent skills listed in ./Skillsfile.
#
# Each Skillsfile line calls `skill <method> <args…>`; this script defines the
# methods. Add a skill = add a line to Skillsfile.
#
#   ./install-skills.sh            install everything in Skillsfile
#   ./install-skills.sh --dry-run  print the commands, run nothing
#   ./install-skills.sh --scan     scan each fetched skill with SkillSpector first
#
# SECURITY: curl-bash and the clone-and-run methods execute remote code. Review
# the sources before running, and prefer --scan once SkillSpector is installed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DRY_RUN=0
SCAN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --scan) SCAN=1 ;;
    -h | --help) sed -n '3,13p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Execute a composed command string. Manifest input is trusted (it's your file),
# so eval is intentional — it lets a line use pipes and &&.
run() {
  echo "  + $1"
  if [[ $DRY_RUN -eq 0 ]]; then
    eval "$1"
  fi
}

# Security gate: with --scan, scan a fetched skill dir; nonzero exit aborts it.
scan_ok() {
  local dir="$1"
  [[ $SCAN -eq 0 ]] && return 0
  if command -v skillspector > /dev/null 2>&1; then
    echo "  🔍 skillspector scan $dir"
    skillspector scan "$dir"
  else
    echo "  ⚠️  --scan set but skillspector not installed yet; not scanning $dir" >&2
    return 0
  fi
}

skill() {
  local method="$1"; shift
  echo "▶ $method $*"
  case "$method" in
    npx) run "npx skills@latest add '$1'" ;;
    uv) run "uv tool install '$1'" ;;
    curl-bash) run "curl -fsSL '$1' | bash" ;;
    raw) _raw "$@" ;;
    git-run) _git_run "$@" ;;
    git-cmd) _git_cmd "$@" ;;
    git-clone) _git_clone "$@" ;;
    graphify-fixup) _fixup_graphify ;;
    *) echo "  unknown method: $method" >&2; return 1 ;;
  esac
}

# graphify-fixup   patch the upstream graphify skill: it ships bare
# `graphify-out` paths in some files while others use `.graphify-out`, which
# leaves stray untracked dirs in every project. Re-run after any update.
_fixup_graphify() {
  local dir="$SKILLS_DIR/graphify"
  [[ -d $dir ]] || { echo "  ✓ not installed, skipping graphify-fixup"; return 0; }
  run "perl -pi -e 's/(?<!\\.)graphify-out/.graphify-out/g' '$dir'/SKILL.md '$dir'/references/*.md 2>/dev/null"
}

# raw <name> <url>  ->  $SKILLS_DIR/<name>/SKILL.md   (accepts GitHub blob URLs)
_raw() {
  local name="$1" url="$2" dest
  url="$(printf '%s' "$url" | sed -e 's#//github\.com/#//raw.githubusercontent.com/#' -e 's#/blob/#/#')"
  dest="$SKILLS_DIR/$name"
  run "mkdir -p '$dest'"
  run "curl -fsSL '$url' -o '$dest/SKILL.md'"
  scan_ok "$dest" || { run "rm -rf '$dest'"; return 1; }
}

# git-run <repo> <dest> <setup-cmd>   clone, scan, then run setup inside it
_git_run() {
  local repo="$1" dest="$2" setup="$3"
  [[ -e $dest ]] && { echo "  ✓ exists, skipping $dest"; return 0; }
  run "git clone --single-branch --depth 1 '$repo' '$dest'"
  scan_ok "$dest" || { run "rm -rf '$dest'"; return 1; }
  run "cd '$dest' && $setup"
}

# git-cmd <repo> <post-clone-cmd>     clone into the skills dir, scan, run cmd
_git_cmd() {
  local repo="$1" cmd="$2" dest
  dest="$SKILLS_DIR/$(basename "$repo" .git)"
  [[ -e $dest ]] && { echo "  ✓ exists, skipping $dest"; return 0; }
  run "git clone --depth 1 '$repo' '$dest'"
  scan_ok "$dest" || { run "rm -rf '$dest'"; return 1; }
  run "cd '$dest' && $cmd"
}

# git-clone <repo>                    clone into the skills dir (no build step)
_git_clone() {
  local repo="$1" dest
  dest="$SKILLS_DIR/$(basename "$repo" .git)"
  [[ -e $dest ]] && { echo "  ✓ exists, skipping $dest"; return 0; }
  run "git clone --depth 1 '$repo' '$dest'"
  scan_ok "$dest" || { run "rm -rf '$dest'"; return 1; }
}

echo "Installing skills into $SKILLS_DIR"
[[ $DRY_RUN -eq 1 ]] && echo "(dry run — nothing will be executed)"
[[ $DRY_RUN -eq 1 ]] || mkdir -p "$SKILLS_DIR"
# shellcheck source=/dev/null
source "$HERE/Skillsfile"
echo "✔ done"
