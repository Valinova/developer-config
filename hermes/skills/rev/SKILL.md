---
name: rev
description: Runs a standalone or composable branch review as one cross-family review at the depth the change warrants (code-simplifier plus the principles audit on the full row) with agreed fixes committed. Use only when the user explicitly invokes "rev" or requests this review workflow.
---

# Adversarial Review — Hermes

Read `~/Development/developer-config/workflows/rev.md` and follow it.
This stub carries only the Hermes facts that body defers to:

- Orchestrator: Grok 4.6. Model card: `hermes/model-defaults.md`; dispatch paths: `coding-orchestration.md`.
- Reviewer seat: from the card's reviewer transports, never the author's family; a Claude reviewer runs through `claude -p` — Opus 5.5 for contained work, Fable 5.1 leading nested Opus discovery for complex work.
- Implement lane: Codex CLI `gpt-6-astra` via the configured wrappers, rung passed explicitly; Hermes writes no product code. `claude -p --model opus` only when the user names it.
