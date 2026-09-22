---
name: agentplan
description: Produces and reviews a phased implementation plan without implementing it. Use only when the user explicitly asks for "agentplan", "agent plan", or "agent-plan".
disable-model-invocation: true
---

# Agent Plan — Grok Build

Read `~/Development/developer-config/workflows/agentplan.md` and follow it.
This stub carries only the Grok Build facts that body defers to:

- Orchestrator: the Grok 4.6 session; native `spawn_subagent` children are Grok 4.6 only. Model card: `grok/model-defaults.md`.
- Implement lane: Codex `gpt-6-astra` via the Codex wrappers, rung passed explicitly; Grok Build writes no product code. Grok `spawn_subagent` or `claude -p --model opus` only when the user names one.
- Reviewer seat: from the card's reviewer transports, never the author's family; a Claude reviewer runs through `claude -p` — Opus 5.5 for contained work, Fable 5.1 leading nested Opus discovery for complex work; lifecycle per `codex/model-defaults.md`.
