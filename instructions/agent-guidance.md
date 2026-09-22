# Agent guidance optimization

Canonical reference for maintaining `AGENTS.md`, `CLAUDE.md`, and routed agent
guidance. This file is deliberately **not auto-loaded**; consult it when creating
or auditing guidance.

## Allocation

- Keep global, human-owned files for durable personal preferences and broad or
  safety-critical rules that should apply everywhere.
- Treat project files as the evidence-trained layer: keep only
  repository-specific, non-obvious constraints, costly failure modes, and
  pointers to canonical owners. Do not use them as project summaries or
  duplicate facts agents can discover cheaply.
- Move narrow instructions with reliable triggers into skills. Turn rules that
  can be checked deterministically into lint, tests, hooks, or CI rather than
  spending context on reminders.
- Give each fact one canonical owner. Other harness files point to that owner
  instead of maintaining parallel copies.

## Maintenance loop

1. Set a fixed context budget for each always-loaded file. New guidance must
   earn its space and should displace lower-value text when the budget is full.
2. Review batches of real sessions for repeated, consequential failures; do not
   encode one-off annoyances or hypothetical problems.
3. Make a few small, evidence-backed edits per pass, then observe later
   sessions before expanding them.
4. Keep broad rules and safety boundaries even when they are not frequently
   triggered; optimize routine or discoverable prose first.
5. Require human approval for guidance changes. Session evidence proposes
   changes; it does not autonomously rewrite standing instructions.

## Sources and further reading

- Kun Chen, [Your AGENTS.md Is a Neural Net](https://blog.kunchenguid.com/p/your-agentsmd-is-a-neural-net)
