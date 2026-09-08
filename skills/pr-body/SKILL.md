---
name: pr-body
description: Structures pull request descriptions into four fixed sections — What changed, Why, Impact, Verification. Use when writing or revising a PR body, or when the user asks to draft, fill in, or fix up a pull request description.
---

# PR body structure

Write the PR description in exactly four sections, in this order. Omit a section only if it is genuinely empty (e.g., a docs-only PR has no user-facing Impact) — state that explicitly rather than deleting the heading.

## What changed

Facts about the diff, not the reasoning behind it. Short bullets or short sentences. Each line states one change: what was added, removed, renamed, or behaves differently. No justification here — that belongs in Why.

## Why

The narrative justification, in a few sentences. What problem, request, bug, or constraint drove this change. Reference the issue/ticket if one exists. This is prose, not a bullet list — it should read as a short explanation someone unfamiliar with the backstory can follow.

## Impact

Who or what is affected, and how:
- **Users/customers**: does behavior, output, or UI change for them? Is it visible or silent?
- **System behavior**: performance, error handling, backward compatibility, data migrations, config/env changes.
- If there is no user-facing or system-behavior impact (internal refactor, test-only change), say so explicitly: "No user-facing impact."

## Verification

What was checked and what the reviewer or CI should check:
- Automated tests run (which suites, and whether they're new or existing)
- Manual validation performed (steps taken, what was observed)
- Checks still needed before merge, if any (e.g., "needs a staging smoke test")

## Rules

- Pull facts from the actual diff and commit history — don't invent changes, impact, or verification steps that didn't happen.
- Keep "What changed" factual and "Why" persuasive-free but explanatory; don't blend the two.
- If impact or verification is unknown, say "not yet verified" rather than omitting the section or guessing.
- Match the terse, factual tone used elsewhere in this repo's PR conventions (see the `git-workflow` skill for commit/PR mechanics; this skill governs body structure/content only).
