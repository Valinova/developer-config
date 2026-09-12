# developer-config

Canonical source for personal Claude Code / Codex / Grok Build / agent
configuration, shared across machines. **Every versioned instruction and tool
config has exactly one owner here**; live machines consume repo-owned files
through symlinks, with documented merges into Codex's, Grok Build's, and
Pi's machine-owned configs.

## The mental model

- **The end state is deterministic; the process is not a script.** `SETUP.md`
  defines a fixed wiring table — identical on every machine — and an agent
  (not an installer) gets each machine there, adapting to local quirks
  (Hermes shim on the Mac, ext4 paths on WSL) without changing the destination.
- **After wiring, the file you edit locally IS the repo file.** Editing
  `~/.claude/scripts/codex-exec.sh` edits this repo's copy through the symlink —
  `git status` here shows it immediately. Reaching the other machine is still
  `commit + push` there, `git pull` here; git doesn't sync by itself.
- **Reconcile any time** by asking an agent to "check SETUP.md compliance" —
  that's the standing drift audit.

## Layout

```
instructions/               The doctrine. One owner per fact.
  principles.md             Engineering principles — every agent, every tool, every repo.
  claude-conventions.md     Claude-Code-only behavior (artifacts policy, …).
  dispatch-bootstrap.md     Always-loaded in Claude Code: hard delegation triggers,
                            the read-on-dispatch rule for the two files below,
                            the External-calls default (none unless decided).
  model-selection.md        Model profiles, harness seats, effort — what sits where.
                            Read on dispatch by Claude Code, Grok Build, and Codex
                            (the latter via `codex/model-defaults.md`);
                            Hermes links it.
  coding-orchestration.md   Hermes farm doctrine: dispatch paths, execution paths,
                            PR-burndown/decision-brief contracts, auth rules.
                            Reference, linked but not auto-loaded.
  codex-delegation.md       How any caller (Hermes, Claude Code, Grok Build) dispatches
                            codex exec: brief grammar, SUMMARY contract, per-caller
                            wrappers, registry. Claude Code reads it on dispatch.
  worktrees.md              Durable worktree layout, naming, reuse. Reference, not auto-loaded.
  agent-guidance.md         How to optimize AGENTS.md/CLAUDE.md and routed guidance.
                            Reference, not auto-loaded.
  opus5-quirks.md           Legacy Opus 5 reference, not auto-loaded.
  rationale.md              Incident and reasoning archive, not auto-loaded.
  token-efficiency.md       Metered-orchestrator context discipline. Reference, not auto-loaded.
claude-root.md              Becomes ~/.claude/CLAUDE.md via symlink. Pure @imports —
                            holds no rules of its own.
SETUP.md                    The wiring contract + verification checklist. An agent on
                            each machine applies it; there is no install script.
always/
  scripts/                  Codex dispatch wrappers (exec / resume / wait / status), Pi's
                            (exec / resume / wait — Pi has no status wrapper), Claude's
                            (exec / wait / status — same-family `claude -p` at a chosen
                            effort; resume is a flag on exec), Codex's dependency-free
                            Grok ACP leaf runner,
                            reap-orphan-mcp.sh, lib/ (the shared codex_registry and
                            claude-registry single owners, sourced by the wrappers,
                            not linked), and the hook-invoked guards
                            (supervised-git-backstop.py + its test, foreground-dispatch-guard.py
                            — repo-path-invoked, not on PATH), and check-private-terms.sh,
                            the CI guard that keeps client/personal identifiers out of the tree
  commands/
    shared/                 Harness-neutral entry points: com, comall, docs, no-use-effect.
    claude/                 Claude entry points: agentplan, babysit, execute-plan,
                            full-docs, longrun, rev.
    pi/                     Pi entry points: agentplan, babysit, execute-plan, full-docs,
                            longrun, rev.
  skills/                   Shared workflow owner for Claude Code, Codex, Pi, and Grok
                            Build when behavior and mechanism are genuinely identical:
                            code-simplifier, com, comall, design-taste-frontend, docs,
                            high-end-visual-design, no-use-effect. Every one is linked
                            into all four harnesses.
  settings.json             User-global ~/.claude/settings.json (permissions, plugins, toggles)
claude/skills/              Claude-owned orchestration workflows. Fable 5.1 orchestrates
                            Codex GPT-6 Astra wrapper passes and runs Claude-native review.
codex/
  model-defaults.md         Codex dispatch routing — native subagents,
                            cross-family `claude -p`, and Grok Build over ACP.
  skills/                   Codex-owned orchestration workflows using native Astra subagents
                            and `claude -p` for cross-family Claude review.
hermes/                     Hermes's consumption layer — owned here, loaded from the
  model-defaults.md         gitignored ~/.hermes via symlink. Seats live in
  skills/                   model-selection.md (this file is a pointer). skills/
                            owns the `/longrun` family (`agentplan`, `execute-plan`,
                            `rev`, `babysit`, `longrun`) under the same names as
                            Claude/Pi/Codex.
                            `docs` is the shared always/skills one.
grok/                       Grok Build's consumption layer. model-defaults.md is the
  model-defaults.md         Grok-scoped dispatch card (native Grok 4.6 spawn_subagent,
  skills/                   Codex wrappers, claude -p). skills/ owns Grok-native ports
                            of the delivery workflows (agentplan, execute-plan,
                            full-docs, longrun, rev, babysit). No commands dir — Grok skills
                            are slash commands. User execute-plan overrides Grok's
                            bundled Graphite DAG skill of that name.
                            Convex MCP skill is the Pi-owned `pi/skills/convex-mcp`,
                            linked in; MCP is machine-local in config.toml. Convex's
                            installer owns project `name: convex`.
packages/                   Opt-in skill/agent bundles — currently only browser-walker, which
                            ships an agent, not a skill (see SETUP.md, judgment-required)
pi/                         Pi's consumption layer. Owned files — settings.json (models, theme,
                            packages), subagents.json (Tintin defaults off), unpinned role agents,
                            model-defaults.md (the Pi-scoped model-×-task card and exact native
                            Agent model IDs wired to APPEND_SYSTEM.md), Pi-native ports of the
                            delivery workflows (agentplan, execute-plan, full-docs, longrun, rev,
                            babysit) plus convex-mcp (also linked into Grok Build), and mechanical extensions — with
                            tests — for destructive operations and bash timeout capping;
                            Pi otherwise consumes principles and harness-neutral shared skills.
```

## Architecture at a glance

```
                        ┌─────────────────────────────────────────────┐
                        │   developer-config  (git = the only sync)   │
                        │         one canonical owner per fact        │
                        └─────────────────────────────────────────────┘
                                            │
      ┌──────────┬───────────┬─────────────┼──────────────┬──────────────┐
      ▼          ▼           ▼             ▼              ▼              ▼
┌────────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│instructions│ │ always/ │ │claude/   │ │ codex/   │ │ pi/      │ │ grok/    │
│ DOCTRINE   │ │ SHARED  │ │skills/   │ │ skills/ +│ │ skills/ +│ │ skills/ +│
│ principles │ │ skills/ │ │ Claude-  │ │ model-   │ │ model-   │ │ model-   │
│ model-sel. │ │ commands│ │ owned    │ │ defaults │ │ defaults │ │ defaults │
│ codex-deleg│ │ scripts │ │ orch     │ │ Codex    │ │ settings,│ │ Grok-    │
│ conventions│ │settings │ │          │ │ orch     │ │ extens.  │ │ owned    │
│ bootstrap  │ │         │ │          │ │          │ │          │ │          │
└─────┬──────┘ └────┬────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
      │             │           │            │            │            │
      │   repo-owned files use symlinks; machine-owned merges cover    │
      │   Codex/Grok config.toml and Pi mcp.json (see SETUP.md)          │
      ▼             ▼           ▼            ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌────────────┐ ┌─────────────────────┐
│ CLAUDE CODE  │ │    CODEX     │ │     PI     │ │     GROK BUILD      │
│ principles + │ │ principles   │ │ principles │ │ rules/*.md:         │
│ conventions +│ │ ONLY; merge  │ │ + pi/model-│ │  principles +       │
│ bootstrap;   │ │ Astra/high;  │ │ defaults   │ │  bootstrap +        │
│ model-sel. + │ │ read model-  │ │ lean agent │ │  grok/model-defaults│
│ codex-deleg  │ │ defaults.md  │ │ always/+pi │ │  (model-sel./codex- │
│ on dispatch  │ │ always/+codex│ │            │ │  deleg on dispatch) │
│              │ │              │ │            │ │ skills: always/+    │
│ skills:      │ │ Astra native │ │            │ │  grok/ (overrides   │
│  always/+    │ │ claude -p    │ │            │ │  bundled execute-   │
│  claude/     │ │ for Claude   │ │            │ │  plan). Native Grok │
│ Codex via    │ │              │ │            │ │ 4.6 spawn_subagent; │
│ wrappers     │ │              │ │            │ │ Codex wrappers;     │
└──────────────┘ └──────────────┘ └────────────┘ │ claude -p for Claude│
                                                 └─────────────────────┘

  WORKFLOW COMPOSITION (same shape in Claude, Codex, Pi, Grok Build; mechanics differ)

   /agentplan ──────────► /execute-plan ─────────► /rev
   plan, mutually         implement plan in        one cross-family review:
   reviewed cross-family  verified commits +       code-simplifier + audit,
        │                 light per-phase checks   agreed fixes committed
        └──────────────────────┴───────────┬───────────┘
                                           ▼
   /longrun = agentplan → execute-plan → rev → docs → (push → PR) → babysit
   (each stage independently invokable; rev/babysit never recurse into longrun)
   Hermes uses the same names; default orch is Grok 4.6, implementer is Codex,
   Claude only through `claude -p`. Grok Build is the same seat in a TUI:
   native Grok 4.6, Codex wrappers, `claude -p`.
```

## How it all fits together

Two machines, one owner. The only sync in the system is git between clones.
Repo-owned files are pointers; the machine-owned Codex, Grok Build, and Pi
configs receive the small merges defined in `SETUP.md`:

```
                    ┌──────────────────────────────────────────┐
                    │  github.com/Valinova/developer-config    │
                    │  the ONE owner of doctrine + tooling     │
                    └───────────────┬──────────────────────────┘
                        push ▲      │      ▼ pull        ← the only "sync"
              ┌─────────────────────┴─────────────────────┐
              │                                           │
     Mac: ~/Development/developer-config        WSL: ~/Development/developer-config
              │  (repo-owned files below are symlinks →   │  (same contract,
              │   same file, zero copies)                 │   minus Hermes shim)
              ▼                                           ▼
```

Inside each machine, every consumer points at the clone (SETUP.md contract):

```
  ~/Development/developer-config
  ├── claude-root.md ◄─────symlink───── ~/.claude/CLAUDE.md      [CLAUDE CODE]
  │     │ @imports
  │     ▼
  ├── instructions/
  │   ├── principles.md ◄──symlink───── ~/.codex/AGENTS.md       [CODEX]
  │   │        ▲
  │   │        ├────────────symlink──── ~/.pi/agent/AGENTS.md    [PI — verbatim, no
  │   │        │                                                  @import; one global
  │   │        │                                                  file, so principles only]
  │   │        └────────────symlink──── ~/.grok/rules/00-        [GROK BUILD — verbatim
  │   │                             principles.md                 rules/*.md, numbered
  │   │                                                           because later-alpha wins]
  │   ├── claude-conventions.md   (Claude only, via claude-root import)
  │   ├── dispatch-bootstrap.md   (Claude via claude-root import, Grok via
  │   │                            ~/.grok/rules/05-; says when
  │   │                            to read the two files below)
  │   ├── model-selection.md      (read on dispatch by Claude Code, Grok Build,
  │   │                            and Codex (the latter via
  │   │                            `codex/model-defaults.md`); Hermes links it)
  │   ├── codex-delegation.md     (orchestrators: Claude + Grok Build read on
  │   │                            dispatch; Hermes links it)
  │   └── coding-orchestration.md (reference, not auto-loaded)
  ├── grok/model-defaults.md   ◄─symlink─ ~/.grok/rules/30-model-defaults.md
  ├── always/scripts/*         ◄─symlinks─ ~/.claude/scripts/*       [the live wrappers]
  ├── always/skills/*          ◄─symlinks─ Claude + Codex + Pi + Grok [shared workflows]
  ├── claude/skills/*          ◄─symlinks─ ~/.claude/skills/*        [Claude orchestration]
  ├── codex/skills/*           ◄─symlinks─ ~/.codex/skills/*         [Codex orchestration]
  ├── pi/skills/*              ◄─symlinks─ ~/.pi/agent/skills/*      [lightweight Pi workflows]
  ├── grok/skills/*            ◄─symlinks─ ~/.grok/skills/*          [Grok orchestration]
  ├── always/commands/{shared,pi}/* ◄─ ~/.pi/agent/prompts/*
  ├── always/commands/{shared,claude}/* ◄─ ~/.claude/commands/*      [Claude: both dirs]
  └── always/settings.json     ◄─symlink─ ~/.claude/settings.json
```

Codex's always-loaded engineering doctrine is principles only. Its global
configuration mechanically defaults native subagents to GPT-6 Astra at high
reasoning and carries a small instruction to consult `codex/model-defaults.md`
and read its canonical policy references before choosing each dispatch
model and effort. When the user names Grok,
that same card points Codex at the dependency-free `grok-acp-exec.py` runner:
Codex remains the orchestrator and Grok Build is one sandboxed leaf process.
Codex-owned workflows arrive through `codex/skills/`. Shared model policy in
`model-selection.md` applies to every harness; `codex-delegation.md` covers
external CLI callers. Grok
Build cannot expand `@import`, so it does not load `claude-root.md`; home
doctrine is three numbered files under `~/.grok/rules/` (principles,
`dispatch-bootstrap.md`, `grok/model-defaults.md`); model-selection and
codex-delegation are read on dispatch. Native
`spawn_subagent` is Grok 4.6 only; implement still goes through the Codex
wrappers; Claude is `claude -p`. `~/.grok/config.toml` is a documented merge
(Claude skill/agent compat off, native subagent models pinned to grok-4.6).
Pi's always-loaded
doctrine is also principles only, but for two reasons: Pi injects context files verbatim (no
`@import` expansion) and loads a single global file, so the multi-file
`claude-root.md` composition can't reach it; and by design Pi runs as a lean
coding agent rather than loading the advanced Claude/Codex orchestration
workflows. Its Pi-scoped model card owns the exact provider/model IDs because,
unlike the other harnesses, native Tintin `Agent` calls cannot rely on semantic
family names resolving to the current model. Unpinned role agents make each
fresh call choose one of those IDs and a thinking level explicitly; resumed
agents keep their existing model.

Claude Code and Grok Build delegate Codex work through the wrappers in
`always/scripts/` (Grok has no second wrapper set); Claude Code also delegates
same-family `claude -p` passes at a chosen effort through `claude-exec.sh`
(`model-selection.md` "The lane follows the effort"). Pi uses native `Agent`
subagents instead: the same wrappers remain available through
`~/.pi/agent/scripts`, but they are not Pi's normal subagent dispatch path.
Repo-level `AGENTS.md`/`CLAUDE.md` files are inherited on top automatically and
hold only repo-specific guidance.

Advanced delivery is composable: `agentplan` produces a cross-family reviewed
plan (full, or scope-only in Discover mode), `execute-plan` implements it in
verified commits, `rev` performs the other-family adversarial review
(code-simplifier plus the principles audit), `docs` consolidates
documentation, and `babysit` watches the open PR to merge-ready — CI and
CodeRabbit settled together, at most one push per round, with a two-round
cost circuit breaker. An unmet ship gate is reported as incomplete delivery.
`longrun` sequences them per the mode (Full / Discover / Iterative — owner:
`instructions/model-selection.md` "Delivery pipeline modes"), pushes, opens
the PR, and ends in `babysit`; CodeRabbit runs on the PR, not as a local
step. Each atomic workflow remains independently invokable; `rev` and
`babysit` never recurse into `longrun`.

The life of an edit (e.g. tweak a codex wrapper):

```
 edit ~/.claude/scripts/codex-exec.sh      ← the "live" path
        = editing the clone's file          (symlink: same inode, no copy)
        → `git status` shows the diff       immediately, automatically
        → commit + push                     when you decide it's ready
        → other machine: git pull           done — its symlinks already point here
```

## New machine

```bash
git clone git@github.com:Valinova/developer-config.git ~/Development/developer-config
```

Then open Claude Code and ask it to apply `SETUP.md`. It wires the symlinks,
runs the verification checklist, and asks about the judgment-required parts
(packages, project settings). Start wiring checks mechanically with
`python3 always/scripts/check-wiring.py`, then complete the remaining
`SETUP.md` verification items. Re-ask any time — "check SETUP.md compliance" is
the standing drift audit.

## Editing doctrine

Edit the canonical owner: shared doctrine under `instructions/`, shared skills
under `always/skills/`, or harness-specific workflows under `claude/skills/`,
`codex/skills/`, `pi/skills/`, and `grok/skills/`. Other machines receive
committed changes through `git pull`; their live paths already point at these
owners.
When the wiring contract or Codex's or Grok Build's mechanical subagent
defaults change, run the `SETUP.md` compliance check on each machine as well.

Never restate an `instructions/` rule in a repo's `AGENTS.md` or in a machine's
local files: one owner per fact. A repo that needs *different* behavior states
an explicit, labeled override in its own `AGENTS.md`.

## A note on `always/settings.json`

This is the user-global `~/.claude/settings.json` — Bash allow/deny lists,
plugin toggles, behavior flags. Because it's a symlink, edits made via
`/config` or by Claude Code itself flow back to git. Volatile keys may show up
as occasional diffs; commit or `git restore` them.
