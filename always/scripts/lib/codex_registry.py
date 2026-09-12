#!/usr/bin/env python3
"""
codex_registry.py — canonical primitives shared by every codex dispatch wrapper.

Two wrapper families dispatch `codex exec` and write to ONE registry at
~/.hermes/state/codex-sessions.jsonl:

  - Hermes   (~/.hermes/scripts/codex_exec.sh, codex_delegate.py, codex_resume.py)
  - Claude   (developer-config/always/scripts/codex-{exec,resume,wait,status}.sh,
              deployed as ~/.claude/scripts/*)

They had drifted on the three things they share: the registry line grammar, the
thread-id / final-message extraction regexes, and the dispatch-hygiene constants.
This module owns all three. It lives in developer-config because that is the
always-present home — the Claude wrappers must work on a machine with no Hermes
install, so the dependency points only in this direction (Hermes → here).

Usable two ways:

  Python   from codex_registry import registry_append, extract_session_id, ...
  Shell    source .../lib/codex-registry.sh   (thin wrapper over the CLI below)

CLI:
  codex_registry.py append --source hermes|claude-code KEY VALUE [KEY VALUE ...]
  codex_registry.py thread-id      <log-path>
  codex_registry.py final-message  <log-path>
  codex_registry.py json-events    <log-path>
  codex_registry.py session-id     --task <name>
  codex_registry.py current-run    --task <name>
  codex_registry.py post-run       --task <name> --status <s> --log <p> ...
  codex_registry.py constants

Registry path resolution: $CODEX_REGISTRY_PATH, else
~/.hermes/state/codex-sessions.jsonl. Values always travel via argv or the
environment — never interpolated into source or into a JSON string by hand.

Line grammar (canonical, written by every new line):
  {"ts":...,"agent":"codex","source":"hermes"|"claude-code","task":...,
   "event":...,"status":...,"log_path":...,...}

`log_path` is the canonical log-path key. Historical Claude-side lines used
`log_file`; readers here normalize it to `log_path` in memory. Registry content
is append-only and NEVER rewritten.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import sys
from datetime import datetime, timezone
from pathlib import Path

# ─── Constants (the dispatch-hygiene numbers both families rely on) ───

DEFAULT_REGISTRY = Path.home() / ".hermes/state/codex-sessions.jsonl"

#: Hard wall-clock cap on a single codex run (90 minutes).
DEFAULT_TIMEOUT_SEC = 5400
#: Seconds a background dispatch may go without emitting a JSON event before it
#: is considered hung on stdin and killed.
HEALTH_CHECK_SEC = 45

SOURCES = ("hermes", "claude-code")

# ─── Log-stream parsing (canonical owners of these patterns) ───

# The first event `codex exec --json` emits is
# {"type":"thread.started","thread_id":"<uuid>"} and that thread_id is what
# `codex exec resume` expects. Never derive it from "newest rollout file on
# disk" — that picks the wrong session when runs overlap.
THREAD_ID_RE = re.compile(r'"thread_id":"([0-9a-f-]{36})"')
AGENT_MSG_RE = re.compile(
    r'"type":"item\.completed","item":\{"id":"item_\d+","type":"agent_message","text":"([^"]*)"'
)

# Registry values that arrive from shell as strings but belong in the JSONL as
# numbers/bools.
RAW_FIELDS = frozenset({
    "exit_code", "staged_count", "duration_sec", "timeout_sec",
    "push_ok", "wip_restored", "json_events",
})

# Events that begin a run. The registry is durable across sessions, so a reused
# task name still has older terminal lines on disk; readers isolate the current
# run by taking only what follows the last of these. Both spellings exist in the
# historical file (`resume_start` from codex_delegate, `resume_started` from the
# Claude wrapper).
RUN_START_EVENTS = frozenset({"start", "resume_start", "resume_started"})


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def registry_path() -> Path:
    return Path(os.environ.get("CODEX_REGISTRY_PATH") or DEFAULT_REGISTRY)


# ─── Writing ───

def registry_append(entry: dict, source: str, path: Path | None = None) -> None:
    """Append one canonical line. `source` says which family wrote it."""
    if source not in SOURCES:
        raise ValueError(f"source must be one of {SOURCES}, got {source!r}")
    path = path or registry_path()
    line = {"ts": utc_now(), "agent": "codex", "source": source, **entry}
    path.parent.mkdir(parents=True, exist_ok=True)
    # Compact separators (no spaces after ':' or ',') so the shell readers'
    # `"task":"<name>"` substring match works uniformly. json.dumps' default
    # `"task": "<name>"` breaks them.
    with path.open("a") as f:
        f.write(json.dumps(line, separators=(",", ":")) + "\n")


# ─── Reading (accepts legacy lines; never rewrites them) ───

def _normalize(entry: dict) -> dict:
    """Legacy compatibility: pre-unification Claude lines carried `log_file`."""
    if "log_path" not in entry and "log_file" in entry:
        entry = {**entry, "log_path": entry["log_file"]}
    return entry


def iter_entries(path: Path | None = None):
    """Yield (raw_line, entry) for every parseable codex line. Junk is skipped."""
    path = path or registry_path()
    if not path.exists():
        return
    with path.open() as f:
        for raw in f:
            raw = raw.rstrip("\n")
            if not raw.strip():
                continue
            try:
                entry = json.loads(raw)
            except ValueError:
                continue
            if not isinstance(entry, dict) or entry.get("agent") != "codex":
                continue
            yield raw, _normalize(entry)


def latest_session_id(task: str, path: Path | None = None) -> str:
    """Most recent session_id recorded for a task, across the whole file."""
    last = ""
    for _, entry in iter_entries(path):
        if entry.get("task") == task and entry.get("session_id"):
            last = entry["session_id"]
    return last


def current_run(task: str, path: Path | None = None) -> list:
    """(raw, entry) pairs belonging to this task's most recent run only."""
    buf: list = []
    for raw, entry in iter_entries(path):
        if entry.get("task") != task:
            continue
        if entry.get("event") in RUN_START_EVENTS:
            buf = []
        buf.append((raw, entry))
    return buf


# ─── Log extraction ───

def extract_session_id(log_path) -> str:
    """thread_id from the head of a --json log ('' if absent/unreadable)."""
    try:
        with open(log_path) as f:
            head = "".join(next(f, "") for _ in range(30))
    except OSError:
        return ""
    m = THREAD_ID_RE.search(head)
    return m.group(1) if m else ""


def extract_final_message(log_path) -> str:
    """The last agent_message text in a --json log, with \\n unescaped."""
    last = ""
    try:
        with open(log_path) as f:
            for line in f:
                m = AGENT_MSG_RE.search(line)
                if m:
                    last = m.group(1)
    except OSError:
        return ""
    return last.replace("\\n", "\n")


def count_json_events(log_path) -> int:
    """How many JSON events the run emitted. Zero means it never started."""
    n = 0
    try:
        with open(log_path) as f:
            for line in f:
                if line.startswith('{"type":'):
                    n += 1
    except OSError:
        return 0
    return n


# ─── Post-run summary ───

def _git(repo, *args: str) -> str:
    """git stdout, or '' when git failed / is unavailable."""
    import subprocess
    try:
        r = subprocess.run(["git", "-C", str(repo), *args],
                           capture_output=True, text=True, timeout=10)
        return r.stdout if r.returncode == 0 else ""
    except Exception:
        return ""


def _git_section(repo, *args: str) -> str:
    """A post-run section body. Distinguishes 'git said nothing' from 'git
    could not run' — reporting an empty diff as a git failure has misled
    readers into thinking the summary was broken."""
    out = _git(repo, *args)
    if out.strip():
        return out.rstrip()
    ok = _git(repo, "rev-parse", "--git-dir").strip()
    return "(none)" if ok else "(no repo / git unavailable)"


def repo_root(cwd) -> Path:
    out = _git(cwd, "rev-parse", "--show-toplevel").strip()
    return Path(out) if out else Path(cwd)


def write_post_run_summary(task: str, status: str, log_path, session_id: str,
                           repo, out_path, title: str = "codex post-run summary",
                           note: str = "") -> None:
    """Staged / unstaged / untracked kept SEPARATE so the invoking agent can
    tell codex's staged work from dangling extras without eyeballing a mixed
    diff. Same layout for every wrapper; only the title/note differ."""
    staged = _git_section(repo, "diff", "--cached", "--stat")
    unstaged = _git_section(repo, "diff", "--stat")
    untracked = _git_section(repo, "ls-files", "--others", "--exclude-standard")
    final_msg = extract_final_message(log_path) or "(no agent_message found in log)"
    note_line = f"- {note}\n" if note else ""

    Path(out_path).write_text(f"""# {title} — task: {task}

- status: {status}
- finished_at: {utc_now()}
{note_line}- log: {log_path}
- session_id: {session_id}

## Staged (`git diff --cached --stat`)
```
{staged.rstrip()}
```

## Unstaged (`git diff --stat`)
```
{unstaged.rstrip()}
```

## Untracked (`git ls-files --others --exclude-standard`)
```
{untracked.rstrip()}
```

## Final agent_message
```
{final_msg}
```
""")


# ─── CLI ───

def _cmd_append(args) -> int:
    kv = args.pair
    if len(kv) % 2:
        print("append: KEY VALUE pairs must be even in number", file=sys.stderr)
        return 1
    entry = {}
    for k, v in zip(kv[::2], kv[1::2]):
        if k in RAW_FIELDS:
            try:
                v = json.loads(v)
            except ValueError:
                pass
        entry[k] = v
    registry_append(entry, source=args.source)
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="codex_registry.py")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("append")
    p.add_argument("--source", required=True, choices=list(SOURCES))
    p.add_argument("pair", nargs="*")
    p.set_defaults(fn=_cmd_append)

    for name, fn in (
        ("thread-id", lambda a: (print(extract_session_id(a.log)), 0)[1]),
        ("final-message", lambda a: (print(extract_final_message(a.log)), 0)[1]),
        ("json-events", lambda a: (print(count_json_events(a.log)), 0)[1]),
    ):
        p = sub.add_parser(name)
        p.add_argument("log")
        p.set_defaults(fn=fn)

    p = sub.add_parser("session-id")
    p.add_argument("--task", required=True)
    p.set_defaults(fn=lambda a: (print(latest_session_id(a.task)), 0)[1])

    p = sub.add_parser("current-run")
    p.add_argument("--task", required=True)
    p.set_defaults(fn=lambda a: ([print(raw) for raw, _ in current_run(a.task)], 0)[1])

    p = sub.add_parser("post-run")
    p.add_argument("--task", required=True)
    p.add_argument("--status", required=True)
    p.add_argument("--log", required=True)
    p.add_argument("--session-id", default="")
    p.add_argument("--repo", default=".")
    p.add_argument("--out", required=True)
    p.add_argument("--title", default="codex post-run summary")
    p.add_argument("--note", default="")
    p.set_defaults(fn=lambda a: (write_post_run_summary(
        a.task, a.status, a.log, a.session_id, a.repo, a.out, a.title, a.note), 0)[1])

    p = sub.add_parser("constants")
    # Shell-quoted: the registry path may contain spaces and this is eval'd.
    p.set_defaults(fn=lambda a: (print(
        f"CODEX_DEFAULT_TIMEOUT_SEC={DEFAULT_TIMEOUT_SEC}\n"
        f"CODEX_HEALTH_CHECK_SEC={HEALTH_CHECK_SEC}\n"
        f"CODEX_REGISTRY={shlex.quote(str(registry_path()))}"), 0)[1])

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
