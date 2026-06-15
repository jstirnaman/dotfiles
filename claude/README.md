# Claude config

Personal global Claude config, refactored for progressive disclosure.

`CLAUDE.md` is loaded into context on **every** session, so it stays lean —
core principles, writing style, and dev philosophy only. Everything
context-specific (per-language toolchains, code-quality bar, git workflow)
lives in `skills/` and loads on demand when the relevant work appears.

## Layout

```
claude/
├── CLAUDE.md                 # always-on: principles, writing style, philosophy
├── install.sh                # symlinks this into ~/.claude
└── skills/
    ├── code-quality-standards/   # hard limits, testing, error handling, CLI tools
    ├── git-workflow/             # commits, PRs, hooks, worktrees
    ├── python-standards/         # uv, ruff, ty, pytest
    ├── node-typescript-standards/# oxlint, oxfmt, vitest, tsconfig
    ├── rust-standards/           # style, type design, cargo lints
    ├── shell-scripting-standards/# set -euo pipefail, shellcheck, shfmt
    └── github-actions-standards/ # SHA pinning, zizmor, dependabot
```

## Install

```bash
./install.sh
```

Symlinks `CLAUDE.md` and each skill into `~/.claude`, backing up any existing
real files to `*.bak.<timestamp>`. Because they're symlinks, editing files in
this repo updates your live config immediately. Re-runnable.

## Notes

- Skills load by context inference. `code-quality-standards` and `git-workflow`
  are cross-cutting (not tied to one language), so watch that they trigger when
  expected. If they under-trigger, either strengthen their `description:` lines
  or move that content back inline into `CLAUDE.md`.
- Full original is preserved in git history (and as `~/.claude/CLAUDE.md.bak.*`
  after first install).
