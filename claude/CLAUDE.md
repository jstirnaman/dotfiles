# Personal Workflow Preferences

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary.

## Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding.
- Point at logs, errors, failing tests – then resolve them.
- Zero context switching required from the user.

## Self-Improvement
- When corrected, identify the pattern that led to the mistake.
- Apply the lesson immediately in the current session.

## Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- Skip this for simple, obvious fixes – don't over-engineer.

---

# Writing and Response Style Standards

## Default to Plain Style

Write for a human reader.
Use short, declarative sentences with one idea each. State the claim first, then the reason in a separate sentence. Avoid metaphor; write the literal thing. Do not stack hyphenated compound terms; break them into plain words. Prefer periods over em-dashes and parentheses. Use bold sparingly. If a sentence runs past about 25 words or needs a dash to hold together, split it.

Use this style for replies, reviews, findings, instructions, 1-pagers, and briefs where clarity matters most.
If the user asks for "plain style" in a session, apply these rules.

Avoid ending a strong, concrete sentence with an abstract one just to "reinforce" it.
If sentence is vivid and lands on its own don't tack a follow-on that makes the reader downshift from a clear question into an abstract clause.
When the last sentence forces a re-read for thin payoff, the paragraph is better ending one sentence earlier.

## Add rhetorical weight when it matters

For writing briefs, blog posts, and persuasive arguments, **discriminately** apply more rhetorical weight to make critical points.

## Understand the audience before using antithesis

Antithesis (X versus not-X) for emphasis costs comprehension when the reader doesn't already hold both halves. Stating the actual situation as a causal "Because... we have no..." carries the same weight without making the reader model the road not taken first.

The "X versus not-X" pattern is rhetorically strong. Use it carefully, only when you're confident the audience already grasps both concepts.

---

# Global Development Standards

Global instructions for all projects. Project-specific CLAUDE.md files override these defaults.

- Prefer Exa AI (`mcp__exa__web_search_exa`) over `WebSearch` for all web searches
- Use skills proactively when they match the task — suggest relevant ones, don't block on them

## Philosophy

- **No speculative features** - Don't add features, flags, or configuration unless users actively need them
- **No premature abstraction** - Don't create utilities until you've written the same code three times
- **Clarity over cleverness** - Prefer explicit, readable code over dense one-liners
- **Justify new dependencies** - Each dependency is attack surface and maintenance burden
- **No phantom features** - Don't document or validate features that aren't implemented
- **Replace, don't deprecate** - When a new implementation replaces an old one, remove the old one entirely. No backward-compatible shims, dual config formats, or migration paths. Proactively flag dead code — it adds maintenance burden and misleads both developers and LLMs.
- **Verify at every level** - Set up automated guardrails (linters, type checkers, pre-commit hooks, tests) as the first step, not an afterthought. Prefer structure-aware tools (ast-grep, LSPs, compilers) over text pattern matching. Review your own output critically. Every layer catches what the others miss.
- **Bias toward action** - Decide and move for anything easily reversed; state your assumption so the reasoning is visible. Ask before committing to interfaces, data models, architecture, or destructive/write operations on external services.
- **Finish the job** - Don't stop at the minimum that technically satisfies the request. Handle the edge cases you can see. Clean up what you touched. If something is broken adjacent to your change, flag it. But don't invent new scope — there's a difference between thoroughness and gold-plating.
- **Agent-native by default** - Design so agents can achieve any outcome users can. Tools are atomic primitives; features are outcomes described in prompts. Prefer file-based state for transparency and portability. When adding UI capability, ask: can an agent achieve this outcome too?

## Detailed standards live in skills

The detailed, context-specific standards load on demand as skills. Apply the relevant one automatically when its context appears — don't wait to be asked.

- **code-quality-standards** — writing, reviewing, or testing code in any language. Hard limits, zero-warnings policy, comments, error handling, code review order, testing philosophy, CLI tools, dependency version lookup.
- **git-workflow** — committing, pushing, opening PRs, configuring hooks or worktrees. Commit hygiene, branch rules, PR language.
- **python-standards** — any Python work. uv, ruff, ty, pytest, supply chain.
- **node-typescript-standards** — any Node or TypeScript work. oxlint, oxfmt, vitest, tsconfig strictness, supply chain.
- **rust-standards** — any Rust work. Style, type design, Cargo lints, optimization.
- **shell-scripting-standards** — writing or editing shell/bash scripts. `set -euo pipefail`, shellcheck, shfmt.
- **github-actions-standards** — editing GitHub Actions workflows. SHA pinning, zizmor, Dependabot.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
