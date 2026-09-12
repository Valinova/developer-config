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

When the user is in an interactive Claude Code session (terminal or IDE), Claude Code can invoke Codex directly for execution horsepower. This is Claude Code's own internal toolchain — Hermes is not involved.

**When:** The user is coding interactively in Claude Code and wants to delegate a mechanical task to Codex.

**How it works:**
1. The user asks Claude Code to do something
2. Claude Code plans the approach
3. Claude Code calls `~/.claude/scripts/codex-exec.sh` — a standalone shell wrapper that invokes `codex exec --sandbox workspace-write --json` directly (it does NOT call `codex_delegate.py`; it shares the registry library, `always/scripts/lib/codex_registry.py`, with the Hermes helpers — see `codex-delegation.md`)
4. Codex CLI executes the task, returns result to Claude Code
5. Claude Code continues the session

**Why this exists:** Claude is a strong planner; Codex is a fast executor. For complex interactive work, having Claude plan and Codex execute gives better results than either alone. This path is orthogonal to Hermes orchestration — it's the user's direct coding workflow.

## Path 4: Crons → Codex CLI (automated/headless) — HISTORICAL, decommissioned

> **Decommissioned (noted 2026-07-30).** No live cron routes *directly* to
> `codex_exec.sh` as its primary engine any more. The actual live pattern is:
> **cron job → `~/.hermes/scripts/agent-run.sh` running `claude -p`**, with
> Codex invoked *inside* that run as the cross-family reviewer rather than as
> the router. Sentry work follows the same shape via `scripts/sentry_cycle.py`.
> The description below is kept for historical context — do not build new crons
> on it.

Scheduled jobs (daily reviews, focus reviews) route directly to Codex CLI. Hermes is NOT in the review decision loop — it only receives the result for delivery.

**When:** Automated code reviews, focus reviews, any scheduled coding task.

**How it works:**
1. Cron pre-run script collects repo context (git log, AGENTS.md, focus.md, REVIEW.md)
2. Script output injects into the Codex prompt deterministically
3. `codex_exec.sh` runs Codex with the review brief, handles full git lifecycle (stash → branch → tree-snapshot → Codex → stage → commit → push → restore WIP)
4. Result gets written to `~/.hermes/cron/output/<job_id>/`
5. Hermes delivers the output; it does not judge or modify the review

**Why direct:** Removed the Hermes-in-the-middle bottleneck. The script was the deterministic router for the subscription CLI path.

## What is NOT used (and why)

### `delegate_task` with `acp_command="codex"`

**Dead.** Codex CLI has no `--acp` flag. The `acp_command` parameter forces `copilot-acp` provider, which tries to spawn `codex --acp --stdio` as a subprocess. Codex doesn't support ACP — this path fails immediately. All references removed from docs and skills.

### `delegate_task` with `delegation.provider: openai-codex` (native HTTP)

**Not viable due to OAuth conflict.** Hermes would store its own Codex OAuth tokens in `~/.hermes/auth.json`, competing with Codex CLI's `~/.codex/auth.json` for the same refresh token. Since the user uses Codex CLI interactively, both consumers would invalidate each other's tokens. The subprocess approach (Path 1) avoids this entirely by using Codex CLI as the single auth consumer.

### `delegate_task` with `acp_command="claude"`

**Dead.** Claude Code has no `--acp` flag (verified v2.1.185, June 2026). Was never functional.

### `delegate_task` native batch (Hermes subagents)

**Niche/lightweight only.** Native Hermes subagents are acceptable for Hermes-specific tools, summaries, extraction, and mechanical batches such as `simplify-code`. They must not be the serious-code implementer; use the CLI path for that. Select the family under `model-selection.md` "Harness note — DeepSeek". This uses Hermes's own model, not Codex or Claude OAuth. No conflict.

## Execution paths (preference order)

1. **Subscription CLI harnesses for ALL farm-out work.**
   - `claude -p` — Anthropic subscription OAuth, *not* direct-API billing. Apply `model-selection.md` "Orchestrator context discipline".
   - `codex exec` — OpenAI subscription coding/review path. Always `</dev/null` in non-interactive contexts.
   - Fan-out follows `model-selection.md` "Subagent fan-out" and the process limits below.
2. **Hermes-native `delegate_task` — niche/lightweight.** Use the native batch contract above.

If routing around path 1 for work that could use it, state why in the dispatch note.

## Approved PR burndown contract

PR burndown uses one subscription-OAuth `claude -p` orchestrator session.
Choose the Claude judgment seat, review effort, and fan-out under
`model-selection.md`. Partition logical review scopes by diff size,
subsystem boundaries, risk, and the value of independent review. Native
Claude subagents inherit the session's effort. The orchestrator
partitions, validates, deduplicates, audits, and synthesizes; the subagents own
deep code review.

Direct fixes run through the existing machine-wide Claude→Codex wrapper in
sequential implementation passes. Select model and effort under
`model-selection.md`, and audit one pass before starting the next. Service
tier follows the wrapper flags contract in `codex-delegation.md`.

The same orchestrator session writes the concise PR-scoped `REVIEW.md`, including
coverage, implementation efforts, rejected findings, nuanced discussion items,
and ranked strategic/architecture observations with future actions. Nuanced
items are also appended to `DISCUSSION-PR<N>.md`. No separate post-burndown
strategic-analysis session is launched.

## Approved decision-brief contract

Decision briefs are an approved subscription-OAuth Claude use for grounded,
genuinely nuanced forks in Sentry triage and PR burndown.

(2026-07-30: the v1 Sentry triage cron is retired/disabled; its replacement,
sentry-cycle v2, mechanizes this escalation as a `FORK` draft PR; its spec
lives with the Hermes deployment, outside this repo.)

The Claude judgment seat chairs and synthesizes; the cross-family challenger
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
- **Scan vs synthesis split for exploratory work:** cheap models in parallel for coverage, ONE expensive model for the judgment artifact. Never the reverse.
- **Never two models on detection output that a downstream filter/reviewer already de-risks.**
- Quota headroom is the real currency; if one subscription runs hot, rebalance the defaults, not per-callsite.

## Subagent dispatch discipline

Every subagent dispatch, from any orchestrator, carries the same rigor as a Codex brief:

- Every dispatch prompt names: scope, explicit file allowlist, Do-NOTs, success criteria with verification commands, and a required report format. An agent needing an out-of-allowlist file stops and reports; the orchestrator re-scopes — agents never expand their own scope.
- Provenance snapshot before dispatch (see "Parallel work in the worktree" in `principles.md`); after each pass, diff against snapshot + allowlist before proceeding.
- Implementation agents leave changes unstaged; the orchestrator owns staging and commits.
- Local verification follows `codex-delegation.md` "Post-run discipline": the implementer runs its scoped checks and the invoker runs the full pre-commit gate. Independent judgment is a separate review decision under `model-selection.md` "External calls", not a required extra agent for verification.
- Concurrency: follow `model-selection.md` "Subagent fan-out". Hard rules on top: parallel WRITERS must have disjoint file allowlists and be told about each other (foreign typecheck errors = environmental, report don't fix); sequential whenever a verification gate needs clean failure attribution. Codex keeps its own limit (see `codex-delegation.md`) — that one is real process contention.

## Background dispatch loop guard (hard — 2026-07-29 incident)

A Hermes session degenerated into a loop: it re-issued an identical background `claude -p --resume` dispatch **~440 times over 59m43s** (one every 6–10s, all resuming the same Fable session) instead of waiting for the first run, which had already written its answer to disk in 7 minutes — each new spawn then truncated that output. Cost: ~3.4M output tokens plus ~275M cached input tokens, 4 spawns hitting the monthly spend limit, concurrent resumes clobbering one session's context, and an hour of user silence. A `/steer` was delivered and ignored; only the user's `/stop` ended it. A behavioral note alone would not have stopped it — enforcement is mechanical:

- **Mechanical enforcement (authoritative): a `pre_tool_call` hook** — `~/.hermes/scripts/dispatch_guard_hook.py`, registered via a `hooks:` block in `~/.hermes/config.yaml`. It blocks a duplicate dispatch against an in-flight `--resume` session, normalized-argv duplicates, >10 LLM-CLI dispatches per rolling 10 minutes, >4 concurrent, and a hard ceiling of 60/day. Decisions logged to `~/.hermes/logs/dispatch-guard-audit.jsonl`. `max_turns` stays at 1000 deliberately — rate, not turn count, is the guarded axis. A guard denial means stop and report; never retry or route around it.
- **All background LLM CLI invocations (`claude -p`, `codex exec`) from Hermes go through `~/.hermes/scripts/llm_dispatch.sh`.** Semantics: signature lock per normalized command + session-ID lock for `--resume`; a duplicate dispatch while running waits on / reads the original's output instead of spawning; a completed result is returned from disk; >3 attempts per signature per day trips a loud circuit breaker. See `~/.hermes/scripts/README-dispatch-guard.md`. This is the idempotency primitive, not the enforcement layer — it only helps when the caller routes through it.
- No `approvals.deny` backstop, and none is possible: deny matching is fnmatch globs on the full command string and structurally cannot distinguish background from foreground, so a deny glob would block legitimate interactive use too (verified against `hermes-agent/tools/approval.py` + `terminal_tool.py`, 2026-07-29; re-confirmed 2026-07-30). Any doc claiming a deny backstop is wrong.
- Agent rule on top: after dispatching a background process, the next action is poll/wait/report — never re-dispatch an identical command. If a re-dispatch seems necessary, read the output file and `process list` first; identical-command re-issue is the loop signal.

## Auth doctrine (hard rules)

- Subscription OAuth only for both CLIs. No `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` in env for CLI sessions; no Doppler-injected Anthropic/OpenAI keys.
- Claude seating: `model-selection.md` "Harness seats" and "Roster".
- `claude -p` waiting, diagnostics, and termination follow the process lifecycle in `codex/model-defaults.md`.
- `claude -p` reported `total_cost_usd` is API-equivalent accounting against quota, not real billing.

## Refinement

This is v2 (June 2026). Replaces the v1 two-track model that incorrectly referenced ACP transports. As patterns emerge, update this doc.
