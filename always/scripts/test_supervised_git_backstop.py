#!/usr/bin/env python3
"""Expectation table for supervised-git-backstop.py."""
import json
import pathlib
import subprocess
import sys
import tempfile

HOOK = str(pathlib.Path(__file__).with_name("supervised-git-backstop.py"))

CASES = [
    # (mode, command, expected)  expected in {"deny", "ask", "allow"}
    # --- deny tier: must fire even in bypass ---
    ("bypassPermissions", "git push --force origin main", "deny"),
    ("bypassPermissions", "git push -f", "deny"),
    ("bypassPermissions", "git push origin +main:main", "deny"),
    ("bypassPermissions", "git push origin +refs/heads/*:refs/heads/*", "deny"),
    ("bypassPermissions", "cd /repo && git push --force", "deny"),
    ("acceptEdits", "git push --force origin main", "deny"),
    ("bypassPermissions", "git -C /repo push --force origin main", "deny"),
    ("bypassPermissions", "git -c core.quotePath=false push -vf origin main", "deny"),
    ("acceptEdits", "git -C /repo restore src/a.ts", "ask"),
    ("acceptEdits", "/bin/rm -rf /home/example", "ask"),
    ("acceptEdits", "rm -R /home/example", "ask"),
    ("acceptEdits", "rm -rf /tmp/../home/example", "ask"),
    ("acceptEdits", "rm -rf /tmp/*", "ask"),
    ("acceptEdits", "rm -rf /tmp/claude-probe -- -real-directory", "ask"),
    ("acceptEdits", "git clean --force", "ask"),
    ("acceptEdits", "rm -rf /tmp/", "ask"),
    ("acceptEdits", "/bin/rm -rf /tmp/claude-probe", "allow"),
    ("acceptEdits", "git -C /repo push --force-with-lease origin feat", "allow"),
    # --- the sanctioned form and normal pushes must pass ---
    ("bypassPermissions", "git push --force-with-lease origin feat", "allow"),
    ("acceptEdits", "git push --force-with-lease", "allow"),
    ("acceptEdits", "git push origin feat", "allow"),
    ("acceptEdits", "git push", "allow"),
    # --- mentions must NOT trip the deny tier (the bug found in testing) ---
    ("acceptEdits", 'grep -rn "git push --force" docs/', "allow"),
    ("acceptEdits", 'echo "never run git push -f"', "allow"),
    ("acceptEdits", 'for c in "git push --force origin main"; do echo "$c"; done', "allow"),
    # --- ask tier, supervised ---
    ("acceptEdits", "git stash", "ask"),
    ("acceptEdits", "git stash push -m wip", "ask"),
    ("acceptEdits", "git restore src/a.ts", "ask"),
    ("acceptEdits", "git checkout -- src/a.ts", "ask"),
    ("acceptEdits", "git clean -fx", "ask"),
    ("acceptEdits", "git worktree remove ../wt", "ask"),
    ("acceptEdits", "rm -rf /Users/someone/Development/foo", "ask"),
    ("acceptEdits", "rm -rf $TARGET", "ask"),
    ("acceptEdits", "rm -r ../build", "ask"),
    # --- scratch roots exempt (the false positive we measured) ---
    ("acceptEdits", "rm -rf /tmp/claude-probe", "allow"),
    ("acceptEdits", "rm -rf /private/tmp/claude-1000/x", "allow"),
    ("acceptEdits", "rm -f /tmp/thing", "allow"),  # not recursive
    # --- ask tier is inert in bypass ---
    ("bypassPermissions", "git stash", "allow"),
    ("bypassPermissions", "rm -rf /Users/someone/Development/foo", "allow"),
    # --- trimmed 2026-07-28: must be silent now ---
    ("acceptEdits", "git checkout main", "allow"),
    ("acceptEdits", "git switch -c feat/x", "allow"),
    ("acceptEdits", "git worktree add ../wt feat", "allow"),
    ("acceptEdits", "git pull", "allow"),
    ("acceptEdits", "git merge main", "allow"),
    ("acceptEdits", "git rebase origin/main", "allow"),
    ("acceptEdits", "git cherry-pick abc123", "allow"),
    ("acceptEdits", "git reset HEAD~1", "allow"),
    ("acceptEdits", "git commit --amend --no-edit", "allow"),
    ("acceptEdits", "git branch -d old", "allow"),
    # --- non-Bash tools ignored ---
]


def _invoke(payload: dict) -> str:
    out = subprocess.run(
        [sys.executable, HOOK],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
    )
    if out.returncode != 0:
        return f"ERROR(rc={out.returncode}) {out.stderr.strip()}"
    raw = out.stdout.strip()
    if not raw:
        return "allow"
    parsed = json.loads(raw)
    return parsed["hookSpecificOutput"]["permissionDecision"]


def run(mode, command, tool="Bash"):
    return _invoke(
        {"tool_name": tool, "permission_mode": mode, "tool_input": {"command": command}}
    )


def run_grok(mode, command, tool="run_terminal_command"):
    return _invoke(
        {
            "toolName": tool,
            "permissionMode": mode,
            "toolInput": {"command": command},
        }
    )


failures = 0
for mode, command, expected in CASES:
    got = run(mode, command)
    ok = got == expected
    failures += not ok
    print(f"{'ok  ' if ok else 'FAIL'} [{mode[:6]}] {command!r:62} → {got} (want {expected})")

got = run("acceptEdits", "git stash", tool="Read")
ok = got == "allow"
failures += not ok
print(f"{'ok  ' if ok else 'FAIL'} [non-Bash tool ignored] → {got} (want allow)")

print("\nGrok camelCase envelope (ask-tier promotes to deny; deny-tier unchanged)")
for mode, command, expected in CASES:
    grok_expected = "deny" if expected == "ask" else expected
    got = run_grok(mode, command)
    ok = got == grok_expected
    failures += not ok
    print(
        f"{'ok  ' if ok else 'FAIL'} [grok {mode[:6]}] {command!r:56} → {got} (want {grok_expected})"
    )

got = run_grok("acceptEdits", "git stash", tool="read_file")
ok = got == "allow"
failures += not ok
print(f"{'ok  ' if ok else 'FAIL'} [grok non-shell tool ignored] → {got} (want allow)")

with tempfile.TemporaryDirectory() as directory:
    outside = pathlib.Path(directory) / "outside"
    outside.symlink_to(pathlib.Path.home(), target_is_directory=True)
    loop = pathlib.Path(directory) / "loop"
    loop.symlink_to(loop)
    for target in (outside / "example", loop / "example"):
        got = run("acceptEdits", f"rm -rf {target}")
        ok = got == "ask"
        failures += not ok
        print(f"{'ok  ' if ok else 'FAIL'} [scratch symlink escape/loop] → {got} (want ask)")

print(f"\n{failures} failure(s)")
sys.exit(1 if failures else 0)
