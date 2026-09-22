---
name: babysit
description: 'Watches the open pull request and refines it to merge-ready: settles CI checks and CodeRabbit together, at most one push per round, with a two-round cost circuit breaker. Use only when the user explicitly invokes "babysit" or as the final longrun stage.'
disable-model-invocation: true
---

# Babysit

Read `~/Development/developer-config/workflows/babysit.md` and follow it. If you
cannot read that file, stop and say so — do not improvise the workflow.

Seats, lanes, and the reviewer come from `model-selection.md` "Harness seats"
for this harness's family; IDs, wrappers, and sandbox limits come from this
harness's model card.
