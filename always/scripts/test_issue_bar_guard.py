#!/usr/bin/env python3
"""Expectation table for issue-bar-guard.py.

A filing without a `Bar:` line is denied once; the same filing with the line
passes. Reads, comments, edits and prose mentions never trip it.
"""
import json
import pathlib
import subprocess
import sys
import tempfile

HOOK = str(pathlib.Path(__file__).with_name("issue-bar-guard.py"))

BAR = "Bar: observed — Sentry APP-C0 fired 2026-10-16\n"
REACHABLE = "Bar: reachable — quote save with an empty tier → total priced at zero\n"
DELETES = "Bar: deletes — feedback table, submit mutation, UI entry\n"
DIRECTED = "Bar: directed — \"open an issue for the target architecture\", 2026-10-26\n"

CASES = [
    # (command, expected)  expected in {"deny", "allow"}
    ("gh issue create --title x --body 'Problem: a guard could miss'", "deny"),
    ("gh issue create -t x -F - <<'EOF'\nProblem text\nEOF", "deny"),
    ("cd /repo && gh issue create --title x --body-file /nonexistent.md", "deny"),
    ("gh api repos/o/r/issues -X POST -f title=x -f body=y", "deny"),
    ("gh api repos/o/r/issues -f title=x", "deny"),
    (f"gh issue create --title x --body '{BAR}Blast radius: …'", "allow"),
    (f"gh issue create --title x --body '{REACHABLE}Blast radius: …'", "allow"),
    (f"gh issue create -t x -F - <<'EOF'\n{DELETES}Pointers at abc123\nEOF", "allow"),
    (f"gh api repos/o/r/issues -X POST -f title=x -f body='{BAR}'", "allow"),
    (f"gh issue create -t x -F - <<'EOF'\n{DIRECTED}Target: …\nEOF", "allow"),
    ("gh issue create --title x --body 'bar: observed - lowercase is not the line'", "deny"),
    # --- not a filing ---
    ("gh issue list --state open", "allow"),
    ("gh issue view 639 --json body", "allow"),
    ("gh issue edit 639 --add-label priority:medium", "allow"),
    ("gh issue comment 639 --body 'Triage: still holds'", "allow"),
    ("gh api repos/o/r/issues", "allow"),
    ("gh api repos/o/r/issues/12/comments -f body=x", "allow"),
    ("gh pr create --title x --body y", "allow"),
    ("grep -rn 'gh issue create' docs/", "allow"),
    ("echo 'never run gh issue create from a leaf'", "allow"),
]


def invoke(payload: dict) -> dict | None:
    out = subprocess.run(
        [sys.executable, HOOK], input=json.dumps(payload), capture_output=True, text=True
    )
    if out.returncode != 0:
        raise SystemExit(f"hook crashed rc={out.returncode}: {out.stderr.strip()}")
    return json.loads(out.stdout) if out.stdout.strip() else None


def claude_decision(command: str, cwd: str = "/", tool: str = "Bash") -> str:
    parsed = invoke({"tool_name": tool, "tool_input": {"command": command}, "cwd": cwd})
    return parsed["hookSpecificOutput"]["permissionDecision"] if parsed else "allow"


def grok_decision(command: str, tool: str = "run_terminal_command") -> str:
    parsed = invoke({"toolName": tool, "toolInput": {"command": command}})
    if not parsed:
        return "allow"
    assert parsed["decision"] == parsed["hookSpecificOutput"]["permissionDecision"], parsed
    return parsed["decision"]


def main() -> None:
    failures = []
    for command, expected in CASES:
        for harness, decide in (("claude", claude_decision), ("grok", grok_decision)):
            got = decide(command)
            if got != expected:
                failures.append(f"[{harness}] {command!r}: expected {expected}, got {got}")

    # --body-file: the line may live in the file rather than the command.
    with tempfile.TemporaryDirectory() as tmp:
        body = pathlib.Path(tmp, "body.md")
        body.write_text("Problem: nothing observed\n")
        cmd = "gh issue create --title x --body-file body.md"
        if claude_decision(cmd, cwd=tmp) != "deny":
            failures.append("body-file without Bar line should deny")
        body.write_text(BAR + "Blast radius: one row\n")
        if claude_decision(cmd, cwd=tmp) != "allow":
            failures.append("body-file with Bar line should allow")

    if claude_decision("gh issue create --title x --body y", tool="Read") != "allow":
        failures.append("non-shell tools are ignored")

    if failures:
        print("\n".join(failures))
        raise SystemExit(1)
    print(f"ok: {len(CASES) * 2 + 3} cases")


if __name__ == "__main__":
    main()
