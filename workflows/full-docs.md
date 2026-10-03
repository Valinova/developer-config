# Full Documentation Review

Shared body for every harness's `full-docs` skill. Seats, lanes, and the reviewer
come from `model-selection.md` "Harness seats"; IDs, wrappers, and sandbox
limits come from the harness's model card (`<harness>/model-defaults.md`;
Claude Code: `instructions/codex-delegation.md`).

Run the `docs` skill (`always/skills/docs/SKILL.md`) over every core document
in the repository — not only the ones the branch touched — then validate the
result adversarially. That validation is this workflow's gate
(`model-selection.md` "External calls"); invoking it is the approval.

## Preamble

Per "Announce-then-proceed preamble": the validation reviewer's seat and rung,
then the audit scope, and the parent pipeline mode only when composed.

## Steps

1. **Recon.** Before judging anything, list what the bar does not govern:
   content the app serves or generates, docs a test, script or lint rule
   reads (with the consumer), and agent commands that write into `docs/`.
2. **Audit.** Apply `docs` to the full core-doc set, fanning out read-only
   audit subagents at the harness's audit seat, with effort and fan-out per
   `model-selection.md` "Effort" and "Subagent fan-out". The output is a
   keep / fold / delete map.
3. **Implement** the map in lanes with fixed file allowlists. Committed plans
   and backlogs go: the reviewer checks each backlog entry against the code,
   and the real ones become issues.
4. **Validate.** One cross-family reviewer at the harness's reviewer seat
   reviews the complete documentation diff. Two finding classes block:
   content lost with no surviving owner, and a claim wrong against the code.
   Otherwise apply only findings the orchestrator and reviewer both deem
   valuable. After an implementer override, pick the reviewer by the actual
   author's family under `model-selection.md` "External calls".
5. **Enforce.** Add or tighten a docs-budget check in the repo's full check
   command, with ceilings at the final size rounded up.
6. Leave the resulting edits unstaged for the user's final review.
