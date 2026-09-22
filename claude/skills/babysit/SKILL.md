---
name: babysit
description: 'Watches the open pull request and refines it to merge-ready: settles CI checks and CodeRabbit together, at most one push per round, with a two-round cost circuit breaker. Use only when the user explicitly invokes "babysit" or as the final longrun stage.'
---

# Babysit — Claude

Read `~/Development/developer-config/workflows/babysit.md` and follow it.
This stub carries only the Claude facts that body defers to:

- Orchestrator: Fable 5.1 (`model-selection.md` "Harness seats", Claude Code row).
- Implement lane: Opus 5.5 — a native `Agent` (inherits the session rung) or `claude-exec.sh --model opus --effort <rung>` when the rung differs; Astra (Codex wrappers) or Grok (`pi-exec.sh`) only when the user names one.
- Long-wait mechanism: the `ScheduleWakeup` heartbeat from `claude-conventions.md` "Prompt-cache heartbeat during long waits", stopped the moment the round resumes.
