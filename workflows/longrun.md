# Long Run

Shared body for every harness's `longrun` skill; the invoking stub names the
harness's seats and model card. Each stage runs this harness's own skill of
that name.

Run the full delivery pipeline autonomously. Invoking this workflow authorizes
the commits, reviews, push, pull request, and babysit's per-round pushes
required by the stages below. Its gates are the plan review, the final `rev`,
and the seam review when a plan tears out what it built (`model-selection.md`
"External calls").

## Preamble

Per "Announce-then-proceed preamble": the mode ("Delivery pipeline modes"),
then the plan review's complexity read, seat, and rung. The planning review is
usually complex but not always; its weight is a judgment stated here, never a
default set by this workflow's name.

## Resume contract

Before running a stage, inspect the current branch, history, artifacts, and
available verification evidence. Treat a stage that was already completed for
the current objective as satisfied and resume at the first incomplete stage.
Never replay a completed stage merely because `longrun` was invoked, the
orchestrator changed, or the base branch advanced.

Repeat only the smallest invalid portion when the request or relevant code has
materially changed and the existing artifact is demonstrably no longer valid.
State that invalidation before repeating work. An existing reviewed plan
satisfies the planning review; if it is valid but uncommitted, continue from
the plan-commit portion of stage 2 instead of rerunning `agentplan`.

## Stages

1. Verify branch authority per `git-operations.md` "Direction and approval":
   ask whether to create or switch only when not already authorized, and name
   the branch yourself.
2. Planning, by mode. Full: if no still-valid reviewed plan exists, run
   `agentplan`, then commit the revised plan file before implementation.
   Discover: `agentplan` scope-only, probe with the user, then `agentplan`
   again for phases, and commit the plan. Iterative: write a short scope note;
   its cross-family scope review is this workflow's plan gate.
3. Run `execute-plan` through every phase (Iterative: implement with the user
   in bounded passes) and commit.
4. Run `rev` and commit its reviewed fixes.
5. Run `docs` to consolidate the branch's documentation — folding any plan's
   durable outcomes into canonical docs and deleting that plan file when
   present — then commit (this workflow authorizes it).
6. Verify the complete branch and the intended remote/branch target, and
   apply the principles §4 "Ship gate". Then push and open a pull request with
   a descriptive summary, verification results, and all important unresolved
   decisions deferred for the user, per `model-selection.md` "PR status at
   delivery".
7. Run `babysit` on the opened pull request.

## Stop conditions

Stop only when a critical ambiguity makes safe progress impossible, when an
operation requires authority this workflow does not grant, or when `babysit`
reports incomplete delivery.
