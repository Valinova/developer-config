# Token Efficiency on Metered Orchestrators (Fable / Anthropic API)

Canonical reference — lives in `developer-config/instructions/` (shared across
machines), not auto-loaded. Written 2026-07-17 after a cost audit of the
a client-repo AI-log-export orchestration session (Fable-5.1
orchestrator, ~45 tool-call turns). Consumers: any metered-orchestrator work
(Claude Code / Hermes). Update HERE first, then re-derive downstream guidance.

## The cost model (why this doc exists)

- On a metered API orchestrator, **every turn re-bills the entire accumulated context**.
  The cost lever is not any single read — it's (a) how much enters the window and
  (b) how many turns multiply it.
- Anthropic prompt caching: cache **reads ~0.1×** input price, **writes ~1.25×**.
  Base TTL **5 minutes, refreshed on every hit**. Optional **1-hour TTL at 2× write**.
- Orchestration sessions (dispatch → wait 10-20 min → wake) are the **worst case** for
  the 5m TTL: every wake-up after a long wait is a cold cache → full-context rewrite at
  1.25× instead of a 0.1× read. Tight interactive sessions cache fine; slow-cadence
  orchestration does not.
- Subscription harnesses (`claude -p`, `codex exec`) bill quota, not dollars. Identical
  sloppiness there is much cheaper — hence different rules per seat.

## Levers (ranked, all adopted 2026-07-17)

### 1. Cache TTL = 1h for Hermes (config, done)
`prompt_caching.cache_ttl: 1h` in `~/.hermes/config.yaml` (valid values: `5m` | `1h`).
One 2× write per hour beats repeated 1.25× rewrites for any session with waits.
Set via `hermes config set prompt_caching.cache_ttl 1h`.

### 2. Heartbeat interval < cache TTL (skills, done)
Metered orchestrator: poll background dispatches with `process(wait, timeout=240)`
(4 min < 5m base TTL) so the prefix stays warm across a whole dispatch. With the 1h TTL
this is belt-and-suspenders; keep it anyway (harmless, and protects if TTL reverts).
Subscription orchestrators follow their harness lifecycle instead: Claude
Code's heartbeat is in `claude-conventions.md`; Codex/Grok/Hermes waiting on
`claude -p` follows `codex/model-defaults.md`. This historical cache advice
does not override those waiting and diagnostic rules.

### 3. Session continuity
Choose by context relevance and degradation under `model-selection.md`
"Fresh window or inherited context", never cache cost or phase boundaries
alone. For adversarial review, follow `codex/model-defaults.md` "Resume or
start fresh for adversarial review". A fresh session receives file paths,
branch, a short state summary, and still-valid evidence; changing sessions
does not invalidate completed work.

### 4. Compaction: at boundaries only, never mid-flow
Compaction rewrites the prefix → next turn is a full cache write, plus the summarization
pass itself. More-frequent compaction is NOT a win. Compact right after a dispatch report
lands (cache about to be cold anyway), or prefer lever 3. Hermes compression config:
`compression.threshold` in config.yaml (0.35 as of Jul 2026).

### 5. Read discipline (the base that everything multiplies)
Audit findings from the 2026-07-17 session — each individually small, all re-billed
every remaining turn:
- **Full plan doc read into orchestrator context** (~7K tokens) when the planner's exec
  summary + Deferred Decisions table sufficed. Rule: plan PATH goes in briefs;
  orchestrator reads summary + D-table only.
- **Duplicate review ingestion** (stdout tail AND file read of the same report).
  Rule: file OR tail, never both.
- **Repo recon in orchestrator turns** (6 git-grep turns) instead of one `claude -p`
  Opus dispatch returning a ≤3K brief. Rule: bulk retrieval → subscription harness
  (canonical: dispatch-bootstrap.md hard delegation triggers).
- **Window-scroll dumps** from session_search: extract the one needed message via a
  python filter, not the whole ±window.
- **Verbose interim reports**: decision-dense, not narrative. If the doctrine answer is
  "implement, one line each", say that.

## Decision rule for the orchestrator seat

Fable (metered) earns the seat only for judgment-dense complex plans. If per-run cost
still hurts after levers 1-5, demote run orchestration to `claude -p` Fable — one-line
job-config change; runbooks are orchestrator-agnostic (also stated in
[Hermes longrun skill](../hermes/skills/longrun/SKILL.md)).

## Config/source anchors (verified 2026-07-17)

- `hermes_cli/config_defaults.py:677-679` — `prompt_caching.cache_ttl` accepts "5m" | "1h" only; others ignored.
- Hermes core doctrine: "Per-conversation prompt caching is sacred" — never mutate past
  context / swap toolsets / rebuild system prompt mid-conversation (hermes-agent
  AGENTS.md). Compression is the sanctioned exception.
- `compression.threshold: 0.35`, `protect_last_n: 10` — config.yaml.

## Future improvements (not yet done)

- Verify empirically (dashboard token analytics / API usage logs) that 1h-TTL writes are
  actually landing as cache hits across dispatch waits.
- Consider a Hermes-side "phase handoff" helper that writes the state summary file and
  opens the fresh session automatically.
