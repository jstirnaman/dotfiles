# ── git worktree helpers ────────────────────────────────────────────────
# wt <branch>  — create a NEW branch off the repo's default branch in a
#                worktree at  <repo>.worktrees/<branch-slashes-as-dashes>
#                and print the worktree path.
#
# Layout, e.g. inside ~/github/influxdata/docs-v2:
#   wt claude/foo  ->  ~/github/influxdata/docs-v2.worktrees/claude-foo
# 
# Example scenario:
#
# cd ~/path/to/dotfiles
# git checkout -b add-worktree-helpers
# mkdir -p zsh/functions
# paste the snippet into zsh/functions/worktree.zsh (and source it from .zshrc)
# git add zsh/functions/worktree.zsh
# git commit -m "Add wt/wtcd git worktree helpers"
# git push -u origin add-worktree-helpers
# gh pr create --fill
#

wt() {
  emulate -L zsh
  local branch=$1
  if [[ -z $branch ]]; then
    print -u2 "usage: wt <branch-name>"
    return 2
  fi

  # Repo target: infer from cwd
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    print -u2 "wt: not inside a git repository"
    return 1
  }

  # Slash handling: flatten to dashes for the directory name
  local dir=${branch//\//-}

  # Consistent location: sibling  <repo>.worktrees/<dir>
  local wt_path=${repo_root}.worktrees/${dir}
  if [[ -e $wt_path ]]; then
    print -u2 "wt: $wt_path already exists"
    return 1
  fi

  # Branch mode: new branch only, from the repo default branch
  local def
  def=$(git -C "$repo_root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  def=${def#origin/}
  if [[ -z $def ]]; then
    if   git -C "$repo_root" show-ref --verify --quiet refs/remotes/origin/main;   then def=main
    elif git -C "$repo_root" show-ref --verify --quiet refs/remotes/origin/master; then def=master
    else print -u2 "wt: could not determine default branch"; return 1
    fi
  fi

  git -C "$repo_root" worktree add -b "$branch" "$wt_path" "origin/$def" >/dev/null || return

  # Post-create: print path only
  print -r -- "$wt_path"
}

# wtcd <branch> — same as wt, then cd into the new worktree
wtcd() { local p; p=$(wt "$1") && cd "$p"; }
