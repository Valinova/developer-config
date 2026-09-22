# hermes

Hermes's consumption layer, owned here so it has history — the live
`~/.hermes/` is gitignored.

- `model-defaults.md` — Hermes dispatch mechanics (Claude only through
  `claude -p`); the roster is `instructions/model-selection.md`.
- `skills/` — the Hermes-owned `/longrun` family (`agentplan`, `execute-plan`,
  `rev`, `babysit`, `longrun`), same names as `claude/`, `pi/`, `codex/`, and
  `grok/`. The harness-neutral `docs` skill is shared from `always/skills/docs`, not copied.

Live path: `~/.hermes/skills/software-development/<name>`, symlinked per SETUP.md.
