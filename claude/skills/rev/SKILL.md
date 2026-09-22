---
name: rev
description: Runs a standalone or composable branch review as one cross-family review at the depth the change warrants (code-simplifier plus the principles audit on the full row) with agreed fixes committed. Use only when the user explicitly invokes "rev" or requests this review workflow.
---

# Adversarial Review

Read `~/Development/developer-config/workflows/rev.md` and follow it. If you
cannot read that file, stop and say so — do not improvise the workflow.

Seats, lanes, and the reviewer come from `model-selection.md` "Harness seats"
for this harness's family; IDs, wrappers, and sandbox limits come from the
harness's model card (`<harness>/model-defaults.md`; Claude Code:
`instructions/codex-delegation.md`).
