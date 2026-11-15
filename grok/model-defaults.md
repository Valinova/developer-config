# Grok Build dispatch defaults

Before dispatch, read
`~/Development/developer-config/instructions/dispatch-bootstrap.md`,
`~/Development/developer-config/instructions/git-operations.md`,
`~/Development/developer-config/instructions/codex-delegation.md`, and
`~/Development/developer-config/instructions/model-selection.md`, especially
"Announce-then-proceed preamble",
"Harness seats" and "Subagent fan-out". Those sections
own shared policy; this card is not a substitute for them. The `claude -p`
process lifecycle is owned in `instructions/codex-delegation.md`
"Raw `claude -p` process lifecycle" — follow it rather than restating it. An explicit user or per-dispatch model/reasoning choice
always wins among valid combinations.

## Native subagents

- The session model is the machine's local config (`model-selection.md`
  "Harness seats"). Pass the latest Grok model ID shown in the live
  `spawn_subagent` schema. If the schema only allows inheritance, verify the
  parent model and role defaults before spawning.
- `spawn_subagent` is Grok-only (`explore`, `plan`, `general-purpose`, plus any
  user-defined type). It cannot start a Claude or Codex child.

## Cross-family dispatch

- **Codex**: the configured wrappers (`~/.claude/scripts/codex-exec.sh` and
  twins). Follow the brief grammar, flags, and post-run discipline in
  `instructions/codex-delegation.md`; select the lane and effort from the
  canonical policy, including implementation overrides.
- **Claude**: `claude -p` — never a Grok subagent standing in for Claude.
  Select the seat and effort from the canonical policy. Follow the process
  lifecycle in `instructions/codex-delegation.md` "Raw `claude -p` process
  lifecycle"; a quiet run is still running until it returns or exits with a
  hard error.
- Native Anthropic inside Grok Build does not exist. Claude is `claude -p`
  only.

## Fan-out

Follow canonical "Subagent fan-out"; browser-driving seats follow "Harness seats".

## Grok as a leaf

How another orchestrator (Claude Code via `pi-exec.sh`, Codex over ACP,
Hermes) briefs a Grok leaf. Grok is never a default seat: route to it
only when the user names Grok for that dispatch. For ACP, resolve the latest
Grok ID in the model picker and pass it as `--model`.

**Grok briefing (light):** prefer short briefs with a clear preference and
hard done criteria; long specs are fine when you already have them. Do not
import Claude-side briefing habits onto Grok — brief it on its own terms
(why: rationale.md#grok-briefing).

**Sizing a user-named Grok pass.** Treat roughly 250K input tokens as a
rough guide to not overloading one pass's context to the point it degrades —
it is not a figure to compute, track, or enforce; size using actual evidence
such as elapsed time, accepted-diff percentage, missed consumers, and
orchestrator corrections.
