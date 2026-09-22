---
name: agentplan
description: Produces and reviews a phased implementation plan without implementing it. Use only when the user explicitly asks for "agentplan", "agent plan", or "agent-plan".
---

# Agent Plan — Claude

Before choosing seats or effort, read
`~/Development/developer-config/instructions/model-selection.md` and
`~/Development/developer-config/instructions/codex-delegation.md` in full —
neither is always-loaded (`dispatch-bootstrap.md` owns the read rule).

Produce a phased implementation plan from the agreed direction. The active
Claude model (Fable 5.1) is the orchestrator; do not replace or pin it.

## Preamble

State first whether an external call is warranted, and why
(`model-selection.md` "External calls", "Announce-then-proceed preamble").

In **Discover** mode, run contextualization and the scope review
(steps 1, 4, 5 over the scope), write the scope section with the open questions
and what must be probed to close them, and stop before phases. A later
`agentplan` invocation resumes at phases via the existing plan artifact.

1. Restate the relevant project guidance and the engineering-principles
   constraints that bind this plan, naming the sections it leans on — the
   ambient principles doctrine is canonical; do not plan from a remembered
   subset. Apply the principles §4 ship gate at plan time: name the change's
   benefit and the surfaces it could regress.
2. Divide implementation into bounded agent passes that avoid context
   degradation (roughly 250K tokens as a guide, not a figure to compute).
3. Give each phase observable success criteria and lightweight orchestrator
   checks for correctness, simplicity, and adherence to any user-supplied
   North Star. Each phase also names its **rung** (decided by brief
   specificity under `model-selection.md` "Effort", never by the operation's
   risk; Opus 5.5 executes — name a seat only when a user override applies),
   whether a **courier** runs and what it reads back (only
   when the success criterion is observable solely on a deployment), and
   whether the implementer may fan out the mechanical tail
   (`codex-delegation.md` "Nested delegation"; seat per the leaf's own harness
   card, "Leaf fan-out").
   Per the principles §4 plan-time rule, each phase also names
   its minimal test set — the owner and failure path each test proves; "no
   new test — covered by <file>" is a valid answer, and a new test file
   ships only when the plan justifies it.
4. Apply `model-selection.md` "External calls" to the plan; a warranted
   review is Astra via the Codex wrappers.
5. Resolve findings before returning the plan. If a reviewer ran, incorporate
   mutually agreed conclusions. Escalate only unresolved critical choices
   under principles §4, with a recommendation and the tradeoff.
6. Return the revised plan. Do not implement it.

Persist the plan as a markdown file in the repository: update the existing plan
artifact if one exists, otherwise write it to the repo's established plan
location (default `plans/<date>-<slug>.md`). The plan is a working artifact —
after delivery, `longrun` folds its durable outcomes into canonical
documentation and deletes it.
