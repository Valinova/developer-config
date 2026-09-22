# Grok Build dispatch defaults

Before dispatch, read
`~/Development/developer-config/instructions/model-selection.md`, especially
"External calls", "Announce-then-proceed preamble",
"Harness seats", "Roster", "Effort", and "Subagent fan-out". Those sections
own shared policy; this card is not a substitute for them. The `claude -p`
process lifecycle is owned in `codex/model-defaults.md` — follow it rather
than restating it. An explicit user or per-dispatch model/reasoning choice
always wins among valid combinations.

## Native subagents

- The session model is the machine's local config (`model-selection.md`
  "Harness seats"). Pin `grok-4.7` on `spawn_subagent` when the parent might
  not already be on it — never a silent older version.
- `spawn_subagent` is Grok-only (`explore`, `plan`, `general-purpose`, plus any
  user-defined type). It cannot start a Claude or Codex child.

## Cross-family dispatch

- **Codex**: the configured wrappers (`~/.claude/scripts/codex-exec.sh` and
  twins). Follow the brief grammar, flags, and post-run discipline in
  `instructions/codex-delegation.md`; select the lane and effort from the
  canonical policy, including implementation overrides.
- **Claude**: `claude -p` — never a Grok subagent standing in for Claude.
  Select the seat and effort from the canonical policy. Follow the process
  lifecycle in `codex/model-defaults.md`; a quiet run is still running until
  it returns or exits with a hard error.
- Native Anthropic inside Grok Build does not exist. Claude is `claude -p`
  only.

## Fan-out

Follow canonical "Subagent fan-out", including browser-driving seats.

## Grok as a leaf

How another orchestrator (Claude Code via `pi-exec.sh`, Codex over ACP,
Hermes) briefs a Grok 4.7 leaf. Grok is never a default seat: route to it
only when the user names Grok for that dispatch.

**Grok 4.7 briefing (light):** prefer short briefs with a clear preference and
hard done criteria; long specs are fine when you already have them. Do not
import Claude-side briefing habits onto Grok — brief it on its own terms
(why: rationale.md#grok-briefing).

**Sizing a user-named Grok pass.** Treat roughly 250K input tokens as a
rough guide to not overloading one pass's context to the point it degrades —
it is not a figure to compute, track, or enforce; size using actual evidence
such as elapsed time, accepted-diff percentage, missed consumers, and
orchestrator corrections.
