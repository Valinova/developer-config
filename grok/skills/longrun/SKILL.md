---
name: longrun
description: Runs the full autonomous delivery pipeline from adversarial planning through implementation, review, docs, push, pull request, and PR babysitting to merge-ready. Use only when the user explicitly invokes "longrun" or "long run".
disable-model-invocation: true
---

# Long Run

Read `~/Development/developer-config/workflows/longrun.md` and follow it. If you
cannot read that file, stop and say so — do not improvise the workflow.

Seats, lanes, and the reviewer come from `model-selection.md` "Harness seats"
for this harness's family; IDs, wrappers, and sandbox limits come from the
harness's model card (`<harness>/model-defaults.md`; Claude Code:
`instructions/codex-delegation.md`).
