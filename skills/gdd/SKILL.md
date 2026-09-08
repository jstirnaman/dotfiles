---
name: gdd
description: Writes, edits, or revises documentation to follow Google Developer Documentation style — active voice, present tense, semantic line feeds, cause-before-effect ordering, one claim per sentence. Use when drafting or editing developer docs, READMEs, API references, tutorials, or any technical explanation, or when the user invokes /gdd.
---

# Google Developer Documentation style

Rewrite or draft the requested content so every sentence is informative, not persuasive. The reader is trying to get something done; the text exists to tell them what's true and what to do about it, not to convince or entertain them.

## Rules

Apply all of these. When two rules conflict, resolve in favor of clarity for the reader over brevity.

1. **Active voice, present tense.** "The client sends a request" not "A request is sent by the client." Describe the system as it behaves now, not as it will behave or behaved historically, unless the content is specifically about a past or future state (changelogs, migration guides).

2. **Cause before effect, not after.** State the fact first, then the consequence, then the resulting action. Don't bury the cause in a trailing clause after the reader has already been told what to do.
   - Wrong: "Restart the server, because the config change doesn't take effect until reload."
   - Right: "Config changes don't take effect until the server reloads. Restart the server to apply them."

3. **Subject as the actor, not the abstraction.** The thing doing the work — the plugin, the sync, the function — is the grammatical subject. Don't nominalize the process into an abstract noun and make *that* the subject.
   - Wrong: "Discovery of new devices happens automatically."
   - Right: "The daemon discovers new devices automatically."

4. **One claim per sentence.** Split compound sentences joined by "and" or "because" into separate sentences. Each sentence carries exactly one fact or instruction. This keeps semantic-line-feed diffs small and rereading cheap.

5. **Semantic line feeds.** Break lines at clause or sentence boundaries, not at a fixed column. Each line should be a unit a reader (or a diff) can evaluate on its own.

6. **No rhetorical framing.** Don't open with a question, a hook, or a claim about how important/powerful/exciting something is. Don't tell the reader how they'll feel. State the fact.
   - Cut: "Ever wondered how caching can transform your app's performance?"
   - Keep: "Caching reduces repeated database reads."

7. **Technical jargon is precision, not decoration.** Use the exact term the reader needs (mutex, idempotent, backpressure) instead of a vaguer paraphrase, as long as the term is standard in the domain. Don't explain jargon the target audience already owns; do define a term the first time it's load-bearing for a less experienced reader.

8. **Metaphors illustrate; they don't replace explanation.** A metaphor may accompany a precise technical statement to build intuition ("a message queue works like a mailbox: messages wait until read"). A metaphor never stands in *for* the technical statement, and never carries meaning the surrounding text doesn't already establish literally.

9. **Cut any paragraph that doesn't change what the reader would do.** If removing a sentence or paragraph leaves the reader's next action identical, remove it. This includes throat-clearing intros, restated summaries, and "as we can see" transitions.

10. **No dramatic effect.** No superlatives, no exclamation points, no "simply" or "just" (they're rarely simple for the reader struggling with them), no marketing adjectives (seamless, powerful, robust, cutting-edge). Report what the system does and what the reader must do.

## Process

1. **Identify the reader's task.** What is the reader trying to do or decide after reading this? Keep that as the filter for rule 9.
2. **Draft or rewrite** applying rules 1–8 sentence by sentence.
3. **Self-review pass.** Re-read the output specifically checking for:
   - Any passive-voice sentence that isn't deliberately describing an action whose actor is unknown or irrelevant.
   - Any sentence with "and"/"because" joining two separate claims.
   - Any paragraph you could delete without changing the reader's next action.
   - Any rhetorical question, hook, or emotional appeal.
   - Any nominalized abstraction ("the implementation of X allows...") that should be recast with a concrete actor.
4. **Output the revised content**, not a description of the changes, unless the user asked for a diff or an explanation of what changed.

## Before / after

**Rhetorical framing + effect-before-cause + nominalization:**

> Have you ever struggled with flaky deploys? The seamless integration of our new rollback system means that recovery from a bad release happens automatically, giving your team peace of mind.

Rewrite:

> A bad release triggers automatic rollback. The system restores the previous version without manual intervention.

**Compound sentence + passive voice:**

> The cache is invalidated when a write occurs and this can cause a brief spike in read latency because downstream reads miss the cache.

Rewrite:

> A write invalidates the cache. Downstream reads then miss the cache. Read latency spikes briefly until the cache repopulates.

## Scope

Applies to prose: READMEs, guides, tutorials, conceptual docs, API descriptions, comments meant for human readers. Code samples, command syntax, and literal API signatures are not subject to these style rules — only the surrounding explanation is.
