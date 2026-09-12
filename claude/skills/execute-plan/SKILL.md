---
name: execute-plan
description: Implements an approved phased plan through bounded Codex passes, verification, and coherent commits. Use only when the user explicitly asks to execute an approved plan.
---

# Execute Plan — Claude

Before choosing seats or effort, read
`~/Development/developer-config/instructions/model-selection.md` and
`~/Development/developer-config/instructions/codex-delegation.md` in full —
neither is always-loaded (`dispatch-bootstrap.md` owns the read rule).

Implement the approved plan only. Plan generation, adversarial final review,
push, and PR creation belong to their own workflows.

The active Claude model (Fable 5.1) is the orchestrator; it is not pinned
here.

## Preamble

State first that no external call runs during implementation — phases verify
locally, full pre-commit gate included (`model-selection.md` "External calls").

## Start

1. Verify the current branch and the user's branch instructions.
2. Follow principles §7: work on the current branch, including an explicitly
   directed default-branch change. Obtain approval before any branch or
   worktree creation or switch the user has not already directed.

## Phase loop

For each bounded pass:

1. Snapshot worktree provenance.
2. Delegate through the configured implementation lane with the seat and
   rung from `model-selection.md` "Harness seats", "Roster", and "Effort".
   Native Claude subagents inherit session effort; when the selected rung
   differs, follow "The lane follows the effort" instead of changing the
   interactive session.
3. Review the exact implementer diff for correctness, plan compliance, and the
   user-supplied North Star.
4. Apply the principles §2–§3 simplicity gate to the diff: remove anything
   that does not trace to the plan or earn its place.
5. Run the phase verification and the repository's full pre-commit check
   in your own shell and read the exit code. An implementer's report of a
   green gate is a claim, not evidence; never commit on it.
6. Stage only the phase's files and create a coherent, descriptive commit.

Keep writing passes sequential unless their file allowlists are disjoint.
Continue through every phase. Do not interrupt the user for noncritical
choices: take reasonable defaults and record them in the final report.
Escalate only per the principles §4 escalation bar.

After the final phase, hand off under `model-selection.md` "External
calls", stating whether a call is warranted and its scope; there is no
closing review pass here, and a fix-verify iteration on a landed phase does
not re-run the full phase loop.
