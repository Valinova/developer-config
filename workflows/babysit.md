# Babysit

Shared body for every harness's `babysit` skill. Seats, lanes, and the reviewer
come from `model-selection.md` "Harness seats"; IDs, wrappers, and sandbox
limits come from the harness's model card (`<harness>/model-defaults.md`;
Claude Code: `instructions/codex-delegation.md`).

Take the current branch's open pull request through one round of CodeRabbit
and CI, then report. Independently runnable and the final `longrun` stage; it
never invokes `longrun`. Invoking it authorizes the fixes, commits, PR replies,
and the one push below, including a rebase onto the PR's base and its
`--force-with-lease` push. The orchestrator owns git; implementer leaves make
no git writes. A PR with neither checks nor CodeRabbit has nothing to babysit:
say so and stop.

1. **Wait** for every check, CodeRabbit's status check included (`gh pr checks
   --watch`). A pass with no review object is a clean review; "Review rate
   limited" means none ran, and `git-operations.md` "CodeRabbit" decides what
   replaces it. If the repo's `.coderabbit.yaml` lacks
   `reviews.auto_review.auto_incremental_review: false`, tell the user: the
   push will spend a second review.
2. **Fix** red checks and the clear-cut findings worth fixing, in one pass on
   the harness's implement lane. Decline the rest with a reason; a finding that
   needs a choice goes to the user in the report. Rebase if the branch is
   behind or conflicting. Verify locally, re-proving per `testing.md` "PR proof
   and regression scenarios", and commit.
3. **Teach.** Where an accept or decline reflects a durable preference, reply
   on its thread mentioning `@coderabbitai` with the reason; it confirms with
   "Learnings Added". Resolving threads and reactions teach it nothing.
4. **Push once**, after verifying the remote target, and wait for its CI. A
   second review needs the user's yes (`git-operations.md` "CodeRabbit").

Report merge-ready only when the PR meets principles §4 "Ship gate" and no
accepted finding is open; otherwise report what remains. Merge only when the
user directed "merge when ready" and named squash or merge commit.
