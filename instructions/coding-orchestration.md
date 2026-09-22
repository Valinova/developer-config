# Coding orchestration architecture

Four-path system for how Hermes dispatches coding work. Each path has a distinct transport, auth owner, and use case.

**Delegation doctrine (2026-08-17):** CLI dispatch remains the default for
serious code work — Codex CLI brings server-side compaction, its own
subscription/auth ownership, and the hardened wrapper scripts. Hermes-native
`delegate_task` stays niche/lightweight (planning farm, trivial retrieval,
summaries), never the implementer. Before dispatch, read
`~/Development/developer-config/instructions/model-selection.md`, especially
"Harness seats", "Roster", "Effort", and "Subagent fan-out". This file owns
transports and farm contracts, not shared model policy. The `/longrun` family lives in
`hermes/skills/` and uses the same names as Claude/Pi (`agentplan` →
`execute-plan` → `rev` → `docs` → `longrun`).

## Path 1: Hermes → Codex CLI subprocess (coding execution — PRIMARY)

Hermes delegates coding tasks by invoking `codex exec` via the terminal tool. Codex CLI owns its own auth lifecycle (`~/.codex/auth.json`).

**When:** All Hermes-initiated coding work — features, refactors, bug fixes, implementation phases.

**Model and effort:** Select from `model-selection.md` "Harness seats", "Roster", and "Effort"; pass those choices explicitly.

**How it works:**
1. Hermes writes a brief to `/tmp/brief.md` (follows `codex-delegation.md` grammar)
2. Hermes launches `codex exec -m <chosen-model> -c model_reasoning_effort=<chosen-effort> --skip-git-repo-check --sandbox workspace-write "$(cat /tmp/brief.md)" </dev/null` via `terminal(background=true, notify_on_complete=true)`, routed through the dispatch guard below.
3. Codex CLI reads/writes files in the repo, manages its own session
4. On completion: Hermes runs `git status` + `git diff --stat`, verifies (typecheck/lint/test), commits
5. Hermes reports summary to the user

**Why subprocess, not native HTTP:** Codex CLI and Hermes share the same ChatGPT OAuth subscription. Native HTTP delegation (`delegation.provider: openai-codex`) would create a second token store (`~/.hermes/auth.json`) competing for the same refresh token — causing `refresh_token_reused` errors. The subprocess approach uses one token consumer (Codex CLI) with one auth file. No conflict.

**Scripts:**
- `~/.hermes/scripts/codex_delegate.py` — session-aware dispatcher (initial dispatch)
- `~/.hermes/scripts/codex_resume.py` — session resume (review → fix iteration)
- `~/.hermes/scripts/codex_exec.sh` — full git lifecycle executor (crons, headless)

**Invocation** (the Hermes caller of the `codex-delegation.md` brief contract):

```bash
python3 ~/.hermes/scripts/codex_delegate.py \
  --task <name> --brief /tmp/brief.md --cwd /path/to/repo
```
Returns JSON on stdout: `{task, agent, status, session_id, log_path, post_run_path, exit_code, ...}`.

Resume (review → fix flow):
```bash
python3 ~/.hermes/scripts/codex_resume.py \
  --task <name> --brief /tmp/followup-brief.md --cwd /path/to/repo
```

`codex_exec.sh` key options: `--repo` / `--brief` (required), `--branch` (defaults `auto-exec/YYYY-MM-DD`), `--model` (defaults `gpt-6-astra`), `--reasoning` (defaults `high`), `--no-push` / `--no-commit` / `--no-stash-wip`, `--output-json`. Note it stashes uncommitted WIP by default — pass `--no-stash-wip` when Codex must see unstaged work.

## Session registry

Every Codex wrapper (Hermes helpers and the Claude/Grok shell wrappers alike) appends lifecycle events to the canonical, durable registry at `~/.hermes/state/codex-sessions.jsonl` — on start, on session_id capture, and on close. It is shared across callers and never auto-pruned; `/tmp/codex-<task>.*` files are per-run ephemera only. On machines without a Hermes install, `~/.hermes/state/` is simply the registry directory — the wrappers `mkdir -p` it.

**One writer schema, one owner.** Both families write through the shared library at `developer-config/always/scripts/lib/codex_registry.py` (shell face: `codex-registry.sh`) — it owns the line grammar, the thread-id / agent-message extraction regexes, the post-run summary, and the dispatch-hygiene constants (90min timeout, 45s stall check). Every new line carries **`log_path`** plus `"source":"hermes"` or `"source":"claude-code"`, with the same event vocabulary (`start` / `session_captured` / `close`, `resume_*` for resumes). Historical Claude-side lines used **`log_file`**; the library's readers normalize those to `log_path` in memory, and registry content is never rewritten. Hermes depends on developer-config for this lib, never the reverse — the Claude wrappers must work on a machine with no Hermes install (`$CODEX_REGISTRY_LIB` overrides the lib lookup; `$CODEX_REGISTRY_PATH` overrides the registry path).

## Path 2: Hermes → Claude Code subprocess

Hermes reaches the Claude seat selected under `model-selection.md` via `claude -p`. Claude Code owns its own auth lifecycle (`~/.claude.json` + macOS keychain).

**When:** The canonical harness and roster rules select a Claude seat for the task.

**Model and effort:** Pass `--model <chosen-seat> --effort <chosen-effort>` from `model-selection.md` "Roster" and "Effort".

**How it works:**
1. Hermes writes a brief to `/tmp/brief.md`
2. Hermes launches `cat /tmp/brief.md | claude -p '...' --model <chosen-seat> --effort <chosen-effort> --dangerously-skip-permissions` via `terminal(background=true, notify_on_complete=true)`, routed through the dispatch guard below. Follow the process lifecycle in `codex/model-defaults.md`.
3. Claude Code reads files, reasons, writes output
4. Hermes reviews result, reports to the user

**Why subprocess, not native HTTP:** Same reason as Codex. Claude Code and Hermes share the same Anthropic OAuth subscription. The subprocess approach keeps Claude Code as the single token consumer. No ACP support exists in Claude Code (`claude --help` has no `--acp` flag as of v2.1.185), so native delegation was never an option here.

## Path 3: Claude Code → Codex CLI (interactive sessions)

When the user is in an interactive Claude Code session (terminal or IDE), Claude Code invokes Codex directly for cross-family review. This is Claude Code's own internal toolchain — Hermes is not involved.

**When:** A key gate under `model-selection.md` "External calls" (the plan/scope review, the final `rev`), or an Astra implement pass the user named for that dispatch.

**How it works:**
1. Claude Code (Opus under the Fable orchestrator) produces the plan or diff
2. Claude Code writes the review or implement brief
3. Claude Code calls `~/.claude/scripts/codex-exec.sh` — a standalone shell wrapper that invokes `codex exec --sandbox workspace-write --json` directly (it does NOT call `codex_delegate.py`; it shares the registry library, `always/scripts/lib/codex_registry.py`, with the Hermes helpers — see `codex-delegation.md`)
4. Codex CLI executes the task, returns result to Claude Code
5. Claude Code continues the session

**Why this exists:** Claude-authored work needs a reviewer outside its own family (why: rationale.md#cross-family-review). This path is orthogonal to Hermes orchestration — it's the user's direct coding workflow.

## Path 4: Crons → Codex CLI — decommissioned

Live crons run `~/.hermes/scripts/agent-run.sh` with `claude -p`, invoking Codex inside that run as the cross-family reviewer; do not build crons on `codex_exec.sh` directly.

## What is NOT used

Native HTTP delegation would give Hermes a second token store competing with the CLI's for the same OAuth refresh token (`refresh_token_reused`), so CLI subprocesses stay the single auth consumer.

- `delegate_task` with `acp_command="codex"` or `"claude"`: dead — neither CLI has `--acp`.
- `delegate_task` with `delegation.provider: openai-codex`: not viable — the OAuth conflict above.
- `delegate_task` native batch: niche/lightweight only — Hermes-specific tools, summaries, extraction, mechanical batches (`simplify-code`); never the serious-code implementer; DeepSeek only for trivial retrieval/summaries.

## Execution paths (preference order)

1. **Subscription CLI harnesses for ALL farm-out work.**
   - `claude -p` — Anthropic subscription OAuth, *not* direct-API billing. Apply `model-selection.md` "Orchestrator context discipline".
   - `codex exec` — OpenAI subscription coding/review path. Always `</dev/null` in non-interactive contexts.
   - Fan-out follows `model-selection.md` "Subagent fan-out" and the process limits below.
2. **Hermes-native `delegate_task` — niche/lightweight.** Use the native batch contract above.

If routing around path 1 for work that could use it, state why in the dispatch note.

## Approved PR burndown contract

PR burndown uses one subscription-OAuth `claude -p` orchestrator session.
The Claude seat is Opus 5.5 (Fable only as a complex reviewer or arbiter);
review effort and fan-out follow `model-selection.md`. Partition logical review scopes by diff size,
subsystem boundaries, risk, and the value of independent review. Native
Claude subagents inherit the session's effort. The orchestrator
partitions, validates, deduplicates, audits, and synthesizes; the subagents own
deep code review.

Direct fixes are sequential Opus 5.5 implementation passes; Astra implements
only when the user names it. Select effort under `model-selection.md`, and
audit one pass before starting the next.

The same orchestrator session writes the concise PR-scoped `REVIEW.md`, including
coverage, implementation efforts, rejected findings, nuanced discussion items,
and ranked strategic/architecture observations with future actions. Nuanced
items are also appended to `DISCUSSION-PR<N>.md`. No separate post-burndown
strategic-analysis session is launched.

## Approved decision-brief contract

Decision briefs are an approved subscription-OAuth Claude use for grounded,
genuinely nuanced forks in Sentry triage and PR burndown.

The Claude seat (Opus 5.5; Fable as arbiter on a complex fork) chairs and synthesizes; the cross-family challenger
selected under `model-selection.md` takes an independent, read-only blind
position. Review subagents do not participate in this decision gate;
their PR code-review role is unchanged. Both participants must independently agree
the user's judgment is required before escalation. They may prefer different
options, and the brief preserves that dissent. Noise, under-evidenced questions,
and decisions already answered by policy do not reach the user.

The consumer selects each model's reasoning effort under `model-selection.md`
"Effort". Service tier follows `codex-delegation.md`.

## Efficiency rules

- **Effort:** apply `model-selection.md` "Effort" to the actual task.
- **Detection before a review gate:** re-run a *specific finding* through the other family only at action boundaries: about to auto-PR, no-go-adjacent finding, or a charter contradiction. Whether a review call happens at all is `model-selection.md` "External calls".
- **Never two models on detection output that a downstream filter/reviewer already de-risks.**
- Quota headroom is the real currency; if one subscription runs hot, rebalance the defaults, not per-callsite.

## Subagent dispatch discipline

All dispatches follow `codex-delegation.md` for briefs, provenance, verification, and git ownership.

- Concurrency: follow `model-selection.md` "Subagent fan-out". Hard rules on top: parallel WRITERS must have disjoint file allowlists and be told about each other (foreign typecheck errors = environmental, report don't fix); sequential whenever a verification gate needs clean failure attribution. Codex keeps its own limit (see `codex-delegation.md`) — that one is real process contention.

## Background dispatch loop guard

Enforcement is mechanical (why: rationale.md#dispatch-loop):

- **Mechanical enforcement (authoritative): a `pre_tool_call` hook** — `~/.hermes/scripts/dispatch_guard_hook.py`, registered via a `hooks:` block in `~/.hermes/config.yaml`. It blocks a duplicate dispatch against an in-flight `--resume` session, normalized-argv duplicates, >10 LLM-CLI dispatches per rolling 10 minutes, >4 concurrent, and a hard ceiling of 60/day. Decisions logged to `~/.hermes/logs/dispatch-guard-audit.jsonl`. `max_turns` stays at 1000 deliberately — rate, not turn count, is the guarded axis. A guard denial means stop and report; never retry or route around it.
- **All background LLM CLI invocations (`claude -p`, `codex exec`) from Hermes go through `~/.hermes/scripts/llm_dispatch.sh`.** Semantics: signature lock per normalized command + session-ID lock for `--resume`; a duplicate dispatch while running waits on / reads the original's output instead of spawning; a completed result is returned from disk; >3 attempts per signature per day trips a loud circuit breaker. See `~/.hermes/scripts/README-dispatch-guard.md`. This is the idempotency primitive, not the enforcement layer — it only helps when the caller routes through it.
- No `approvals.deny` backstop, and none is possible: its globs cannot distinguish background from foreground. Any doc claiming a deny backstop is wrong.
- Agent rule on top: after dispatching a background process, the next action is poll/wait/report — never re-dispatch an identical command. If a re-dispatch seems necessary, read the output file and `process list` first; identical-command re-issue is the loop signal.

## Auth doctrine (hard rules)

- Subscription OAuth only for both CLIs. No `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` in env for CLI sessions; no Doppler-injected Anthropic/OpenAI keys.
- Claude seating: `model-selection.md` "Harness seats" and "Roster".
- `claude -p` waiting, diagnostics, and termination follow the process lifecycle in `codex/model-defaults.md`.
- `claude -p` reported `total_cost_usd` is API-equivalent accounting against quota, not real billing.
