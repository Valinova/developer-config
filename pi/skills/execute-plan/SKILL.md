---
name: execute-plan
description: Implements an approved phased plan through bounded Codex agent passes, verification, and coherent commits. Use only when the user explicitly asks to execute an approved plan.
---

# Execute Plan — Pi

Before choosing seats or effort, read
`~/Development/developer-config/pi/model-defaults.md`
and its required canonical policy sections.

Implement the approved plan only. Plan generation, adversarial final review,
push, and PR creation belong to their own workflows.

The active Pi model is the orchestrator — Grok 4.6 by default (harness seats
in `model-selection.md`). Implementation is a Codex `Agent`; Grok or DeepSeek
`Agent` when the user names one, Anthropic only when the user names it.

## Preamble

State first that no external call runs during implementation — phases verify
locally, full pre-commit gate included (`model-selection.md` "External calls").

## Start

1. Verify the current branch and the user's branch instructions.
2. Follow `git-operations.md`: work on the current branch, including an explicitly
   directed default-branch change. Obtain approval before any branch or
   worktree creation or switch the user has not already directed.

## Phase loop

For each bounded pass:

1. Snapshot worktree provenance.
2. Delegate implementation to an `Agent` with the seat and rung selected
   under `model-selection.md` "Harness seats", "Roster", and "Effort". Resolve
   the exact model ID and dispatch mechanics through the Pi model-defaults
   card.
3. Review the exact agent diff for correctness, plan compliance, and the
   user-supplied North Star.
4. Apply the principles §2–§3 simplicity gate to the diff: remove anything
   that does not trace to the plan or earn its place.
5. Run the phase verification and the repository's full pre-commit check
   in your own shell and read the exit code. An implementer's report of a
   green gate is a claim, not evidence; never commit on it.
6. Stage only the phase's files and create a coherent, descriptive commit.

Keep writing passes sequential unless their file allowlists are disjoint
(worktree isolation for genuinely parallel passes). Continue through every
phase. Do not interrupt the user for noncritical choices: take reasonable
defaults and record them in the final report. Escalate only per the
principles §4 escalation bar.

After the final phase, hand off under `model-selection.md` "External
calls", stating whether a call is warranted and its scope; there is no
closing review pass here, and a fix-verify iteration on a landed phase does
not re-run the full phase loop.
