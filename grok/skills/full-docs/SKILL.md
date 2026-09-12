---
name: full-docs
description: Performs a deep Grok-led documentation audit with Codex adversarial validation. Use only when the user explicitly invokes "full docs" or "full-docs".
disable-model-invocation: true
---

# Full Documentation Review — Grok Build

Before choosing seats or effort, read
`~/Development/developer-config/grok/model-defaults.md`
and its required canonical policy sections.

Select native `spawn_subagent` audit children, effort, and fan-out under
`model-selection.md` "Roster", "Effort", and "Subagent fan-out". Follow
`grok/model-defaults.md` for dispatch mechanics.

Before the audit, follow `model-selection.md` "Announce-then-proceed
preamble": state first whether any external call is warranted on the
documentation diff, and why; only if one is, its seat and rung;
then the audit scope, and the parent pipeline mode only when composed. In a
non-interactive run, put the same block at the top of the final report.

Audit the current branch for:

1. One-time documents that should be deleted or folded into canonical
   architecture documentation.
2. Mismatches between implementation and core documentation.
3. Clear improvements in correctness, consolidation, simplicity, visual
   explanation, and canonical ownership.

Implement every clear, valuable improvement. Then apply `model-selection.md`
"External calls" to the complete documentation diff through the selected
harness lane, applying only findings the orchestrator and reviewer both deem
valuable. Leave the resulting edits unstaged for the user's final review.
