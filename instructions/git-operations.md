# Git operations

Owns how git, branch, worktree, and commit operations are run on every surface, including their permission rules; `principles.md` §7 points here.

## Direction and approval

- **Explicit direction IS the approval — don't re-ask for what I already named.** A directed sequence ("stage, commit, push, then switch to X") authorizes the whole sequence: execute it end to end and report. This includes the recoverable-destructive family when I name it — `branch -D`, `reset --hard`, `stash`, `clean -f`, `worktree remove`, `checkout -- <path>` — and a directed rebase of a pushed branch authorizes the `--force-with-lease` push that completes it (SHAs change, content doesn't). An authorized delivery task or workflow also permits necessary recoverable maintenance of its approved feature branch under the checks below. Ask only when an extra operation changes the authorized target/scope, affects my parallel work, or risks unrecoverable loss.
- **Undirected: the ask-first rules below apply.** Prefer the soft form: `reset --soft`/`--mixed` unless I said `--hard`; no stash I didn't name. When you ask, name the recovery path (reflog, `stash@{n}`, dangling blob) in the same line.
- **Commit and push only when directed.** When a change seems commit-ready and I haven't said to commit it, ask; don't act.
- **Branches follow the deliverable; worktrees only when I direct one.** A `longrun`, a PR, or a sequence of PRs I direct implies the branch each one needs: reuse its branch, or create one from its intended base and name it per the next bullet; return only from a switch you made. Without my direction nothing else moves the branch: no scratch branch to try an idea, no switch to look at something, no branch for a fix I did not ask for, and being on the default branch is not a reason to branch. Work happens in the worktree I'm in or the one I assign; a long-lived one follows `durable-worktrees.md`. A task that seems to need a branch or worktree outside this: ask whether, in one line. (why: rationale.md#branch-switches)
- **Branch names are the agent's to pick, never a question.** Once a branch is authorized, name it yourself. When I've directed Linear for the task and it's available, use the ticket's branch name from Linear. Otherwise `<type>/<short-kebab-slug>` describing the change (`fix/`, `feat/`, `docs/`, `chore/`). Never a harness or model prefix (`codex/`, `claude/`, `grok/`).
- **Remote operations: ask and verify first.** Before any push, remote URL/config change, or other remote-writing operation: state exactly what will run, confirm with me unless I directed that push (approval for one *undirected* operation does not roll forward), and verify the target (current branch, remote URL, ahead/behind vs base). Read-only remote ops (fetch, `gh pr view`) need no asking. (why: rationale.md#remote-ops)
- **CodeRabbit: PR review is primary, one round on the opening push.** A second review needs my yes. Read `~/Development/developer-config/coderabbit/README.md` before proposing one, running the CLI, or handling a rate-limited PR review.

## The mechanical floor

For Codex, command approval (`~/Development/developer-config/codex/permissions.md`) describes the native automatic
reviewer and `codex/command-safety.rules`, which hard-blocks the unrecoverable operations below in Codex's literal-prefix form;
everything else rests on the ask-when-unclear rules in this file. `approval_policy =
"never"` prevents review and must not be mistaken for missing task authority.

`always/scripts/supervised-git-backstop.py` is the Claude-compatible PreToolUse hook
in `always/settings.json`, not a Codex hook. Its docstring and
`test_supervised_git_backstop.py` own the design — run the test after touching it.

Blocked in every mode, including bypass: bare force-push (`--force-with-lease` passes), and the `permissions.deny` list, which holds only the unrecoverable (`rm -rf` of a root, force-push or `push --delete` of the default branch). `git stash`, `restore`, `checkout -- <path>`, `clean -f` and `worktree remove` follow "Direction and approval": done when I named them, otherwise ask first and name the recovery path, especially in bypass, where the hook's ask is inert; approved-task exceptions are under "Updating a branch".

## Commits

- Commit only the work that was asked for, including pre-existing changes when I say "commit all". Stage explicit file lists; never `git add -A` / `git add .`. Report other pre-existing changes and leave them uncommitted. Commits are recoverable and revertible.
- One logical change per commit, split by concern (file-level is fine — no hunk-level splitting), each with a message saying what and why. Never lump unrelated changes into one commit.
- Single-concern PRs are the default; I may explicitly opt into a bundled multi-concern PR. In a bundle, the commit is the revert and review unit — one concern per commit, each independently green — and that discipline becomes mandatory.
- **Never alter commit author/committer identity or rewrite author history.** No `git config user.name`/`user.email`, no `--author`, no `filter-branch`/`rebase`/amend to change who authored a commit — unless I explicitly ask you to fix authorship. Commits use my configured identity as-is.
- **Worktree identity:** never `git config user.*` inside a worktree (it clobbers the shared `.git/config`). When I explicitly authorize an identity change, scope it per-invocation (`git -c user.name=… -c user.email=… commit`), and after removing a scratch worktree, verify `git config user.email` still resolves correctly. (why: rationale.md#worktree-identity)

## Updating a branch: prefer rebase over merge

- **Check, then proceed within the approved task.** Before a rebase or reset, inspect status (including staged/untracked files), the branch/upstream, and the commits or paths affected. Establish ownership from the task's initial snapshot; unknown work is mine. Record the original HEAD and a usable recovery path. Proceed with a clean feature-branch rebase or a soft/mixed reset that preserves task-owned work; no repeat conversational approval is needed. Verify the resulting diff and the project's required checks afterward.
- **Discarding files needs stronger evidence.** A hard reset, restore, clean or worktree removal may lose content that reflog cannot recover. Proceed autonomously only when the task already authorizes the operation and everything discarded is proven task-owned disposable work or has a verified independent backup. Preview exact paths first (`git clean -n` for clean). Otherwise ask for explicit approval of the target and loss. Never stash, unstage or discard my parallel WIP to make the tree clean.
- Default to rebasing onto the repo's base branch (derive it — e.g. `git rebase origin/main` — never hardcode it) rather than merging the base in. (why: rationale.md#rebase-over-merge)
- Push rebased branches with `--force-with-lease` (never bare `--force`) so a parallel session's push is rejected instead of clobbered.
- Two exceptions where merge stays correct — state which one applies instead of rebasing silently:
  - The branch contains ANOTHER open PR's commits (stacked branches): rebasing rewrites that PR's history under its review. Merge, or consolidate the stack first.
  - Rewriting would orphan review anchors or in-flight CI on a branch others are actively working from.

## Parallel WIP

I often work in parallel in the same worktree; `principles.md` §3 states the rule (uncommitted changes that don't trace to your task are mine). The mechanics:

- **Snapshot before delegating.** Before dispatching any subagent that can touch the worktree, record `git status --porcelain` + `git diff HEAD --stat` in the session scratchpad. Everything pre-dispatch is mine; only deltas beyond it are the agent's.
- **Provenance check before any revert.** Before `git restore` / `git checkout --` / unstaging anything, diff against the snapshot. No snapshot: assume it's mine and ask.
- If you discard something by mistake, attempt recovery before reporting it lost: staged content usually survives as an unreachable blob (`git fsck --unreachable`, or the blob hash from a diff header you printed).

## Enforcement scope: interactive vs autonomous

The ask-first rules above assume I'm present; conversational approval is the mechanism. Autonomous agents (Hermes, cron) enforce the **same invariants** mechanically via their own approval policy (see the agent's autonomy envelope, e.g. `~/.hermes/SOUL.md`). A denial or timeout is never license to achieve the same effect by an alternate route.
