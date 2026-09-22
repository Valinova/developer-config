# Full Documentation Review

Shared body for every harness's `full-docs` skill; the invoking stub names the
harness's audit and reviewer seats and model card.

Run the `docs` skill (`always/skills/docs/SKILL.md`) over every core document
in the repository — not only the ones the branch touched — then validate the
result adversarially. That validation is this workflow's gate
(`model-selection.md` "External calls"); invoking it is the approval.

## Preamble

Per "Announce-then-proceed preamble": the validation reviewer's seat and rung,
then the audit scope, and the parent pipeline mode only when composed.

## Steps

1. **Audit.** Apply `docs` to the full core-doc set, fanning out audit
   subagents at the harness's audit seat, with effort and fan-out per
   `model-selection.md` "Effort" and "Subagent fan-out".
2. **Implement** every clear, valuable improvement the audit finds.
3. **Validate.** One cross-family reviewer at the harness's reviewer seat
   reviews the complete documentation diff. Apply only findings the
   orchestrator and reviewer both deem valuable.
4. Leave the resulting edits unstaged for the user's final review.
