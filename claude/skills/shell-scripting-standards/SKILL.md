---
name: shell-scripting-standards
description: Personal shell and bash scripting conventions. Apply whenever writing or editing shell scripts — .sh files, bash one-liners destined for a script, CI shell steps, or any task that produces or modifies shell code. Triggers on shebangs, set -euo pipefail, shellcheck/shfmt usage. Use this automatically when authoring shell scripts, even if the user doesn't name a linter.
---

# Shell Scripting Standards

All scripts must start with `set -euo pipefail`.

Lint and format before considering a script done:

```bash
shellcheck script.sh && shfmt -d script.sh
```

`shfmt -i 2 -w script.sh` formats with two-space indentation.
