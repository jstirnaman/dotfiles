---
name: code-quality-standards
description: Personal cross-language code-quality bar — hard limits, zero-warnings policy, comments, error handling, code review, and testing philosophy, plus preferred CLI tools and dependency version lookup. Apply whenever writing, editing, reviewing, or testing code in any language, or searching a codebase. Triggers on code review, writing tests, handling errors, adding dependencies, or reaching for grep/find. Use this automatically during any substantive coding or review work, even if the user doesn't ask for a standard. For language-specific toolchains, also consult the matching language skill (python-standards, rust-standards, node-typescript-standards).
---

# Code Quality Standards

Cross-language quality bar. For language-specific toolchains, also load the matching skill (`python-standards`, `rust-standards`, `node-typescript-standards`, `shell-scripting-standards`).

## Hard limits
1. ≤100 lines/function, cyclomatic complexity ≤8
2. ≤5 positional params
3. 100-char line length
4. Absolute imports only — no relative (`..`) paths
5. Google-style docstrings on non-trivial public APIs

## Zero warnings policy
Fix every warning from every tool — linters, type checkers, compilers, tests. If a warning truly can't be fixed, add an inline ignore with a justification comment. Never leave warnings unaddressed; a clean output is the baseline, not the goal.

## Comments
Code should be self-documenting. No commented-out code — delete it. If you need a comment to explain WHAT the code does, refactor the code instead.

## Error handling
- Fail fast with clear, actionable messages
- Never swallow exceptions silently
- Include context (what operation, what input, suggested fix)

## Reviewing code
Evaluate in order: architecture → code quality → tests → performance. Before reviewing, sync to latest remote (`git fetch origin`).

For each issue: describe concretely with file:line references, present options with tradeoffs when the fix isn't obvious, recommend one, and ask before proceeding.

## Testing
**Test behavior, not implementation.** Tests should verify what code does, not how. If a refactor breaks your tests but not your code, the tests were wrong.

**Test edges and errors, not just the happy path.** Empty inputs, boundaries, malformed data, missing files, network failures — bugs live in edges. Every error path the code handles should have a test that triggers it.

**Mock boundaries, not logic.** Only mock things that are slow (network, filesystem), non-deterministic (time, randomness), or external services you don't control.

**Verify tests catch failures.** Break the code, confirm the test fails, then fix. Use mutation testing (`cargo-mutants`, `mutmut`) to verify systematically. Use property-based testing (`proptest`, `hypothesis`) for parsers, serialization, and algorithms.

## Adding dependencies
When adding dependencies, CI actions, or tool versions, always look up the current stable version — never assume from memory unless the user provides one.

## CLI tools

| tool | replaces | usage |
|------|----------|-------|
| `rg` (ripgrep) | grep | `rg "pattern"` - 10x faster regex search |
| `fd` | find | `fd "*.py"` - fast file finder |
| `ast-grep` | - | `ast-grep --pattern '$FUNC($$$)' --lang py` - AST-based code search |
| `shellcheck` | - | `shellcheck script.sh` - shell script linter |
| `shfmt` | - | `shfmt -i 2 -w script.sh` - shell formatter |
| `actionlint` | - | `actionlint .github/workflows/` - GitHub Actions linter |
| `zizmor` | - | `zizmor .github/workflows/` - Actions security audit |
| `prek` | pre-commit | `prek run` - fast git hooks (Rust, no Python) |
| `wt` | git worktree | `wt switch branch` - manage parallel worktrees |
| `trash` | rm | `trash file` - moves to macOS Trash (recoverable). **Never use `rm -rf`** |

Prefer `ast-grep` over ripgrep when searching for code structure (function calls, class definitions, imports, pattern matching across arguments). Use ripgrep for literal strings and log messages.
