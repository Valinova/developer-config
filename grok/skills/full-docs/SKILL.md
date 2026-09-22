---
name: full-docs
description: Performs a deep Grok-led documentation audit with Codex adversarial validation. Use only when the user explicitly invokes "full docs" or "full-docs".
disable-model-invocation: true
---

# Full Documentation Review — Grok Build

Read `~/Development/developer-config/workflows/full-docs.md` and follow it.
This stub carries only the Grok Build facts that body defers to:

- Orchestrator: the Grok 4.6 session; native `spawn_subagent` children are Grok 4.6 only. Model card: `grok/model-defaults.md`.
- Audit seat: native Grok 4.6 `spawn_subagent` children.
- Validation reviewer: Codex via the Codex wrappers.
