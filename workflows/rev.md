# Adversarial Review

Shared body for every harness's `rev` skill. Seats, lanes, and the reviewer
come from `model-selection.md` "Harness seats"; IDs, wrappers, and sandbox
limits come from the harness's model card (`<harness>/model-defaults.md`;
Claude Code: `instructions/codex-delegation.md`).

Review the committed branch. This workflow IS the diff review
(`dispatch-bootstrap.md` "External calls"), independently runnable and also the
review stage composed by `longrun`; it never invokes `longrun` itself.
Invoking it authorizes the review at the chosen depth and the commits required
for the agreed fixes.

## Depth

Pick the lightest matching row of the rev-depth table in `workflows/longrun.md`
"Delivery pipeline modes" and announce it, with the reviewer seat and rung,
per "Announce-then-proceed preamble". The table owns what each row runs; in
this workflow the full row's simplifier is the shared `code-simplifier` skill,
and the full and contained rows' pass is the principles audit.

The principles audit is the engineering principles and the repo's
`AGENTS.md`/`CLAUDE.md` guidance: correctness and regressions, with emphasis on
simplicity, intentionality, canonical ownership, and removal of unnecessary
scope. Check PR proof and its scenario decision against `testing.md` "PR proof
and regression scenarios". Test changes are judged against `testing.md` "Shapes
to refuse": a new test file without a stated reason, or a case that restates a registry,
roster, or i18n literal, is a finding. When tests or shared test harnesses or
mocks change, the reviewer reads `testing.md` in full and compares each
changed contract with coverage across files; a finding names the concrete
failure missed or the stronger test already covering it. It checks the
recorded seen-failing evidence and the sibling consumers of a shared harness
change; missing evidence means unverified, not never-failed. It reviews the
diff, not the unchanged suite. The chosen depth and scope travel in the
reviewer's brief.

## External-review-only mode

When a caller invokes this skill as its already-selected cross-family reviewer
(today: Claude through `claude -p` from Codex or Hermes), run the
review at the depth and scope the caller's brief names, apply the clear-cut
fixes, return the remaining findings, and stop. Do not dispatch another
reviewer, stage, or commit. Discovery nesting follows `model-selection.md` "Subagent fan-out";
omission does not forbid it.

## Sequence

For a normal invocation, verify the branch against the user's direction
(`git-operations.md` "Direction and approval") before modifying files.

1. **Review.** Dispatch one cross-family reviewer at the harness's reviewer
   seat, rung per `model-selection.md` "Harness seats", at the
   chosen depth over the committed diff. It applies the clear-cut fixes itself
   (principles §3: one right answer), with no git writes, and returns the
   findings that need a choice. The orchestrator never reviews its own diff.
2. **Validate.** The orchestrator reads the fix diff and the open findings
   once, and notes each edit it rejects and each finding it would take, with
   its reasoning.
3. **Align.** Resume the reviewer with those notes. What the two agree on gets
   the clear-cut default, and the reviewer applies it, reverting rejected
   edits. What they cannot agree on goes to the PR as a follow-up under
   `longrun`, otherwise to the user in the final report.
4. **Verify and commit.** The orchestrator runs the full check battery,
   stages exact files, and creates coherent descriptive commits.

If the kept findings require several passes, execute them here as a bounded
review-fix plan; do not recurse into `longrun`. Do not push or open a PR.

Reuse valid findings. Verify ordinary fixes locally; another review runs only
when a separate gate requires it. A confirmed finding earns an in-scope fix or
an out-of-scope report under principles §3. A review finding alone does not
justify a test: a bug must have a costly recurrence, and new logic follows
`testing.md`'s authoring gate. The final report states what each pass changed;
a pass that changed nothing is reported as such, never hidden — that is the
signal to lower the default next time (why: rationale.md#cross-family-review).
