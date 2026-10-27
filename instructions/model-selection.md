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

Every session starts in one of two families, by harness. Inside a range, the
task's complexity picks the rung; complex work takes the higher side.

| | Claude Code (and `claude -p` from anywhere) | Codex |
|---|---|---|
| Orchestrate | Opus 5.5 or Fable 5.1, the user's `/model` pick | GPT-6 Astra |
| Mechanical (retrieval, recon, a tail with an exact spec) | Sonnet 5.5 @ `medium`–`high` | GPT-6.1 Sol @ `medium`–`high` |
| Work (implement, research, docs fold, judged exploration) | Opus 5.5, fresh native `Agent` @ `medium`–`high` | Sol @ `high`–`xhigh`; Astra @ `medium`–`high` when long-horizon, cross-cutting, or a Sol pass failed the gate |
| Browser walk (why: rationale.md#opus-browser-walks) | Opus 5.5 (Sonnet for a purely scripted walk) @ `medium` | — |
| Review, contained | Sol @ `high`–`xhigh`, Codex wrappers | Opus 5.5 @ `high`, `claude -p` |
| Review, complex or cross-cutting | Astra @ `high`–`xhigh` | Fable 5.1 @ `high` with nested Opus discovery |

- **Never the author's family.** The review row follows who wrote the work,
  after an implementer override the actual author. No third family unless
  the user names one.
- **Unavailable seat:** if the seat is unavailable under the harness's access
  rules, stop and say so; the user decides the substitute.
- **Ceilings:** `high` for Claude models, `xhigh` for Codex models; never
  `max` or `ultra` (Astra's delegate-for-you rung: delegation is the
  orchestrator's job). The wrappers pass `--effort` through verbatim, so
  doctrine closes them, not tooling.
- **Pass the rung on every fresh dispatch.** Every lane takes it as a parameter
  (`Agent` `effort`, the wrappers' `--effort`); this table is the explicit
  instruction the `Agent` tool's `effort` parameter requires. The session's
  own effort and `always/settings.json` `effortLevel` are transient TUI state,
  never the baseline (why: rationale.md#session-effort).
- **Pi** dispatches default to DeepSeek Flash @ `high`; **Hermes** runs its
  machine's local default. Both follow the cross-family rule.
- **Any other model runs only when the user names it or gives guidance for
  it**, never as a default seat, a cost saving, or an extra opinion.

(why: rationale.md#effort)

## Announce-then-proceed preamble

Under granted autonomy without an invoked skill, state first whether an
external call is warranted and why; only if one is, add the complexity read,
seat, and rung per call. For an invoked workflow, announce its gates and each
reviewer's seat and rung. Name mode (`workflows/longrun.md` "Delivery pipeline
modes") and stage only inside a running delivery workflow. Then continue
without waiting unless the action itself requires permission. This is the
user's refinement loop, so it runs even when the answer is "none".
Interactive work without an invoked workflow gets no preamble. Silence means
default; a non-default choice made silently is a defect, not discretion. In
non-interactive runs, the same block goes at the top of the final report.

## Family tendencies — a lens, not a checklist

Opus 5.5 under-proves: asserts inferences as fact, calls a partial check a full
read, checks a plan against its own requirements (System Card p.36). Astra
over-builds: files, types, tests, research the brief did not ask for. Sol 6.1
reshapes what it was told to keep: trims rationale, renames names and test
titles, adds unasked assertions. As author, say in the summary how you
compensated (Opus: claims verified vs inferred; Astra, Sol: what went beyond
the brief and why). As reviewer, lead with the author's tendency (Opus: what is
missing; Astra: what to delete; Sol: prose, names, tests against the brief),
then read the whole diff.

## Subagent fan-out

When independent review is warranted, start with one reviewer; add lenses
only for separable questions. A broad repo alone does not justify fan-out. An
Opus contained or Fable complex reviewer may nest Opus discovery subagents
unless the brief forbids it; the reviewer keeps the judgment, and discovery
subagents are not extra lenses. Otherwise spawn only the subagents the
situation needs, never a fleet. Soft ceiling: **eight at a time**; beyond
eight requires genuine value and a user check-in first.

## Fresh window or inherited context

Only context degradation drives this decision, never cache cost
(why: rationale.md#context-degradation). From Claude Code the same-family lane
is the native `Agent` (why: rationale.md#native-agent-lane). The orchestrator
decides lane and rung per task and states them and why in the preamble (or the
report, when non-interactive).

- **Fork** (`subagent_type: "fork"`) inherits the session window and rung:
  right when the session context *is* the input (a review lens over what was
  just discussed, a retrieval pass the orchestrator will read).
- **Fresh `Agent`** starts from zero plus the brief and takes `model` and
  `effort`: the default for any bounded pass, implementation above all.
- **`claude-exec.sh`**: callers outside Claude Code, and from Claude Code only
  a run that must outlive the session; its cold start never pays off for
  minute-scale tasks. Codex family: the wrappers or `spawn_agent(reasoning_effort=…)`.
- **Tiebreaker:** the larger the orchestrator's window, the more every bounded
  task belongs in a fresh agent; it keeps its window for review.
