# Opus 5 quirks

Canonical owner of Opus 5–specific prompting/briefing behavior. Applies to
`claude -p` dispatches and interactive Claude Code sessions. Sources:
Anthropic's "Prompting Claude Opus 5" guide + community testing, Jul 2026.

Before selecting this model or its effort, read `model-selection.md`
"Roster" and "Effort". This file owns prompting behavior, not seat selection.

## Briefs

- **Full spec up front.** Give the whole job (start state → end state) in one
  brief; don't pre-decompose into sequential steps. Opus 5 is long-horizon and
  plans better than our step lists.
- **State when the job ends.** Every brief gets a scope-end clause: what done
  means AND what not to do. Opus 5 expands scope by default.
- **No self-verification instructions.** Remove "double-check", "verify your
  work", "use a subagent to verify" — it self-verifies as it goes; these only
  add cost. Independent verification stays an orchestrator-level gate, never an
  instruction to the implementer.
- **Retrieval briefs: report all requested evidence.** Never "only report
  high-severity" / "be conservative" — Opus 5 obeys literally and
  under-reports. Judgment and severity filtering belong to the canonical
  review seat.
- **Subagents:** implementers don't spawn subagents to check their own work;
  delegation only for genuinely independent, sizeable tracks.

## Output control

- **Cap the response in the report format.** Outcome-first, few short bullets.
  (Response length ≠ deliverable length — see next.)
- **Constrain the deliverable separately.** A short reply can still ship a
  bloated artifact; give size guidance for the thing being written.
- **Narration:** one sentence before the first tool call, updates only on
  direction changes or important findings, final message leads with the outcome.

## Thinking & effort

- **Keep thinking on; control cost with effort.** Never put "don't think /
  don't reason" rules in prompts — with thinking disabled they worsen internal
  XML-tag and tool-call-as-text leakage. Choose the rung from
  `model-selection.md` "Effort"; this prompting guidance does not widen it.
