---
name: execute-plan
description: Implements an approved phased plan through bounded Opus implementer passes, verification, and coherent commits. Use only when the user explicitly asks to execute an approved plan.
---

# Execute Plan — Claude

Read `~/Development/developer-config/workflows/execute-plan.md` and follow it.
This stub carries only the Claude facts that body defers to:

- Orchestrator: Fable 5.1 (`model-selection.md` "Harness seats", Claude Code row).
- Implement lane: Opus 5.5 — a native `Agent` (inherits the session rung) or `claude-exec.sh --model opus --effort <rung>` when the rung differs; Astra (Codex wrappers) or Grok (`pi-exec.sh`) only when the user names one.
- Reviewer seat (default): Astra via the Codex wrappers (`codex-delegation.md`).
- After an implementer override, pick the reviewer by the actual author's family under `model-selection.md` "External calls".
