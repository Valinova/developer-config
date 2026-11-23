#!/usr/bin/env python3
"""Expectation table for supervised-git-backstop.py."""
import json
import pathlib
import subprocess
import sys

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
    ("acceptEdits", "git clean --force", "ask"),
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
    # --- unrecoverable: denied in bypass, since settings deny rules are gone ---
    ("bypassPermissions", "git push --delete origin main", "deny"),
    ("bypassPermissions", "git push origin --delete master", "deny"),
    ("bypassPermissions", "git push origin :main", "deny"),
    ("bypassPermissions", "git push --delete origin feat/main", "allow"),
    ("bypassPermissions", "git push -u origin main", "allow"),
    ("bypassPermissions", "rm -rf /", "deny"),
    ("bypassPermissions", "rm -fr ~", "deny"),
    ("bypassPermissions", 'cd /x && rm -rf "$HOME"', "deny"),
    ("bypassPermissions", "rm -rf ..", "deny"),
    ("bypassPermissions", "rm -rf ~/*", "deny"),
    ("bypassPermissions", "rm -rf /tmp/foo", "allow"),
    ("bypassPermissions", "rm -rf node_modules ../dist", "allow"),
    ("bypassPermissions", "/bin/rm -rf ~/Development/x", "deny"),
    ("bypassPermissions", "sudo rm -f /etc/x", "deny"),
    ("bypassPermissions", "sudo -n /bin/rm -rf /opt/x", "deny"),
    ("bypassPermissions", "sudo npm rm x", "deny"),  # accepted false positive
    ("bypassPermissions", "diskutil eraseDisk APFS X disk4", "deny"),
    ("bypassPermissions", "diskutil apfs deleteVolume disk3s7", "deny"),
    ("bypassPermissions", "diskutil list", "allow"),
    ("bypassPermissions", "dd if=x.iso of=/dev/rdisk4 bs=1m", "deny"),
    ("bypassPermissions", "dd if=/dev/zero of=/tmp/x count=1", "allow"),
    ("bypassPermissions", "gh repo delete o/r --yes", "deny"),
    ("bypassPermissions", "gh repo view o/r", "allow"),
    ("bypassPermissions", "npx supabase db reset --linked", "deny"),
    ("bypassPermissions", "supabase db reset", "allow"),
    ("bypassPermissions", "doppler run --config base -- npx convex import --replace-all -y --prod x.zip", "deny"),
    ("bypassPermissions", "pnpm exec convex import --prod --replace x.zip", "deny"),
    ("bypassPermissions", "npx convex import --replace-all x.zip", "allow"),
    ("bypassPermissions", "npx convex export --prod --path x.zip", "allow"),
    ("bypassPermissions", "find ~ -delete", "deny"),
    ("bypassPermissions", "find ~/ -mindepth 1 -delete", "deny"),
    ("bypassPermissions", "find ~ -name .DS_Store -delete", "allow"),
    ("bypassPermissions", "find /tmp/x -delete", "allow"),
    ("bypassPermissions", "grep -rn '/bin/rm -rf' docs/", "allow"),
    # --- ask tier, supervised ---
    ("acceptEdits", "git stash", "ask"),
    ("acceptEdits", "git stash push -m wip", "ask"),
    ("acceptEdits", "git restore src/a.ts", "ask"),
    ("acceptEdits", "git checkout -- src/a.ts", "ask"),
    ("acceptEdits", "git clean -fx", "ask"),
    ("acceptEdits", "git worktree remove ../wt", "ask"),
    # --- ask tier is inert in bypass ---
    ("bypassPermissions", "git stash", "allow"),
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

print(f"\n{failures} failure(s)")
sys.exit(1 if failures else 0)
