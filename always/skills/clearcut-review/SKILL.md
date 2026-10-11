---
name: clearcut-review
description: Reviews a stated scope of changes — the current branch against its base by default, a stated commit range, or a recent window such as the last 48 hours of merged commits — implements clear-cut high-value fixes, verifies the result, and reports merge blockers. Use when the user explicitly invokes "clearcut review" or "clearcut-review", or asks to review a branch, commit range, or recent merged changes and apply clear-cut fixes; not for a read-only review.
---

# Clearcut Review

1. Determine the scope from the invocation argument: default is the current branch against its base, identified without changing branches or worktrees; a stated commit range means exactly that range; a recent-changes request means the commits or merged pull requests in the stated window, defaulting to the last 48 hours when no duration is given.
2. Use native subagents when independent review lenses would materially
   improve the result. Before dispatch, read
   `~/Development/developer-config/instructions/model-selection.md` for seats
   and effort, and the harness's model card (`<harness>/model-defaults.md`;
   Claude Code: `instructions/codex-delegation.md`) for IDs and wrappers.
   Additional reviewer selection follows "External calls";
   this skill does not invoke the delivery pipeline.
3. Review correctness, regressions, performance, dead code, simplification, duplication, canonicalization, and meaningful test gaps.
4. Implement and verify every clear-cut, valuable improvement — clear-cut per principles §3: one right answer, small, keeps or plainly corrects behaviour. Do not fix, report, or backlog nits, subjective preferences, speculative concerns, or low-value opportunities.
5. Escalate only when the correct business or architectural choice cannot be established and choosing incorrectly would be costly to undo. Lead with a recommendation and the key tradeoff.
6. Run the relevant verification. Do not commit or push unless the user explicitly requested it.

Report only changes made, verification results, escalated decisions, and merge blockers.
