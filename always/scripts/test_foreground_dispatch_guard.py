#!/usr/bin/env python3
"""Expectation table for foreground-dispatch-guard.py.

A dispatcher name counts as a command only with a path-or-quote prefix and
an argument-like suffix (whitespace, quote, or end), so prose mentions inside
heredocs, backticks and parentheses are not dispatches. The one residual false
positive is a heredoc line that reads exactly like an invocation
(`codex-exec.sh now detaches`); it is textually indistinguishable.
"""
import json
import pathlib
import subprocess
import sys

HOOK = str(pathlib.Path(__file__).with_name("foreground-dispatch-guard.py"))

HEREDOC_MIDLINE = "git commit -F - <<'EOF'\nFix codex-exec.sh health check\nEOF"
HEREDOC_LINESTART = "git commit -F - <<'EOF'\ncodex-exec.sh: drop the log flag\nEOF"

CASES = [
    # (background, command, expected)  expected in {"deny", "allow"}
    # --- foreground dispatch is always denied ---
    (False, "codex-exec.sh t /tmp/b.md", "deny"),
    (False, "codex-resume.sh t /tmp/b.md --foreground", "deny"),
    (False, "~/.claude/scripts/claude-exec.sh t /tmp/b.md", "deny"),
    (False, "cd /repo && pi-exec.sh t /tmp/b.md", "deny"),
    (False, "cd /repo; pi-resume.sh t /tmp/b.md", "deny"),
    # --- waits, status and prose mentions are not dispatches ---
    (False, "codex-wait.sh t 3600", "allow"),
    (False, "claude-status.sh t", "allow"),
    (False, "grep -n codex-exec.sh README.md", "allow"),
    (False, 'echo "run claude-exec.sh in the background"', "allow"),
    # --- background: the dispatch must be the final command ---
    (True, "codex-exec.sh t /tmp/b.md", "allow"),
    (True, "codex-exec.sh t /tmp/b.md  \n", "allow"),
    (True, "cd /repo && claude-exec.sh t /tmp/b.md --effort high", "allow"),
    (True, "codex-exec.sh t /tmp/b.md && codex-wait.sh t", "deny"),
    (True, "pi-exec.sh t /tmp/b.md; pi-wait.sh t", "deny"),
    (True, "claude-exec.sh t /tmp/b.md | tee /tmp/out", "deny"),
    (True, "claude-exec.sh t /tmp/b.md &", "deny"),
    (True, "codex-exec.sh t /tmp/b.md\nclaude-wait.sh t", "deny"),
    (True, "codex-wait.sh t 3600", "allow"),
    (False, '"$HOME/.claude/scripts/codex-exec.sh" t /tmp/b.md', "deny"),
    # --- dispatcher names inside prose are not dispatches ---
    (False, HEREDOC_MIDLINE, "allow"),
    (False, HEREDOC_LINESTART, "allow"),
    (False, 'git commit -m "(claude-exec.sh) tidy usage"', "allow"),
    (False, 'git commit -m "tidy claude-exec.sh usage"', "allow"),
    (False, "python3 - <<'EOF'\nx = 'takes `effort`; `claude-exec.sh` is used there'\nEOF", "allow"),
    (False, "cat <<'EOF'\n- **`claude-exec.sh`** is for callers outside\nEOF", "allow"),
]


def invoke(payload: dict) -> dict | None:
    out = subprocess.run(
        [sys.executable, HOOK], input=json.dumps(payload), capture_output=True, text=True
    )
    if out.returncode != 0:
        raise SystemExit(f"hook crashed rc={out.returncode}: {out.stderr.strip()}")
    return json.loads(out.stdout) if out.stdout.strip() else None


def claude_decision(background: bool, command: str, tool: str = "Bash") -> str:
    parsed = invoke(
        {"tool_name": tool, "tool_input": {"command": command, "run_in_background": background}}
    )
    return parsed["hookSpecificOutput"]["permissionDecision"] if parsed else "allow"


def grok_decision(background: bool, command: str, tool: str = "run_terminal_command") -> str:
    parsed = invoke(
        {"toolName": tool, "toolInput": {"command": command, "background": background}}
    )
    if not parsed:
        return "allow"
    # Grok reads the top-level decision; it must agree with the Claude field.
    assert parsed["decision"] == parsed["hookSpecificOutput"]["permissionDecision"], parsed
    return parsed["decision"]


failures = 0


def check(label: str, got: str, want: str) -> None:
    global failures
    ok = got == want
    failures += not ok
    print(f"{'ok  ' if ok else 'FAIL'} [{label}] → {got} (want {want})")


for background, command, expected in CASES:
    mode = "bg" if background else "fg"
    check(f"claude {mode} {command!r}", claude_decision(background, command), expected)
    check(f"grok {mode} {command!r}", grok_decision(background, command), expected)

check("non-shell tool ignored", claude_decision(False, "codex-exec.sh t b", tool="Read"), "allow")
check("grok non-shell tool ignored", grok_decision(False, "codex-exec.sh t b", tool="read_file"), "allow")

print(f"\n{failures} failure(s)")
sys.exit(1 if failures else 0)
