# Codex dispatch defaults

Before dispatch, read
`~/Development/developer-config/instructions/dispatch-bootstrap.md` "External
calls" and
`~/Development/developer-config/instructions/model-selection.md`, especially
"Announce-then-proceed preamble",
"Harness seats" and "Subagent fan-out". Those sections
own shared policy; this card is not a substitute for them.
The `claude -p` process lifecycle is Codex-specific and is owned here. Grok
is dormant; `grok/` holds its config. An explicit user or per-dispatch model/reasoning choice always
wins among valid combinations under that policy.

## Native subagents

- **`spawn_agent` takes `model` and `reasoning_effort` per spawn.** Choose
  both from the canonical policy and use the live tool schema. Full-history
  forks (`fork_turns="all"`, including the default) inherit the parent's model
  and effort and reject overrides. For a different model or rung, pass an
  explicit override with `fork_turns="none"` and a brief, or a supported
  partial-history fork. Machine defaults in `~/.codex/config.toml` are setup
  mechanics; see SETUP.md.
- When a workflow calls for a cross-family Claude pass, use `claude -p` —
  never substitute another Codex subagent.

## Cross-family `claude -p` dispatch

- Pass the selected Claude seat and rung as `--model <chosen>` and
  `--effort <chosen>` under canonical "Harness seats". Include those
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
  forward explicit model/delegate overrides that satisfy canonical
  "Harness seats"; do not preserve an invalid seat assignment from an
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
