# Git operations

Owns how git, branch, worktree, and commit operations are run on every surface, including their permission rules; `principles.md` §7 points here.

## Direction and approval

- **Explicit direction IS the approval — don't re-ask for what I already named.** A directed sequence ("stage, commit, push, then switch to X") authorizes the whole sequence: execute it end to end and report. This includes the recoverable-destructive family when I name it — `branch -D`, `reset --hard`, `stash`, `clean -f`, `worktree remove`, `checkout -- <path>` — and a directed rebase of a pushed branch authorizes the `--force-with-lease` push that completes it (SHAs change, content doesn't). An authorized delivery task or workflow also permits necessary recoverable maintenance of its approved feature branch under the checks below. Ask only when an extra operation changes the authorized target/scope, affects my parallel work, or risks unrecoverable loss.
- **Undirected: the ask-first rules below apply.** Prefer the soft form: `reset --soft`/`--mixed` unless I said `--hard`; no stash I didn't name. When you ask, name the recovery path (reflog, `stash@{n}`, dangling blob) in the same line.
- **Commit and push only when directed.** When a change seems commit-ready and I haven't said to commit it, ask; don't act.
- **Branches follow the deliverable; worktrees only when I direct one.** A `longrun`, a PR, or a sequence of PRs I direct implies the branch each one needs: reuse its branch, or create one from its intended base and name it per the next bullet; return only from a switch you made. Without my direction nothing else moves the branch: no scratch branch to try an idea, no switch to look at something, no branch for a fix I did not ask for, and being on the default branch is not a reason to branch. Work happens in the worktree I'm in or the one I assign; a long-lived one follows `durable-worktrees.md`. A task that seems to need a branch or worktree outside this: ask whether, in one line. (why: rationale.md#branch-switches)
- **Branch names are the agent's to pick, never a question.** Once a branch is authorized, name it yourself. When I've directed Linear for the task and it's available, use the ticket's branch name from Linear. Otherwise `<type>/<short-kebab-slug>` describing the change (`fix/`, `feat/`, `docs/`, `chore/`). Never a harness or model prefix (`codex/`, `claude/`, `grok/`).
- **Remote operations: ask and verify first.** Before any push, remote URL/config change, or other remote-writing operation: state exactly what will run, confirm with me unless I directed that push (approval for one *undirected* operation does not roll forward), and verify the target (current branch, remote URL, ahead/behind vs base). Read-only remote ops (fetch, `gh pr view`) need no asking. (why: rationale.md#remote-ops)
- **CodeRabbit: the PR review is the record of the first round; the CLI reviews every later delta.** A PR in a repo with CodeRabbit auto-review gets its first review without anything added, and `babysit` waits for it. No later round waits for a PR review: the push re-triggers auto-review and a review that lands is triaged, but the round settles on CI plus one CLI pass over that round's commits (`--base <the head the PR review covered>`), never on a second PR review or a rate-limit window. When the FIRST review is rate limited, the diff's risk decides, and the report names the call: an involved or risky PR (an owner, a contract, money, auth, data writes, or a large diff) waits for the window and the PR review; any other PR gets one CLI pass instead; a trivial diff (a few lines, no owner, contract, or behaviour change, gate and suite green) gets neither and stands on its gate. The CLI also serves code no PR review will see yet: complex, unreviewed code before its first push, or a large implementation at a phase boundary (never per commit). Always `--deep` — without it the CLI runs a lighter policy than the PR review — and once over the diff under review:
  `coderabbit review --deep --committed --base <reviewed head, or origin/<default>> --agent -c ~/Development/developer-config/coderabbit/tests.path-instructions.yaml AGENTS.md`.
  Triage findings as PR findings; the repo's own gate still decides (why: rationale.md#coderabbit). A first push into an empty repo has no base to diff, so skip it and say so. No CLI: say so in the report.

## The mechanical floor

For Codex, command approval (`~/Development/developer-config/codex/permissions.md`) describes the native automatic
reviewer and `codex/command-safety.rules`, which hard-blocks the Deny tier's unrecoverable operations below in Codex's literal-prefix form;
everything else rests on the ask-when-unclear rules in this file. `approval_policy =
"never"` prevents review and must not be mistaken for missing task authority.

`always/scripts/supervised-git-backstop.py` is the Claude-compatible PreToolUse hook
in `always/settings.json`, not a Codex hook. Its docstring and
`test_supervised_git_backstop.py` own the design — run the test after touching it.

| Tier | Covers | Rule |
|---|---|---|
| **Deny** — every mode, including bypass | Bare force-push (`--force-with-lease` passes). The `permissions.deny` list beside it holds only the unrecoverable — `rm -rf` of a root, force-push or `push --delete` of the default branch — never reflog-recoverable ops. | Blocked outright. |
| **Directed** | `git stash`, `git restore`, `git checkout -- <path>`, `git clean -f`, `git worktree remove` — when I named it. | Done: answer the hook's prompt (it asks only in supervised modes) and move on. |
| **Undirected** | The same family when I did **not** name it. | Otherwise ask first and name the recovery path — in every mode, especially bypass, where the ask tier is inert; approved-task exceptions are defined under 'Updating a branch'. |

## Commits

- Commit only the work that was asked for. Stage explicit file lists; never `git add -A` / `git add .`. Changes in the tree that you didn't produce stay uncommitted unless I explicitly name them — report them instead.
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

## Durable worktrees

Before creating or repurposing a long-lived `git worktree` checkout, read `instructions/durable-worktrees.md` (layout, naming, reuse). Whether you may is owned by "Direction and approval" above.
