---
name: codex-functionality-review
description: Reviews a named repository feature or subsystem end to end, optionally using a branch, commit range, or recent time window to focus the investigation; implements clear high-value fixes and verifies the result. Use when the user asks for a functionality review rather than a diff-only review; not for a read-only report.
---

# Codex Functionality Review

Treat the named functionality as the review boundary. A branch, commit range,
or time window is an optional investigation lens, not permission to ignore
unchanged code that participates in the same behavior.

1. Establish the target functionality and optional history lens from the
   request, including the requested delivery mode: calibration, staged changes,
   commit, or pull request. Default to the functionality at the current
   revision. Do not switch branches or worktrees unless the user authorized it.
2. Read the repository guidance and canonical domain documentation, then map
   the complete functional slice: entry points, business-rule owners, storage
   and external boundaries, callers, projections or caches, UI consumers, and
   existing tests. Use history to explain intent and identify hotspots when a
   branch, range, or window was supplied.
3. Run focused existing tests before editing when they provide a useful
   baseline. Name the observable behavior and failure path any new or changed
   test will protect; prefer adding cases to the existing owner test file.
4. Use native subagents when independent lenses materially improve coverage.
   Before dispatch, read
   `~/Development/developer-config/codex/model-defaults.md` and its required
   canonical policy sections to choose the model and effort. Keep initial
   passes independent and review-only, then
   validate every finding against the code and canonical rules before acting.
   Require each reported finding to identify the expected-behavior owner, the
   regression surface, and the smallest existing test owner that can prove it.
   Useful lenses are correctness/state transitions and authorization,
   performance/data access and scale, and simplification/canonicalization.
5. Review correctness, regressions, race or idempotency hazards, authorization,
   performance, dead code, duplication, canonical ownership, and meaningful
   test gaps. Preserve intended behavior and public contracts; treat a bug fix
   as clear only when the expected behavior is established by a canonical rule,
   public contract, or observable regression test.
6. Implement every clear, valuable improvement within the functional boundary.
   Do not fix, report, or backlog nits, subjective preferences, speculative
   concerns, or low-value opportunities. Escalate only when the correct business
   or architectural choice cannot be established and choosing incorrectly would
   be costly to undo; lead with a recommendation and the key tradeoff. In a
   calibration run, also escalate a confirmed issue whose safe fix requires a
   schema, data, or multi-deployment rollout rather than silently expanding the
   exercise into a migration.
7. Apply the installed `code-simplifier` skill to the resulting diff. Give each
   candidate a `simplify`, `keep-with-reason`, or `escalate` disposition, and
   make all agreed behavior-preserving simplifications before verification.
8. Run the focused tests plus the repository's full blocking verification when
   implementation changed. Run any repository-defined advisory review that is
   expected before handoff, and evaluate only findings caused by or relevant to
   this work.

Do not stage, commit, push, or open a pull request unless the user explicitly
requested the corresponding action. Report only changes made, verification
results, escalated decisions, blockers, and high-value discussion items.
