---
description: Draft a pull request description structured as What changed / Why / Impact / Verification, then open the PR (or write a .pr.md draft if remote access isn't available).
argument-hint: [base branch, issue/ticket, or instructions]
---

Apply the `pr-body` skill to draft the PR description for the current branch's changes against the base branch given in the arguments (default to the repo's main branch if none is given).

1. Gather facts: `git status`, `git diff` against the merge-base, and `git log` for the commit history on this branch. Use these — not guesses — for What changed, Impact, and Verification.
2. Draft the body per the `pr-body` skill's four sections.
3. Check whether a PR can actually be opened: a `github`/`origin`-style remote exists, a forge CLI (e.g. `gh`) is installed and authenticated, and the branch can be pushed. If any of that is missing or you don't have permission to push/open a PR, don't attempt it.
   - **Remote access available**: push the branch if needed and open the PR (e.g. `gh pr create`) with the drafted body, following this repo's `git-workflow` conventions. Confirm with the user before pushing or opening, per standard practice for actions visible to others.
   - **Remote access not available**: write the drafted body to `.pr.md` at the repo root instead (create it if missing, overwrite if present) and tell the user it's a local draft they can use when they open the PR themselves.

$ARGUMENTS
