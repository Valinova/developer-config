---
name: longrun
description: Runs the full autonomous delivery pipeline from adversarial planning through implementation, review, docs, push, pull request, and PR babysitting to merge-ready. Use only when the user explicitly invokes "longrun" or "long run".
---

# Long Run — Hermes

Read `~/Development/developer-config/workflows/longrun.md` and follow it.
This stub carries only the Hermes facts that body defers to:

- Orchestrator: Grok 4.6. Model card: `hermes/model-defaults.md`; dispatch paths: `coding-orchestration.md`.
- Implement lane: Codex CLI `gpt-6-astra` via the configured wrappers, rung passed explicitly; Hermes writes no product code. `claude -p --model opus` only when the user names it.
- Reviewer seat: from the card's reviewer transports, never the author's family; a Claude reviewer runs through `claude -p` — Opus 5.5 for contained work, Fable 5.1 leading nested Opus discovery for complex work.
