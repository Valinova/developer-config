# Model selection

Profiles, not rules — general criteria for what each model tends to be best
at. They fill in a default when a dispatch doesn't specify one; the user
overrides any of them where they see fit, for the unit they named, and the
next unit derives its own. Hard model-specific constraints below still apply.
Reasoning behind the rules: `rationale.md` (not loaded).

## Harness seats

The shared policy (roster, effort, reviewer selection) is canonical here; each
harness's own seat row is canonical in its card. Farm-out mechanics
(`claude -p` / `codex exec` lifecycle, Hermes paths, auth doctrine) live in
`coding-orchestration.md` and the harness projections:

- Pi seat, slugs, `Agent` dispatch, delegated `pi -p` runs: `pi/model-defaults.md`
- Codex native / `claude -p` / Grok ACP process lifecycle: `codex/model-defaults.md`
- Grok Build seat, native / wrappers / `claude -p`, Grok as a leaf: `grok/model-defaults.md`
- Hermes seat + machine-local vs owned: `hermes/model-defaults.md`

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

| Harness | Orchestrator | Implement default | Implement override (user-named only) | Reviewer transport |
|---------|--------------|-------------------|--------------------------------------|----------------------|
| **Claude Code** | Fable 5.1 (Anthropic sub) | Opus 5.5 via native `Agent` (`model: "opus"`) or `claude-exec.sh --model opus` | Astra via Codex wrappers (ChatGPT sub); Grok via `pi-exec.sh` | Codex wrappers (Astra) |
| **Codex** | GPT-6 Astra | Astra native | `claude -p --model opus`; Grok Build over ACP | `claude -p` (Opus; Fable when complex) |
| **Pi**, **Hermes**, **Grok Build** | rows live in their projection files (above); same column grammar | | | |

Reviewer need and model follow "External calls"; this table only selects
transports. Pi does not farm `claude -p`.

## Roster

Only these families are in play. Haiku is never used. Sonnet is out of the
default roster — admissible only as an explicit override for a remedial
browser walk (see "Subagent fan-out"), never chosen on an agent's own judgment.

**Claude Code:** Fable 5.1 orchestrates; Opus 5.5 executes everything else —
implement, explore/recon, retrieval, browser walks, docs fold, contained
review, mechanical tails. Fable is never an implementer by default. Astra
reviews at the key gates ("External calls").

**Codex:** Astra orchestrates and implements; Claude reviews via `claude -p` —
Opus 5.5 for contained work, Fable 5.1 with nested Opus discovery subagents
for complex or cross-cutting work.

The Opus seat applies from every harness that farms `claude -p` on the
subscription (Claude Code, Codex, Hermes, Grok Build); Pi is API-billed and
does not use it.

| Family | Default role | Override (user-named only) |
|--------|--------------|----------------------------|
| **Fable 5.1** | Claude Code orchestrator; complex reviewer of Codex-authored work | — |
| **Opus 5.5** | All Claude-side execution; contained review of Codex-authored work | Implementer from Codex |
| **Codex (GPT-6 Astra)** | Codex orchestrator and implementer; gate reviewer of Claude-authored work | Implementer from Claude Code |
| **Grok 4.6** | Pi / Hermes / Grok Build native seat | Any other seat |
| **DeepSeek V4 Flash** | — | Any seat |

Codex dispatch uses only `gpt-6-astra`; older model lines are retired from
this repo. Their availability in a harness does not authorize their use.

**Grok and DeepSeek outside their native harnesses run only when the user
names them for that dispatch** — never a default seat, a cost saving, or an
extra opinion an agent adds on its own judgment. When named, do not copy
Claude-specific prompting or effort habits onto them. Briefing Grok and
routing an implement to a Grok leaf: `grok/model-defaults.md` "Grok as a leaf".

## Effort

**Task shape picks the rung; the family's band clamps it.** On
well-specified work the top rungs make the output worse, not merely slower
(why: rationale.md#effort-ceilings).

| Family | Band | Outside the band |
|---|---|---|
| **Fable 5.1** | `medium`–`high` | `xhigh` (genuinely very complex or cross-cutting) and `low` (mechanical passes): suggested, never taken by default |
| **Astra** | `medium`–`high` | as Fable |
| **Opus 5.5** | `medium`–`high`; `medium` is the default, `high` for long multistep terminal/agentic passes or open unknowns | `low` (trivial retrieval) and `xhigh` (genuinely very complex): suggested, never taken by default; `max` never (why: rationale.md#opus-effort) |
| **Grok 4.6** | `high`–`xhigh`; `xhigh` is evidence-backed and reached for directly on complex or cross-cutting work | `medium` for explicitly trivial passes |
| **DeepSeek V4 Flash** | `high`–`xhigh`; `xhigh` for complex or cross-cutting | no useful mid-rung — trivial still runs `high` |

The brief's specificity is the signal: a known owner, a fixed allowlist, and
success criteria that fit in a sentence favor the lower rung of the band;
unknowns warrant more reasoning. A plan, arbitration, investigation, or
review is not automatically complex work.

**Fable and Astra overrides are suggested, never picked.** When a task looks
like a genuinely ideal candidate for `xhigh` — not merely substantial — the
orchestrator says so and proposes a `high` vs `xhigh` side-by-side (same
brief, two dispatches, compare the diffs and the cost); `low` is proposed the
same way. The user decides, and one favourable comparison is not standing
permission (why: rationale.md#effort-ceilings).

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
  diff review; `longrun` → plan review + final `rev` (+ the seam review).
- **Granted autonomy without a skill** ("go build it and open a PR"): judge
  it, and state what was chosen and why.

Nothing else converts "available" into "required" — not a subagent's
existence, not a repo-level `AGENTS.md` command (why:
rationale.md#pipeline-proportionality).

**Who: one rule.** Plan review and diff review are the same thing — a
cross-family review at the weight the complexity warrants (why:
rationale.md#cross-family-review).

- **Never the author's family.** Claude-authored work (Opus or Fable) goes
  to Astra at the gates. Codex-authored work goes to Opus 5.5 when contained,
  to Fable 5.1 with nested Opus discovery when complex or cross-cutting.
- **Rung per "Effort":** the upper rung of the band for complex or
  cross-cutting work (a reviewer is the check on everything below it), the
  lower rung for contained work.
- **No third family** unless the user names one.

This mapping applies to Claude Code and Codex; if its seat is unavailable
under the harness's access rules, stop and say so; the user decides the
substitute. Pi, Hermes, and Grok Build use the reviewer pairing in their
projection file. Reuse valid findings; ordinary
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
| Contained, well-specified | One cross-family pass at the implementer's rung; no lens fan-out |
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

**Announce-then-proceed preamble.** Under granted autonomy, state first
whether an external call is warranted and why; only if one is, add the
complexity read, seat, and rung per call. Name mode and stage only inside a
running delivery workflow. Then continue without waiting unless the action
itself requires permission. This is the user's refinement loop, so it runs
even when the answer is "none". Interactive directed work gets no preamble —
a call there is suggested and confirmed, never announced and taken. Silence means default; a non-default choice made silently is a
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
native seat (`pi/model-defaults.md`). The per-call economy rule in
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

Research on Claude Code uses a native Opus subagent, or
`claude -p --model opus` on Hermes/Grok Build; research on Codex uses Astra.
Pi, Grok Build, and Hermes recon seats: their projection files.

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
  and whenever the task's rung differs from the session's (for Astra, the
  Codex wrappers or `spawn_agent(reasoning_effort=…)`). Its cold-start floor
  means it never pays off for minute-scale tasks.
- The orchestrator's window size is the tiebreaker. The larger it grows, the
  more every bounded task belongs in a fresh process with the distilled brief,
  and the orchestrator keeps its window for what only it can do: review.

The orchestrator decides rung and lane per task, states them and why in the
preamble (or the report, when non-interactive), and continues.
