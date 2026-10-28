#!/usr/bin/env python3
"""Require an observed, reachable, deletes or directed bar before filing.

principles.md §8 admission nudge (why: rationale.md#issue-bar): deny
`gh issue create` or a `gh api` write to an `/issues` endpoint unless the
command carries a `BAR_CHECKED=<kind>` assignment. Re-sending with it passes;
no human approval or content judgment. The bar is an internal check: the
answer stays in the command transcript, never in the issue body.

Same envelope as foreground-dispatch-guard.py (Claude, Codex, Grok). Codex
loads it from codex/hooks.json after a one-time trust in `/hooks`.
"""

import json
import re
import sys

BAR_MARK = re.compile(r"(?:^|[\s;&|(])BAR_CHECKED=(?:observed|reachable|deletes|directed)(?=\s)")

# Leading `NAME=value` assignments still put `gh` in command position.
CMD_POSITION = r"(?:^|[;&|(]|\n)\s*(?:\w+=\S*\s+)*(?:\S*/)?"
ISSUE_CREATE = re.compile(CMD_POSITION + r"gh\s+issue\s+create\b")
# A `gh api` segment naming an /issues collection with a write flag. Reads
# (`gh api repos/x/y/issues`) and comment writes (`/issues/12/comments`) pass.
API_ISSUES_WRITE = re.compile(
    CMD_POSITION
    + r"gh\s+api\b(?P<seg>[^\n;&|]*)"
)
API_WRITE_FLAG = re.compile(r"(?:^|\s)(?:-X\s*POST|--method[=\s]+POST|-[fF]\b|--(?:raw-)?field\b|--input\b)")
API_ISSUES_PATH = re.compile(r"/issues(?=[\"'\s]|$)")

SHELL_TOOLS = {"Bash", "bash", "run_terminal_command", "run_terminal_cmd"}

REASON = (
    "Issue bar (principles.md §8): before filing, check that it is observed "
    "(a user saw it, Sentry fired, or a data count shows wrong output today), "
    "reachable (<path> → <wrong outcome>), deletes (<what goes>), or directed "
    "(the user explicitly asked for this issue). A rule the code does not yet "
    "meet, a smarter lint, a tighter type, or a test rewrite is not filed: "
    "leave it in the report, or put a `simplified:` marker at its one site. "
    "If it passes, re-send prefixed with BAR_CHECKED=<observed|reachable|"
    "deletes|directed>; never write the bar into the issue body."
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


def main() -> None:
    data = json.load(sys.stdin)
    tool_name, tool_input, grok = envelope(data)
    if tool_name not in SHELL_TOOLS:
        sys.exit(0)
    command = tool_input.get("command", "")
    if files_issue(command) and not BAR_MARK.search(command):
        deny(REASON, grok=grok)
    sys.exit(0)


if __name__ == "__main__":
    main()
