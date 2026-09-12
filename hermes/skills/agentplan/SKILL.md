---
name: agentplan
description: Produces and reviews a phased implementation plan without implementing it. Use only when the user explicitly asks for "agentplan", "agent plan", or "agent-plan".
---

# Agent Plan — Hermes

Before choosing seats or effort, read
`~/Development/developer-config/hermes/model-defaults.md`
and its required canonical policy sections.

Produce a phased implementation plan from the agreed direction. The active
Hermes model is the orchestrator — prefer **Grok 4.6** (harness seats in
`model-selection.md`).

## Preamble

State first whether an external call is warranted, and why
(`model-selection.md` "External calls", "Announce-then-proceed preamble").

## Steps

In **Discover** mode, run contextualization and the scope review
(steps 1, 4, 5 over the scope). After reconciliation, persist the scope
section with the open questions and required probes, then stop before phases.
A later `agentplan` invocation resumes at phases via the existing plan
artifact.

1. Restate the relevant project guidance and the engineering-principles
   constraints that bind this plan, naming the sections it leans on — the
   ambient principles doctrine is canonical; do not plan from a remembered
   subset. Apply the principles §4 ship gate at plan time: name the change's
   benefit and the surfaces it could regress.
2. Divide implementation into bounded agent passes that avoid context
   degradation (roughly 250K tokens as a guide, not a figure to compute).
3. Give each phase observable success criteria and lightweight orchestrator
   checks for correctness, simplicity, and adherence to any user-supplied
   North Star. Each phase also names its **seat and rung** (decided by brief
   specificity under `model-selection.md` "Roster" and "Effort", never by the
   operation's risk), whether a **courier** runs and what it reads back (only
   when the success criterion is observable solely on a deployment), and
   whether the implementer may fan out the mechanical tail
   (`codex-delegation.md` "Nested delegation"; seat per the leaf's own harness
   card, "Subagent fan-out").
   Per the principles §4 plan-time rule, each phase also names
   its minimal test set — the owner and failure path each test proves; "no
   new test — covered by <file>" is a valid answer, and a new test file
   ships only when the plan justifies it.
4. Apply `model-selection.md` "External calls" to the plan; a warranted
   reviewer goes through the harness's model card and transports.
5. Resolve findings before returning the plan. If a reviewer ran, incorporate
   mutually agreed conclusions. Escalate only unresolved critical choices
   under principles §4, with a recommendation and the tradeoff.
6. Return the revised plan. Do not implement it.

Persist the plan as a markdown file in the repository: update the existing plan
artifact if one exists, otherwise write it to the repo's established plan
location (default `plans/<date>-<slug>.md`). The plan is a working artifact —
after delivery, `longrun` folds its durable outcomes into canonical
documentation and deletes it.
