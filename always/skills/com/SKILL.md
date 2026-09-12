---
name: com
description: Commits only the changes that are already staged, using the repository's commit conventions and required verification. Use only when the user explicitly invokes "com" or explicitly asks to commit the staged changes; never use it to infer commit authorization.
---

# Commit Staged Changes

1. Inspect the staged diff and current status.
2. Do not stage additional files or include unrelated work.
3. Run the repository's required pre-commit verification unless the same staged state has already passed it.
4. Commit the staged changes with a descriptive message grouped by functionality or file.
5. Follow commit-message conventions in the active project instructions. Otherwise, use a conventional prefix such as `fix:`, `feat:`, or `refactor:`.
6. Do not push unless the user explicitly requested it.
