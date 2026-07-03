# Terminal Setup — Recommended

Zellij + Ghostty + neovim + gh-dash, tuned for cross-repo projects and always-on services. Companion to the worktree doctrine in [`zsh/README.md`](zsh/README.md).

## 1. Sessionizer targets the parent workspace, not a repo

Install zoxide + zellij-smart-sessionizer and bind one key to it. Point it at **parent dirs**, e.g. `~/Documents/github/influxdata/`, not individual repos. One project = one session over the parent. (Targeting single repos splits a cross-repo project across multiple sessions — the scatter just moves.)

## 2. Cross-repo projects: one session, tabs by activity

Give each project a layout KDL and organize its tabs by *activity* — editor, PRs, shell — **not one tab per repo**. Then:

- One neovim launched from the parent (`cd ~/Documents/github/influxdata && nvim .`) spans every repo. Telescope (the neovim fuzzy-finder plugin, `telescope.nvim`) searches recursively from where you launched: `find_files` opens any file by name and `live_grep` jumps to any line by its text — across all the repos at once, so you switch repos by fuzzy-finding, not tab-toggling.
- gh-dash scoped to the project's repos shows their PRs in one view.
- Cross-*branch* work → git worktrees (see the doctrine). Cattle live in `~/.worktrees/<repo>/`.

## 3. Shared env at the parent

Put `direnv` or `mise` at `~/Documents/github/influxdata/` so `INFLUX_*` / tokens / org load once across every repo, instead of per-repo drift.

## 4. Services run under docker, never as Zellij panes

InfluxDB + Telegraf stay on `docker compose up -d` (already the case). A pane process dies on close/reboot; a supervisor doesn't.

The "background" Zellij session is **monitoring-only** — `docker compose logs -f`, an `influx` CLI, `telegraf --test`, maybe `btop`/`ctop`. It *attaches to* the running services, so closing it never kills the DB. Bind a key to swap to it; keep it out of sight otherwise.

## 5. Make the layout durable (anti-scatter)

- Zellij config: `session_serialization true`, `serialize_pane_viewport true` — the intended layout survives restarts, ad-hoc splits don't.
- Rule: new tabs/panes come from a **template** (keybind or alias), never a manual split. Treat a manual `Ctrl-p n` as the smell.

## Tool checklist

| Need | Tool |
|---|---|
| Jump to project | zoxide + zellij-smart-sessionizer (parent dirs) |
| Cross-repo editing | neovim + telescope.nvim (+ auto-session) |
| PR/issue focus | gh-dash, scoped per project |
| Worktree lifecycle | git worktree + `wt`/`wtrm`/`wtreap` |
| Branch movement | git switch / restore |
| Per-project env | direnv or mise (at parent) |
| Services | docker compose (not panes) |
| Durable layouts | Zellij session serialization |

*Alternative for terminal-tied services: tmux's server model (`tmux new -d -s bg …`) keeps a detached process alive independent of any client — better than Zellij for that one job, but for always-on, docker still wins.*

## References

- [zellij-smart-sessionizer](https://github.com/demestoss/zellij-smart-sessionizer)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [Zellij CLI actions — `new-tab --cwd`/`--layout`](https://zellij.dev/documentation/cli-actions)
