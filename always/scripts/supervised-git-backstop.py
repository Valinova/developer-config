#!/usr/bin/env python3
"""Backstop for operations that destroy work or publish irreversibly.

Two tiers, because they answer different questions:

  DENY tier (all modes, incl. bypassPermissions)
      What cannot be undone and is never wanted unattended: bare force-push
      or deletion of a remote default branch, root rm, typed ways around the
      rm guard (always/scripts/rm, which owns the core-path list), disk
      erasure, and wholesale remote wipes. A hook `deny` is a *block*, not a
      prompt, and bypassPermissions only skips prompts — so this tier still
      bites in the mode long autonomous runs use.
      `--force-with-lease` passes: it is the form git-operations.md
      mandates, and settings `deny` rules can't express "--force but not
      --force-with-lease" (deny rules carry no allowlist exceptions).

  ASK tier (supervised modes only — default / acceptEdits / plan)
      Operations that destroy uncommitted work with no reflog to recover
      from, and that a parallel agent on the same branch cannot see coming.

Deliberately NOT covered (trimmed 2026-07-28): checkout / switch / worktree
add / pull / merge / rebase / cherry-pick / reset / commit --amend /
branch -d / -m, plain push, and recursive rm outside the rm guard's core
paths. All are recoverable or disposable, and all are things the user
routinely directs — prompting on them taxed directed work without protecting
anything. The governing rule is git-operations.md: explicit direction IS the approval,
so this hook covers only what stays dangerous even when directed.

Matching is a regex over the raw command string — cruder than the native
permission parser, so quoted prose mentioning e.g. "git stash" can
false-positive. In supervised mode that costs one extra approval tap;
acceptable for a backstop.
"""

import json
import os
import pathlib
import re
import shlex
import subprocess
import sys

SEGMENT_SPLIT = re.compile(r"[;&|]|\n")

# A bare `\bgit push\b` over the raw string also fires on commands that merely
# MENTION one — `grep "git push" …`, a test harness, an edit to these very
# docs. Tolerable for an ask; unacceptable for the deny tier, which can't be
# overridden. So every matcher here requires the verb at a command position:
# start of a segment, after optional VAR=val assignments and any path prefix.
CMD_POSITION = r"^\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*(?:\S*/)?"

# Git global options occur before the subcommand, including routine `git -C`.
GIT_COMMAND = (
    r"git\s+(?:(?:(?:-C|-c|--git-dir|--work-tree|--namespace)\s+\S+"
    r"|--[\w-]+(?:=\S+)?|-C\S+|-c\S+)\s+)*"
)
GIT_PUSH = re.compile(CMD_POSITION + GIT_COMMAND + r"push\b")
# `--force` not continuing into `--force-with-lease`, short flags containing `f`,
# or a `+refspec` (the third way to force, easy to forget).
FORCE_FORMS = re.compile(
    r"(?:^|\s)(?:--force(?!-with-lease)|-[A-Za-z]*f[A-Za-z]*)(?=\s|$)"
    r"|(?:^|\s)\+[^\s]+"
)

# Tools usually launched through a runner: `npx convex`, `doppler run -- supabase`.
RUNNER = (
    CMD_POSITION
    + r"(?:(?:npx|pnpm|bunx|bun|yarn|npm|doppler|env|time|nohup|command)\b.*?\s)?(?:\S*/)?"
)
DENY_PATTERNS = [
    (
        r"^\s*git\s.*\bpush\b.*(?:\s(?:--delete|-d)\b.*\s|\s:)(?:refs/heads/)?(?:main|master)(?=\s|$)",
        "Deleting the remote default branch is never allowed.",
    ),
    (
        CMD_POSITION + r"rm\s+(?:-\S+\s+)+[\"']?(?:/|~|\$\{?HOME\}?|\.\.)/?\*?[\"']?(?=\s|$)",
        "Never delete the filesystem root, the home directory or the parent directory.",
    ),
    (
        CMD_POSITION + r"sudo\s(?:.*\s)?(?:\S*/)?rm(?=\s|$)",
        "sudo rm skips the rm guard.",
    ),
    (
        RUNNER + r"(?:sudo\s+)?diskutil\s+(?i:erase|reformat|partitiondisk|zerodisk|randomdisk|secureerase|apfs\s+(?:delete|erase))",
        "Erasing a disk or volume is never allowed.",
    ),
    (
        CMD_POSITION + r"(?:sudo\s+)?(?:dd\s(?:.*\s)?of=/dev/r?(?:disk|sd|nvme)|(?:mkfs|newfs)(?:[._]\w+)?\s)",
        "Writing over a disk device is never allowed.",
    ),
    (RUNNER + r"gh\s+repo\s+delete\b", "Deleting a GitHub repository is never allowed."),
    (
        RUNNER + r"supabase(?:@\S+)?\s+db\s+reset\b.*\s--(?:linked|db-url)\b",
        "Resetting a remote database is never allowed.",
    ),
    (
        RUNNER + r"convex(?:@\S+)?\s+import\b(?=.*\s--replace)(?=.*\s--prod\b)",
        "Replacing production Convex data is never allowed.",
    ),
]
ABSOLUTE_RM = re.compile(
    r"^\s*(?:\w+=\S*\s+)*(?:(?:command|time|nohup|env)\s+)*(?:/usr)?/bin/rm\s"
)
DENY_MATCHERS = [(re.compile(p), reason) for p, reason in DENY_PATTERNS]

DENY_ADVICE = (
    " Do not retry another way; if it is truly wanted, tell the user the exact "
    "command to run outside the agent."
)
RM_GUARD = pathlib.Path(__file__).with_name("rm")
FIND_DELETE = re.compile(CMD_POSITION + r"find\s.*\s-delete(?=\s|$)")
# Any other find predicate narrows the match, so it is not a whole-directory delete.
FIND_UNFILTERED = {"-delete", "-depth", "-d", "-x", "-xdev", "-print", "-mindepth", "-maxdepth", "-type"}

ASK_PATTERNS = [
    (
        GIT_COMMAND + r"stash\b",
        "git stash empties the working tree — invisible to a parallel agent "
        "whose uncommitted work just vanished (principles.md § 3)",
    ),
    (
        GIT_COMMAND + r"restore\b",
        "git restore discards uncommitted work; there is no reflog for "
        "content that was never committed",
    ),
    (
        GIT_COMMAND + r"checkout\b.*\s--\s",
        "git checkout -- <path> discards uncommitted work; no reflog covers it",
    ),
    (
        GIT_COMMAND + r"clean\b.*\s(?:-[a-zA-Z]*f|--force\b)",
        "git clean -f deletes untracked files outright — unrecoverable",
    ),
    (
        GIT_COMMAND + r"worktree\s+remove\b",
        "git worktree remove can discard uncommitted work in that worktree",
    ),
]
ASK_MATCHERS = [(re.compile(CMD_POSITION + p), reason) for p, reason in ASK_PATTERNS]


# Claude Code: tool_name / tool_input / permission_mode (snake_case).
# Grok Build: toolName / toolInput / permissionMode (camelCase); shell tool is
# run_terminal_command (matcher "Bash" still fires via Grok's alias).
SHELL_TOOLS = {"Bash", "bash", "run_terminal_command", "run_terminal_cmd"}


def envelope(data: dict) -> tuple[str, str, dict, bool]:
    grok = "toolName" in data or "toolInput" in data
    if grok:
        return (
            data.get("toolName") or "",
            data.get("permissionMode") or "",
            data.get("toolInput") or {},
            True,
        )
    return (
        data.get("tool_name") or "",
        data.get("permission_mode") or "",
        data.get("tool_input") or {},
        False,
    )


def respond(decision: str, reason: str, *, grok: bool = False) -> None:
    # Claude reads hookSpecificOutput.permissionDecision. Grok reads top-level
    # decision and has no hook-ask: supervised ask-tier becomes deny there so
    # the model must get conversational approval (bypass still skips ask-tier).
    grok_decision = "deny" if grok and decision == "ask" else decision
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": grok_decision if grok else decision,
            "permissionDecisionReason": reason,
        }
    }
    if grok:
        payload["decision"] = grok_decision
        payload["reason"] = reason
    print(json.dumps(payload))
    sys.exit(0)


def forced_push(command: str) -> bool:
    for segment in SEGMENT_SPLIT.split(command):
        if GIT_PUSH.search(segment) and FORCE_FORMS.search(segment):
            return True
    return False


def core_find_delete(command: str, cwd: str) -> bool:
    for segment in SEGMENT_SPLIT.split(command):
        if not FIND_DELETE.search(segment):
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            continue
        args = tokens[next(i for i, t in enumerate(tokens) if t.split("/")[-1] == "find") + 1:]
        split = next((i for i, t in enumerate(args) if t[0:1] in "-(!"), len(args))
        roots, tests = args[:split], args[split:]
        if any(t.startswith(("-", "(", "!")) and t not in FIND_UNFILTERED for t in tests):
            continue
        paths = [os.path.expanduser(os.path.expandvars(r)) for r in roots] or ["."]
        check = subprocess.run(
            [str(RM_GUARD), "--guard-check", "--", *paths],
            cwd=cwd if os.path.isdir(cwd) else None,
            capture_output=True,
        )
        if check.returncode != 0:
            return True
    return False


def main() -> None:
    data = json.load(sys.stdin)
    tool_name, permission_mode, tool_input, grok = envelope(data)

    if tool_name not in SHELL_TOOLS:
        sys.exit(0)

    command = tool_input.get("command", "")

    # Deny tier — evaluated before the bypass check, on purpose.
    if forced_push(command):
        respond(
            "deny",
            "Bare force-push is never allowed: it can clobber a parallel "
            "session's push. Use --force-with-lease (git-operations.md).",
            grok=grok,
        )

    for segment in SEGMENT_SPLIT.split(command):
        for matcher, reason in DENY_MATCHERS:
            if matcher.search(segment):
                respond("deny", reason + DENY_ADVICE, grok=grok)
        if ABSOLUTE_RM.search(segment):
            respond("deny", "/bin/rm skips the rm guard; use plain `rm`, which it checks.", grok=grok)
    if core_find_delete(command, data.get("cwd") or ""):
        respond("deny", "find -delete on a core path is never allowed." + DENY_ADVICE, grok=grok)

    # Ask tier — supervised modes only. bypassPermissions is the user's opt-in
    # for autonomous runs; the harness ignores hook `ask` there anyway, and
    # checking explicitly keeps the intent legible.
    if permission_mode == "bypassPermissions":
        sys.exit(0)

    for segment in SEGMENT_SPLIT.split(command):
        for matcher, reason in ASK_MATCHERS:
            if matcher.search(segment):
                respond("ask", reason, grok=grok)

    sys.exit(0)


if __name__ == "__main__":
    main()
