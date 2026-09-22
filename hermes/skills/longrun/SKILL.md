---
name: longrun
description: Runs the full autonomous delivery pipeline from adversarial planning through implementation, review, docs, push, pull request, and PR babysitting to merge-ready. Use only when the user explicitly invokes "longrun" or "long run".
---

# Long Run — Hermes

Before choosing seats or effort, read
`~/Development/developer-config/hermes/model-defaults.md`
and its required canonical policy sections.

Run the full delivery pipeline autonomously. Invoking this workflow authorizes
the commits, code-simplifier review, push, pull request, and babysit's
per-round pushes required by the steps below.

The active Hermes model is the orchestrator — prefer **Grok 4.6** (harness
seats in `model-selection.md`). Cross-family rigor comes from each stage's
explicit dispatches (Codex CLI; `claude -p --model opus` as the other-family
reviewer or user-named implementer override, Fable only as the complex
arbiter).

## Preamble

State first whether the plan review warrants an external call and why
(`model-selection.md` "External calls", "Announce-then-proceed preamble") —
then the mode. Stage 4's `rev` runs regardless: invoking longrun is its
whether, and "External calls" decides only who and at what weight. The
planning review is usually complex but not always; its level is a judgment
stated here, never a default set by this workflow's name.

## Resume contract

Before running a stage, inspect the current branch, history, artifacts, and
available verification evidence. Treat a stage that was already completed for
the current objective as satisfied and resume at the first incomplete stage.
Never replay a completed stage merely because `$longrun` was invoked, the
orchestrator changed, or the base branch advanced.

Repeat only the smallest invalid portion when the request or relevant code has
materially changed and the existing artifact is demonstrably no longer valid.
State that invalidation before repeating work. An existing reviewed
plan satisfies the planning review; if it is valid but uncommitted, continue
from the plan-commit portion of step 2 instead of rerunning `$agentplan`.

1. Verify the branch and follow `git-operations.md`. Work on the current branch,
   honoring explicit default-branch direction. If the requested PR requires a
   different branch, use existing explicit direction or obtain approval for
   its name before creating or switching; workflow invocation alone does not
   authorize that change.
2. Run the planning stage per mode: Full — the Hermes `$agentplan`
   workflow, if no still-valid reviewed plan exists; Discover —
   `$agentplan` scope-only, probe with the user, then `$agentplan` again for
   phases; Iterative — a short scope note with "External calls" applied to
   it, no plan artifact. In Full and Discover, commit the reviewed plan
   file before implementation.
3. Run the Hermes `$execute-plan` workflow through every phase (Iterative:
   implement with the user in bounded passes) and commit.
4. Run the Hermes `$rev` workflow and commit its reviewed fixes.
5. Run the `$docs` workflow to consolidate the branch's documentation —
   folding any plan's durable outcomes into canonical docs and deleting that
   plan file when present — then commit (this workflow authorizes it).
6. Verify the complete branch and the intended remote/branch target, and
   apply the principles §4 ship gate: the change is clearly beneficial and no
   known regression ships — rare accepted residual risk is stated in the PR
   with why, how it is tested, and how we know nothing else regressed. Then
   push and open a pull request with a descriptive summary, verification
   results, and all important unresolved decisions deferred for the user.
   Apply `model-selection.md` "PR status at delivery".
7. Run the Hermes `$babysit` workflow on the opened pull request: wait for CI
   and CodeRabbit to settle together, triage, fix, and push only when needed.
   Apply babysit's two-round cost circuit breaker and final verification: report
   merge-ready only when its ship gate passes, otherwise incomplete delivery.
   Merge only under explicit "merge when ready" direction that names squash
   vs merge commit.

Do not interrupt the user for noncritical choices. Take reasonable defaults and
record them. Stop only when a critical ambiguity makes safe progress impossible
or when an operation requires authority not granted by this workflow, or
when babysit's cost circuit breaker stops incomplete delivery.
