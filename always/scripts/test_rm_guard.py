#!/usr/bin/env python3
"""The rm guard deletes ordinary paths and refuses core ones, however spelled.

Regression: an agent's rm of a home folder, project root or .git, reached
through a variable, glob, `bash -c` or script file that text matching misses.
Destructive cases only ever touch a fake HOME; real system paths are tried
without -r, which /bin/rm refuses too, so a broken guard cannot delete them.
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

SCRIPTS = pathlib.Path(__file__).parent
REAL_HOME = pathlib.Path.home()
failures = 0


def report(label, ok, detail=""):
    global failures
    failures += not ok
    print(f"{'ok  ' if ok else 'FAIL'} {label} {'' if ok else detail}")


def sh(command, home, claude=True):
    env = {**os.environ, "HOME": str(home), "PATH": f"{SCRIPTS}:/usr/bin:/bin"}
    env.pop("CLAUDECODE", None)
    if claude:
        env["CLAUDECODE"] = "1"
    return subprocess.run(["bash", "-c", command], cwd=home, env=env,
                          capture_output=True, text=True)


# (command run in the fake HOME, path it targets)
BLOCKED = [
    ('rm -rf "$HOME"', "."),
    ("rm -rf ~/*", "Documents/f"),
    ("rm -rf Documents", "Documents/f"),
    ("rm -rf Documents/", "Documents/f"),
    ("rm -r -f -- Documents", "Documents/f"),
    ("rm .zshrc", ".zshrc"),
    ("rm -rf ~/Development/proj", "Development/proj/f"),
    ("rm -rf ~/Development/*", "Development/proj/f"),
    ("cd Development/proj/src && rm -rf ../../proj", "Development/proj/f"),
    ("D=~/Development/proj; rm -rf $D", "Development/proj/f"),
    ("bash -c 'rm -rf ~/Development/proj'", "Development/proj/f"),
    ("echo 'rm -rf ~/Development/proj' > s.sh; sh s.sh", "Development/proj/f"),
    ("echo Development/proj | xargs rm -rf", "Development/proj/f"),
    ("find Development/proj -prune -exec rm -rf {} +", "Development/proj/f"),
    ("rm -rf Development/proj/.git", "Development/proj/.git/objects"),
    ("rm -rf Development/proj/.git/*", "Development/proj/.git/objects"),
    ("rm .ssh/id", ".ssh/id"),
    ("rm -rf .claude/projects/p", ".claude/projects/p/t"),
    ("rm -rf link/", "Documents/f"),
    ("rm -rf scratch/a Documents", "scratch/a"),
]
ALLOWED = [
    ("rm -rf Development/proj/src", "Development/proj/src"),
    ("rm -rf Development/proj/node_modules", "Development/proj/node_modules"),
    ("rm Development/proj/.git/index.lock", "Development/proj/.git/index.lock"),
    ("rm loose.zip", "loose.zip"),
    ("rm -rf link", "link"),
    ("cd scratch/a && rm -rf ../a", "scratch/a"),
]


def build(home):
    for path in ("Documents/f", ".zshrc", "Development/proj/f", "Development/proj/src/f",
                 "Development/proj/node_modules/f", "Development/proj/.git/objects/f",
                 "Development/proj/.git/index.lock", ".ssh/id", ".claude/projects/p/t",
                 "loose.zip", "scratch/a/f"):
        file = home / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text("x")
    (home / "link").symlink_to("Documents")


# Outside the temp roots: those are always deletable, so they cannot show a block.
base = REAL_HOME / ".cache"
base.mkdir(exist_ok=True)
for cases, survives in ((BLOCKED, True), (ALLOWED, False)):
    for command, target in cases:
        home = pathlib.Path(tempfile.mkdtemp(prefix="rm-guard-test-", dir=base))
        try:
            build(home)
            result = sh(command, home)
            ok = os.path.lexists(home / target) == survives
            ok = ok and ("rm guard: blocked" in result.stderr) == survives
            report(f"{'blocked' if survives else 'allowed'} {command}", ok, result.stderr)
        finally:
            shutil.rmtree(home, ignore_errors=True)

home = pathlib.Path(tempfile.mkdtemp(prefix="rm-guard-test-", dir=base))
try:
    build(home)
    for path in ("/", "/usr", "/usr/bin", "/etc", str(REAL_HOME), str(REAL_HOME / ".claude/projects"),
                 str(REAL_HOME.parent), "/tmp"):
        result = sh(f'rm "{path}"', home)
        report(f"blocked with HOME overridden: {path}", "rm guard: blocked" in result.stderr, result.stderr)
    for path in ("$(mktemp -d /tmp/rm-guard.XXXXXX)", "$(mktemp -d)"):
        result = sh(f'D={path}; mkdir -p "$D/.git"; cd "$D" && rm -rf "$D" && [ ! -e "$D" ]', home)
        report(f"allowed: rm -rf of the current temp directory {path}", result.returncode == 0, result.stderr)
    sh("rm -rf Documents", home, claude=False)
    report("inactive outside Claude Code", not (home / "Documents").exists())
finally:
    shutil.rmtree(home, ignore_errors=True)

print(f"\n{failures} failure(s)")
sys.exit(1 if failures else 0)
