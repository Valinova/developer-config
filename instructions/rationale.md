# Rationale and incident archive

Not loaded into any session. Each entry is the story behind a rule that lives
in the instruction file named by its section heading; the rule points here as
`(why: rationale.md#<heading>)`. Headings are stable anchors — rename one only
together with its pointers. Entries hold stories, dates, and
measurements; a one-clause reason that clarifies scope or failure mode stays
inline with the rule. Never move the rule itself, or an action trigger, here.

## principles.md

### simplicity

A hardcoded value masks errors and drifts silently. Left unchecked, generated
code drifts toward over-engineering, which is why the "keep it simple" rules
apply while writing rather than in a later cleanup. Splitting one hard
function into pass-through wrappers lowers the line count and the lint score
while making the code worse. A senior engineer's "overcomplicated" is the
smell test because it is the review that actually happens.

### parallel-worktree-wip

The user often works in parallel in the same worktree. An agent judged
uncommitted changes that did not trace to its task as agent overreach and
reverted them; they were the user's intentional in-progress work. Hence: never
revert, restore, stash, or delete unexplained worktree changes without
asking, and snapshot provenance before dispatching anything that can touch
the tree.

### agent-proposals

Agents should keep suggesting fixes as they work, but a bare unstaged edit is
the wrong channel: the snapshot rule above reads unlabeled dirt as the user's, so
mixing proposals into the tree destroys both his and the next agent's ability
to tell them apart. Proposals go in a labeled slot — `OUT_OF_SCOPE_FINDINGS`,
or a patch file named there — and land only when the user applies them. The
blast-radius trigger keeps the loop useful; without it the slot fills with
idle-pass noise nobody reads.

### pre-commit-gate

Proven 2026-07-17: the quick lint loop passed and CI failed. Quick linters
skip the custom/architecture rules — exactly the load-bearing ones — so a
quick pass says nothing about the full gate.

Two 2026-09-06 failures added "in your own shell, reading the exit code": a
phase was committed on a leaf's *report* that the gate was green while the
branch tip failed an architecture check the leaf had never run, and a
backgrounded `pnpm gate | tail` reported the pipeline's last stage, not the
gate's, pushing a red commit. A gate result is an exit code the invoker read,
not a claim.

### test-shapes

A 2026-08-20 whole-suite audit (1,189 files) found ~15% of files violating one
of the six refused test shapes. Each shape is therefore a named finding class
with real instances, not theory. What each shape costs: a test that must
change whenever the implementation changes passes forever and catches
nothing; a mirrored literal makes the test a second owner of a production
fact and forces a test edit per production edit; a hand-rolled shim or
in-test reimplementation of a production rule passes while production drifts;
self-referential assertions let consistent-but-wrong pass; near-identical
`it()`s inflate count and wall-clock without signal; source-text assertions
pass broken code and break on reformat. A test that would never catch a
regression is just more code to maintain.

### fail-loud

An obvious failure surfaced at dev time is cheaper than a silent wrong answer
observed in production days later.

### idle-pass

Doing work "just to do stuff" burns tokens and review attention. Idle-pass
output is worse than no output.

### browser-cost

The cost of a browser session is not the tool schemas (they load on demand);
it is per call — every snapshot, screenshot, or network dump is thousands of
tokens.

### entropy

Entropy is the accumulation of small "fine for now" compromises. Every change
either fights it or feeds it. Two patterns for one job is how rot starts. A
named compromise is manageable debt; a silent one is entropy.

### ui-drift

LLM-generated UI drifts toward putting everything on screen; that is a
defect, not thoroughness. Prose doctrine alone does not survive generated UI,
which is why a repeatedly violated UI rule graduates into a mechanical check
(§11). `<details>` is not where unjustifiable content hides. A raw UUID means
nothing to a user. A second route or `-v2` component rendering the same data
is a fork that rots both halves.

## git-operations.md

### branch-switches

The user works across branches and worktrees in parallel. An agent switched
branch without asking and changed the directory under the user's feet mid-work.
Hence: ask first, every time, for any branch or worktree the agent chose.

### worktree-identity

Worktrees share the main repo's `.git/config`. An agent ran
`git config user.*` inside a throwaway worktree and silently clobbered the
real identity for every checkout of that repo. Hence per-invocation `-c`
scoping only, and a `git config user.email` check after removing a scratch
worktree.

### remote-ops

Remotes may be authenticated, so a remote write will actually go through;
there is no sandbox catching a wrong push.

### rebase-over-merge

We are a small team with minimal conflicts, so rebasing carries little
resolution cost and keeps history linear and free of update-merge bubbles.

## model-selection.md

### effort-ceilings

Escalation is not free quality. Anthropic's extended-thinking research
measures up to −36% on intuitive, pattern-matching tasks, and Astra's own
coding evals peak at `high` and put `max` below it (Terminal-Bench 4.0,
DeepSWE v1.1). On
well-specified work the top rungs make the output worse, not merely slower.
Nothing in the roster earns `max` on current evidence: Astra scores worse
there, Fable buys ~1 index point for +40% cost, and the rest top out below
it. The Fable range is experience over benchmarks, deliberately: Artificial
Analysis puts Fable `xhigh` at 65 and `max` at ~66, but `xhigh` has not paid
off in our own runs, so it stays an opt-in experiment rather than the
ceiling.

Field note, 2026-09: initial feedback has Fable 5.1 and Astra 6 performing
well at `medium`–`high`; `xhigh` shows little benefit and is excessive in
most cases. Hence the restraint in the table — `xhigh` is reserved for
genuinely very complex or cross-cutting work, and the orchestrator proposes a
`high` vs `xhigh` side-by-side on an ideal candidate rather than picking it,
so the ceiling moves on evidence, not on how substantial a task looks.

### opus-effort

Opus 5.5 launch charts (Anthropic, Sep 2026). FrontierCode v1.1 (agentic
coding): low ~47% at $0.40/task, **medium ~55% at $0.80 (peak)**, high ~54%,
xhigh ~51% (a dip), max ~54.5% at $6. Terminal-Bench 4.0: low ~38%, medium
~57% at $3, **high ~64% at $4**, xhigh ~66% at $7.50, max ~65% at $11. So
`medium` is the default for repo coding; `high` earns its ~33% extra cost on
long terminal-heavy work; `xhigh` buys ~2 points for ~2x cost and regresses
on repo coding; `low` drops 8–19 points, contrary to the migration guide's
"comes close" line. The API default is also `medium` (Opus 5's was `high`),
and at a given level 5.5 thinks more per turn than Opus 5, so carrying Opus
5's `high` over means longer, costlier turns.

### session-effort

The user changes the interactive effort constantly with `/effort` depending on
the work at hand, and Claude Code saves each change as the default for new
sessions. So the value in `always/settings.json`
(`modelSettings.*.effortLevel`) and whatever a session happens to be running
at are transient TUI state, never the intended baseline.

### cross-family-review

Genuine cross-family review catches what same-family review misses: a
Claude pass over Fable-orchestrated code reliably finds nothing. So
Claude-authored work (Opus implements under Fable) goes to Astra at the
gates, and Codex-authored work to Opus or, when complex, Fable.

### coderabbit

CodeRabbit runs on the PR anyway and its findings flow into the PR-burndown
contract, so a local CLI pass duplicated that cost plus the tokens to
arbitrate it. `babysit` pushes once per round because a lone CI fix
re-triggers a review before the pending one is even read; it stops after
round 2 because two rounds cover nearly every PR, and any count threshold on
remaining findings turns into a quota.

A round settles on CodeRabbit's status check, not on a review object: it
posts a review only when it has findings, so a push that resolves them
flips the check to pass and resolves the threads with nothing new posted.
On 2026-09-09 an agent polling for a review on the new head waited
indefinitely on an already-clean round.

### opus-browser-walks

Opus quota is normally available, so there is no reason to drop below it
for a browser walk.

### context-degradation

Cached tokens are cheap enough that re-sending a large prefix is never the
deciding cost. Context degradation is: a model's reasoning quality falls as
the window fills, regardless of how cheaply that window is billed (lost in
the middle; NoLiMa; Chroma's context-rot study; Anthropic's context
engineering guidance — verify citations before quoting). The two axes are
independent, and with Fable 5.1's cache pricing only the degradation axis
should drive the fresh-window decision. A `claude -p` dispatch pays a fixed
cold-start floor of roughly 40K tokens (harness prompt + instruction
imports), which is why it never pays off for minute-scale tasks.

### grok-briefing

When the user names Grok 4.6, its own briefing habits apply; Claude-side
briefing and effort habits copied onto it degrade results.

## dispatch-bootstrap.md

### just-in-time-loading

Until 2026-09-06 every Claude Code session, subagent, and `claude -p` leaf
force-imported model-selection.md and codex-delegation.md (~4.1K words) though
most never dispatch. They became read-on-dispatch, matching how Codex and
Hermes already loaded them; the always-loaded bootstrap block keeps only the
triggers and the read rule so the rule can bootstrap itself (Codex review
condition). Grok Build's rules directory was relinked the same way.

### pipeline-proportionality

Agents were running `rev` on trivial PRs because "two gates, never skipped"
read as unconditional. The first fix scaled the rev gate's depth with the
change, but a scaled-down pass still dispatched a reviewer on every rev, so
adversarial review kept firing on near-every prompt. The gate therefore
moved from depth to need: decide first whether independent judgment adds
evidence (plan, pre-PR, or an unresolved critical issue), then its model and
scope. Simple testable work uses local checks; workflow names and fix loops
do not create review gates, and every pass reports whether it changed
anything. On 2026-09-07 the gate briefly moved inside `rev` (a local
self-review, with an external Validate step gated behind "External calls");
that made the orchestrator review its own diff and then triage a second
opinion of it, which was the noise source. Final decision: `rev` is one
independent cross-family review; the whether lives at the caller (`longrun`
always, otherwise the user's invocation); proportionality is the reviewer's
weight and rung, never skipping the review.

### heavy-verification-serialization

2026-09-06, three worktrees with two Codex implementers, one Claude reviewer,
one gate and one browser walk: the low-memory guard fired seven times in
ninety minutes, taking the waiters (`#waiter-orphaning`) and twice a running
gate with it.

The measurements were one machine's and are not reproduced here; their
portable shape is the ratio. A leaf in its verification phase, a full gate's
typecheck fan-out, and a dev server behind a walk are each *multi-gigabyte*,
within the same order as the editor's resident language servers — which stand
there all day, one set per open checkout. Two of those three at once is the
peak that trips the guard; the guard trips on the peak, with headroom still
showing on a sustained read, so no amount of apparent free memory licenses
overlapping them. Whether it reads available memory, cgroup pressure, or the
harness's own footprint is unknown; knowing the threshold would turn this
rule into arithmetic instead of a ban.

Capping the fan-out inside the repo (vitest workers, turbo concurrency)
helped and did not stop the kills, and serializing by hand still died once —
overlapped by a *reviewer* running its own suite, which no brief had
forbidden. That is why the bound is written into the brief
(`codex-delegation.md` §4) rather than left to the orchestrator's intentions.

## codex-delegation.md

### codex-stdin

Without `</dev/null`, `codex exec` blocks on stdin reading "Reading
additional input from stdin..." even when the prompt is passed as an
argument. In background / cron / subprocess contexts this hangs until a
timeout kills it. Passing the brief as a file via `$(cat ...)` keeps the
invocation readable and avoids shell-escaping bugs.

### dispatch-shell

Two incident classes: (1) a foreground timeout SIGTERMs the whole process
group (2026-07-16: killed a freshly dispatched run ~1min in; symptom: frozen
log, registry start event with no close); (2) a *background* task that is
stopped kills its process group too — if the dispatching shell is still
alive because a wait is chained after the dispatch, the detached worker dies
as that group's descendant (2026-07-27: a stopped
`codex-exec.sh && codex-wait.sh` background task killed a Pass-mid run ~18min
in). Codex workers now detach via `setsid`. The earlier `set -m`
own-process-group attempt killed the job and hung the wrapper on first field
use (2026-07-16) and was reverted. The PreToolUse hook
`always/scripts/foreground-dispatch-guard.py` (added 2026-07-22, extended
2026-07-27) enforces dispatch shape deterministically in every permission mode
including bypass.

### leaf-side-effects

2026-09-06: a phase 2 implementer pushed a half-built schema to a shared dev
slot with a codegen command no brief had forbidden. A leaf that is not told
which commands deploy, migrate, or write a shared environment discovers the
side effect by causing it — hence the brief's Do NOT list names them, sourced
from the repo's own environment docs.

### pattern-kill

2026-07-14: a `pkill -f "codex exec"` took down an unrelated session's task.
Parallel sessions' runs are indistinguishable by command line, so any
pattern kill has shared blast radius. A stalled task whose log is frozen
usually has no live process at all.

### parallel-limit

Max parallel Codex runs was raised from 2 to 3 on 2026-07-06 to
progressively test wrapper management at that scale. Provisional: revert to 2
if health checks start flagging `stalled` runs or wall-clock degrades.

### leaf-gates

On this machine the Codex sandbox fails the web build on port binding and the
repo's source-acquisition validation on spawning git, so those runs only burn
memory — four wasted gate attempts on 2026-09-05, each a memory peak. Hence a
brief never asks the leaf for a build or gate that needs network, port
binding, or git subprocesses.

### waiter-orphaning

2026-07-28: the `codex-wait.sh` background task is a child of the Claude Code
session, so a session restart killed the waiter while the detached codex run
continued unaffected and closed into a registry nobody was watching. Symptom:
a "stopped / no completion record" task notification for the wait call, then
silence. The harness's low-memory guard kills background waiters the same way
(2026-09-05: twice during a leaf's typecheck + build, on top of the editor's
language servers; 2026-09-06: seven times in ninety minutes —
`#heavy-verification-serialization`, where `ScheduleWakeup` polling per
"Waiter recovery" was the working fallback, at a turn every five minutes and
no instant notification). In every case the detached run is unaffected; a dead
waiter costs only the notification. `xhigh` reasoning stretches can go quiet
past the stall threshold, which is why STALE means "look at the log tail",
not "kill it".

### claude-exec-simplicity

`claude-exec.sh` is deliberately simpler than the Codex wrappers: `claude -p`
has no stdin hang, no sandbox, and can write `.git/`, so the wrapper needs no
stdin redirect and no sandbox flag — only the same git policy by brief.

## coding-orchestration.md

### dispatch-loop

2026-07-29: a Hermes session re-issued an identical background
`claude -p --resume` dispatch ~440 times over 59m43s (one every 6–10s, all
resuming the same Fable session) instead of waiting for the first run, which
had written its answer to disk in 7 minutes — each new spawn truncated that
output. Cost: ~3.4M output tokens plus ~275M cached input tokens, 4 spawns
hitting the monthly spend limit, concurrent resumes clobbering one session's
context, and an hour of user silence. A `/steer` was delivered and ignored;
only the user's `/stop` ended it. A behavioral note alone would not have
stopped it, which is why enforcement is a mechanical `pre_tool_call` hook.
`approvals.deny` cannot serve as a backstop: its fnmatch globs on the full
command string cannot distinguish background from foreground (verified
against `hermes-agent/tools/approval.py` + `terminal_tool.py`, 2026-07-29 and
2026-07-30).

## claude-conventions.md

### artifacts

The Artifact tool is biased to fire whenever something "could be visual";
left alone it wraps ordinary answers in rendered pages nobody asked for.

### prompt-cache-heartbeat

The Anthropic prompt cache on Claude Code sessions has a one-hour TTL
measured from the last request. A cache read costs about a tenth of an
uncached read, so one cold rebuild of the session prefix costs roughly ten
warm pings — for any wait shorter than about seven hours a heartbeat is
cheaper than letting the cache lapse (settled 2026-09-03). Fifty minutes, not
fifty-nine: the wake fires after the delay, then queues and runs, and the TTL
clock does not wait for that.

## SETUP.md

### mcp-on-demand

Deferred tool schemas hide only the schema text; Claude Code still spawns
every configured stdio MCP server at session start. Playwright's server
launches a Chromium of 10–15 OS processes per session that navigates, so the
cost scales with open sessions: on 2026-09-08 seven concurrent sessions with
Playwright at user scope tripped WSL's memory ceiling and stalled the WSLg
compositor. That is why heavy servers are a per-session `--mcp-config` opt-in.
