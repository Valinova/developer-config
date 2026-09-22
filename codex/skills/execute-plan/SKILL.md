---
name: execute-plan
description: Implements an approved phased plan through bounded native Codex passes, verification, and coherent commits. Use only when the user explicitly asks to execute an approved plan.
---

# Execute Plan — Codex

Read `~/Development/developer-config/workflows/execute-plan.md` and follow it.
This stub carries only the Codex facts that body defers to:

- Orchestrator: GPT-6 Astra. Model card: `codex/model-defaults.md`.
- Implement lane: native Astra `spawn_agent` with `model` and `reasoning_effort` per spawn (override rules in the card); `claude -p --model opus` only when the user names it.
- Reviewer seat: Claude through `claude -p` — Opus 5.5 for contained work, Fable 5.1 leading nested Opus discovery for complex or cross-cutting work; process lifecycle per the card.
