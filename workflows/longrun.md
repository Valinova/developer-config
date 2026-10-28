# Long Run

Shared body for every harness's `longrun` skill. Seats, lanes, and the reviewer
come from `model-selection.md` "Harness seats"; IDs, wrappers, and sandbox
limits come from the harness's model card (`<harness>/model-defaults.md`;
Claude Code: `instructions/codex-delegation.md`). Each stage runs this harness's own skill of
that name.

Run the full delivery pipeline autonomously. Invoking this workflow authorizes
the commits, reviews, push, pull request, and babysit's one push
required by the stages below, and the dev proof `testing.md` "PR proof and
regression scenarios" requires, under its ask triggers. Its gates are the plan review, the final `rev`,
and an interim review only where the approved plan names one (`dispatch-bootstrap.md`
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
satisfies the planning review; if it is still valid, continue at stage 3
instead of rerunning `agentplan`.

## Delivery pipeline modes

These modes describe an invoked delivery workflow, not every task.
`agentplan`, `execute-plan`, `rev`, `docs`, `babysit`, and `longrun` compose
these stages:

```
Full       agentplan(scope + phases) → execute-plan → rev → docs → PR → babysit
Discover   agentplan(scope only) → probe → agentplan(phases) → execute-plan → rev → docs → PR → babysit
Iterative  scope note → implement with the user → rev → docs → PR → babysit
```

- **Gates:** the plan gate before code lands is a full adversarial plan review
  in Full and a scope-only review in Discover and Iterative; the rev gate's
  depth scales (below).
- **Review at the start and the end; interim reviews are agreed, never
  default.** Reviews run at planning and scoping (the plan gate) and at the
  end (`rev`). An interim cross-family review runs only for a genuinely
  complex boundary, typically later phases deleting or re-keying what
  earlier phases built, and only when the plan names it and the user agreed
  at the plan gate; the final rev then covers what it did not see. Phases
  never each get one.
- **An extended change ships in coherent chunks.** When one PR would be too
  long for a scoped review (many phases or concerns), split it into coherent
  chunks, each with its own scoped `rev`, rather than one large review at
  the end.
- **Discover** is chosen when the plan would have to guess at facts only a
  probe can settle (database shape, a spike, a failing test).
- **Iterative** is chosen when the work's shape is not known up front and the
  user is steering live; there is no phased plan artifact.
- The orchestrator picks the mode and states it in the preamble. Default is
  Full.

**Review depth scales with the change.** The pipeline is for non-trivial work
(whether a review runs at all is `dispatch-bootstrap.md` "External calls");
within it, the rev gate is always present but its depth follows the change,
never the fact that a workflow was invoked (why:
rationale.md#pipeline-proportionality):

| Change | Rev depth |
|---|---|
| Complex or cross-cutting | Full rev: code-simplifier, judgment lenses where they earn fan-out, other-family validation per `model-selection.md` "Harness seats" |
| Contained, well-specified | One cross-family pass; no lens fan-out |
| Mini PR, or a fix-verify iteration loop | A light cross-family validation of the fix and its verification evidence; no simplifier or lenses |

Classify by risk and affected contracts, not size: a change that fits the
complex row wins regardless of diff size. The light row covers a bounded
delta against an already-reviewed baseline; it never replaces the branch's
outstanding full review. The orchestrator selects the lightest matching row
and announces it — the full row is the fallback when unsure, not a ritual.
The chosen depth and scope travel in the reviewer's brief.

**PR status at delivery.** A completed `longrun` opens a ready-for-review
(non-draft) PR so CI and automated reviewers can run. Draft is reserved for
an explicit user request or an unresolved critical blocker that makes ready
status inaccurate; name the exception in the final report. A blocker is not
completed delivery.

## Stages

1. Verify branch authority per `git-operations.md` "Direction and approval":
   ask whether to create or switch only when not already authorized, and name
   the branch yourself.
2. Planning, by mode. Full: if no still-valid reviewed plan exists, run
   `agentplan`; the plan file stays local and uncommitted (principles §13).
   Discover: `agentplan` scope-only, probe with the user, then `agentplan`
   again for phases. Iterative: write a short scope note;
   its cross-family scope review is this workflow's plan gate.
3. Run `execute-plan` through every phase (Iterative: implement with the user
   in bounded passes) and commit.
4. Run the dev proof the plan named (`testing.md` "PR proof and regression
   scenarios") against the branch running in the approved dev environment,
   fix what it finds, and commit; its record goes in the pull request body.
   In Iterative mode the passes with the user may already have been that
   proof; the agent judges whether they covered the named surfaces and
   records what they did not. A gap the ask triggers leave open is recorded
   as incomplete, never called verified.
5. Run `rev` and commit its reviewed fixes.
6. Run `docs` to consolidate the branch's documentation — folding what
   passes the principles §13 bar from the local plan into canonical docs and
   deleting that plan file — then commit (this workflow authorizes it).
7. Verify the complete branch and the intended remote/branch target, and
   apply the principles §4 "Ship gate". Then push and open a pull request with
   a descriptive summary, verification results, and all important unresolved
   decisions deferred for the user, per "PR status at delivery" above.
8. Run `babysit` on the opened pull request.

## Stop conditions

Stop only when a critical ambiguity makes safe progress impossible, when an
operation requires authority this workflow does not grant, or when `babysit`
reports incomplete delivery.
