---
name: codex-branch-review
description: Reviews a stated scope of changes — the current branch against its base by default, or a recent range such as the last 48 hours of merged commits — implements clear high-value fixes, verifies the result, and reports merge blockers. Use when the user explicitly invokes "codex branch review" or asks to review a branch or recent merged changes; not for a read-only review.
---

# Codex Branch Review

1. Determine the scope from the invocation argument: default is the current branch against its base, identified without changing branches or worktrees; a recent-changes request means the commits or merged pull requests in the stated window, defaulting to the last 48 hours when no duration is given.
2. Use native subagents when independent review lenses would materially
   improve the result. Before dispatch, read
   `~/Development/developer-config/codex/model-defaults.md` and its required
   canonical policy sections to choose the model and effort.
   Additional reviewer selection follows "External calls";
   this skill does not invoke the delivery pipeline.
3. Review correctness, regressions, performance, dead code, simplification, duplication, canonicalization, and meaningful test gaps.
4. Implement and verify every clear, valuable improvement. Do not fix, report, or backlog nits, subjective preferences, speculative concerns, or low-value opportunities.
5. Escalate only when the correct business or architectural choice cannot be established and choosing incorrectly would be costly to undo. Lead with a recommendation and the key tradeoff.
6. Run the relevant verification. Do not commit or push unless the user explicitly requested it.

Report only changes made, verification results, escalated decisions, and merge blockers.
