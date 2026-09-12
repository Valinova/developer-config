#!/usr/bin/env python3
"""Backstop for operations that destroy work or publish irreversibly.

Two tiers, because they answer different questions:

  DENY tier (all modes, incl. bypassPermissions)
      Bare force-push. A hook `deny` is a *block*, not a prompt, and
      bypassPermissions only skips prompts — so this is the one rule here
      that still bites in the mode long autonomous runs use.
      `--force-with-lease` passes: it is the form principles.md § 7
      mandates, and settings `deny` rules can't express "--force but not
      --force-with-lease" (deny rules carry no allowlist exceptions).

  ASK tier (supervised modes only — default / acceptEdits / plan)
      Operations that destroy uncommitted work with no reflog to recover
      from, and that a parallel agent on the same branch cannot see coming.

Deliberately NOT covered (trimmed 2026-07-28): checkout / switch / worktree
add / pull / merge / rebase / cherry-pick / reset / commit --amend /
branch -d / -m, and plain push. All are reflog-recoverable or already on
the `permissions.deny` floor, and all are things the user routinely directs —
prompting on them taxed directed work without protecting anything. The
governing rule is principles.md § 7: explicit direction IS the approval,
so this hook covers only what stays dangerous even when directed.

Matching is a regex over the raw command string — cruder than the native
permission parser, so quoted prose mentioning e.g. "git stash" can
false-positive. In supervised mode that costs one extra approval tap;
acceptable for a backstop.
"""

import json
import re
import shlex
import sys
import tempfile
from pathlib import Path

# Temp roots where recursive rm is routine (scratchpads, /tmp, macOS TMPDIR).
SCRATCH_ROOTS = tuple(Path(root).resolve() for root in ("/tmp", "/private/tmp", tempfile.gettempdir()))

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


RM_AT_COMMAND_POSITION = re.compile(CMD_POSITION + r"rm\s")


def recursive_rm_outside_scratch(command: str) -> bool:
    for segment in SEGMENT_SPLIT.split(command):
        match = RM_AT_COMMAND_POSITION.search(segment)
        if not match:
            continue
        try:
            args = shlex.split(segment[match.end():])
        except ValueError:
            return True  # Unresolved shell syntax cannot prove a scratch removal.
        separator = args.index("--") if "--" in args else len(args)
        options = args[:separator]
        flags = [a for a in options if a.startswith("-")]
        if not any(f == "--recursive" or re.fullmatch(r"-[a-zA-Z]*[rR][a-zA-Z]*", f) for f in flags):
            continue
        paths = [a for a in options if not a.startswith("-")] + args[separator + 1:]
        # Resolve traversal and symlinks before granting the temp exemption.
        if not paths:
            return True
        for path in paths:
            if not Path(path).is_absolute() or re.search(r"[\*?\[\]{}$`<>]", path):
                return True
            try:
                try:
                    resolved = Path(path).resolve(strict=True)
                except FileNotFoundError:
                    resolved = Path(path).resolve()
            except (OSError, RuntimeError):
                return True  # A symlink loop or inaccessible path is not proven safe.
            if not any(root in resolved.parents for root in SCRATCH_ROOTS):
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
            "session's push. Use --force-with-lease (principles.md § 7).",
            grok=grok,
        )

    # Ask tier — supervised modes only. bypassPermissions is the user's opt-in
    # for autonomous runs; the harness ignores hook `ask` there anyway, and
    # checking explicitly keeps the intent legible.
    if permission_mode == "bypassPermissions":
        sys.exit(0)

    for segment in SEGMENT_SPLIT.split(command):
        for matcher, reason in ASK_MATCHERS:
            if matcher.search(segment):
                respond("ask", reason, grok=grok)

    if recursive_rm_outside_scratch(command):
        respond("ask", "recursive rm outside /tmp and the scratchpad", grok=grok)

    sys.exit(0)


if __name__ == "__main__":
    main()
