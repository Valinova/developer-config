# Codex dispatch defaults

Before dispatch, read
`~/Development/developer-config/instructions/model-selection.md`, especially
"External calls", "Announce-then-proceed preamble",
"Harness seats", "Roster", "Effort", and "Subagent fan-out". Those sections
own shared policy; this card is not a substitute for them.
The `claude -p` and Grok ACP process lifecycles are Codex-specific and are
owned here; the Grok lane runs only when the user names Grok. An explicit user or per-dispatch model/reasoning choice always
wins among valid combinations under that policy.

## Native subagents

- **`spawn_agent` takes `model` and `reasoning_effort` per spawn.** Choose
  both from the canonical policy and use the live tool schema. Full-history
  forks (`fork_turns="all"`, including the default) inherit the parent's model
  and effort and reject overrides. For a different model or rung, pass an
  explicit override with `fork_turns="none"` and a brief, or a supported
  partial-history fork. Machine defaults in `~/.codex/config.toml` are setup
  mechanics; see SETUP.md.
- **Sol (`gpt-6-sol`) at `high` is the native subagent default**, set as
  `[agents] default_subagent_model` / `default_subagent_reasoning_effort` in
  `~/.codex/config.toml`; pass `model="gpt-6-astra"` for an Astra pass.
- When a workflow calls for a cross-family Claude pass, use `claude -p` —
  never substitute another Codex subagent.

## Cross-family Grok ACP dispatch

Only when the user names Grok for a dispatch, delegate one leaf task through Grok Build's native
ACP server. This is an external Grok process supervised by Codex, not a Codex
native subagent and not `grok -p` or Pi; it does not change Codex's own
seats:

```bash
~/.claude/scripts/grok-acp-exec.py <task-name> /tmp/grok-<task-name>-brief.md \
  --cwd /absolute/path/to/repo --sandbox workspace \
  --model <chosen-model> --effort <chosen-effort>
```

- Grok Build owns OAuth in `~/.grok`; the wrapper inherits the authenticated
  CLI environment and never reads, copies, or logs auth files or tokens.
- The wrapper runs `grok agent stdio` with ACP, `--no-subagents`, an OS-level
  sandbox, all Git CLI calls disabled, and Claude/Cursor MCP discovery off for
  that subprocess. `--no-subagents` is this ACP leaf only — not a
  `claude -p` review rule (`codex-delegation.md` "Nested delegation"). Grok
  leaves changes unstaged; Codex owns scope review, verification, and every
  Git operation.
- Use `workspace` to implement and `read-only` to investigate or review.
  `strict` is available for untrusted repositories. The sandbox still allows
  Grok's own session state and temporary files as documented by Grok Build.
- Briefs name the scope, explicit file allowlist, anti-goals, and success
  criteria. The allowlist limits edits, not investigation: Grok may inspect
  broadly enough to validate downstream consumers. If correct completion needs
  another file or an unresolved dependency, it reports
  `scope_expansion_needed` with the exact files and reasons and does not claim
  completion. Codex then expands the leaf assignment or moves the remaining
  work to the canonical implementer. Tell Grok to report changed files and
  out-of-scope findings; do not ask it to stage or commit.
- Brief it per "Grok as a leaf" in `grok/model-defaults.md`; the wrapper does
  not enforce token accounting.
- Run the wrapper in a long-lived exec session. It streams raw ACP traffic to
  `/tmp/grok-acp-<task>.events.jsonl`, Grok stderr to
  `/tmp/grok-acp-<task>.stderr.log`, and the final answer to
  `/tmp/grok-acp-<task>.result.md`. Timeout or cancellation first sends
  `session/cancel`, then terminates only the process created for that task.
- One wrapper invocation is one fresh Grok session. Parallel work uses distinct
  task names and non-overlapping file allowlists. There is deliberately no
  resume, registry, background daemon, nested-agent support, or Pi fallback in
  this first lane; add one only after a real need survives local use.

## Cross-family `claude -p` dispatch

- Pass the selected Claude seat and rung as `--model <chosen>` and
  `--effort <chosen>` under canonical "Roster" and "Effort". Include those
  policy references in the brief for any child that will delegate further;
  review lenses and browser walks use the corresponding canonical seats.
- Delegated fan-out follows canonical "Subagent fan-out".

### Resume or start fresh for adversarial review

- **Resume the relevant review orchestrator** for the same review, follow-up
  fixes, or related integration when its findings and decisions still help.
  Identify the exact session; follow the process lifecycle below if it is
  still running rather than starting a replacement review.
- Give a compact delta brief: exact new base/head, changed owners and affected
  contracts, prior finding dispositions, and validation added or invalidated
  since the last pass. Link the retained review evidence instead of replaying
  raw logs. Reuse completed evidence that remains valid; review materially
  invalidated areas and their affected consumers, not the whole change again
  merely because the commit IDs changed.
- **Fresh delegates do not require a fresh orchestrator.** Use them when
  independent eyes or newly affected ownership justify another lens. Carry
  forward explicit model/delegate overrides that satisfy canonical "Roster"
  and "Harness seats"; do not preserve an invalid seat assignment from an
  earlier run. Resolve such a conflict before resuming the affected dispatch.
- **Start a fresh orchestrator** for a genuinely different objective, stale or
  misleading context, or when a concise handoff carries the relevant evidence
  more efficiently than the existing history. Include the same delta brief
  and valid review evidence so fresh eyes do not repeat completed work.
- Resumption avoids reconstructing useful context; `--resume` does not
  guarantee fewer billed tokens. Retained context, cache behavior, and repeated
  work all affect cost. Choose by relevance and the work remaining, without
  arbitrary turn, token, or elapsed-time thresholds.

### Process lifecycle (hard rule)

- Run `claude -p` in a long-lived exec session and wait for its terminal
  result. In the default text mode it normally emits the review only when the
  run completes; 20-plus minutes without stdout is not evidence of failure.
- Do not pass `--max-turns`, `--max-budget-usd`, or wrap the run in a shell
  timeout. Subscription quota accounting is not a per-dispatch spending
  boundary.
- Poll non-destructively for completion. Every ten minutes, perform a
  diagnostic checkpoint: confirm the original session/process is alive,
  record elapsed time, inspect available process-tree activity, and check for
  new stdout, stderr, or a terminal exit. For positive evidence of progress —
  text mode emits no stdout until the end — check that the run's session
  transcript (the most recently modified `*.jsonl` under
  `~/.claude/projects/`, matching the run's start time) is still growing.
  Report a concise status to the user. A quiet stdout with a growing
  transcript is a healthy run, not a wedge; a healthy checkpoint always means
  continue waiting, and there is no elapsed-time kill threshold.
- Never signal the process or launch a duplicate run because it is quiet or
  long-running. If diagnostics provide concrete evidence of a probable wedge,
  report that evidence and ask the user before terminating or retrying.
  Explicit user cancellation is the only preemptive stop. A hard CLI failure
  should exit nonzero with an error; preserve and report it.
- Independent investigation may continue while Claude runs, but do not mutate
  the artifact Claude is reviewing until its result returns.
