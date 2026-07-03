---
name: python-standards
description: Personal Python toolchain and conventions. Apply whenever working in Python — writing, editing, linting, type-checking, testing, or setting up a Python project, package, or virtualenv. Triggers on .py files, pyproject.toml, requirements, uv/ruff/ty/pytest usage, or any task involving Python dependencies, packaging, or supply chain. Use this automatically when the work is clearly Python, even if the user doesn't name a specific tool.
---

# Python Standards

**Runtime:** 3.13 with `uv venv`

| purpose | tool |
|---------|------|
| deps & venv | `uv` |
| lint & format | `ruff check` · `ruff format` |
| static types | `ty check` |
| tests | `pytest -q` |

**Always use uv, ruff, and ty** over pip/poetry, black/pylint/flake8, and mypy/pyright — they're faster and stricter. Configure `ty` strictness via `[tool.ty.rules]` in pyproject.toml. Use `uv_build` for pure Python, `hatchling` for extensions.

Tests in `tests/` directory mirroring package structure.

## Supply chain
- `pip-audit` before deploying
- Pin exact versions (`==` not `>=`)
- Verify hashes with `uv pip install --require-hashes`
