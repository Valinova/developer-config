---
name: rev
description: Runs a standalone or composable branch review as one cross-family review (code-simplifier plus the principles audit) with agreed fixes committed. Use only when the user explicitly invokes "rev" or requests this review workflow.
disable-model-invocation: true
---

# Adversarial Review — Grok Build

Before choosing seats or effort, read
`~/Development/developer-config/grok/model-defaults.md`
and its required canonical policy sections.

Review the committed branch. This workflow is independently runnable and is
also the review stage composed by `longrun`; it never invokes `longrun` itself.
Invoking it authorizes the code-simplifier pass and the commits required for
the agreed fixes.

The active Grok session orchestrates. Use `grok/model-defaults.md` for
reviewer transports; the implementing lane applies the fixes.

## Preamble

State first the reviewer seat and rung chosen, and why (`model-selection.md`
"External calls" for who, "Effort" for the rung, "Announce-then-proceed
preamble").

## Sequence

Verify the branch before modifying files.
Follow `git-operations.md`: honor the user's branch direction, including work on
the default branch; do not create or switch branches or worktrees without
existing authorization. Work on the current branch otherwise.

1. **Review.** Dispatch one cross-family reviewer — seat per
   `model-selection.md` "External calls", rung per "Effort"; Fable as the
   reviewer leads Opus discovery subagents per "Roster". The reviewer runs the
   shared `code-simplifier` skill and the principles audit over the committed
   diff (the engineering principles and the repo's `AGENTS.md`/`CLAUDE.md`
   guidance: correctness and regressions, with emphasis on simplicity,
   intentionality, canonical ownership, and removal of unnecessary scope) and
   returns one findings list. The orchestrator never reviews its own diff.
2. **Agree.** Read the findings once; keep what is valuable and give each
   dropped finding a one-line reason in the final report. No second review, no
   re-triage loop. Escalate only unresolved critical choices under principles
   §4.
3. **Fix.** An implementer subagent (seat per `model-selection.md` "Harness
   seats") applies the kept set; the orchestrator does no mechanical editing
   itself.
4. **Verify and commit.** The Grok orchestrator runs the full check
   battery, stages exact files, and creates coherent descriptive commits.

If the kept findings require several passes, execute them here as a bounded
review-fix plan; do not recurse into `longrun`. Do not push or open a PR.
