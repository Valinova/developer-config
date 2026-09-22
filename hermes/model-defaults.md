# Hermes dispatch defaults

Before dispatch, read
`~/Development/developer-config/instructions/model-selection.md`, especially
"External calls", "Announce-then-proceed preamble",
"Harness seats", "Roster", "Effort", and "Subagent fan-out". Those sections
own shared policy; this card is not a substitute for them. Then read
`~/Development/developer-config/instructions/coding-orchestration.md` for
dispatch paths, wrappers, auth doctrine, and the PR-burndown / decision-brief
contracts.

## Hermes mechanics

- The session model is the machine's local config (`model-selection.md`
  "Harness seats"). Claude is `claude -p` only (Anthropic sub) — never
  Hermes-native Anthropic, which bills the API. Codex is `codex exec`
  (ChatGPT sub).
- DeepSeek via `delegate_task` only for trivial retrieval/summaries.

## Machine-local vs owned here

Doctrine and the Claude-access rule live in this repo with history
(`model-selection.md` and this card). Only machine facts — the session
model, install paths, auth files, which host actually runs Hermes — belong
in the gitignored `~/.hermes/`. Hermes skills that restate doctrine instead
of pointing at it are drift (see SETUP.md).

## Cache and compression config

`~/.hermes/config.yaml` sets `prompt_caching.cache_ttl: 1h` (valid: `5m` | `1h`)
and `compression.threshold: 0.35`; compact only at boundaries, never mid-flow.
