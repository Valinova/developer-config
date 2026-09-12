# hermes

Hermes's consumption layer, owned here so it has history — the live
`~/.hermes/` is gitignored.

- `model-defaults.md` — pointer at harness seats in
  `instructions/model-selection.md` (Claude only through `claude -p`).
- `skills/` — the Hermes-owned `/longrun` family (`agentplan`, `execute-plan`,
  `rev`, `babysit`, `longrun`), same names as `claude/`, `pi/`, and `codex/`. The
  harness-neutral `docs` skill is shared from `always/skills/docs`, not copied.

Live path: `~/.hermes/skills/software-development/<name>`, symlinked per SETUP.md.
