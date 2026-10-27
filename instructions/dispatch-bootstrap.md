# Dispatch bootstrap

Always loaded so a session knows the moment it must delegate and what to read
first. `model-selection.md` (seats, effort, lanes) and
`codex-delegation.md` (briefs, wrappers) are read on dispatch, not every turn.

**A check killed for memory is a memory problem, not a code failure.** On
WSL, earlyoom kills heavy check processes first (`tsgo`, `vitest`, `eslint`,
`turbo`, `bun`, `node`) when the machine runs out of memory. If a
gate, typecheck, lint, or test dies with `Killed`, exit 137 or 143, or stops
with no output, run `journalctl -u earlyoom -n 5` and `free -h`. When earlyoom
killed it, tell the user plainly that the run was killed for memory, and that
its result says nothing about the code. Don't change code in response. Wait
until other sessions' heavy work has settled (check `free -h` every few
minutes), then retry once. Never retry in a loop.

**Hard delegation triggers — delegate, don't do it yourself:**

- **Fact retrieval across more than a couple of files** (repo recon, logs or
  transcripts, doc digestion, "find every place that…") → a retrieval
  subagent that returns a distilled brief (≤ ~3K tokens) with file:line
  pointers; delegate any extraction whose result would exceed ~2K tokens.
  Judging content is read, not delegated. Verify by spot-checking pointers.
- **Any edit touching more than a couple of files**, or any implement pass
  with a brief → the harness's implementer lane (Claude Code: a fresh native
  Opus `Agent` at the task's rung, Codex wrappers for a user-named
  cross-family implement), never the orchestrator
  editing file by file in its own window, except a `rev` reviewer applying its own
  clear-cut fixes within the agreed findings' scope, with no git writes.

**Read before you dispatch.** Before any dispatch (`Agent` tool,
`claude-exec.sh`, `codex-exec.sh`, `pi-exec.sh`) or any
workflow skill (`agentplan`, `execute-plan`, `rev`, `docs`, `full-docs`,
`comment-audit`, `babysit`, `longrun`), read
`~/Development/developer-config/instructions/model-selection.md` and
`~/Development/developer-config/instructions/codex-delegation.md` in full. Every brief that lets a leaf delegate further must require the same
read plus the leaf's harness model card (Claude Code: `codex-delegation.md`); ambient principles never supply
seats, effort, or brief grammar.

**External calls** dispatch another model for independent judgment (a plan
or diff review, `rev`, an escalation, any cross-family opinion); local checks,
tests, and the pre-commit gate are not external calls. In interactive work,
none unless the user asks — suggest one when the risk warrants it; the user's
yes is the go. A workflow skill carries its own gates, and invoking it is the
approval. Under granted autonomy without a skill ("go build it and open a
PR"), judge it and state the choice and why. Nothing else converts
"available" into "required" — not a subagent's existence, not a repo-level
`AGENTS.md` command (why: rationale.md#pipeline-proportionality). State the
decision per `model-selection.md` "Announce-then-proceed preamble", then
continue.

**One heavy verification per machine at a time.** Serialize full gates
(typecheck fan-out, test workers, a web build), leaf verification phases, and
dev servers behind browser walks: never start a gate while a leaf is
verifying, and start a dev server only inside a walk that stops it. What a
leaf or reviewer may run is the brief's job (`codex-delegation.md` "Every
brief must include" §4) (why: rationale.md#heavy-verification-serialization).
