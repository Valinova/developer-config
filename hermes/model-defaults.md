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
  Hermes-native Anthropic or the Claude subscription plugin as an automatic
  route. The plugin was tried as the session brain and was not reliable;
  do not put it back without an explicit ask. Farm-out Codex goes through the
  shared `~/.claude/scripts/codex-*.sh` wrappers (ChatGPT sub). Hermes
  conversation, when it is Codex, is `provider: openai-codex` with picker slug
  `gpt-6.1-sol-900k` — the suffix is stripped on the wire. Do not pin
  `model.context_length` over it; the bare slug budgets the stale 272k
  advertisement.
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
