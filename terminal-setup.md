# Terminal Setup — Recommended

Zellij + Ghostty + neovim + gh-dash, tuned for cross-repo projects and always-on services. Companion to the worktree doctrine in [`zsh/README.md`](zsh/README.md).

## 1. Sessionizer jumps to a repo or a defined project

Install zoxide + zellij-smart-sessionizer and bind one key to it. Point a session at the repo you're actually working (`docs`, `zs`), or at a defined cross-repo set (`proj <name> <repos…>`) — not at the parent-of-everything. The parent `~/Documents/github/influxdata/` is where zoxide indexes and where shared tooling lives (Section 3), but it's too broad to be a session or editor root: rooting there sweeps every clone into one workspace.

## 2. Cross-repo projects: one session, tabs by activity

Give each project a layout KDL and organize its tabs by *activity* — editor, PRs, shell — **not one tab per repo**. Then:

- Root neovim at the repo you're working (`cd <repo> && nvim .`), not the parent — Telescope (`telescope.nvim`) then searches just that repo, focused and fast. To reach a sibling repo when a task needs it, give Telescope `search_dirs` for that path, or open a picker result straight into an nvim split (`Ctrl-v` / `Ctrl-x`). That keeps the common case focused and makes cross-repo an on-demand reach, not a permanent sweep across every clone.
- gh-dash scoped to the project's repos shows their PRs in one view.
- Cross-*branch* work → git worktrees (see the doctrine). Cattle live in `~/.worktrees/<repo>/`.

## 3. Shared tooling and env at the parent

One `.envrc` at `~/Documents/github/influxdata/` covers every repo beneath it — direnv walks up from wherever you are and loads the nearest ancestor `.envrc`. Use it to put shared tooling on PATH (e.g. `docs-tooling`) and shared env (`INFLUX_*`, `ORG`) in one place, available across all clones. This is the parent's real job: tooling *scope*, not editor root. Keep the `.envrc` only at the parent — a repo-level one overrides it unless it calls `source_up`.

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
| Shared tooling/env | direnv `.envrc` at the parent (covers all repos below) |
| Services | docker compose (not panes) |
| Durable layouts | Zellij session serialization |

*Alternative for terminal-tied services: tmux's server model (`tmux new -d -s bg …`) keeps a detached process alive independent of any client — better than Zellij for that one job, but for always-on, docker still wins.*

## References

- [zellij-smart-sessionizer](https://github.com/demestoss/zellij-smart-sessionizer)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [Zellij CLI actions — `new-tab --cwd`/`--layout`](https://zellij.dev/documentation/cli-actions)
