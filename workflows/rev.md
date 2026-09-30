# Adversarial Review

Shared body for every harness's `rev` skill. Seats, lanes, and the reviewer
come from `model-selection.md` "Harness seats"; IDs, wrappers, and sandbox
limits come from the harness's model card (`<harness>/model-defaults.md`;
Claude Code: `instructions/codex-delegation.md`).

Review the committed branch. This workflow IS the diff review
(`model-selection.md` "External calls"), independently runnable and also the
review stage composed by `longrun`; it never invokes `longrun` itself.
Invoking it authorizes the review at the chosen depth and the commits required
for the agreed fixes.

## Depth

Pick the lightest matching row of the rev-depth table in `model-selection.md`
"Delivery pipeline modes" and announce it, with the reviewer seat and rung,
per "Announce-then-proceed preamble". The table owns what each row runs; in
this workflow the full row's simplifier is the shared `code-simplifier` skill,
and the full and contained rows' pass is the principles audit.

The principles audit is the engineering principles and the repo's
`AGENTS.md`/`CLAUDE.md` guidance: correctness and regressions, with emphasis on
simplicity, intentionality, canonical ownership, and removal of unnecessary
scope. Test changes are judged against `testing.md` "Shapes to refuse": a
new test file without a stated reason, or a case that restates a registry,
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
(today: Claude through `claude -p` from Codex, Grok Build, or Hermes), run the
review at the depth and scope the caller's brief names, return complete
findings, and stop. Do not dispatch another reviewer, edit files, stage, or
commit. Discovery nesting follows `model-selection.md` "Subagent fan-out";
omission does not forbid it.

## Sequence

For a normal invocation, verify the branch against the user's direction
(`git-operations.md` "Direction and approval") before modifying files.

1. **Review.** Dispatch one cross-family reviewer at the harness's reviewer
   seat (`model-selection.md` "External calls"), rung per "Effort", at the
   chosen depth over the committed diff. It returns one findings list. The
   orchestrator never reviews its own diff. After an implementer override,
   pick the reviewer by the actual author's family under "External calls".
2. **Agree.** Read the findings once; keep what is valuable and give each
   dropped finding a one-line reason in the final report. No second review, no
   re-triage loop. Escalate only unresolved critical choices under principles
   §4.
3. **Fix.** The harness's implement lane applies the kept set; the
   orchestrator does no mechanical editing itself.
4. **Verify and commit.** The orchestrator runs the full check battery,
   stages exact files, and creates coherent descriptive commits.

If the kept findings require several passes, execute them here as a bounded
review-fix plan; do not recurse into `longrun`. Do not push or open a PR.
