# Claude Code conventions

Rules that apply only to Claude Code sessions.

## Artifacts — ask, don't default

Don't auto-generate a claude.ai artifact; answers stay as terminal text (why: rationale.md#artifacts). ASCII or Mermaid sketches in plain answers need no ask. When a rendered visual is warranted (a mock, a dashboard, a diagram), first ask whether I want it rendered and whether it lives on claude.ai or as a file in the repo. Skip the ask only when I say "make an artifact", "render it" or "mock this up as a page", or ask to share a standalone page.

## Memory — ask before saving

Ask before writing anything to auto memory: say what you would save and why in
one line, and write it only on my yes. Memory is for how I want you to work and
pointers I would otherwise restate — never PR status, shipped work, pending-item
lists, or anything git, a PR, or the code can answer. A ruling about code goes
in the repo (a comment at the site, or `AGENTS.md` for a recurring trap).

## Edit tracked files with the Edit tool, never an in-place shell rewrite

A shell in-place rewrite of a tracked file (`sed -i`, `perl -pi`, `cp`/`mv`
over it, a heredoc script) is easily misread by Claude Code's removal check,
which stalls a subagent wherever the bypass approval hook is not running. Every
implementer brief restates it (why: rationale.md#tracked-file-edits).

Delete with plain `rm` and literal paths. A "rm guard: blocked" is final: never
reach the same target through a script, `find`, or another tool.

## Shell commands stay plain

One plain pipeline or a short `&&` chain per Bash call: no nested `$(…)`,
`( … )` subshell, backticks, `<(…)`, or `||` fallback that runs a second
pipeline. A command Claude Code cannot parse trips the same kind of prompt.
Multi-step logic goes in a scratch script created with the Write tool; a
deletion is always a plain, visible `rm <explicit path>`, never inside a
script. A command that check denies is rewritten, never retried. Every brief
restates it (why: rationale.md#plain-shell-commands).

## Report what you verified

Say which claims you verified and which you inferred (`model-selection.md` "Family tendencies").
