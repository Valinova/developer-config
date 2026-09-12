#!/usr/bin/env python3
"""Deny agent-dispatch wrappers run in foreground Bash calls.

Foreground Bash tool calls have a hard timeout; on expiry the harness
SIGTERMs the whole process group. codex-exec.sh / codex-resume.sh (and the
pi twins and claude-exec.sh) have a pre-detach window (registry write + health check) during
which that SIGTERM kills the freshly dispatched run (real incidents:
2026-07-16 killed a run ~1min in; 2026-07-22 a chained dispatch survived
only because codex had already detached). The standing rule in
instructions/codex-delegation.md — dispatch wrappers (and any chained wait)
run in their own run_in_background Bash call — is enforced here
deterministically.

Unlike supervised-git-backstop.py this emits "deny", not "ask": it guards a
correctness bug, so it applies in every permission mode including
bypassPermissions (hook denies are honored in bypass; asks are not).

A wrapper-side fix was tried and reverted (set -m own-process-group killed
the job and hung the wrapper, 2026-07-16) — do not move this check into the
wrappers.

Matching requires the wrapper name at a command position (start of string,
or after ; | & ( or newline), so prose mentions and `grep codex-exec.sh ...`
don't trip it. codex-wait.sh alone is deliberately not guarded: killing a
wait only loses the notification; the detached worker is unharmed.

Background calls are guarded too, differently (2026-07-27 incident: a
background `codex-exec.sh ... && codex-wait.sh ...` task was stopped
mid-wait; the stop SIGKILLed the process group while the dispatching shell
was still alive as the worker's ancestor, killing the codex run ~18min in).
In a run_in_background call the dispatch must be the FINAL command — the
shell must exit right after the wrapper returns so a later stop has no
group to kill. Attach codex-wait.sh in a separate Bash call.
"""

import json
import re
import sys

DISPATCH_AT_COMMAND_POSITION = re.compile(
    r"(?:^|[;&|(]|\n)\s*\S*(?:(?:codex|pi)-(?:exec|resume)|claude-exec)\.sh\b"
)

# Anything after the dispatch invocation that starts another command keeps the
# dispatching shell alive as the worker's ancestor: `;`, `&`, `|`, or a
# newline followed by a non-blank line. Trailing whitespace is fine.
COMMAND_AFTER_DISPATCH = re.compile(r"[;&|]|\n\s*\S")


SHELL_TOOLS = {"Bash", "bash", "run_terminal_command", "run_terminal_cmd"}


def envelope(data: dict) -> tuple[str, dict, bool]:
    grok = "toolName" in data or "toolInput" in data
    if grok:
        return data.get("toolName") or "", data.get("toolInput") or {}, True
    return data.get("tool_name") or "", data.get("tool_input") or {}, False


def deny(reason: str, *, grok: bool = False) -> None:
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }
    if grok:
        payload["decision"] = "deny"
        payload["reason"] = reason
    print(json.dumps(payload))
    sys.exit(0)


def main() -> None:
    data = json.load(sys.stdin)
    tool_name, tool_input, grok = envelope(data)

    if tool_name not in SHELL_TOOLS:
        sys.exit(0)

    command = tool_input.get("command", "")
    match = DISPATCH_AT_COMMAND_POSITION.search(command)
    background = (
        tool_input.get("run_in_background") is True
        or tool_input.get("background") is True
    )

    if background:
        if match and COMMAND_AFTER_DISPATCH.search(command[match.end():]):
            deny(
                "In a run_in_background / background Bash call, the codex/pi/"
                "claude dispatch wrapper must be the FINAL command — nothing "
                "chained after it (no *-wait.sh, no `&&`, `;`, `|`). A stopped "
                "background task kills its process group; if the dispatching "
                "shell is still alive (e.g. waiting), the detached worker dies "
                "with it (2026-07-27 incident). Dispatch alone, then attach "
                "codex-wait.sh in a SEPARATE Bash call.",
                grok=grok,
            )
        sys.exit(0)

    if match:
        deny(
            "codex-exec.sh / codex-resume.sh / pi-exec.sh / pi-resume.sh / "
            "claude-exec.sh must run "
            "in their own background shell call (Claude: run_in_background:true; "
            "Grok: background:true) — never in a foreground call: the foreground "
            "timeout SIGTERMs the process group and can kill the dispatch in its "
            "pre-detach window. Re-issue as a background call with the dispatch "
            "as the final command, and attach codex-wait.sh in a SEPARATE call.",
            grok=grok,
        )

    sys.exit(0)


if __name__ == "__main__":
    main()
