# Grok Build dispatch defaults

Before dispatch, read
`~/Development/developer-config/instructions/model-selection.md`, especially
"External calls", "Announce-then-proceed preamble",
"Harness seats", "Roster", "Effort", and "Subagent fan-out". Those sections
own shared policy; this card is not a substitute for them. The `claude -p`
process lifecycle is owned in `codex/model-defaults.md` — follow it rather
than restating it. An explicit user or per-dispatch model/reasoning choice
always wins among valid combinations.

## Grok Build seat

Canonical seat row for this harness; column grammar and shared policy per model-selection.md "Harness seats":

| Harness | Orchestrator | Implement default | Implement override | Reviewer transport |
|---------|--------------|-------------------|--------------------|----------------------|
| **Grok Build** | Grok 4.6 (xAI sub). Native `spawn_subagent` is Grok 4.6 only — never a silent `grok-4.5`. | Codex via wrappers (ChatGPT sub) | Grok `spawn_subagent`; `claude -p --model fable` (`opus` for mechanical passes). Never Grok-native Anthropic. | Native Grok; `claude -p`; Codex wrappers |

## Native seat

- Pin the canonical native model on `spawn_subagent` when the parent might
  not already be on it; the seat row above names the selected version.
- `spawn_subagent` is Grok-only (`explore`, `plan`, `general-purpose`, plus any
  user-defined type). It cannot start a Claude or Codex child.
- Choose native effort under canonical "Effort".
- Recon and bulk fact-gathering (canonical "Orchestrator context
  discipline"): `claude -p` on the Claude seat chosen by task shape under
  "Roster"; native Grok 4.6 `spawn_subagent` is also fine for in-family recon.

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
Hermes) briefs and routes to a Grok 4.6 leaf. Select Grok under the canonical review or implementation policy.

**Grok 4.6 briefing (light):** prefer short briefs with a clear preference and
hard done criteria; long specs are fine when you already have them. Do not
import Claude-side briefing habits onto Grok — brief it like a third-family
peer (why: rationale.md#grok-briefing).

**Grok implementation routing is semantic, not a file-count rule.** Prefer a
Grok leaf when the canonical owner and local pattern are known, the result is
locally testable, downstream impact is shallow, and success criteria are
explicit. Prefer Codex Astra for shared contracts or registries, generated
artifacts, persistence/auth/pagination/cache behavior, multi-surface changes,
or an uncertain blast radius. A broad mechanical edit can be a better Grok
task than a three-file architectural change. Treat roughly 250K input tokens
as a rough guide to not overloading one pass's context to the point it
degrades — it is not a figure to compute, track, or enforce; route using
actual evidence such as elapsed time, accepted-diff percentage,
missed consumers, and orchestrator corrections.
