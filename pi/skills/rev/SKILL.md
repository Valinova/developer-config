---
name: rev
description: Runs a standalone or composable branch review as one cross-family review at the depth the change warrants (code-simplifier plus the principles audit on the full row) with agreed fixes committed. Use only when the user explicitly invokes "rev" or requests this review workflow.
---

# Adversarial Review — Pi

Read `~/Development/developer-config/workflows/rev.md` and follow it.
This stub carries only the Pi facts that body defers to:

- Orchestrator: the active Pi model, Grok 4.6 by default. Model card: `pi/model-defaults.md` (exact IDs, `Agent` dispatch).
- Reviewer seat: a cross-family `Agent` — Grok vs Codex; Anthropic only when the user names it (card "Pi seat").
- Implement lane: a Codex `Agent`; Grok or DeepSeek `Agent` when the user names one, Anthropic only when the user names it.
