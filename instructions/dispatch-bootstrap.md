# Dispatch bootstrap

Always loaded so a session knows the moment it must delegate and what to read
first. `model-selection.md` (seats, effort, review, pipeline) and
`codex-delegation.md` (briefs, wrappers) are read on dispatch, not every turn.

**Hard delegation triggers — delegate, don't do it yourself:**

- **Any read or search across more than a couple of files** (repo recon, log
  or transcript reconstruction, doc digestion, "find every place that…") →
  a retrieval subagent that returns a distilled brief (≤ ~3K tokens) with
  file:line pointers.
- **Any edit touching more than a couple of files**, or any implement pass
  with a brief → the implementer lane (`claude-exec.sh` or a native Opus
  `Agent`; Codex wrappers when Astra implements), never the orchestrator editing file by file in its own window.
- Heuristic: extracting facts → delegate (above all any tool result you expect
  to exceed ~2K tokens); judging content → read. Verify by spot-checking
  pointers, not re-reading the corpus.

**Read before you dispatch.** Before any dispatch (`Agent` tool, Grok
`spawn_subagent`, `claude-exec.sh`, `codex-exec.sh`, `pi-exec.sh`) or any
workflow skill (`agentplan`, `execute-plan`, `rev`, `docs`, `full-docs`,
`babysit`, `longrun`), read
`~/Development/developer-config/instructions/model-selection.md` and
`~/Development/developer-config/instructions/codex-delegation.md` in full. Every brief that lets a leaf delegate further must require the same
read plus the leaf's harness model card; ambient principles never supply
seats, effort, or brief grammar.

**External calls** (a plan or diff review, `rev`, any cross-family opinion):
in interactive work, none unless the user asks — suggest one when the risk
warrants it. A workflow skill carries its own gates, and invoking it is the
approval. Under granted autonomy without a skill, judge it and state the
choice. Which gates each skill carries, who reviews, and at what rung:
`model-selection.md` "External calls"; state the decision per
"Announce-then-proceed preamble", then continue.

**One heavy verification per machine at a time.** A full gate (typecheck
fan-out, test workers, a web build), a Codex or Claude leaf in its own
verification phase, and a dev server behind a browser walk each cost several
gigabytes on top of the editor's resident language servers; two of them
together have tripped the harness's low-memory guard (why:
rationale.md#heavy-verification-serialization). The orchestrator serializes
gate runs, never starts a gate while a leaf is verifying, and starts a dev
server only inside a walk that stops it. What a leaf or reviewer may run is
the brief's job (`codex-delegation.md` "Every brief must include" §4).
