#!/usr/bin/env python3
"""Answer the Bash prompts Claude Code still shows in bypassPermissions.

Its removal check asks whenever it cannot parse a command, and the hook input
does not say why it asked, so this approves them all. That is safe only while
the rm guard (always/scripts/rm) decides what may be deleted: without its link
the prompt stands. Deny rules and PreToolUse denies run first and still block;
an explicit `ask` rule for Bash would be approved too.

Not CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS: Claude Code ignores it
wherever any Bash deny or ask rule exists, and repos rely on theirs.
"""

import json
import pathlib
import sys

GUARD = pathlib.Path(__file__).with_name("rm")
LINK = pathlib.Path.home() / ".claude/scripts/rm"

data = json.load(sys.stdin)
if (
    data.get("tool_name") == "Bash"
    and data.get("permission_mode") == "bypassPermissions"
    and LINK.exists()
    and LINK.samefile(GUARD)
):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PermissionRequest",
        "decision": {"behavior": "allow"},
    }}))
