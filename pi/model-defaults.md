# Sub-agent model defaults (Pi)

Before dispatch, read
`~/Development/developer-config/instructions/model-selection.md`, especially
"External calls", "Announce-then-proceed preamble",
"Harness seats", "Roster", "Effort", and "Subagent fan-out". Those sections
own shared policy; this card is not a substitute for them.

Pi-only concerns below: explicit slugs (Pi cannot fuzzy-resolve family
names), dispatch mechanics, and delegated `pi -p` runs. Hermes farm contracts
in `coding-orchestration.md` (`delegate_task`, cron, PR-burndown) do not apply
to Pi.

An explicit user instruction wins among valid combinations; hard constraints
still apply.

## Pi seat

- The session model is the machine's local config (`model-selection.md`
  "Harness seats"). Each `Agent` dispatch's model follows the same
  two-family rule, translated through the ID map below.
- Native Anthropic on Pi bills the API: an `anthropic/…` `Agent` runs only
  when the user names it, and the subscription-only Opus rule in canonical
  "Subagent fan-out" does not authorize it.

## Exact Pi model IDs

Every fresh `Agent` call needs `provider/id` — use this map, do not guess
versioned slugs:

| Family | Pi ID |
|--------|-------|
| **Grok 4.7** | `xai/grok-4.7` |
| **Codex (Astra)** | `openai-codex/gpt-6-astra` |
| **Codex (Sol)** | `openai-codex/gpt-6-sol` |
| **Fable 5.1** | `anthropic/claude-fable-5-1` |
| **DeepSeek V4 Flash** | `deepseek/deepseek-flash` |

This is an ID map, not a roster or authorization to use a seat. For an
explicitly authorized model absent here, resolve its exact ID in Pi's
authenticated `/model` list before dispatch; do not guess a versioned slug.

### Provider routing is sealed

The provider prefix names an **authenticated Pi provider**, not the model's
vendor. Two prohibitions, neither a preference:

- **DeepSeek only through `deepseek`.**
- **OpenAI models only through the `openai-codex` subscription** — never
  `openrouter` or the metered `openai` API, unless the user explicitly
  instructs that route for that dispatch.

Stated as prohibitions because Pi does not error on an unknown provider/model
pair: it falls through to OpenRouter and bills the metered key. A
vendor-prefixed or stale ID therefore fails **silently onto a paid route** —
a mid-run 402, not a dispatch error. The worked example: `openai/gpt-6-astra`
is OpenRouter's slug, while the subscription route is
`openai-codex/gpt-6-astra`; and `deepseek-v4-flash` does not exist in the
`deepseek` provider, whose model is `deepseek-flash`. If a needed ID is absent
from the table above, confirm the pair resolves inside the provider these
rules name — Pi's authenticated `/model` list or
`~/.pi/agent/models-store.json` — before dispatch.

**Hard constraints, restated because a prohibition must not depend on a
lookup:** never Haiku, never Sonnet, and Pi does not farm `claude -p`.

## Dispatch mechanics

- **Every fresh dispatch names `model` and `thinking`.** Tintin agent profiles
  own roles and tools only — not model defaults. Resume keeps the existing
  session model.
- Choose the seat and rung from canonical "Harness seats", "Roster", and
  "Effort", then translate the model through the ID map above.
  Interactive session model/thinking is TUI state in
  `pi/settings.json` — expected to change; do not reconcile it.
- Sub-agents can only use models Pi has authenticated (`/model`). If a pick
  or its selected rung is unavailable, report the unavailable dispatch;
  do not silently substitute a model, rung, or transport.

## Delegated runs (`pi -p` from another orchestrator)

The Codex delegation pattern (`instructions/codex-delegation.md`) works for
`pi` via mirror wrappers in `~/.claude/scripts/`:

```bash
~/.claude/scripts/pi-exec.sh <task-name> /tmp/pi-<task-name>-brief.md [--model SLUG] [--provider NAME] [--thinking LEVEL]
~/.claude/scripts/pi-wait.sh <task-name> [timeout-seconds]
~/.claude/scripts/pi-resume.sh <task-name> /tmp/pi-<task-name>-followup.md [same flags]
```

Wrapper defaults: `xai` / `grok-4.7` / thinking `high`; select each dispatch under `model-selection.md` and resolve Pi IDs through the map above. Registry: `~/.hermes/state/pi-sessions.jsonl` (separate file, created on first dispatch — it does not exist until then; shell-wrapper line grammar, i.e. the `log_file` + `source` shape, not the Hermes-helper `log_path` shape). Logs `/tmp/pi-<task>.log`, post-run summary `/tmp/pi-<task>.post-run.md`. Resume is cwd-keyed — run `pi-resume.sh` from the same repo as the dispatch.

Differences from Codex that change the brief:

- **Pi is NOT sandboxed.** The same no-git-writes Sandbox note, `CHANGED_FILES` report, and post-run provenance checks apply; git centralization is policy, not mechanics.
- The vendored `destructive-guard` extension (`pi/extensions/destructive-guard.ts`) hard-blocks unrecoverable ops (`rm -rf`, `sudo rm`, `find -delete`, `git reset --hard`, `git clean -f`, force pushes) in non-interactive `pi -p` mode — a blocked command in the log means pi tried one; treat it as a brief-compliance finding, not a wrapper bug.
- The vendored `bash-timeout-guard` extension (`pi/extensions/bash-timeout-guard.ts`) caps bash timeouts so hung commands cannot block forever.
- All other brief sections (Scope, Allowlist, Do NOT, Success criteria, final SUMMARY block) and post-run discipline apply unchanged.
- This covers *delegated* pi runs dispatched by an orchestrator. Direct interactive pi use (the user driving the TUI) is out of scope for these rules.
