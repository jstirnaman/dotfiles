# Terminal Stack & Workflows

How the terminal setup fits together, and the exact commands and keys to drive it.
Companion to `terminal-setup.md` (install) and `zsh/README.md` (worktree doctrine).

## Concepts: how the layers nest

Four layers, each doing one job. Each layer contains the next.

1. **Ghostty window** — the macOS window. Keep one; you rarely need more.
2. **Zellij session** — a whole workspace, usually one project. Sessions are
   independent and persistent. You switch between them; you do not nest them.
   Only one session is attached in the window at a time.
3. **Tab** — an activity inside a session (editor, tests, a service, gh-dash).
4. **Pane** — a split inside a tab.

The rule that resolves most confusion: to get another workspace, you do **not**
open another Ghostty window. You open or switch to another Zellij *session*. An
editor, a test runner, gh-dash — each is a tab or pane inside a session, never a
separate OS window.

## The stack

| Tool | Role |
|---|---|
| Ghostty | Terminal emulator — draws the window, handles input. |
| Zsh | The shell — runs your commands. |
| Zellij | Multiplexer — holds sessions, tabs, panes. |
| zoxide + zellij-smart-sessionizer (`zs`) | Jump to a project dir → its session. |
| `proj` | Build a cross-repo session, one tab per repo. |
| `workstreams` | Open the main session (docs / code / background tabs). |
| neovim + telescope + auto-session | Editor that spans repos and restores state. |
| gh-dash + prr | PR triage (`Alt g` floats it) and editor-native reviews. |
| revdiff | Editor-native reviews of local diffs. |
| git worktrees + `wt`/`wtpick`/`wtrm`/`wtreap` | Slot-vs-cattle worktrees. |
| docker compose | Runs InfluxDB/Telegraf as services. |
| `~/dotfiles` + `install.sh` | Source of truth for the configs above. |

## Entry points (run these from a plain shell)

Each command opens or reattaches a session. Run them from a plain Ghostty shell,
**not** from inside Zellij — they detect an active session and refuse.

| Command | Opens |
|---|---|
| `zs` | Pick a project directory (zoxide + fzf), attach or create its session. |
| `proj <name> <repo…>` | A cross-repo session named `<name>`, one tab per repo. |
| `workstreams` | The main session (`workstreams` layout: docs / code / background tabs). |

All three attach if the session already exists, otherwise create it. Because a
session is a top-level workspace, you cannot launch one from inside another: run
`proj` or `workstreams` while already in a session and it prints "already inside a
Zellij session" and does nothing. To move between sessions, use the session
manager or detach (see below).

## Moving around inside Zellij

Your default mode is **locked** — keys pass straight to the shell. Press
`Ctrl g` to enter **normal** mode, then a single letter to act. `Ctrl g` again
re-locks.

| Action | Keys |
|---|---|
| Unlock / re-lock | `Ctrl g` |
| New tab | `Ctrl g` `t` `n` |
| New pane | `Ctrl g` `p` `n` |
| Move between panes / tabs | `Alt ←` / `Alt →` (works while locked) |
| Go to tab N | `Ctrl g` `t` `<number>` |
| Detach (return to a plain shell) | `Ctrl g` `o` `d` |
| Session manager (switch or create sessions) | `Ctrl g` `o` `w` |

The session manager (`Ctrl g` `o` `w`) is how you jump between sessions without
detaching — for example from your `mcp-e2e` project to `main`.

## Getting gh-dash

`Alt g` floats [gh-dash](https://gh-dash.dev) on top of the focused pane,
cwd-aware to that pane's repo (bound in `zellij/config.kdl`). It's not a
dedicated tab or session — float it from wherever you're working, close it
when done (`close_on_exit` is set).

In gh-dash: `R` = prr review, `a` = Claude pass, `A` = Copilot review, `v` = approve.

## Workflows

### Start work on a project

1. From a plain shell, run `zs` and pick the project. Its session opens.
2. In the editor tab, run `nvim .`. auto-session restores your buffers and layout.
3. Open files with `<Space>ff`; search text across the repo with `<Space>fg`.
4. When done for now, detach with `Ctrl g` `o` `d`. The session keeps running.

### Cross-repo project (mcp_server + starfleet)

1. From a plain shell, run `proj mcp-e2e influxdb3_mcp_server starfleet`.
2. You land in a session with one tab per repo. Switch tabs with `Alt ←` / `Alt →`.
3. Edit in one tab, run tests in another, bring up the service in a third.
4. To reopen later, run `proj mcp-e2e …` again — it reattaches.

### Review PRs

Press `Alt g` in any pane to float gh-dash in that pane's repo. No session or
tab switch needed.

### Ephemeral worktree task

1. Run `wtcd fix/typo` — creates a branch and a hidden worktree, then cd's in.
2. Make the change, push, open the PR.
3. After it merges, run `wtreap` to remove merged worktrees (prints a count).

### Deploy config changes

- Edit files under `~/dotfiles/…`, then run `cd ~/dotfiles && ./install.sh` to
  re-render the zellij, ghostty, and gh-dash configs.
- neovim config is symlinked (live) — just restart nvim.
- Shell startup files (`.zshenv`, `.zshrc`, `.zprofile`) are edited directly in
  `~`, not in the repo.
