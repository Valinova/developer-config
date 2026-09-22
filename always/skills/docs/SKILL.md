---
name: docs
description: Reviews documentation created or modified on the current branch, consolidates one-time material into canonical documentation, and updates affected core docs. Use when the user explicitly invokes "docs" for a branch documentation pass.
---

# Documentation Review

Review all documentation created or modified on the current branch.

**Seat.** When this stage is farmed out (a `claude-exec.sh` lane, or the docs
stage inside `longrun`), it runs on the Opus seat
(`claude-exec.sh <task> <brief> --model opus --effort medium`), never Fable:
under a distilled brief that names the sources, the allowlist and what to
verify against the code, the fold is mechanical work per
`instructions/model-selection.md` "Roster". The orchestrator's own pass over
the resulting diff is the judgment step.

- Fold useful one-time documents, such as implementation guides, into the canonical architectural documentation.
- Delete one-time material when it is stale or no longer useful.
- Update any other documentation affected by the branch.
- Keep core architecture documentation current, concise, visual where that improves understanding, and complete enough to serve as the durable reference.
- Verify documentation claims against the implementation where practical.

Leave the resulting edits for the user's review. Do not commit or push unless explicitly requested.
