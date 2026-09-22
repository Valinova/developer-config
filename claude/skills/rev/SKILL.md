---
name: rev
description: Runs a standalone or composable branch review as one cross-family review (code-simplifier plus the principles audit) with agreed fixes committed. Use only when the user explicitly invokes "rev" or requests this review workflow.
---

# Adversarial Review — Claude

Before choosing seats or effort, read
`~/Development/developer-config/instructions/model-selection.md` and
`~/Development/developer-config/instructions/codex-delegation.md` in full —
neither is always-loaded (`dispatch-bootstrap.md` owns the read rule).

Review the committed branch. This workflow is independently runnable and is
also the review stage composed by `longrun`; it never invokes `longrun` itself.
Invoking it authorizes the code-simplifier pass and the commits required for
the agreed fixes.

## Preamble

State first the reviewer seat and rung chosen, and why (`model-selection.md`
"External calls" for who, "Effort" for the rung, "Announce-then-proceed
preamble").

When invoked through `claude -p` in **external-review-only mode**, Claude is
the cross-family reviewer already selected by the caller. Perform the shared
`code-simplifier` review and principles audit described in step 1 below,
return complete findings to the caller, and stop before the normal sequence.
Do not dispatch another reviewer, edit files, stage, or commit. Discovery
subagents are allowed only when the caller's brief authorizes them.

For a normal invocation, verify the branch before modifying files.
Follow `git-operations.md`: honor the user's branch direction, including work on
the default branch; do not create or switch branches or worktrees without
existing authorization. Work on the current branch otherwise.

1. **Review.** Dispatch one cross-family reviewer — Astra via the Codex
   wrappers (`model-selection.md` "External calls"), rung per "Effort". The
   reviewer runs the shared `code-simplifier` skill and the principles audit
   over the committed diff (the engineering principles and the repo's `AGENTS.md`/`CLAUDE.md`
   guidance: correctness and regressions, with emphasis on simplicity,
   intentionality, canonical ownership, and removal of unnecessary scope) and
   returns one findings list. The orchestrator never reviews its own diff.
2. **Agree.** Read the findings once; keep what is valuable and give each
   dropped finding a one-line reason in the final report. No second review, no
   re-triage loop. Escalate only unresolved critical choices under principles
   §4.
3. **Fix.** An Opus 5.5 implementer subagent (`model-selection.md` "Harness
   seats") applies the kept set; the orchestrator does no mechanical editing
   itself.
4. **Verify and commit.** The Claude orchestrator runs the full check
   battery, stages exact files, and creates coherent descriptive commits.

If the kept findings require several passes, execute them here as a bounded
review-fix plan; do not recurse into `longrun`. Do not push or open a PR.
