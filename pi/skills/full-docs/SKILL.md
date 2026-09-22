---
name: full-docs
description: Performs a deep Grok-led documentation audit with Codex adversarial validation. Use only when the user explicitly invokes "full docs" or "full-docs".
---

# Full Documentation Review — Pi

Read `~/Development/developer-config/workflows/full-docs.md` and follow it.
This stub carries only the Pi facts that body defers to:

- Orchestrator: the active Pi model, Grok 4.6 by default. Model card: `pi/model-defaults.md` (exact IDs, `Agent` dispatch).
- Audit seat: Grok `Agent` dispatches.
- Validation reviewer: a Codex `Agent`; Anthropic only when the user names it.
