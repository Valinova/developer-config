# Git operations

Owns how git, branch, worktree, and commit operations are run on every surface, including their permission rules; `principles.md` §7 points here.

## Direction and approval

- **Explicit direction IS the approval — don't re-ask for what I already named.** A directed sequence ("stage, commit, push, then switch to X") authorizes the whole sequence: execute it end to end and report. This includes the recoverable-destructive family when I name it — `branch -D`, `reset --hard`, `stash`, `clean -f`, `worktree remove`, `checkout -- <path>` — and a directed rebase of a pushed branch authorizes the `--force-with-lease` push that completes it (SHAs change, content doesn't). If a directed sequence needs an unnamed extra step (a stash, a rebase, a branch I didn't mention), do the named parts and ask about that one step only.
- **Undirected: the ask-first rules below apply.** Prefer the soft form: `reset --soft`/`--mixed` unless I said `--hard`; no stash I didn't name. When you ask, name the recovery path (reflog, `stash@{n}`, dangling blob) in the same line.
- I manage branches myself. Only branch, switch, commit, or push when I've explicitly directed it — being on the default branch is not a reason to branch first. When a change seems commit-ready and I haven't said to commit it, ask; don't act.
- **Branch switches and worktrees: ask first, every time.** My naming the exact branch or worktree IS the answer — the guard is against ones *you* chose. Directing implementation or a PR does **not** imply branch/worktree approval, and intent with a veto window ("say the word if…") is not approval. When work needs one I haven't named, ask **whether** to create it and wait for my reply; for a worktree, propose the path in the same ask. (why: rationale.md#branch-switches)
- **Branch names are the agent's to pick, never a question.** Once a branch is authorized, name it yourself. When I've directed Linear for the task and it's available, use the ticket's branch name from Linear. Otherwise `<type>/<short-kebab-slug>` describing the change (`fix/`, `feat/`, `docs/`, `chore/`). Never a harness or model prefix (`codex/`, `claude/`, `grok/`).
- **Remote operations: ask and verify first.** Before any push, remote URL/config change, or other remote-writing operation: state exactly what will run, confirm with me unless I directed that push (approval for one *undirected* operation does not roll forward), and verify the target (current branch, remote URL, ahead/behind vs base). Read-only remote ops (fetch, `gh pr view`) need no asking. (why: rationale.md#remote-ops)

## The mechanical floor

`always/scripts/supervised-git-backstop.py` is a PreToolUse hook in `always/settings.json`; its docstring and `test_supervised_git_backstop.py` own the design — run the test after touching the hook.

| Tier | Covers | Rule |
|---|---|---|
| **Deny** — every mode, including bypass | Bare force-push (`--force-with-lease` passes). The `permissions.deny` list beside it holds only the unrecoverable — `rm -rf` of a root, force-push or `push --delete` of the default branch — never reflog-recoverable ops. | Blocked outright. |
| **Directed** | `git stash`, `git restore`, `git checkout -- <path>`, `git clean -f`, `git worktree remove`, recursive `rm` outside temp roots — when I named it. | Done: answer the hook's prompt (it asks only in supervised modes) and move on. |
| **Undirected** | The same family when I did **not** name it. | Get my ok in conversation first, recovery path named — in every mode, especially bypass, where the ask tier is inert. |

## Commits

- Commit only the work that was asked for. Stage explicit file lists; never `git add -A` / `git add .`. Changes in the tree that you didn't produce stay uncommitted unless I explicitly name them — report them instead.
- One logical change per commit, split by concern (file-level is fine — no hunk-level splitting), each with a message saying what and why. Never lump unrelated changes into one commit.
- Single-concern PRs are the default; I may explicitly opt into a bundled multi-concern PR. In a bundle, the commit is the revert and review unit — one concern per commit, each independently green — and that discipline becomes mandatory.
- **Never alter commit author/committer identity or rewrite author history.** No `git config user.name`/`user.email`, no `--author`, no `filter-branch`/`rebase`/amend to change who authored a commit — unless I explicitly ask you to fix authorship. Commits use my configured identity as-is.
- **Worktree identity:** never `git config user.*` inside a worktree (it clobbers the shared `.git/config`). Scope any needed identity per-invocation (`git -c user.name=… -c user.email=… commit`), and after removing a scratch worktree, verify `git config user.email` still resolves correctly. (why: rationale.md#worktree-identity)

## Updating a branch: prefer rebase over merge

- Default to `git rebase origin/master` rather than merging the base in. (why: rationale.md#rebase-over-merge)
- Push rebased branches with `--force-with-lease` (never bare `--force`) so a parallel session's push is rejected instead of clobbered.
- Two exceptions where merge stays correct — state which one applies instead of rebasing silently:
  - The branch contains ANOTHER open PR's commits (stacked branches): rebasing rewrites that PR's history under its review. Merge, or consolidate the stack first.
  - Rewriting would orphan review anchors or in-flight CI on a branch others are actively working from.

## Enforcement scope: interactive vs autonomous

The ask-first rules above assume I'm present; conversational approval is the mechanism. Autonomous agents (Hermes, cron) enforce the **same invariants** mechanically via their own approval policy (see the agent's autonomy envelope, e.g. `~/.hermes/SOUL.md`). On every surface: never rewrite authorship, never bare force-push, stage explicit paths, never touch my parallel WIP, and **anything unrecoverable requires my approval**. A denial or timeout is never license to achieve the same effect by an alternate route.

## Durable worktrees

Layout, naming, and reuse of long-lived `git worktree` checkouts; read before creating or repurposing one. Whether you may is owned by "Direction and approval" above.

**Scope: durable, human-facing worktrees** — the ones I work in across sessions. Agent-internal ephemeral worktrees (the Claude harness's `isolation: "worktree"`, Codex's own scratch space) are auto-created and auto-removed inside their harness's world; they are out of scope, leave them alone. Any interactive session (Claude, Codex, Pi) may manage durable worktrees with the authorization above. Codex invoked via CLI cannot reliably stage, commit, or manage worktrees from its sandbox: expect it to leave edits unstaged, and the invoking agent does all git operations (`codex-delegation.md` Sandbox note).

### Layout & naming

A durable worktree is a **sibling of its repo** — same parent directory — named `<repo-basename>-wtN`.

No absolute paths in this rule: it has to hold on macOS, WSL, and native Windows, where the parent directory differs. Derive it, never hardcode it:

```bash
git -C "$repo" worktree add "$(dirname "$repo")/$(basename "$repo")-wt1" <branch>
```

Why: unambiguous when several repos share one parent (`acme-api-wt1` vs `acme-web-wt1`), sorts next to its repo in `ls`, generalizes to every repo.

### A small fixed pool, repurposed

Keep **one or two** slots per repo and reuse them. Do not create a worktree per task and delete it after — that churn is why they end up scattered and stale.

The directory name and the branch are independent. After obtaining the authorization above, derive the remote and base ref from the repo or PR before repurposing:

```bash
cd <repo>-wt1
git fetch <verified-remote>
git checkout -B <authorized-branch> <verified-base-ref>
```

- **Never task-name a slot.** The branch carries the task; the directory carries only the slot number. A dir named after a 3-week-old task is a slot nobody reuses.
- The slot must be **clean** before repurposing — that's the only cleanup this scheme asks for. A branch can't be checked out in two worktrees at once.
- `git worktree list` won't tell you what a slot is for; `git branch -vv` will.
- Renaming a slot per task (`git worktree move`) is possible but rejected: it's bookkeeping that gets dropped, and it invalidates a running session's cwd.
- Growing the pool past two is a decision to raise with me, not a default.

### Project-specific setup

Environment, backend, deployment, and port assignments belong in the repository's own instructions. Read those instructions before wiring or repurposing a worktree; this cross-project guide does not own them.

Do run the repo's install (`pnpm install`, `bun install`, …) in a new slot — several hooks and checks silently no-op without `node_modules`, which costs you the typecheck safety net.
