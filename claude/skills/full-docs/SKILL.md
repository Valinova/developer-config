---
name: full-docs
description: Performs a deep Claude-led documentation audit with Codex adversarial validation. Use only when the user explicitly invokes "full docs" or "full-docs".
---

# Full Documentation Review — Claude

Read `~/Development/developer-config/workflows/full-docs.md` and follow it.
This stub carries only the Claude facts that body defers to:

- Orchestrator: Fable 5.1 (`model-selection.md` "Harness seats", Claude Code row).
- Audit seat: Opus 5.5 subagents.
- Validation reviewer (default): Astra via the Codex wrappers.
- After an implementer override, pick the reviewer by the actual author's family under `model-selection.md` "External calls".
