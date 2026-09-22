---
name: comall
description: Commits everything currently in the worktree — staged, unstaged, and untracked — split into coherent groupings with descriptive messages. Use only when the user explicitly invokes "comall" or explicitly asks to commit all current changes; never use it to infer commit authorization.
---

# Commit All Worktree Changes

Invoking this command authorizes committing every change currently in the
worktree. Flag anything that looks unintended — secrets, scratch files,
unrelated parallel WIP — before including it, instead of committing blindly.

1. Inspect the full picture first: staged, unstaged, and untracked.
2. Split the changes into coherent groupings per `git-operations.md`
   "Commits"; when one file mixes concerns, put it in the most fitting commit
   and move on.
3. Run the repository's required pre-commit verification before the first
   commit.
4. Give every commit a descriptive message: a subject saying what changed and
   where, plus a short body saying why — enough for `git blame` and history
   archaeology to stand alone. Never a bare "update", "fixes", or "wip".
   Follow the project's conventions; otherwise match this shape:

   ```
   codex-status: follow the resume log when it is fresher

   The resume wrapper logs to <task>-resume.log while the original log
   goes quiet; triage now tracks whichever was written most recently.
   ```

5. Do not push unless the user explicitly requested it.
