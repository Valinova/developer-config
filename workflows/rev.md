# Adversarial Review

Shared body for every harness's `rev` skill; the invoking stub names the
harness's reviewer and implement seats and model card.

Review the committed branch. This workflow IS the diff review
(`model-selection.md` "External calls"), independently runnable and also the
review stage composed by `longrun`; it never invokes `longrun` itself.
Invoking it authorizes the review at the chosen depth and the commits required
for the agreed fixes.

## Depth

Pick the lightest matching row of the rev-depth table in `model-selection.md`
"Delivery pipeline modes" and announce it, with the reviewer seat and rung,
per "Announce-then-proceed preamble":

- **Complex or cross-cutting (full):** the reviewer runs the shared
  `code-simplifier` skill and the principles audit; judgment lenses only where
  they earn fan-out ("Subagent fan-out").
- **Contained, well-specified:** one cross-family principles-audit pass at the
  implementer's rung; no simplifier, no lens fan-out.
- **Mini PR or fix-verify iteration:** a light cross-family validation of the
  fix and its test; no simplifier or lenses.

The principles audit is the engineering principles and the repo's
`AGENTS.md`/`CLAUDE.md` guidance: correctness and regressions, with emphasis on
simplicity, intentionality, canonical ownership, and removal of unnecessary
scope. The chosen depth and scope travel in the reviewer's brief.

## External-review-only mode

When a caller invokes this skill as its already-selected cross-family reviewer
(today: Claude through `claude -p` from Codex, Grok Build, or Hermes), run the
review at the depth and scope the caller's brief names, return complete
findings, and stop. Do not dispatch another reviewer, edit files, stage, or
commit. Discovery subagents are allowed only when the caller's brief
authorizes them.

## Sequence

For a normal invocation, verify the branch against the user's direction
(`git-operations.md` "Direction and approval") before modifying files.

1. **Review.** Dispatch one cross-family reviewer at the harness's reviewer
   seat (`model-selection.md` "External calls"), rung per "Effort", at the
   chosen depth over the committed diff. It returns one findings list. The
   orchestrator never reviews its own diff.
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
