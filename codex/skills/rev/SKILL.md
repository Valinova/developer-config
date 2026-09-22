---
name: rev
description: Runs a standalone or composable branch review as one cross-family review at the depth the change warrants (code-simplifier plus the principles audit on the full row) with agreed fixes committed. Use only when the user explicitly invokes "rev" or requests this review workflow.
---

# Adversarial Review — Codex

Read `~/Development/developer-config/workflows/rev.md` and follow it.
This stub carries only the Codex facts that body defers to:

- Orchestrator: GPT-6 Astra. Model card: `codex/model-defaults.md`.
- Reviewer seat: Claude through `claude -p` — Opus 5.5 for contained work, Fable 5.1 leading nested Opus discovery for complex or cross-cutting work; process lifecycle per the card.
- Implement lane: native Astra `spawn_agent` with `model` and `reasoning_effort` per spawn (override rules in the card); `claude -p --model opus` only when the user names it.
- Claude's installed `rev` may be invoked through `claude -p` in external-review-only mode with that seat and rung.
