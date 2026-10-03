---
name: docs
description: Reviews documentation created or modified on the current branch, consolidates one-time material into canonical documentation, and updates affected core docs. Use when the user explicitly invokes "docs" for a branch documentation pass.
---

# Documentation Review

Review all documentation created or modified on the current branch.

**Seat.** When this stage is farmed out (a delegated lane, or the docs stage
inside `longrun`), seat and rung come from `instructions/model-selection.md`
"Harness seats" and "Effort". Under a distilled brief that names
the sources, the allowlist and what to verify against the code, the fold is
mechanical work. The orchestrator's own pass over the resulting diff is the
judgment step.

- Judge each document against the bar in `instructions/principles.md` §13. Fold what passes into its one owning doc; delete the rest, including the branch's local plan.
- Update any other documentation the branch made wrong, toward the code.
- Check every claim in a rewritten doc against the implementation.
- Before moving or deleting a doc, search code, tests, scripts, lint rules and agent commands for its path; change the consumer in the same edit.
- A diagram stays only when the flow crosses ownership boundaries and the order is itself a rule; it carries a `Source:` line.

Leave the resulting edits for the user's review. Do not commit or push unless explicitly requested.
