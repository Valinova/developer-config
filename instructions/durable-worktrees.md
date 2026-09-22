# Durable worktrees

Layout, naming, and reuse of long-lived `git worktree` checkouts; read before creating or repurposing one. Whether you may is owned by `git-operations.md` "Direction and approval".

**Scope: durable, human-facing worktrees** — the ones I work in across sessions. Agent-internal ephemeral worktrees (the Claude harness's `isolation: "worktree"`, Codex's own scratch space) are auto-created and auto-removed inside their harness's world; they are out of scope, leave them alone. Any interactive session (Claude, Codex, Pi) may manage durable worktrees with that authorization. Delegated CLI agents make no git writes, worktree management included; the invoking agent does all git operations (`codex-delegation.md` "Hard rules").

## Layout & naming

A durable worktree is a **sibling of its repo** — same parent directory — named `<repo-basename>-wtN`.

No absolute paths in this rule: it has to hold on macOS, WSL, and native Windows, where the parent directory differs. Derive it, never hardcode it:

```bash
git -C "$repo" worktree add "$(dirname "$repo")/$(basename "$repo")-wt1" <branch>
```

## A small fixed pool, repurposed

Keep **one or two** slots per repo and reuse them. Do not create a worktree per task and delete it after.

The directory name and the branch are independent. After obtaining authorization, derive the remote and base ref from the repo or PR before repurposing:

```bash
cd <repo>-wt1
git fetch <verified-remote>
git checkout -B <authorized-branch> <verified-base-ref>
```

- **Never task-name a slot.** The branch carries the task; the directory carries only the slot number.
- The slot must be **clean** before repurposing — that's the only cleanup this scheme asks for. A branch can't be checked out in two worktrees at once.
- Don't rename a slot per task (`git worktree move`); it invalidates a running session's cwd.
- Growing the pool past two is a decision to raise with me, not a default.

## Project-specific setup

Environment, backend, deployment, and port assignments belong in the repository's own instructions. Read those instructions before wiring or repurposing a worktree; this cross-project guide does not own them.

Do run the repo's install (`pnpm install`, `bun install`, …) in a new slot — several hooks and checks silently no-op without `node_modules`, which costs you the typecheck safety net.
