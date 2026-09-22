---
name: babysit
description: 'Watches the open pull request and refines it to merge-ready: settles CI checks and CodeRabbit together, at most one push per round, with a two-round cost circuit breaker. Use only when the user explicitly invokes "babysit" or as the final longrun stage.'
disable-model-invocation: true
---

# Babysit — Grok Build

Read `~/Development/developer-config/workflows/babysit.md` and follow it.
This stub carries only the Grok Build facts that body defers to:

- Orchestrator: the Grok 4.6 session; native `spawn_subagent` children are Grok 4.6 only. Model card: `grok/model-defaults.md`.
- Implement lane: Codex `gpt-6-astra` via the Codex wrappers, rung passed explicitly; Grok Build writes no product code. Grok `spawn_subagent` or `claude -p --model opus` only when the user names one.
- Long-wait mechanism: keep polling (`gh pr checks --watch`, `gh api`).
