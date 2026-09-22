---
name: rev
description: Runs a standalone or composable branch review as one cross-family review at the depth the change warrants (code-simplifier plus the principles audit on the full row) with agreed fixes committed. Use only when the user explicitly invokes "rev" or requests this review workflow.
---

# Adversarial Review — Claude

Read `~/Development/developer-config/workflows/rev.md` and follow it.
This stub carries only the Claude facts that body defers to:

- Orchestrator: Fable 5.1 (`model-selection.md` "Harness seats", Claude Code row).
- Reviewer seat: Astra via the Codex wrappers (`codex-delegation.md`).
- Implement lane: Opus 5.5 — a native `Agent` (inherits the session rung) or `claude-exec.sh --model opus --effort <rung>` when the rung differs; Astra (Codex wrappers) or Grok (`pi-exec.sh`) only when the user names one.
- External-review-only mode: Claude is the reviewer when Codex, Grok Build, or Hermes invokes this skill through `claude -p`.
