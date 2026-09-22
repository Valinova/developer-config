---
name: agentplan
description: Produces and reviews a phased implementation plan without implementing it. Use only when the user explicitly asks for "agentplan", "agent plan", or "agent-plan".
---

# Agent Plan — Claude

Read `~/Development/developer-config/workflows/agentplan.md` and follow it.
This stub carries only the Claude facts that body defers to:

- Orchestrator: Fable 5.1 (`model-selection.md` "Harness seats", Claude Code row).
- Implement lane: Opus 5.5 — a native `Agent` (inherits the session rung) or `claude-exec.sh --model opus --effort <rung>` when the rung differs; Astra (Codex wrappers) or Grok (`pi-exec.sh`) only when the user names one.
- Reviewer seat: Astra via the Codex wrappers (`codex-delegation.md`).
