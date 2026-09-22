---
name: babysit
description: 'Watches the open pull request and refines it to merge-ready: settles CI checks and CodeRabbit together, at most one push per round, with a two-round cost circuit breaker. Use only when the user explicitly invokes "babysit" or as the final longrun stage.'
---

# Babysit — Hermes

Read `~/Development/developer-config/workflows/babysit.md` and follow it.
This stub carries only the Hermes facts that body defers to:

- Orchestrator: Grok 4.6. Model card: `hermes/model-defaults.md`; dispatch paths: `coding-orchestration.md`.
- Implement lane: Codex CLI `gpt-6-astra` via the configured wrappers, rung passed explicitly; Hermes writes no product code. `claude -p --model opus` only when the user names it.
- Long-wait mechanism: keep polling (`gh pr checks --watch`, `gh api`).
