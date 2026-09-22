# Model selection

Profiles, not rules — general criteria for what each model tends to be best
at. They fill in a default when a dispatch doesn't specify one; the user
overrides any of them where they see fit, for the unit they named, and the
next unit derives its own. Hard model-specific constraints below still apply.
Reasoning behind the rules: `rationale.md` (not loaded).

## Harness seats

The roster and the shared policy (effort, reviewer selection) are canonical
here. Harness cards own only mechanics — IDs, provider routing, CLI
lifecycle, sandbox limits: `codex/`, `grok/`, `pi/`, and
`hermes/model-defaults.md`. Farm-out mechanics (`claude -p` / `codex exec`
lifecycle, Hermes paths, auth doctrine) live in `coding-orchestration.md`.

Interactive Claude Code and `claude -p` ride the Anthropic subscription.
Native Anthropic on Pi or inside Hermes bills the API (extra usage).

The same subscription-over-metered rule seals **provider routing** on the
harnesses sharing Pi's provider store (Pi, Hermes, Grok Build): a model goes
through the provider that owns it — **DeepSeek only through `deepseek`, OpenAI
models only through the `openai-codex` subscription** — unless the user
explicitly names another route for that dispatch. A `provider/id` pair naming
the model's vendor rather than an authenticated provider does not error; it
falls through to OpenRouter and bills the metered key. Pi's exact IDs and the
pre-dispatch resolution check live in `pi/model-defaults.md`.

Every session starts in one of two families, by harness:

| Side | Orchestrator | Executes | Adversarial review |
|------|--------------|----------|--------------------|
| **Claude Code** (and `claude -p` from anywhere) | Fable 5.1 — the session model is the user's `/model` pick; Opus for simpler sessions is fine | Opus 5.5 via native `Agent` (`model: "opus"`) or `claude-exec.sh --model opus` | GPT-6 Astra via the Codex wrappers |
| **Codex** | GPT-6 Astra | GPT-6 Sol (`gpt-6-sol`) native subagents at `high`; Astra when the work is long-horizon, cross-cutting, or a Sol pass failed the gate | Claude via `claude -p`: Opus 5.5 contained, Fable 5.1 + nested Opus complex |

**Pi, Hermes, Grok Build:** their default model is whatever each machine's
local config sets — out of doctrine. When they review or implement
cross-family, the same two-family rule applies (never the author's family).

**Overrides (user-named only):** cross-family implement — from Claude Code
→ Sol (Codex wrappers, `--model gpt-6-sol`), from Codex → Opus
(`claude -p --model opus`); anywhere, Grok 4.7, DeepSeek, open-source models,
and GPT-6 Luna, at `high` unless the user says otherwise.

## Roster

Only the families above are in play. Haiku is never used. Sonnet is out of the
default roster — admissible only as an explicit override for a remedial
browser walk (see "Subagent fan-out"), never chosen on an agent's own judgment.

On the Claude side Opus 5.5 executes everything the orchestrator does not —
implement, explore/recon, retrieval, browser walks, docs fold, contained
review, mechanical tails. Fable is never an implementer by default.

Codex dispatch uses `gpt-6-astra` and `gpt-6-sol`; `gpt-6-luna` only as a
user-named override. Older model lines are retired from this repo; their
availability in a harness does not authorize their use.

**Overrides run only when the user names them for that dispatch** — never a
default seat, a cost saving, or an extra opinion an agent adds on its own
judgment. When named, do not copy Claude-specific prompting habits onto them.
Briefing Grok and routing an implement to a Grok leaf:
`grok/model-defaults.md` "Grok as a leaf".

## Effort

`medium` or `high` for everything; `xhigh` only suggested (a Fable or Astra
stretch); never `max`. Step up one rung only for long multistep
terminal/agent work or a brief with open unknowns. On the Codex side, when Sol
at `high` isn't enough, switch to Astra rather than raising Sol's rung.

| Family | Default | Step up |
|---|---|---|
| Opus 5.5 | `medium` | `high` |
| GPT-6 Sol | `high` | → Astra |
| GPT-6 Astra | `high` | `xhigh` (suggest only) |
| Fable 5.1 | `medium` | `high` |

(why: rationale.md#effort)

**`max` and `ultra` are never an agent's choice.** `ultra` (Astra's
delegate-for-you rung) is out entirely — delegation is the orchestrator's job,
not something a leaf improvises. The wrappers pass `--effort` through
verbatim, so both are closed by doctrine, not by tooling.

**The interactive session effort is not doctrine.** The
`always/settings.json` `effortLevel` and a session's running rung are
transient TUI state: never read them as the baseline, reconcile them to this
table, or flag the drift (why: rationale.md#session-effort).

**The lane follows the effort**: a task whose rung differs from the session's
needs a lane that takes effort as a flag — "Fresh window or inherited context"
below.

## External calls

An external call dispatches another model for independent judgment — a plan
or diff review, `rev`, an escalation, any cross-family opinion. Local checks,
tests, and the pre-commit gate are not external calls and always run.

- **Interactive / iterative work with the user:** no external call unless the
  user asks. Suggest one when the risk warrants it; the user's yes is the go.
- **A workflow skill carries its own gates, and invoking it is the
  approval:** `agentplan` → plan/scope review; `execute-plan` → only the seam
  review, when a later phase tears out what an earlier one built; `rev` → the
  diff review; `longrun` → plan review + final `rev` (+ the seam review);
  `full-docs` → its adversarial validation of the documentation diff.
- **Granted autonomy without a skill** ("go build it and open a PR"): judge
  it, and state what was chosen and why.

Nothing else converts "available" into "required" — not a subagent's
existence, not a repo-level `AGENTS.md` command (why:
rationale.md#pipeline-proportionality).

**Who: one rule.** Plan review and diff review are the same thing — a
cross-family review at the weight the complexity warrants (why:
rationale.md#cross-family-review).

- **Never the author's family.** Codex-authored work goes to Claude — Opus
  5.5 when contained, Fable 5.1 with nested Opus discovery when complex or
  cross-cutting. Claude-authored work (Opus or Fable) goes to Astra. After an
  implementer override, the reviewer follows the actual author's family.
- **Rung per "Effort":** the family default for contained work, its step-up
  for complex or cross-cutting work (a reviewer is the check on everything
  below it). Astra reviews at `high`; `xhigh` only when the user approves the
  suggested stretch.
- **No third family** unless the user names one.

Pi, Hermes, and Grok Build follow the same two-family rule. If the seat is
unavailable under the harness's access rules, stop and say so; the user
decides the substitute. Reuse valid findings; ordinary
fixes get regression checks, not another pass. The final report states what
each pass changed; a pass that changed nothing is reported as such, never
hidden — that is the signal to lower the default next time.

**Known family tendencies — a lens, not a rule.** The principles decide what
good looks like; this only says where each heavyweight tends to miss them.
Opus 5.5 under-proves: it asserts unverified inferences as fact, calls a
partial check a full read, and checks a plan against requirements it wrote
itself (Opus 5.5 System Card p.36). Astra proves well — cross-file breaks,
false assumptions, the missing test — but over-builds: extra files, types,
tests, and research the brief did not ask for. So, as author, compensate for
your own tendency and say so in the summary (Opus: which claims it verified
and which it inferred; Astra: what it added beyond the brief and why each
item stays). As reviewer, lead with the author's tendency: reviewing Opus,
hunt what is missing; reviewing Astra, hunt what to delete.
Read the whole diff either way; this is where to look first, not a checklist.

## Delivery pipeline modes

These modes describe an invoked delivery workflow, not every task.
`agentplan`, `execute-plan`, `rev`, `docs`, `babysit`, and `longrun` compose
these stages; which gates each carries, and who reviews at what weight, is
"External calls":

```
Full       agentplan(scope + phases) → execute-plan → rev → docs → PR → babysit
Discover   agentplan(scope only) → probe → agentplan(phases) → execute-plan → rev → docs → PR → babysit
Iterative  scope note → implement with the user → rev → docs → PR → babysit
```

- **Gates:** the plan gate before code lands is a full adversarial plan review
  in Full and a scope-only review in Discover and Iterative; the rev gate's
  depth scales (below).
- **One seam review before a tear-out.** When a plan's later phases delete
  or re-key what its earlier phases built, run one cross-family review of
  the built seam at that boundary, before the tear-out phase, and scope the
  final rev to what that review did not see. A seam defect found under
  deleted code costs a second pass over the tear-out's fixtures; found at
  the boundary it costs one fix pass rev would have demanded anyway. This is
  the only interim adversarial run; phases never each get one.
- **Discover** is chosen when the plan would have to guess at facts only a
  probe can settle (database shape, a spike, a failing test).
- **Iterative** is chosen when the work's shape is not known up front and the
  user is steering live; there is no phased plan artifact.
- The orchestrator picks the mode and states it in the preamble. Default is
  Full.

**Review depth scales with the change.** The pipeline is for non-trivial work
(whether a review runs at all is "External calls"); within it, the rev gate is
always present but its depth follows the change, never the fact that a
workflow was invoked (why: rationale.md#pipeline-proportionality):

| Change | Rev depth |
|---|---|
| Complex or cross-cutting | Full rev: code-simplifier, judgment lenses where they earn fan-out, other-family validation per "External calls" |
| Contained, well-specified | One cross-family pass at the reviewer family's default rung ("Effort"); no lens fan-out |
| Mini PR, or a fix-verify iteration loop | A light cross-family validation of the fix and its test; no simplifier or lenses |

Classify by risk and affected contracts, not size: a change that fits the
complex row wins regardless of diff size. The light row covers a bounded
delta against an already-reviewed baseline; it never replaces the branch's
outstanding full review. The orchestrator selects the lightest matching row
and announces it — the full row is the fallback when unsure, not a ritual.
The chosen depth and scope travel in the reviewer's brief.

**PR status at delivery.** A completed `longrun` opens a ready-for-review
(non-draft) PR so CI and automated reviewers can run. Draft is reserved for
an explicit user request or an unresolved critical blocker that makes ready
status inaccurate; name the exception in the final report. A blocker is not
completed delivery.

**Announce-then-proceed preamble.** Under granted autonomy without an
invoked skill, state first whether an external call is warranted and why;
only if one is, add the complexity read, seat, and rung per call. For an
invoked workflow, announce its gates and each reviewer's seat and rung. Name
mode and stage only inside a running delivery workflow. Then continue without
waiting unless the action itself requires permission. This is the user's
refinement loop, so it runs even when the answer is "none". Interactive work
without an invoked workflow gets no preamble — a call there is suggested and
confirmed, never announced and taken. Silence means default; a non-default choice made silently is a
defect, not discretion. In non-interactive runs, the same block goes at the
top of the final report.

CodeRabbit is not a local step; its PR-side review is consumed by `babysit`,
which settles it together with CI, at most one push per round, with a
two-round cost circuit breaker. The cap never implies merge-ready: apply
babysit's final verification and report incomplete delivery when its ship
gate is unmet (why: rationale.md#coderabbit).

## Subagent fan-out

When independent review is warranted, start with one reviewer. Add lenses
only for separable questions. A broad repo alone does not justify fan-out.
An Opus contained reviewer or a Fable complex reviewer may nest Opus discovery
subagents unless the brief forbids it; the reviewer keeps the judgment.
Discovery subagents are not extra review lenses.

Outside those gates, spawn only the number of subagents the situation actually
needs — never a fleet for its own sake. Soft ceiling: **eight at a time**;
beyond eight requires genuine value and a user check-in first.

Browser-driving subagents (Playwright walks, UI verification, screenshot
loops) are mechanical work: in subscription Claude lanes they take the
**Opus 5.5** seat (why: rationale.md#opus-browser-walks); Sonnet is admissible
there for a purely remedial walk, only as an explicit override. Pi uses its
local default. The per-call economy rule in
`principles.md` §9 still governs.

## Orchestrator context discipline

On Claude Code, everything in the orchestrator's window is re-sent every turn
and degrades its reasoning as it grows (see "Fresh window or inherited
context" below). The Claude Code orchestrator's own tool calls are limited to:
writing briefs,
dispatching, reading verdicts and post-run summaries, reading the diff it is
about to commit, small decision-critical artifacts, authorized local
verification (including the full pre-commit gate), and git. Everything else
is farmed out to Opus per "Roster"; when to delegate at all is
`dispatch-bootstrap.md`.

Research on Claude Code uses a native Opus subagent; research on Codex uses
a native Sol subagent. Pi, Grok Build, and Hermes use their local default.

### Leaf fan-out: a judgment core and a mechanical tail

An implement pass usually has one judgment core (the seam, the contract, the
admission rule) and a long mechanical tail (re-keying many callers, writing
table-driven test rows, mirroring a change across sibling files). The default
brief for such a pass lets the Opus implementer farm the tail to nested Opus
subagents with fixed allowlists, and carries the `dispatch-bootstrap.md` read
rule so the leaf takes seats and rungs from doctrine. A brief that forbids
nested delegation says so explicitly. The orchestrator still owns git and the
combined-diff provenance check.

### Fresh window or inherited context: decide by the input, not the cache

Only context degradation drives this decision, never cache cost
(why: rationale.md#context-degradation).

- A **native Claude subagent** inherits the session window and rung, with no
  effort override. It is right when the session context *is* the input: a
  review lens over what was just discussed, a retrieval pass the orchestrator
  will read.
- A **`claude -p` process** (`claude-exec.sh`) starts from zero plus the brief
  and takes `--effort` as a flag. It is right when a brief *can* be the input
  — any bounded, well-specified pass, concentrated implementation above all —
  and whenever the task's rung differs from the session's (for the Codex family, the
  Codex wrappers or `spawn_agent(reasoning_effort=…)`). Its cold-start floor
  means it never pays off for minute-scale tasks.
- The orchestrator's window size is the tiebreaker. The larger it grows, the
  more every bounded task belongs in a fresh process with the distilled brief,
  and the orchestrator keeps its window for what only it can do: review.

The orchestrator decides rung and lane per task, states them and why in the
preamble (or the report, when non-interactive), and continues.
