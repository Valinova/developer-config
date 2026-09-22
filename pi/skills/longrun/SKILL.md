---
name: longrun
description: Runs the full autonomous delivery pipeline from adversarial planning through implementation, review, docs, push, pull request, and PR babysitting to merge-ready. Use only when the user explicitly invokes "longrun" or "long run".
---

# Long Run — Pi

Read `~/Development/developer-config/workflows/longrun.md` and follow it.
This stub carries only the Pi facts that body defers to:

- Orchestrator: the active Pi model, Grok 4.6 by default. Model card: `pi/model-defaults.md` (exact IDs, `Agent` dispatch).
- Implement lane: a Codex `Agent`; Grok or DeepSeek `Agent` when the user names one, Anthropic only when the user names it.
- Reviewer seat: a cross-family `Agent` — Grok vs Codex; Anthropic only when the user names it (card "Pi seat").
