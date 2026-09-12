#!/usr/bin/env bash
#
# codex-status.sh — one-shot triage verdict for a codex-exec.sh task.
#
# Answers "is it hung or just slow?" without hand-rolling registry greps,
# log mtime checks, and post-run lookups. Read-only: touches nothing,
# kills nothing — safe to run at any time, including against live runs.
#
# Usage:
#   codex-status.sh <task-name>
#
# Verdicts (first line of output) and exit codes:
#   0  CLOSED    — current run reached "status":"closed"; post-run summary ready.
#   3  RUNNING   — no terminal event and the log is actively being written.
#   4  FAILED    — current run reached "status":"error" or "stalled".
#   5  STALE     — no terminal event and the log has been quiet past the
#                  threshold. Either a slow reasoning stretch or an orphaned
#                  run — inspect the log tail before assuming either.
#   6  UNKNOWN   — task has no start event in the registry.
#   1  usage error; 2 registry missing.
#
# STALE threshold: 300s without log writes. Long xhigh reasoning stretches can
# legitimately exceed it — STALE is a prompt to look, never proof of death.
# Recovery guidance lives in instructions/codex-delegation.md ("Post-run
# discipline" / waiter-orphaning note).

set -euo pipefail

# Shared primitives (registry path + current-run isolation) — see
# lib/codex_registry.py. Read-only here; CODEX_SOURCE is irrelevant.
# shellcheck source=lib/codex-registry.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/codex-registry.sh"

STALE_AFTER=300

if [[ $# -ne 1 ]]; then
  echo "Usage: codex-status.sh <task-name>" >&2
  exit 1
fi

TASK="$1"
# codex-exec.sh logs to <task>.log; codex-resume.sh logs to <task>-resume.log.
# Track whichever was written most recently — a resumed task's original log
# goes quiet while the resume log is the live one.
LOG_PATH="/tmp/codex-${TASK}.log"
RESUME_LOG="/tmp/codex-${TASK}-resume.log"
if [[ -f "$RESUME_LOG" ]]; then
  if [[ ! -f "$LOG_PATH" || "$RESUME_LOG" -nt "$LOG_PATH" ]]; then
    LOG_PATH="$RESUME_LOG"
  fi
fi
POST_RUN="/tmp/codex-${TASK}.post-run.md"

if [[ ! -f "$CODEX_REGISTRY" ]]; then
  echo "codex-status.sh: registry not found at $CODEX_REGISTRY" >&2
  exit 2
fi

# Current-run isolation lives in the shared lib (same reader codex-wait.sh
# uses): the registry is append-only and durable across sessions, so only
# lines after this task's most recent start event belong to the current run.
RUN="$(current_run_lines "$TASK")"

if [[ -z "$RUN" ]]; then
  echo "UNKNOWN — no start event for task '$TASK' in $CODEX_REGISTRY"
  exit 6
fi

last_ts() {
  printf '%s\n' "$RUN" | tail -n 1 | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p'
}

log_age() {
  if [[ -f "$LOG_PATH" ]]; then
    # GNU first, BSD second. On GNU coreutils `-f` means --file-system, so
    # `stat -f %m <path>` parses as two file arguments: %m fails, the path
    # succeeds and prints its filesystem block to STDOUT, which then lands
    # inside the arithmetic below. Ordering matters, not just the redirect.
    local mtime
    mtime="$(stat -c %Y "$LOG_PATH" 2>/dev/null || stat -f %m "$LOG_PATH" 2>/dev/null)"
    echo $(( $(date +%s) - mtime ))
  else
    echo -1
  fi
}

if printf '%s\n' "$RUN" | grep -E '"status":"closed"' >/dev/null 2>&1; then
  echo "CLOSED — task '$TASK' closed at $(last_ts)"
  if [[ -f "$POST_RUN" ]]; then
    echo "post-run: $POST_RUN"
  else
    echo "post-run: MISSING (expected $POST_RUN) — read the log tail instead: $LOG_PATH"
  fi
  exit 0
fi

if printf '%s\n' "$RUN" | grep -E '"status":"(error|stalled)"' >/dev/null 2>&1; then
  echo "FAILED — task '$TASK' hit a failure terminal (error/stalled) at $(last_ts)"
  echo "log: $LOG_PATH"
  exit 4
fi

AGE="$(log_age)"
if [[ "$AGE" -lt 0 ]]; then
  echo "STALE — task '$TASK' has a start event but no log at $LOG_PATH"
  echo "registry says started; the dispatch may have died before first write."
  exit 5
fi

if [[ "$AGE" -le "$STALE_AFTER" ]]; then
  echo "RUNNING — task '$TASK' log active ${AGE}s ago"
  echo "log: $LOG_PATH ($(du -h "$LOG_PATH" | cut -f1 | tr -d ' ') so far)"
  exit 3
fi

echo "STALE — task '$TASK' has no terminal event and the log has been quiet for ${AGE}s"
echo "Could be a long reasoning stretch OR an orphaned run. Inspect before acting:"
echo "  tail -c 2000 $LOG_PATH"
echo "Never pattern-kill; if truly dead, re-dispatch under a fresh -r2 name."
exit 5
