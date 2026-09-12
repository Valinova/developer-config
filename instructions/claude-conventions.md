# Claude Code conventions

Behavior rules that apply only to Claude Code sessions (Codex and other agents
never load this file). Reasoning behind them: `rationale.md` (not loaded).

## Artifacts — ask, don't default

- **Don't auto-generate a claude.ai artifact** (why: rationale.md#artifacts). Default to a plain answer in the terminal; one-off analyses, summaries, and explanations stay as text.
- When a visual deliverable *is* warranted (a mock, a dashboard, a diagram, a viz), ask before building: (1) do I want a rendered artifact, or just the answer? (2) where should it live — an ephemeral artifact on claude.ai, or a **file in the repo** (a real component, a checked-in mock/doc)? Repo-bound work is a Write/Edit, not an artifact. Skip the ask only when I explicitly say "make an artifact" / "render it" / "mock this up as a page," or asked to *share* a standalone visual page.

## Explanations

Explain behaviour, tradeoffs, and verification; omit prose that merely defends brevity. Explanation I asked for is given in full.

## Prompt-cache heartbeat during long waits

The session prompt cache lapses after an hour idle; a warm ping is cheaper
than a cold rebuild for any wait under about seven hours (why:
rationale.md#prompt-cache-heartbeat).

- **When:** only while the Fable orchestrator is blocked on work that may run
  longer than an hour with no other turn expected — a long Codex/pi/`claude -p`
  run, a slow migration, a live proof. Ordinary waits need nothing: the
  completion notification is itself the next request.
- **How:** `ScheduleWakeup` with `delaySeconds` of 3000 (50 min, not 59) and
  `noop: true`. The wake-up prompt does exactly one thing — check the run's
  status (`codex-status.sh <task>` or the equivalent) — and either reschedules
  the same heartbeat if still running or **stops the loop**
  (`ScheduleWakeup stop: true`) and proceeds with the post-run work.
- **Always remove it.** The heartbeat exists for one named run: stop it in the
  same turn the run closes, fails, or is abandoned, never reschedule it "in
  case." Before ending any turn with a heartbeat armed, name the run it waits
  on; if you cannot, stop the loop.
- **Never** schedule wakeups to poll work the harness already notifies on, and
  never at intervals shorter than the run's own horizon.
