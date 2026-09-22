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
- **How:** `ScheduleWakeup`, `delaySeconds: 3000`, `noop: true`. Each wake
  checks the run's status (`codex-status.sh <task>` or equivalent) and either
  reschedules or stops the loop (`stop: true`) and proceeds.
- **Always remove it.** One heartbeat per named run; stop it the turn the run
  closes, fails, or is abandoned. If you cannot name the run it waits on, stop
  it. Never poll work the harness already notifies on.
