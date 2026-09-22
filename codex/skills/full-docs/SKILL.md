---
name: full-docs
description: Performs a deep native Codex documentation audit with Claude adversarial validation. Use only when the user explicitly invokes "full docs" or "full-docs".
---

# Full Documentation Review — Codex

Read `~/Development/developer-config/workflows/full-docs.md` and follow it.
This stub carries only the Codex facts that body defers to:

- Orchestrator: GPT-6 Astra. Model card: `codex/model-defaults.md`.
- Audit seat: native Astra subagents.
- Validation reviewer (default): Claude through `claude -p` (seat per the card).
- After an implementer override, pick the reviewer by the actual author's family under `model-selection.md` "External calls".
