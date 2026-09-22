---
name: babysit
description: 'Watches the open pull request and refines it to merge-ready: settles CI checks and CodeRabbit together, at most one push per round, with a two-round cost circuit breaker. Use only when the user explicitly invokes "babysit" or as the final longrun stage.'
---

# Babysit — Pi

Read `~/Development/developer-config/workflows/babysit.md` and follow it.
This stub carries only the Pi facts that body defers to:

- Orchestrator: the active Pi model, Grok 4.6 by default. Model card: `pi/model-defaults.md` (exact IDs, `Agent` dispatch).
- Implement lane: a Codex `Agent`; Grok or DeepSeek `Agent` when the user names one, Anthropic only when the user names it.
- Long-wait mechanism: keep polling (`gh pr checks --watch`, `gh api`).
