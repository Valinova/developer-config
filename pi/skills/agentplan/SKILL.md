---
name: agentplan
description: Produces and reviews a phased implementation plan without implementing it. Use only when the user explicitly asks for "agentplan", "agent plan", or "agent-plan".
---

# Agent Plan — Pi

Read `~/Development/developer-config/workflows/agentplan.md` and follow it.
This stub carries only the Pi facts that body defers to:

- Orchestrator: the active Pi model, Grok 4.6 by default. Model card: `pi/model-defaults.md` (exact IDs, `Agent` dispatch).
- Implement lane: a Codex `Agent`; Grok or DeepSeek `Agent` when the user names one, Anthropic only when the user names it.
- Reviewer seat: a cross-family `Agent` — Grok vs Codex; Anthropic only when the user names it (card "Pi seat").
