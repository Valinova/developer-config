# Model selection

Profiles, not rules — general criteria for what each model tends to be best
at. They fill in a default when a dispatch doesn't specify one; the user
overrides any of them where they see fit, for the unit they named, and the
next unit derives its own. Hard model-specific constraints below still apply.
Reasoning behind the rules: `rationale.md` (not loaded). Claude Code reads
this file on dispatch, not every turn — `dispatch-bootstrap.md` owns the read
rule for Claude Code and Grok Build alike.

**Harness seats**: the shared policy (roster, effort, reviewer selection) is
canonical here; each harness's own seat row is canonical in its card below. Farm-out mechanics (`claude -p` / `codex exec` lifecycle, Hermes paths,
auth doctrine) live in `coding-orchestration.md` and the harness projections:

- Pi seat, slugs, `Agent` dispatch, delegated `pi -p` runs: `pi/model-defaults.md`
- Codex native / `claude -p` / Grok ACP process lifecycle: `codex/model-defaults.md`
- Grok Build seat, native / wrappers / `claude -p`, Grok as a leaf: `grok/model-defaults.md`
- Hermes seat + machine-local vs owned: `hermes/model-defaults.md`

## Harness seats

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

| Harness | Orchestrator | Implement default | Implement override | Reviewer transport |
|---------|--------------|-------------------|--------------------|----------------------|
| **Claude Code** | Fable 5.1 (Anthropic sub) | Codex Astra via wrappers (ChatGPT sub) | Opus via `claude-exec.sh --model opus` or native `Agent` (default); Fable via `claude-exec.sh --effort` only when complex (Roster); Grok via `pi-exec.sh` | Grok via `pi-exec.sh`; native Claude; Codex wrappers |
| **Codex** | GPT-6 Astra | Astra native | `claude -p --model opus` (default) or `--model fable --effort <chosen>` when complex (Roster); Grok Build over ACP | Grok Build over ACP; `claude -p`; native Astra |
| **Pi**, **Hermes**, **Grok Build** | rows live in their projection files (above); same column grammar | | | |

Reviewer need and model follow "External calls"; this table only selects
transports. Pi does not farm `claude -p`.

## Roster

Only these families are in play. Haiku is never used. Sonnet is out of the
default roster — admissible only as an explicit override for a remedial
browser walk (see "Subagent fan-out"), never chosen on an agent's own judgment.

**Claude seats:** prefer Fable for genuinely complex work, Opus for
mechanical and default work. Never spawn Fable for something that isn't
difficult; when unsure, take Opus (why: rationale.md#fable-bar).

| Seat | Dispatch |
|---|---|
| Opus 5 | native `Agent` with `model: "opus"`, or `claude -p --model opus` / `claude-exec.sh --model opus` |
| Fable 5.1 | native `Agent`, or `claude-exec.sh --effort` for a chosen rung |

**Operational risk never raises the seat.** A deletion, a migration, or a
production-adjacent module is not Fable work because it is dangerous; risk
raises *verification* (a clone rehearsal, a courier read-back, a census before
the run), never the seat. Seat follows brief specificity alone, and a phase
whose unknowns the plan's probes already closed is mechanical by definition.

Seat and rung are one decision with two outputs (see "Effort"): a mechanical
Opus pass takes the corresponding rung. The seat applies from every harness
that farms `claude -p` on the subscription (Claude Code, Codex, Hermes, Grok
Build); Pi is API-billed and does not use it.

| Family | Default role | Also fine when chosen |
|--------|--------------|------------------------|
| **Fable 5.1** | Complex work (see "Claude seats") | — |
| **Opus 5** | Mechanical and default subagent work, including contained review | — |
| **Codex (GPT-6 Astra)** | Implement; deep investigate | Explore / plan when you want depth or another family |
| **Grok 4.6** | Lighter adversarial review; Pi unspecified `Agent`; Hermes orch; Grok Build native | Explore / plan / implement elsewhere when chosen; strong on UI-ish |
| **DeepSeek V4 Flash** | — (opt-in peer, same shelf as Grok) | Explore / plan / implement — third-family opinions |

Codex dispatch uses only `gpt-6-astra`; older model lines are retired from
this repo. Their availability in a harness does not authorize their use.

**Unspecified dispatch** follows the harness table, not a global Fable default.
DeepSeek Flash is opt-in. Treat Grok and DeepSeek as experimental peers while
we build evidence; do not copy Claude-specific prompting or effort habits
onto them.
Briefing Grok and routing an implement to a Grok leaf: `grok/model-defaults.md`
"Grok as a leaf".

**Harness note — DeepSeek:** In Pi (and any comparative implementer lane),
Flash is an opt-in peer across explore/plan/implement. Hermes `delegate_task`
may still use DeepSeek for trivial retrieval/summaries only (a Hermes contract
in `coding-orchestration.md`, not a denial of the peer role elsewhere).

## Lane defaults

The harness table decides who actually sits in a lane.

| Lane | Default | Opt-in / override |
|------|---------|-------------------|
| **Explore / plan / UI-ish** | Native seat of the harness (Claude Code → the Claude seat per "Roster": Opus 5 unless complex; Pi / Hermes / Grok Build → Grok) | Other in-roster families when chosen; Hermes/Codex/Grok Build may `claude -p` |
| **Implement** | Codex | Grok or DeepSeek Flash when chosen |
| **Review** | Per "External calls" | Honor harness access restrictions |

## Effort

**Task shape picks the rung; the family's band clamps it.** On
well-specified work the top rungs make the output worse, not merely slower
(why: rationale.md#effort-ceilings).

| Family | Band | Outside the band |
|---|---|---|
| **Fable 5.1** | `medium`–`high` | `xhigh` (genuinely very complex or cross-cutting) and `low` (mechanical passes): suggested, never taken by default |
| **Astra** | `medium`–`high` | as Fable |
| **Opus 5** | `medium`–`high` | — |
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
verbatim, so both are closed by doctrine, not by tooling. Opus 5 dispatches
additionally follow `opus5-quirks.md`.

**The interactive session effort is not doctrine.** The value in
`always/settings.json` (`modelSettings.*.effortLevel`) and whatever a session
happens to be running at are transient TUI state — never read them as the
intended baseline, never reconcile them to this table, never flag the drift
(why: rationale.md#session-effort). The rules here govern dispatches where
effort is a flag.

**The lane follows the effort.** Native Claude `Agent` subagents inherit the
session's rung with no override, so whenever a task's rung differs from the
session's, use a dispatch that takes effort as a flag — `claude-exec.sh
--effort` for Fable, the Codex wrappers or `spawn_agent(reasoning_effort=…)`
for Astra — even when the model is the same. When the session context itself
is the input (a review lens over what was just discussed, recon the
orchestrator will read), the native subagent at the inherited rung is right.
The orchestrator decides rung, lane, and Claude seat (Fable or Opus, per the
Roster) per task, states them and why in the preamble (or the report, when
non-interactive), and continues.

## External calls

An external call dispatches another model for independent judgment — a plan
or diff review, `rev`, an escalation, any cross-family opinion. **Who is in
the loop decides whether one happens** (the interactive / granted-autonomy
split of `principles.md` §4, not the name of a skill). Local checks, tests,
and the pre-commit gate are not external calls and always run.

- **Interactive, directed work:** never dispatch one unprompted. Suggest one
  if you think it is needed and wait for confirmation; the user asking is
  itself the confirmation. A critical issue you cannot resolve is a question
  for the user, not a reason to spend a model on it.
- **Granted autonomy** (a running plan, a delivery workflow, any "go build it
  and open a PR"): judge it yourself and state what you are doing and why, so
  the default can be refined over time. Scoping stages state "no call, still
  scoping" — that is the rule working, not an exception to it.

Nothing converts "available" into "required": not a subagent's existence,
not a repo-level `AGENTS.md` command. A downstream repo command supplies
scope, never the whether, and neither a workflow name nor a fresh session
resets a scope carried in the brief. `rev` is itself the call: invoking it
(directly, or through `longrun`) is the whether, and this section decides only
who and at what weight (why: rationale.md#pipeline-proportionality).

**Who: one rule.** Plan review and diff review are the same thing — a
cross-family review at the weight the complexity warrants (why:
rationale.md#cross-family-review).

- **Cross-family is the constraint:** never the author's own family.
- **Two families by default:** the other family's heavyweight reviews —
  Claude-authored work goes to Astra; Codex-authored, to Fable — with Opus
  discovery subagents as useful. Complexity picks the rung per "Effort": the
  upper rung of the band for complex or cross-cutting work (a reviewer is
  the check on everything below it), the lower rung for contained work.
- **Cheap alternatives, not a third default:** on less complex work Grok
  (its own subscription) or Opus (the cheaper Claude pool; reviewing
  Codex-authored work keeps it cross-family) may take the adversarial review
  or an implement pass to save cost. Take the saving when it is real; never
  add a family for its own sake.

If that seat is unavailable under the harness's access rules, take an
eligible seat of another family and say why. Reuse valid findings; ordinary
fixes get regression checks, not another pass. The final report states what
each pass changed; a pass that changed nothing is reported as such, never
hidden — that is the signal to lower the default next time.

**Known family tendencies — a lens, not a rule.** The principles decide what
good looks like; this only says where each heavyweight tends to miss them.
Fable holds intent, shape, and scope well but under-proves: it can look
finished while missing callers, invariants, error paths, and the test that
would fail. Astra proves well — cross-file breaks, false assumptions, the
missing test — but over-builds: extra files, types, tests, and research the
brief did not ask for. So, as author, compensate for your own family's
tendency and say so in the summary (Fable: the callers and tests it covered;
Astra: what it added beyond the brief and why each item stays). As reviewer
(including Grok on a cheap pass), lead with the author's tendency:
reviewing Fable, hunt what is missing; reviewing Astra, hunt what to delete.
Read the whole diff either way; this is where to look first, not a checklist.

## Delivery pipeline modes

These modes describe an invoked delivery workflow, not every task.
`agentplan`, `execute-plan`, `rev`, `docs`, `babysit`, and `longrun` compose
these stages. `rev` is the cross-family review; the caller decides whether it
runs (`longrun` always; otherwise only when the user invokes it) and "External
calls" decides who and at what weight:

```
Full       agentplan(scope + phases) → execute-plan → rev → docs → PR → babysit
Discover   agentplan(scope only) → probe → agentplan(phases) → execute-plan → rev → docs → PR → babysit
Iterative  scope note → implement with the user → rev → docs → PR → babysit
```

- **Two cross-family gates always:** one on scope/plan before code lands, one
  on code at rev. The first gate scales from a full adversarial plan review
  (Full) to a scope-only review (Discover, Iterative). Rev is never skipped;
  its depth scales (below).
- **One seam review before a tear-out.** When a plan's later phases delete
  or re-key what its earlier phases built, run one cross-family review of
  the built seam at that boundary, before the tear-out phase, and scope the
  final rev to what that review did not see. A seam defect found under
  deleted code costs a second pass over the tear-out's fixtures; found at
  the boundary it costs one fix pass rev would have demanded anyway. This is
  the only interim adversarial run; phases never each get one.
- **Discover** is chosen when the plan would have to guess at facts only a
  probe can settle (database shape, a spike, a failing test). agentplan runs
  contextualization + the cross-family scope review, writes the scope section
  of the plan file with the open questions and what must be probed to close
  them, and stops before phases. After iteration, invoking agentplan again
  resumes at phases via the existing resume contract.
- **Iterative** is for work whose shape is not known up front and the user is
  steering live: no phased plan artifact; a short scope note still goes
  through the other family ("does this direction make sense, what does it
  break") before code lands.
- The orchestrator picks the mode and states it in the preamble. Default is
  Full.

**Review depth scales with the change.** The pipeline is for non-trivial work
(`dispatch-bootstrap.md` owns what skips it); within it, the rev gate is
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
only for separable questions; Fable uses Opus for discovery and noncritical
work, retaining critical judgment itself. A broad repo alone does not
justify fan-out.

Outside those gates, spawn only the number of subagents the situation actually
needs — never a fleet for its own sake. Soft ceiling: **eight at a time**;
beyond eight requires genuine value and a user check-in first.

Browser-driving subagents (Playwright walks, UI verification, screenshot
loops) are mechanical work: in subscription Claude lanes they take the
**Opus 5** seat (why: rationale.md#opus-browser-walks); Sonnet is admissible
there for a purely remedial walk, only as an explicit override. Pi uses its
native seat (`pi/model-defaults.md`). The per-call economy rule in
`principles.md` §9 still governs.

## Orchestrator context discipline

Everything in the orchestrator's window is re-sent every turn and degrades
its reasoning as it grows (see "Fresh window or inherited context" below).
The orchestrator's own tool calls are limited to: writing briefs,
dispatching, reading verdicts and post-run summaries, reading the diff it is
about to commit, small decision-critical artifacts, authorized local
verification (including the full pre-commit gate), and git. Everything else
is farmed out under "Roster" so discovery does not require Fable.

The hard triggers — when to delegate at all, and the extract → delegate /
judge → read heuristic — are always-loaded in `dispatch-bootstrap.md`, their
one owner; they are not restated here.

Bulk fact-gathering never enters the orchestrator raw:

- Research on Claude Code uses a native Claude subagent, or `claude -p` on
  Hermes/Codex/Grok Build, on the Claude seat chosen by task shape under
  "Roster" (Opus discovery; Fable critical judgment).
  It returns a distilled brief (≤ ~3K tokens) with file:line pointers.
  Pi, Grok Build, and Hermes recon seats: their projection files.
- Orchestrator reads directly only: verdicts of delegated work, diffs it is
  about to commit, small decision-critical artifacts.

### Leaf fan-out: a judgment core and a mechanical tail

An implement pass usually has one judgment core (the seam, the contract, the
admission rule) and a long mechanical tail (re-keying many callers, writing
table-driven test rows, mirroring a change across sibling files). The default
brief for such a pass lets the Fable implementer farm the tail to nested Opus
subagents with fixed allowlists, and carries the `dispatch-bootstrap.md` read
rule so the leaf takes seats and rungs from doctrine. A brief that forbids
nested delegation says so explicitly. The orchestrator still owns git and the
combined-diff provenance check.

### Fresh window or inherited context: decide by the input, not the cache

Only context degradation drives this decision, never cache cost
(why: rationale.md#context-degradation).

- A **native Claude subagent** inherits the session window and is right when
  the session context *is* the input: a review lens over what was just
  discussed, a retrieval pass the orchestrator will read.
- A **`claude -p` process** (`claude-exec.sh`) starts from zero plus the brief
  and is right when a brief *can* be the input: any bounded, well-specified
  pass, concentrated implementation above all. Its cold-start floor means it
  never pays off for minute-scale tasks.
- The orchestrator's window size is the tiebreaker. The larger it grows, the
  more every bounded task belongs in a fresh process with the distilled brief,
  and the orchestrator keeps its window for what only it can do: review.
