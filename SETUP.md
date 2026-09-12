# SETUP.md — the wiring contract

This file replaces `install.sh` + `BOOTSTRAP.md`. There is no installer: an
agent (Claude Code) on each machine implements and verifies this contract with
judgment a script can't apply. The contract is the canonical definition of
"correctly wired"; if the machine disagrees with this file, the machine is wrong.

## Contract

The repo is cloned at `~/Development/developer-config` on every machine
(all paths are `~`-relative, so there is one contract — no Mac/WSL fork).

| Live path | → | Canonical source (this repo) |
|---|---|---|
| `~/.claude/CLAUDE.md` | symlink | `claude-root.md` |
| `~/.codex/AGENTS.md` | symlink | `instructions/principles.md` |
| `~/.codex/config.toml` native subagent defaults | merge | Set `[agents]` to GPT-6 Astra / high and tell Codex to read `codex/model-defaults.md` before dispatch; preserve every unrelated setting |
| `~/.pi/agent/AGENTS.md` | symlink | `instructions/principles.md` |
| `~/.claude/settings.json` | symlink | `always/settings.json` |
| `~/.claude/mcp/playwright.json` | symlink | `always/mcp/playwright.json` (on-demand MCP server definition — see "MCP servers load on demand") |
| `~/.claude/mcp/playwright-browser.json` | symlink | `always/mcp/playwright-browser.json` (headless Chromium options, the default) |
| `~/.claude/mcp/playwright-browser-headed.json` | symlink | `always/mcp/playwright-browser-headed.json` (headed variant, selected per session via `PLAYWRIGHT_MCP_BROWSER_CONFIG`) |
| shell rc (`~/.bashrc` / `~/.zshrc`) | merge | `alias claude-pw='claude --mcp-config ~/.claude/mcp/playwright.json'` and `alias claude-pw-headed='PLAYWRIGHT_MCP_BROWSER_CONFIG=~/.claude/mcp/playwright-browser-headed.json claude --mcp-config ~/.claude/mcp/playwright.json'`; preserve everything else |
| `~/.pi/agent/settings.json` | symlink | `pi/settings.json` |
| `~/.pi/agent/subagents.json` | symlink | `pi/subagents.json` (Tintin defaults disabled) |
| `~/.pi/agent/APPEND_SYSTEM.md` | symlink | `pi/model-defaults.md` |
| `~/.pi/agent/mcp.json` Convex entry | merge | Add the machine-owned `mcpServers.convex` entry described below; preserve unrelated servers |
| `~/.pi/agent/agents/<f>` | symlink each | `pi/agents/<f>` (role/tools only; model and thinking stay dispatch-owned) |
| `~/.pi/agent/extensions/<f>` | symlink each | `pi/extensions/<f>` (`destructive-guard.ts` protects unrecoverable operations; `bash-timeout-guard.ts` caps bash timeouts so hung commands cannot block forever) |
| `~/.claude/skills/<shared>` | symlink each | `always/skills/<shared>` |
| `~/.claude/skills/<claude>` | symlink each | `claude/skills/<claude>` |
| `~/.codex/skills/<shared>` | symlink each | `always/skills/<shared>` |
| `~/.codex/skills/<codex>` | symlink each | `codex/skills/<codex>` |
| `~/.pi/agent/skills/<shared>` | symlink each | `always/skills/<shared>` |
| `~/.pi/agent/skills/<pi>` | symlink each | `pi/skills/<pi>` |
| `~/.grok/rules/00-principles.md` | symlink | `instructions/principles.md` |
| `~/.grok/rules/05-dispatch-bootstrap.md` | symlink | `instructions/dispatch-bootstrap.md` (model-selection and codex-delegation are read on dispatch, not linked) |
| `~/.grok/rules/30-model-defaults.md` | symlink | `grok/model-defaults.md` |
| `~/.grok/skills/<shared>` | symlink each | `always/skills/<shared>` |
| `~/.grok/skills/<grok>` | symlink each | `grok/skills/<grok>` |
| `~/.grok/skills/convex-mcp` | symlink | `pi/skills/convex-mcp` (Pi/Grok MCP policy; Claude uses the official plugin. Convex's installer owns project `name: convex`) |
| `~/.grok/config.toml` Claude compat + native subagent models | merge | Set `[compat.claude] skills = false` and `agents = false`; pin `[subagents.models]` explore / plan / general-purpose to `grok-4.6`; preserve every unrelated setting |
| `~/.claude/scripts/<f>` | symlink each | `always/scripts/<f>` (PATH-invoked scripts only — see note) |
| `~/.pi/agent/scripts` | symlink | `always/scripts` |
| `~/.claude/commands/<f>` | symlink each | `always/commands/{shared,claude}/<f>` (both dirs) |
| `~/.pi/agent/prompts/<f>` | symlink each | `always/commands/{shared,pi}/<f>` (both dirs) |
| `~/.hermes/skills/software-development/<name>` | symlink each | `hermes/skills/<name>` (Hermes-owned only: `agentplan`, `execute-plan`, `rev`, `babysit`, `longrun`) |
| `~/.hermes/skills/software-development/docs` | symlink | `always/skills/docs` (harness-neutral, same file Claude, Codex, Pi, and Grok Build read) |
| `~/.hermes/scripts/sync-soul-principles.py` | symlink | `hermes/scripts/sync-soul-principles.py` (SOUL principles embedder; Hermes hosts only) |

`always/scripts/check-wiring.py` is the enforced form of this table; change both together.
It requires Python 3.11+ (stdlib TOML parsing), reads configuration without
starting harnesses, and never installs packages or changes live files.

Use symlinks for repo-owned files so edits land in git. The existing plain-copy
exception for Claude settings is described below. Machine-owned merges are the
listed Codex defaults/routing, Grok compatibility/models/MCP, and Pi MCP entries;
preserve all unrelated configuration.

The hook scripts — `always/scripts/supervised-git-backstop.py` (plus its test,
`test_supervised_git_backstop.py`) and `foreground-dispatch-guard.py` — are NOT
linked into `~/.claude/scripts/`: the `PreToolUse` hooks in `always/settings.json`
invoke them by absolute repo path, so per-file links would be dead weight.
`always/scripts/lib/` — the shared `codex_registry` and `claude-registry`
owners — is likewise not linked; the wrappers source it by repo path at
runtime. `check-wiring.py` and `check-private-terms.sh` are likewise unlinked —
the Verification section and CI invoke them by repo path. Every other file directly in `always/scripts/`,
excluding all `test_*.py` files and scripts referenced by the settings `hooks`
block, is linked into `~/.claude/scripts/` for invocation on `PATH`.

Add `~/.claude/scripts` and, when Pi is installed, `~/.pi/agent/scripts` to
the interactive shell's `PATH` (on zsh, configure `~/.zshrc`). Verify in a fresh
shell that `command -v codex-exec.sh`, `command -v claude-exec.sh`, and, when
installed, `command -v pi-exec.sh` resolve to these repo-owned wrappers.

**Runtime-mutable keys in `always/settings.json`:** because the file is
symlinked, Claude Code's `/model` and `/effort` toggles rewrite the `model` and
`effortLevel` keys in place — and picking the default model deletes the `model`
key outright rather than writing a value. Whatever those two keys hold at HEAD
is last-toggle residue, not a deliberate cross-machine default; diffs limited to
them are session noise. The sanctioned way to keep that noise out of `git
status` is machine-local `git update-index --skip-worktree` on the settings
file (`git ls-files -v` shows `S` once set). Set it per machine for this file
and `pi/settings.json`. The tradeoff: real changes (e.g. Pi's `packages`) also stop
showing; un-skip, commit, re-skip when deliberately editing one.

The same is true of the keys the harness itself owns: `enabledPlugins`,
`extraKnownMarketplaces`, and the UI toggles are rewritten whenever a plugin is
installed or a cloud-side setting syncs down. **This drift is expected — do not
"reconcile" it.** Only two things in this file are the repo's to own and worth
keeping in sync: `permissions` (allow / deny) and `hooks`. If a machine's
`~/.claude/settings.json` is a plain copy rather than the symlink, that's the
same story — compare the `permissions` and `hooks` blocks, ignore the rest.

To stop the noise on a symlinked clone, set the skip-worktree bit once:

```bash
git update-index --skip-worktree always/settings.json
```

This is whole-file, not hunk-level: git ignores *all* local edits to the file,
so runtime toggles never surface in `git status`. The tradeoff is pulls — when
an upstream commit changes `settings.json`, the pull refuses ("local changes
would be overwritten"). To take it: `--no-skip-worktree`, `git checkout --
always/settings.json`, pull, then re-set the bit. Editing shared settings
yourself is the same dance. Prefer not to carry the bit? Fall back to dropping
the model/effort hunks (`git add -p` / `git checkout -p`) when committing other
settings changes.

`~/.codex/AGENTS.md` is what Codex actually reads globally — NOT
`~/.claude/AGENTS.md` (the old install.sh linked there; Codex never looks in
`~/.claude/`, which is why Codex ran with no instructions on WSL). That symlink
loads the shared engineering principles only. Keep model routing out of that
file. Merge these values into `~/.codex/config.toml` without replacing any
unrelated instruction or setting:

```toml
[agents]
default_subagent_model = "gpt-6-astra"
default_subagent_reasoning_effort = "high"
```

Also append this sentence to the existing top-level `developer_instructions`
string, or create that string if it is absent:

> Before dispatching native subagents, a cross-family `claude -p` pass, or a Grok ACP pass, read
> `~/Development/developer-config/codex/model-defaults.md` and apply it unless
> an explicit user or per-dispatch model/reasoning choice overrides it.

The TOML values are mechanical defaults, not an effort floor. Before each
dispatch, the referenced card requires reading
`instructions/model-selection.md` and choosing the model and rung for that
task. Explicit spawn values override the defaults. This is an intentional
merge rather than a symlink because Codex owns and mutates the rest of
`config.toml` (plugins, trusted projects, MCP, and desktop state). Shared
model policy in `model-selection.md` applies to every harness;
`codex-delegation.md` covers external CLI callers.

**Grok Build** (`~/.grok/`) is a **full orchestrator**, like Claude Code: native
Grok 4.6 session, native `spawn_subagent` children (Grok 4.6 only — they cannot
be Claude or Codex), Codex implement via the existing Claude Code wrappers, and
Claude via `claude -p`. Grok does **not** expand `@import`, so there is no
`grok-root.md`. Home doctrine is `~/.grok/rules/*.md` (verbatim, every file;
later-alphabetical wins on conflict, which is why the links are numbered). That
set is principles, `dispatch-bootstrap.md`, and the Grok projection; it
deliberately omits `claude-conventions.md`, and model-selection and
codex-delegation are read on dispatch per the bootstrap rule, not linked.

Grok's TUI mutates `~/.grok/config.toml` (hints, UI, marketplace), so that file
is a documented merge rather than a symlink, same reason as Codex. Merge without
replacing unrelated settings:

```toml
[compat.claude]
skills = false
agents = false

[subagents.models]
explore = "grok-4.6"
plan = "grok-4.6"
general-purpose = "grok-4.6"
```

`skills = false` / `agents = false` stop Grok from ingesting Claude's
orchestration skills and the `@import` stub at `~/.claude/CLAUDE.md` (roughly
170 tokens of unexpanded imports — Grok would otherwise treat that as its
global doctrine). Keep `hooks` and `mcps` on the Claude compat defaults: the PreToolUse
hooks in `always/settings.json` invoke the same repo-path scripts, which accept
both Claude's snake_case envelope and Grok's camelCase one; Playwright MCP is
NOT in `~/.claude.json` (see "MCP servers load on demand" — Grok gets it only
through the same on-demand file). Convex is **not** that Claude plugin:
add `[mcp_servers.convex]` to this machine's `~/.grok/config.toml`
(`command = "npx"`, `args = ["-y", "convex@latest", "mcp", "start"]`), re-added
by hand per machine, same server Pi wires in `~/.pi/agent/mcp.json`. Never
check that block into the repo. Grok has no hook-ask, so the git
backstop's supervised ask-tier is a deny-with-reason under Grok (the model must
get conversational approval); `bypassPermissions` still skips that tier.

Grok skills *are* slash commands — there is no `always/commands/grok/` and no
`~/.grok/commands/` links. Shared skills come from `always/skills/` via
per-skill symlinks into `~/.grok/skills/`; the delivery six are Grok-owned
ports under `grok/skills/` (native `spawn_subagent` + Codex wrappers +
`claude -p`). A user skill named `execute-plan` overrides Grok's bundled
Graphite DAG `/execute-plan`; that shadow is intentional so `/execute-plan`
means the same delivery workflow as in the other harnesses. Bundled `/design`
and `/implement` stay.

Do not create `~/.grok/hooks/` copies of the Claude PreToolUse hooks — Grok
already loads them from `~/.claude/settings.json`, and a second registration
would double-fire.

**Pi** (`~/.pi/agent/`) is wired as a deliberately **lean coding agent**, not an
orchestrator. Its one global context file points at `principles.md` (same as
Codex). Pi differs from Claude Code in two ways that matter here — it injects
context files **verbatim** (no `@import` expansion, so the `claude-root.md`
pure-imports pattern does NOT work for it) and it loads only **one** global
context file. So Pi receives the universal root doctrine (`principles.md`) and
nothing is duplicated.

The full orchestrator doctrine (`coding-orchestration.md`, `codex-delegation.md`)
is deliberately NOT wired into Pi — most of it (Hermes `delegate_task`, Fable,
cron, PR-burndown) doesn't apply. Orchestration is handled by the
`@tintinweb/pi-subagents` package (declared in `pi/settings.json`), which spawns
sub-agents on any model in Pi's registry. Its hardcoded default agents are
disabled by `pi/subagents.json`; `pi/agents/*.md` supplies only role, tool, and
prompt-inheritance profiles, with no pinned model or thinking level. **Models
and thinking are specified at runtime in every fresh `Agent()` call** (resume
keeps the existing session model). `bash-timeout-guard.ts` — see contract
table.

Pi loads a lean, Pi-scoped distillation of the model-×-task table via
`~/.pi/agent/APPEND_SYSTEM.md` → `pi/model-defaults.md` (a separate system-prompt
slot, so `principles.md` / `AGENTS.md` stays clean and Codex never sees it). It
helps the orchestrator choose each explicit dispatch and is a labeled Pi-scope
of canonical `model-selection.md`; if the two conflict on a shared fact, the
canonical doc wins and both get updated. The same Pi file owns the exact
provider/model ID mapping: other harnesses may resolve a semantic family name
to its current model, but a native Pi `Agent` dispatch must use the mapped slug
rather than infer or guess a version. There is no `pi-root.md`, and custom agent
profiles never pin models.

Claude Code and Grok Build use the Codex wrappers under `always/scripts/` when
delegating Codex work (Grok invokes the same `~/.claude/scripts/` links; there
is no second Grok wrapper set). Pi instead uses native Tintin `Agent` subagents.
The wrappers are still on Pi's `PATH` through `~/.pi/agent/scripts`, but they
are not Pi's normal dispatch mechanism; add a purpose-built owner before making
Pi invoke them.

**Runtime-mutable keys in `pi/settings.json`:** because the file is
symlinked, Pi's `/model` and thinking toggles rewrite `defaultProvider`,
`defaultModel`, and `defaultThinkingLevel` in place — the versioned values are
cross-machine *initial* defaults, not a live policy to keep in sync. Diffs
limited to those keys (plus `lastChangelogVersion` and `theme`) are session
noise. **This drift is expected — do not "reconcile" it.** Dispatch policy is
independent and lives in `pi/model-defaults.md`. The repo owns `packages`.

Pi's consumption layer stays intentionally lean:
`~/.pi/agent/settings.json` → `pi/settings.json`,
`~/.pi/agent/subagents.json` → `pi/subagents.json`, role profiles under
`~/.pi/agent/agents/` → `pi/agents/`,
Pi-owned skills under `~/.pi/agent/skills/<f>` → `pi/skills/<f>`
(`agentplan`, `execute-plan`, `full-docs`, `longrun`, `rev`, `babysit`, plus `convex-mcp`),
and prompt entry points from `always/commands/{shared,pi}/`. It receives the
shared principles and clear-cut shared workflows. The delivery workflows are
Pi-native ports (Tintin `Agent` dispatch + Pi model card), not the Claude or
Codex orchestration implementations. Convex deployment access rides the
official Convex MCP server — a `convex` entry
(`npx -y convex@latest mcp start`) in machine-local `~/.pi/agent/mcp.json`,
merged under `mcpServers.convex` with `command: "npx"` and
`args: ["-y", "convex@latest", "mcp", "start"]`;
`pi/skills/convex-mcp` owns MCP policy (status
first, never production deployments). Code guidance is Convex's project skills
and `convex/_generated/ai/guidelines.md` — the installer owns `name: convex`. `~/.pi/agent/mcp.json` is never repo-owned: MCP entries carry
absolute paths in raw argv that no shell expands, so a checked-in copy cannot
be portable across machines. Only the Convex entry is checked by this contract;
unrelated MCP entries remain machine-owned. Optional `~/.pi/agent/models.json`
is machine-local custom provider configuration outside this contract.

Harness-neutral skills live once under `always/skills/<name>/SKILL.md` and are
per-skill symlinked into Claude, Codex, Pi, and Grok Build (never
whole-directory links — Codex owns `.system/` inside its skill root).
Orchestration workflows whose mechanisms genuinely differ live as complete,
stable copies under `claude/skills/`, `codex/skills/`, `pi/skills/`, and
`grok/skills/`. Claude uses the configured Codex wrappers and runs
Claude-native review; Codex uses native Astra subagents and `claude -p` for
cross-family review; Pi uses Tintin `Agent` subagents and the Pi model card;
Grok Build uses native Grok 4.6 `spawn_subagent` children, the same Codex
wrappers as Claude, and `claude -p` for Claude.

The intentional Claude/Codex/Pi/Grok delivery set is `agentplan`,
`execute-plan`, `full-docs`, `longrun`, `rev`, and `babysit`. They share outcomes and
safety invariants but not dispatch mechanics. When changing one harness copy,
an agent must inspect the counterparts and reconcile only the facts that
should remain aligned; do not mechanically make the files identical.
<!-- simplified: sibling parity across the five skill projections is by hand.
     upgrade when: a second delivery-skill commit lands in fewer than five
     projections (then a staged-diff sibling check in the gate). -->

`codex-branch-review` (which also covers a stated recent range, e.g. the last
48 hours), `codex-functionality-review`, and `codexclear` are Codex-only.
`convex-mcp` is owned under `pi/skills/convex-mcp` and linked into Pi and Grok
Build; the name `convex` is left to Convex's project installer. Claude uses
the official plugin instead.

### MCP servers load on demand

Claude Code spawns EVERY configured stdio MCP server at session start — user
scope (`~/.claude.json`), project scope (a repo's `.mcp.json` or the project
block in `~/.claude.json`), and every enabled plugin that ships an
`.mcp.json` — whether or not the session ever calls a tool on it. Deferred
tool schemas defer only the schema text, never the process. A server that
spawns its own child processes (Playwright launches a Chromium of 10–15 OS
processes per session that navigates) multiplies by the number of open
sessions; seven concurrent sessions with Playwright at user scope tripped
WSL's memory ceiling on 2026-09-08 and stalled the WSLg compositor.

The rule, for every MCP server on every machine:

1. **Nothing heavy at user scope.** User scope is for servers that are cheap
   to hold idle and wanted in most sessions. A server that launches a browser,
   a database engine, or another long-lived child is never registered there.
2. **Heavy servers are a per-session opt-in via `--mcp-config`.** The server
   definition lives in this repo under `always/mcp/<name>.json`, symlinked to
   `~/.claude/mcp/<name>.json`, and a shell alias starts the session that
   needs it (`claude-pw` for Playwright). A running session cannot gain a
   server afterward; start the right session. Definitions expand `$HOME`
   through `bash -c` so the checked-in file is portable across Mac and WSL —
   never an absolute `/home/<user>` path in argv.
3. **Project scope is for repo-bound servers that every session in that repo
   should hold** (Sentry, Next devtools, Convex). It still autostarts per
   session; if it is heavy, it belongs in rule 2 instead.
4. **Plugins that bundle an MCP server are enabled only where their server is
   wanted**; an enabled plugin autostarts its server like user scope does.
5. **One browser walk per machine at a time**, and it runs headless
   (`always/mcp/playwright-browser.json`). A headed window is a deliberate
   per-session choice for a human to watch: start the session with
   `claude-pw-headed`, which points `PLAYWRIGHT_MCP_BROWSER_CONFIG` at the
   headed options file. The server reads its options once at startup, so a
   running session cannot switch between headed and headless.

To bring a machine onto this: `claude mcp remove playwright -s user` if the
entry exists, create the three symlinks from the table, add the alias, and open
one `claude-pw` session so the MCP downloads its Chromium into
`~/.cache/ms-playwright`. Zed's Claude agent takes the same
`--mcp-config ~/.claude/mcp/playwright.json` in its launch args on machines
where a browser from Zed is wanted; that setting is machine-local.
`always/scripts/reap-orphan-mcp.sh` reaps orphaned Playwright MCP servers older than two hours; Codex workers are excluded.

### Skills — the shared workflow primitive

Claude Code, Codex, Pi, and Grok Build read the same `skills/<name>/SKILL.md`
format (YAML frontmatter `name` + `description`, then the body) from their home
skill directories. Codex may expose installed skills in its command picker and
also supports explicit `$skill-name` invocation; its older custom-prompt surface
is deprecated, so this repo does not maintain a second Codex prompt copy. Grok
Build treats each skill as a slash command; it has no separate commands
directory.

Canonical shared directories live under `always/skills/`; harness-specific
directories live under `claude/skills/`, `codex/skills/`, `pi/skills/`, and
`grok/skills/`. Each live skill path is a per-skill symlink to exactly one of
those owners.

The shared set is `code-simplifier`, `com`, `comall`, `design-taste-frontend`,
`docs`, `high-end-visual-design`, and `no-use-effect` — all seven linked into
Claude, Codex, Pi, and Grok Build. Keep this list current when adding a shared
skill: a skill nobody enumerates is a skill nobody links (`code-simplifier` sat
unlinked in every harness for exactly that reason).

For a workflow that is also a slash command or Pi prompt, the **`SKILL.md` is
canonical**. Shared command links target `always/skills/<name>/SKILL.md`;
Claude command links target `claude/skills/<name>/SKILL.md`; Pi command links
target `pi/skills/<name>/SKILL.md`. The command surfaces inject the YAML
frontmatter along with the body; that cosmetic preamble is preferable to a
second maintained prompt.

Skills can activate from a `description` match as well as explicit invocation.
Write the description as a functional, third-person summary, then name trigger
phrases and exclusions. Do not phrase it as an imperative to the agent. Keep it
narrow so it does not self-trigger mid-task.

Workflows that carry consequential intent include `agents/openai.yaml` with
`allow_implicit_invocation: false`; they remain visible for explicit selection
but cannot activate from conversational similarity. That is every skill under
`codex/skills/`, plus `com`, `comall`, `docs`, and `design-taste-frontend` from
`always/skills/`. Standing policies such as `no-use-effect` ship an
`agents/openai.yaml` carrying an `interface:` block and deliberately no
`policy:` block, so they stay implicitly discoverable; `code-simplifier` and
`high-end-visual-design` carry no `agents/` directory at all and are likewise
discoverable.

## Instruction hierarchy (who loads what)

```
claude-root.md                      the ~/.claude/CLAUDE.md loader — pure @imports of the
                                    three always-loaded Claude-side files below, holds no rules itself
instructions/principles.md          every agent, every repo  (Claude via claude-root import;
                                    Codex via ~/.codex/AGENTS.md; Grok via ~/.grok/rules/00-principles.md;
                                    Hermes references it directly)
instructions/claude-conventions.md  Claude Code only
instructions/dispatch-bootstrap.md  Claude Code + Grok Build always-loaded: hard delegation
                                    triggers, the read-on-dispatch rule,
                                    the External-calls default (none unless decided)
instructions/model-selection.md     canonical model profiles, harness seats, and effort —
                                    read on dispatch by Claude Code, Grok Build, and
                                    Codex (the latter via `codex/model-defaults.md`);
                                    Hermes links it
instructions/agent-guidance.md      reference, not auto-loaded
codex/model-defaults.md              Codex dispatch routing (native subagents,
                                     cross-family `claude -p`, Grok Build over ACP),
                                     loaded on dispatch
pi/model-defaults.md                 Pi dispatch projection, loaded via APPEND_SYSTEM.md
grok/model-defaults.md               Grok Build dispatch projection, loaded via
                                     ~/.grok/rules/30-model-defaults.md
hermes/model-defaults.md             Hermes seat row + recon notes (Claude via claude -p only)
instructions/rationale.md            incident and reasoning archive behind the loaded rules — not auto-loaded
instructions/codex-delegation.md    orchestrators only (Claude / Hermes / Grok Build) —
                                    Claude Code reads it on dispatch (not auto-loaded);
                                    Grok reads it on dispatch (not linked)
instructions/coding-orchestration.md Hermes farm doctrine — linked, not auto-loaded
instructions/worktrees.md            reference, not auto-loaded
instructions/opus5-quirks.md         Opus 5 prompting reference, not auto-loaded
instructions/token-efficiency.md     reference, not auto-loaded
```

Repo-level guidance is separate and inherited automatically: each repo keeps
`AGENTS.md` (content) + `CLAUDE.md` (`@AGENTS.md` import). Repo files hold only
repo-specific rules — never restate these globals (a repo restating a global is
a second owner; a deliberate override must be labeled as one).

## Verification (any agent, any machine, any time)

- Start with the read-only checker below. Pi startup, including `pi --help`,
  can install configured packages; use `PI_OFFLINE=1` for Pi diagnostics.
- [ ] `python3 always/scripts/check-wiring.py` exits 0.
      On Hermes installs, this includes `agentplan`, `execute-plan`, `rev`,
      `babysit`, `longrun`, and shared `docs` under `skills/software-development/`.
- [ ] `~/.codex/AGENTS.md` resolves to a file whose first line is `# Engineering principles`
- [ ] `~/.codex/config.toml` retains all machine-owned settings after merging.
- [ ] *If Grok Build is installed:* `grok --version` and `grok models` succeed under the machine-local Grok login.
- [ ] *If Pi is installed:* `~/.pi/agent/AGENTS.md` starts with `# Engineering principles`; role profiles under `~/.pi/agent/agents/` have no pinned model/thinking.
- [ ] *If Grok Build is installed:* `~/.grok/config.toml` retains all machine-owned settings after merging.
- [ ] *If Grok Build is installed:* a fresh `grok inspect` lists `00-principles.md`, `05-dispatch-bootstrap.md`, and `30-model-defaults.md` as loaded project instructions. `~/.claude/CLAUDE.md` if listed is tagged `[disabled]` (unexpanded `@import` stub).
- [ ] *If Grok Build is installed:* `grok inspect` labels the delivery six `user` from `~/.grok/skills`, not `user [claude]`, and lists an MCP server named `convex` from `~/.grok/config.toml`.
- [ ] A fresh `claude` session sees principles §1–§12, the Artifacts rule, AND the
      dispatch-bootstrap hard delegation triggers; `model-selection.md` and
      `codex-delegation.md` are NOT in its ambient context (read on dispatch only)
- [ ] *If Hermes is installed:* `~/.hermes/SOUL.md`'s principles block matches
      `principles.md` — `python3 ~/.hermes/scripts/sync-soul-principles.py`
      prints `already in sync`. Any other output means the block drifted (or
      was hand-edited) and has just been regenerated.
- [ ] `~/.hermes/state/` is writable *if present* — the Codex, Pi, and Claude wrappers
      `mkdir -p` it on first delegation, so the session registries land there on
      every machine (Hermes installed or not). Do NOT pre-create it as an empty
      dir; an empty `~/.hermes/` just reads as a stray Hermes install. Absent is
      compliant.
- [ ] `~/.claude/rules/` is empty or absent (the script covers the
      `~/.claude/CLAUDE.md` symlink itself, not this directory)

For changes to the wiring checker or executable safeguards, run their full
local verification battery (no model dispatch or package installation):

```bash
python3 always/scripts/test_check_wiring.py
python3 always/scripts/test_supervised_git_backstop.py
python3 always/scripts/test_grok_acp_exec.py
bash always/scripts/lib/test-codex-registry.sh
bun pi/tests/destructive-guard.test.ts
bun pi/tests/bash-timeout-guard.test.ts
```

Ask: "check SETUP.md compliance" — that's the whole drift audit.

## Machine notes

**Mac (Hermes host).** Hermes injects `~/.hermes/SOUL.md` as one verbatim file (no `@import`, same
limitation as Pi), so the shared principles cannot be linked in — they are
**embedded** between `<!-- PRINCIPLES:BEGIN -->` / `<!-- PRINCIPLES:END -->` by
`sync-soul-principles.py` (repo-owned at `hermes/scripts/`, linked to
`~/.hermes/scripts/` per the contract table), which nests the headings under
SOUL §5. That block is a mechanical derivative, not a second owner: **never
hand-edit it** — change `principles.md`, then re-run the script. Everything
outside the markers is Hermes-only (identity, hard constraints, autonomy
envelope) and the script leaves it untouched.

Two things make Hermes drift quietly, so re-check it whenever doctrine changes:
`~/.hermes/skills/` is otherwise gitignored (local/agent skills have no history);
the `/longrun` family is the exception — those five skills (`agentplan`,
`execute-plan`, `rev`, `babysit`, `longrun`) are owned here under `hermes/skills/`
and only *loaded* via symlink; `docs` loads from `always/skills/docs` alongside
them.
Hermes restating doctrine in other local skills is still drift — prefer a
pointer at this repo.
Model/effort policy: read `instructions/model-selection.md` "Harness seats",
"Roster", and "Effort" through `hermes/model-defaults.md` before dispatch.

**WSL.** Keep all clones on the Linux filesystem (`~/Development/...`), never
under `/mnt/c` — symlinks are unreliable on the Windows mount and git won't
preserve them. No Hermes install needed, and don't create `~/.hermes/` by hand
— the Codex wrappers `mkdir -p ~/.hermes/state/` lazily on the first delegation.

## Judgment-required extras (the old BOOTSTRAP.md scope)

- `packages/` — opt-in skill/agent bundles; ask which to install, then wire each
  into the directory matching what it ships (the only one today,
  `browser-walker`, declares an agent, so it belongs in `~/.claude/agents/`, not
  `~/.claude/skills/`). Skip anything an official marketplace plugin now
  covers — install the plugin instead of vendoring a stale copy. (Convex was
  removed for exactly this: use the `convex@claude-plugins-official` plugin,
  which supersedes the old vendored skills.)
- Repo permission grants are machine-local (`<repo>/.claude/settings.local.json`,
  re-created on demand); the root-level settings are canonical and permissive.
- `~/.claude-local/` — personal overlay, gitignored, layered on top if present.
