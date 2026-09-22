# Hermes seat defaults

Before dispatch, read
`~/Development/developer-config/instructions/model-selection.md`, especially
"External calls", "Announce-then-proceed preamble",
"Harness seats", "Roster", "Effort", and "Subagent fan-out". Those sections
own shared policy; this card is not a substitute for them. Then read
`~/Development/developer-config/instructions/coding-orchestration.md` for
dispatch paths, wrappers, auth doctrine, and the PR-burndown / decision-brief
contracts.

## Hermes seat

Canonical seat row for this harness; column grammar and shared policy per model-selection.md "Harness seats":

| Harness | Orchestrator | Implement default | Implement override | Reviewer transport |
|---------|--------------|-------------------|--------------------|----------------------|
| **Hermes** | Grok 4.6 (xAI sub) | `codex exec` (ChatGPT sub) | `claude -p --model opus` (Anthropic sub; Fable only as a complex reviewer/arbiter). Never Hermes-native Anthropic. | Grok; `claude -p`; Codex wrappers |

- Recon and bulk fact-gathering (canonical "Orchestrator context
  discipline"): `claude -p` on Opus 5.5 (Fable only as a complex
  reviewer/arbiter); DeepSeek via `delegate_task` only for trivial
  retrieval/summaries.

## Machine-local vs owned here

Seats and the Claude-access rule are decisions and live in this repo with
history (`model-selection.md` and the row above). Only machine facts —
install paths, auth files, which host actually runs Hermes — belong in the
gitignored `~/.hermes/`. Hermes skills that restate doctrine instead of
pointing at it are drift (see SETUP.md).
