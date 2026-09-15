---
name: babysit
description: 'Watches the open pull request and refines it to merge-ready: settles CI checks and CodeRabbit together, at most one push per round, with a two-round cost circuit breaker. Use only when the user explicitly invokes "babysit" or as the final longrun stage.'
---

# Babysit — Claude

Before choosing seats or effort, read
`~/Development/developer-config/instructions/model-selection.md` and
`~/Development/developer-config/instructions/codex-delegation.md` in full —
neither is always-loaded (`dispatch-bootstrap.md` owns the read rule).

Refine the current branch's open pull request until it is merge-ready. This
workflow is independently runnable and is also the final stage composed by
`$longrun`; it never invokes `$longrun` itself. Invoking it authorizes
the accepted fixes, checks, commits, PR review replies, and at most one
push per round described below, including a rebase onto the PR's base and
the `--force-with-lease` push that follows it. The orchestrator owns git operations;
implementer leaves make no git writes (`codex-delegation.md` Sandbox note).

CI checks and the CodeRabbit review together are CI/CD. A round treats them
as one signal and combines any needed changes into at most one push.

## Round

1. **Wait until both have settled**: every check concluded, including
   CodeRabbit's own status check. Do not wait for a review object —
   CodeRabbit posts one only when it has findings; a pass with no review is a
   settled, clean round. Poll read-only with `gh` (`gh pr checks`, `gh api`);
   a poll that keys on a review object appearing on the new head never
   satisfies after a clean push.
   A wait past an hour uses the `ScheduleWakeup` heartbeat from
   `claude-conventions.md`, stopped the moment the round resumes.
2. **Triage.** Red checks get fixed. Every CodeRabbit finding is accepted,
   declined with a reason, or deferred to the user in the report — the
   orchestrator's call under the principles §4 escalation bar. There is no
   count threshold: "minimal" means nothing is left that the orchestrator
   would accept. If the branch is behind or conflicting, verify the PR's
   actual base branch and remote, then rebase onto it (the `git-operations.md`
   stacked-branch exception still applies). Merge order across PRs is the
   user's call.
3. **Fix.** Accepted findings and CI fixes go to ONE implementer pass; seat
   and effort come from `model-selection.md` "Harness seats", "Roster", and
   "Effort". Verify locally and commit.
4. **Push once if changes need publishing** (`--force-with-lease` after a
   rebase), after verifying the remote target.
   Never push a CI fix alone while a CodeRabbit review is pending. If nothing
   needs changing and the PR satisfies the ship gate, report merge-ready.

## Teaching CodeRabbit

Resolving threads and thumbs reactions teach it nothing. Where an accept or
decline reflects a durable team preference, reply on that line thread
mentioning `@coderabbitai` with the reasoning ("we intentionally … because
…"); a one-off exception gets a plain reply without the mention. Encouraged
wherever there is real learning, never mandatory. CodeRabbit confirms with a
"Learnings Added" section.

## Two-round cost circuit breaker

If round 1 changes the PR, wait for its CI and review before round 2. After
round 2's triage, implement accepted fixes. If another push is needed, comment
`@coderabbitai ignore` on the PR (never in the description, which would have
skipped round 1), then push once. Wait for the final push's CI checks to
conclude before assessing readiness.

There is no round 3: the cap limits review cost, not the ship gate. Report
merge-ready only when the current PR satisfies principles §4 and no accepted
findings remain unresolved. Otherwise preserve the work and report the
circuit breaker, remaining findings, and failed or blocked checks as
incomplete delivery; do not claim merge-ready.

Merge only when the user explicitly directed "merge when ready" and named
squash vs merge commit; otherwise report the verified PR status without merging.
