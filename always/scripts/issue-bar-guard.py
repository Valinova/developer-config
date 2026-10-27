#!/usr/bin/env python3
"""Require an observed, reachable, deletes or directed bar before filing.

principles.md §8 admission nudge (why: rationale.md#issue-bar): deny
`gh issue create` or a `gh api` write to an `/issues` endpoint without a
`Bar:` line. Re-sending with the line passes; no human approval or content
judgment. The answer stays in the issue for the reader to check.

Same envelope as foreground-dispatch-guard.py (Claude, Codex, Grok). Codex
loads it from codex/hooks.json after a one-time trust in `/hooks`.
"""

import json
import os
import re
import sys

# The line opens the body, so it follows a newline, a quote or `body=`.
BAR_LINE = re.compile(r"(?:^|[\n\"'=])\s*Bar:\s*(?:observed|reachable|deletes|directed)\s*[—–-]+\s*\S")

CMD_POSITION = r"(?:^|[;&|(]|\n)\s*(?:\S*/)?"
ISSUE_CREATE = re.compile(CMD_POSITION + r"gh\s+issue\s+create\b")
# A `gh api` segment naming an /issues collection with a write flag. Reads
# (`gh api repos/x/y/issues`) and comment writes (`/issues/12/comments`) pass.
API_ISSUES_WRITE = re.compile(
    CMD_POSITION
    + r"gh\s+api\b(?P<seg>[^\n;&|]*)"
)
API_WRITE_FLAG = re.compile(r"(?:^|\s)(?:-X\s*POST|--method[=\s]+POST|-[fF]\b|--(?:raw-)?field\b|--input\b)")
API_ISSUES_PATH = re.compile(r"/issues(?=[\"'\s]|$)")
BODY_FILE = re.compile(r"(?:--body-file|-F)[=\s]+[\"']?([^\s\"']+)")

SHELL_TOOLS = {"Bash", "bash", "run_terminal_command", "run_terminal_cmd"}

REASON = (
    "Issue bar (principles.md §8): observed, reachable, or deletes. "
    "Open the body with one line:\n"
    "  Bar: observed — <who saw it, the Sentry id, or the data count showing "
    "wrong output today>\n"
    "  Bar: reachable — <path> → <wrong outcome>\n"
    "  Bar: deletes — <what goes>\n"
    "  Bar: directed — <the user's request, quoted> (only when the user "
    "explicitly asked for this issue)\n"
    "A rule the code does not yet meet, a smarter lint, a tighter type, or a "
    "test rewrite is not filed: leave it in the "
    "report, or put a `simplified:` marker at its one site. Re-send with the "
    "line, or don't file."
)


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


def files_issue(command: str) -> bool:
    if ISSUE_CREATE.search(command):
        return True
    for match in API_ISSUES_WRITE.finditer(command):
        seg = match.group("seg")
        if API_ISSUES_PATH.search(seg) and API_WRITE_FLAG.search(seg):
            return True
    return False


def states_bar(command: str, cwd: str) -> bool:
    if BAR_LINE.search(command):
        return True
    for path in BODY_FILE.findall(command):
        if path == "-":
            continue
        full = os.path.join(cwd, os.path.expanduser(path))
        try:
            with open(full, encoding="utf-8", errors="replace") as handle:
                if BAR_LINE.search(handle.read()):
                    return True
        except OSError:
            continue
    return False


def main() -> None:
    data = json.load(sys.stdin)
    tool_name, tool_input, grok = envelope(data)
    if tool_name not in SHELL_TOOLS:
        sys.exit(0)
    command = tool_input.get("command", "")
    if files_issue(command) and not states_bar(command, data.get("cwd") or os.getcwd()):
        deny(REASON, grok=grok)
    sys.exit(0)


if __name__ == "__main__":
    main()
