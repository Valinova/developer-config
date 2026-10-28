# Execute Plan

Shared body for every harness's `execute-plan` skill. Seats, lanes, and the reviewer
come from `model-selection.md` "Harness seats"; IDs, wrappers, and sandbox
limits come from the harness's model card (`<harness>/model-defaults.md`;
Claude Code: `instructions/codex-delegation.md`).

Implement the approved plan only. Plan generation, the final review, push, and
PR creation belong to their own workflows.

## Preamble

This workflow's only external call is an interim review the approved plan names
(`dispatch-bootstrap.md` "External calls"); phases otherwise verify locally, full
pre-commit gate included. State whether the plan names one, per
"Announce-then-proceed preamble".

## Start

Verify the current branch against the user's direction and follow
`git-operations.md` "Direction and approval".

## Phase loop

For each bounded pass:

1. Snapshot worktree provenance.
2. Delegate to the harness's implement lane at the phase's rung
   (`model-selection.md` "Harness seats"; the lane that can carry that rung per
   "Fresh window or inherited context").
3. Review the exact implementer diff for correctness, plan compliance, and the
   user-supplied North Star; check test changes against `testing.md`.
4. Apply the principles §2–§3 simplicity gate to the diff: remove anything
   that does not trace to the plan or earn its place.
5. Run the phase verification and the repository's full pre-commit check
   in your own shell and read the exit code. An implementer's report of a
   green gate is a claim, not evidence; never commit on it.
6. Stage only the phase's files and create a coherent, descriptive commit.

Where the approved plan names an interim review (`workflows/longrun.md`
"Delivery pipeline modes"), run it at that boundary at the harness's
reviewer seat (`model-selection.md` "Harness seats"), then continue.

Keep writing passes sequential unless their file allowlists are disjoint.
Pi: genuinely parallel passes use `Agent` worktree isolation.
Continue through every phase; noncritical choices take defaults recorded in
the final report (principles §4 "Escalation bar").

After the final phase, hand off: the final review belongs to `rev`, and a
fix-verify iteration on a landed phase does not re-run the full phase loop.
