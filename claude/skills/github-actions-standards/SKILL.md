---
name: github-actions-standards
description: Personal GitHub Actions security and maintenance conventions. Apply whenever creating or editing CI/CD workflows — .github/workflows/ files, action pinning, Dependabot config, or any task involving GitHub Actions security. Triggers on workflow YAML, uses: statements, actionlint/zizmor usage. Use this automatically when editing Actions workflows, even if the user doesn't mention security.
---

# GitHub Actions Standards

Pin actions to SHA hashes with version comments:

```yaml
uses: actions/checkout@<full-sha>  # vX.Y.Z
```

Set `persist-credentials: false`.

Scan workflows before committing:

```bash
actionlint .github/workflows/   # syntax + correctness
zizmor .github/workflows/        # security audit
```

Configure Dependabot with 7-day cooldowns and grouped updates.
