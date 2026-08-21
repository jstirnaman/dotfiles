# Worktree & Project Doctrine

## The rule

**A worktree is a *slot* or it's *cattle*. A topic is a *branch*.**
If I'm naming a worktree to remember it later, it should have been a branch.

The point isn't tidiness — it's attention. Every kept worktree is an open loop I half-track in the background. Closing loops is the goal.

## The decision, at creation

Say it out loud: **slot or cattle?**
- "Slot" → reuse an existing one, don't create.
- "Cattle" → create with `wt` (born with a death condition).
- Can't answer instantly → it's a **branch**. Not a worktree.

## Slots — few, fixed, earned

- Long-lived, named for a standing job (`trunk`, maybe `review`), never for a topic.
- Default: **one anchor per repo**. A second must be earned over weeks.
- Count never grows; branches rotate through with `git switch`.
- Stable paths, so sessionizer and muscle memory hold.

## Cattle — many, discoverable, disposable

- Live in `~/worktrees/<repo>/…`: visible so people and agent UIs can open or
  receive their paths without having to expose hidden files.
- Machine-named if I don't care. No naming ritual.
- Die when their branch merges (`wtreap`).
- Re-enter via picker (`wtpick`), never by memory.
- **Cap: 3 live. One anchor slot. 2–3 project sessions.** Hit the cap → reap before creating.

## Branches carry topics

New idea → `git switch -c topic/x` in an existing worktree, or one line in `~/ideas.md`. Not a new directory.

## git switch

`checkout` is retired — it changed branches *and* files. Now:
`git switch <b>` · `git switch -c <b>` · `git switch -` · `git restore <f>` · `git restore --staged <f>`.
Bonus: `switch` refuses a branch already checked out elsewhere — the slot model, enforced by git.

## Cross-repo: docs-v2 · influxdb3_mcp · docs-tooling

These three repos are one ecosystem, so a task often spans all of them — treat it as one project, not three.

Open one Zellij session on the parent, `~/Documents/github/influxdata/`, with tabs by activity, not by repo: editor, PRs, shell. A tab per repo just puts you back to toggling tabs and hunting for panes.

Let the editor span the repos for you. Launch neovim once from the parent (`cd ~/Documents/github/influxdata && nvim .`); Telescope's `find_files` and `live_grep` search recursively from there, so you reach any file in any repo by typing part of its name or a line of its code — no tab-switching. (Plugins: telescope.nvim, plus oil.nvim for directory browsing.)

gh-dash shows all three repos' PRs in one view. Reserve per-repo panes only for long-running processes like dev servers, grouped in one labeled tab. Put shared env (`INFLUX_*`, tokens, org) in a `.envrc`/`mise.toml` at the parent so it loads once. Per repo: anchor slot plus branches for ongoing work, cattle for cross-cutting experiments.

## Stack

| Need | Tool |
|---|---|
| Jump to project | zoxide + zellij-smart-sessionizer (target parent dirs) |
| Re-enter worktree | fzf (`wtpick`) |
| Branch movement | git switch / restore |
| Cattle lifecycle | wt / wtrm / wtreap |
| Per-project env | direnv or mise (at parent) |
| Durable layouts | Zellij `session_serialization true` |
| PR/issue focus | gh-dash, scoped to the 3 repos |
| Editor workspace | nvim + auto-session |

New tabs/panes come from a template (keybind/alias), never a manual split.

---

The `wt` / `wtcd` / `wtpick` / `wtrm` / `wtreap` functions live in [`functions/`](functions/). They're autoloaded automatically: `bash_aliases` (sourced by `~/.zshrc`) runs `autoload -Uz $DOTFILES/zsh/functions/*(.:t)` inside a zsh guard, so any new file dropped in `functions/` registers on the next shell — no per-function edit needed.
