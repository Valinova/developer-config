---
name: babysit
description: 'Watches the open pull request and refines it to merge-ready: settles CI checks and CodeRabbit together, at most one push per round, with a two-round cost circuit breaker. Use only when the user explicitly invokes "babysit" or as the final longrun stage.'
---

# Babysit — Codex

Read `~/Development/developer-config/workflows/babysit.md` and follow it.
This stub carries only the Codex facts that body defers to:

- Orchestrator: GPT-6 Astra. Model card: `codex/model-defaults.md`.
- Implement lane: native Astra `spawn_agent` with `model` and `reasoning_effort` per spawn (override rules in the card); `claude -p --model opus` only when the user names it.
- Long-wait mechanism: keep polling (`gh pr checks --watch`, `gh api`).
