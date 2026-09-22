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

One line per top-level entry; each file's header and `SETUP.md` own the detail.

```
instructions/     The doctrine, one owner per fact: principles, git-operations,
                  claude-conventions, dispatch-bootstrap (always loaded in Claude
                  Code), model-selection and codex-delegation (read on dispatch),
                  coding-orchestration, agent-guidance, durable-worktrees, the
                  rationale archive (reference, not auto-loaded), and benchmarks
                  (data log behind the effort rule, not loaded).
claude-root.md    Becomes ~/.claude/CLAUDE.md via symlink. Pure @imports.
SETUP.md          The wiring contract + verification checklist. No install script.
workflows/        One shared body per delivery workflow (agentplan, execute-plan,
                  full-docs, longrun, rev, babysit). Not a skill dir, never linked.
always/
  scripts/        Dispatch wrappers (Codex, Claude, Pi), Grok ACP runner, hook
                  guards, wiring and private-terms checkers, reap-orphan-mcp.sh.
  commands/       Slash-command / prompt entry points: shared/, claude/, pi/.
  skills/         Harness-neutral skills linked into Claude, Codex, Pi, and Grok
                  Build: code-simplifier, com, comall, design-taste-frontend, docs,
                  no-use-effect.
  mcp/            On-demand MCP server definitions (Playwright).
  settings.json   User-global ~/.claude/settings.json.
claude/skills/    Claude stubs over workflows/ (harness facts only).
codex/            model-defaults.md (Codex dispatch card); skills/: stubs over
                  workflows/ plus Codex-only skills.
grok/             model-defaults.md (Grok Build card); skills/: stubs over workflows/.
pi/               model-defaults.md (Pi card), settings, subagents, role agents,
                  extensions + tests; skills/: stubs over workflows/ plus convex-mcp.
hermes/           model-defaults.md; skills/: the /longrun family stubs; scripts/.
packages/         Opt-in bundles (browser-walker agent); see SETUP.md.
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
│ principles │ │ skills/ │ │ stubs    │ │ model-   │ │ model-   │ │ model-   │
│ model-sel. │ │ commands│ │ over     │ │ defaults │ │ defaults │ │ defaults │
│ codex-deleg│ │ scripts │ │workflows/│ │ stubs    │ │ settings,│ │ stubs    │
│ conventions│ │settings │ │          │ │          │ │ extens.  │ │          │
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
│ bootstrap;   │ │ Sol/high;    │ │ defaults   │ │  bootstrap +        │
│ model-sel. + │ │ read model-  │ │ skills:    │ │  grok/model-defaults│
│ codex-deleg  │ │ defaults.md  │ │  always/+pi│ │  (model-sel./codex- │
│ on dispatch  │ │ always/+codex│ │            │ │  deleg on dispatch) │
│ skills:      │ │              │ │            │ │ skills: always/+    │
│  always/+    │ │ Astra orch;  │ │ local model│ │  grok/ (overrides   │
│  claude/     │ │ Sol impl;    │ │ per machine│ │  bundled execute-   │
│ Fable orch;  │ │ claude -p    │ │ (two-family│ │  plan). Native Grok │
│ Opus impl;   │ │  (Claude)    │ │  rule)     │ │ 4.7 spawn_subagent; │
│ Astra review │ │  reviews     │ │            │ │ Codex wrappers;     │
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
   Two families: Claude side (Fable orch, Opus executes, Astra reviews) and
   Codex side (Astra orch, Sol executes, Claude reviews). Pi, Hermes, and Grok
   Build run each machine's local default model under the same two-family
   rule; Grok 4.7, DeepSeek, open-source models, and Luna are user-named
   overrides anywhere.
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

Inside each machine, every live path is a symlink into this clone or a small
documented merge into a machine-owned config; the table is `SETUP.md`
"Contract". What each harness loads, and why Codex, Pi, and Grok Build load
less than Claude Code, is in `SETUP.md` (the per-harness sections and
"Instruction hierarchy"). Who orchestrates, implements, and reviews on each
harness is `instructions/model-selection.md` "Harness seats" and "Roster".

## New machine

```bash
git clone https://github.com/Valinova/developer-config.git ~/Development/developer-config
```

Then open Claude Code and ask it to apply `SETUP.md`. It wires the symlinks,
runs the verification checklist, and asks about the judgment-required parts
(packages, project settings). Start wiring checks mechanically with
`python3 always/scripts/check-wiring.py`, then complete the remaining
`SETUP.md` verification items. Re-ask any time — "check SETUP.md compliance" is
the standing drift audit.

## Editing doctrine

Edit the canonical owner: shared doctrine under `instructions/`, delivery
workflow bodies under `workflows/`, shared skills under `always/skills/`.
Harness stubs under `claude/skills/`, `codex/skills/`, `pi/skills/`,
`grok/skills/`, and `hermes/skills/` carry only harness facts (model card,
lanes, long-wait mechanism). Other machines receive committed changes through
`git pull`; their live paths already point at these owners. When the wiring
contract or Codex's or Grok Build's mechanical subagent defaults change, run
the `SETUP.md` compliance check on each machine as well.

Never restate an `instructions/` rule in a repo's `AGENTS.md` or in a machine's
local files: one owner per fact. A repo that needs *different* behavior states
an explicit, labeled override in its own `AGENTS.md`.

`always/settings.json` is the symlinked `~/.claude/settings.json`; which of its
keys the repo owns and how to handle runtime drift is `SETUP.md` "Settings
drift".

License: [MIT](LICENSE).
