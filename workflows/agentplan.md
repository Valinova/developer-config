# Agent Plan

Shared body for every harness's `agentplan` skill. Seats, lanes, and the reviewer
come from `model-selection.md` "Harness seats"; IDs, wrappers, and sandbox
limits from the harness's model card.

Produce a phased implementation plan from the agreed direction. Do not
implement it. This workflow's gate is the plan/scope review
(`model-selection.md` "External calls"); invoking it is the approval.

## Preamble

Follow `model-selection.md` "Announce-then-proceed preamble" for the plan
review: its complexity read, seat, and rung.

In **Discover** mode, run steps 1, 4, and 5 over the scope, persist the scope
section with the open questions and what must be probed to close them, and
stop before phases. A later `agentplan` invocation resumes at phases via the
existing plan artifact.

## Steps

1. Restate the relevant project guidance and the engineering-principles
   constraints that bind this plan, naming the sections it leans on — the
   ambient principles doctrine is canonical; do not plan from a remembered
   subset. Apply the principles §4 "Ship gate" at plan time: name the change's
   benefit and the surfaces it could regress.
2. Divide implementation into bounded agent passes that avoid context
   degradation (roughly 250K tokens as a guide, not a figure to compute).
3. Give each phase observable success criteria and lightweight orchestrator
   checks for correctness, simplicity, and adherence to any user-supplied
   North Star. Each phase also names:
   - its **rung**, decided by brief specificity under `model-selection.md`
     "Effort", never by the operation's risk; a **seat** only when a user
     override applies (the harness's implement default otherwise);
   - whether a **courier** runs and what it reads back — only when the success
     criterion is observable solely on a deployment;
   - whether the implementer may fan out the mechanical tail
     (`codex-delegation.md` "Nested delegation"; `model-selection.md`
     "Leaf fan-out");
   - its minimal test set per the principles §4 "Plan-time rule" — the owner
     and failure path each test proves; "no new test — covered by <file>" is
     a valid answer, and a new test file ships only when the plan justifies it.
4. Run the plan review: one cross-family reviewer at the harness's reviewer
   seat, weight and rung per "External calls" and "Effort" — a full
   adversarial plan review in Full mode, scope-only in Discover
   ("Delivery pipeline modes").
5. Resolve findings before returning the plan: incorporate the mutually agreed
   conclusions; escalate only unresolved critical choices under principles §4.
6. Return the revised plan.

Persist the plan as a markdown file in the repository: update the existing plan
artifact if one exists, otherwise write it to the repo's established plan
location (default `plans/<date>-<slug>.md`). The plan is a working artifact —
after delivery, `longrun`'s docs stage folds its durable outcomes into
canonical documentation and deletes it.
