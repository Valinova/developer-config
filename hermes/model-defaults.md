# Hermes dispatch defaults

Before dispatch, read
`~/Development/developer-config/instructions/dispatch-bootstrap.md`,
`~/Development/developer-config/instructions/git-operations.md`,
`~/Development/developer-config/instructions/codex-delegation.md`, and
`~/Development/developer-config/instructions/model-selection.md`, especially
"Announce-then-proceed preamble",
"Harness seats" and "Subagent fan-out". Those sections
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
  conversation, when it is Codex, uses `provider: openai-codex` and the current
  Sol model from the picker. Choose its expanded-context entry when offered
  (`-900k` is stripped on the wire). Leave `model.context_length` unset so
  Hermes uses the picker entry's budget.

## Machine-local vs owned here

Doctrine and the Claude-access rule live in this repo with history
(`model-selection.md` and this card). Only machine facts — the session
model, install paths, auth files, which host actually runs Hermes — belong
in the gitignored `~/.hermes/`. Hermes skills that restate doctrine instead
of pointing at it are drift (see SETUP.md).

## Cache and compression config

`~/.hermes/config.yaml` sets `prompt_caching.cache_ttl: 1h` (valid: `5m` | `1h`)
and `compression.threshold: 0.35`; compact only at boundaries, never mid-flow.
