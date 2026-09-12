#!/usr/bin/env bash
#
# codex-wait.sh — block until a codex-exec.sh task closes.
#
# Polls the canonical codex session registry at
# ~/.hermes/state/codex-sessions.jsonl for a `"status":"closed"` event
# for the named task and exits when found. Designed to be used inline as the
# command of a Monitor `until` loop (the Monitor regex was bug-prone in
# practice — `"status":"close"` vs `"status":"closed"` had silently never
# matched), or directly via run_in_background to wait on a long codex run.
#
# Usage:
#   codex-wait.sh <task-name> [timeout-seconds]
#
# Defaults:
#   - timeout: 3600 (1 hour). Pass 0 to wait indefinitely.
#   - poll interval: 5s.
#
# Output:
#   - Exit 0: close event observed.
#   - Exit 1: usage error.
#   - Exit 2: registry file missing.
#   - Exit 3: timeout reached without a close event.
#   - Exit 4: failure terminal observed.
#
# The exit code is the entire signal — no stdout. Read the post-run summary
# at /tmp/codex-<task>.post-run.md separately when this returns 0.
#
# Read the companion notes in ~/.claude/CLAUDE.md under "Codex delegation".

set -euo pipefail

# Shared primitives (registry path + current-run isolation) — see
# lib/codex_registry.py. Read-only here; CODEX_SOURCE is irrelevant.
# shellcheck source=lib/codex-registry.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/codex-registry.sh"

POLL_INTERVAL=5

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: codex-wait.sh <task-name> [timeout-seconds]" >&2
  exit 1
fi

TASK="$1"
TIMEOUT="${2:-3600}"

if [[ ! -f "$CODEX_REGISTRY" ]]; then
  echo "codex-wait.sh: registry not found at $CODEX_REGISTRY" >&2
  exit 2
fi

# Both wrappers write a normalized "status" on every line: codex-exec.sh and
# (since the resume status-field fix) codex-resume.sh emit "status":"closed" on
# success and "status":"failed" (exec) or "status":"error" (resume) on failure.
#
# The registry is append-only and DURABLE ACROSS SESSIONS, so a task name reused
# in a later session still has the *previous* run's terminal line on disk. Matching
# the whole file would return on that stale close (false positive). `current_run_lines`
# (shared lib) emits only the lines after this task's most recent start event.
CLOSED_STATUS="\"status\":\"closed\""
FAILED_STATUS="\"status\":\"(error|stalled|failed)\""

start=$(date +%s)
while true; do
  run="$(current_run_lines "$TASK")"
  if printf '%s\n' "$run" | grep -E "$CLOSED_STATUS" >/dev/null 2>&1; then
    exit 0
  fi
  # Don't sit through the full timeout on a failed/stalled run or resume — break
  # immediately with a distinct exit code so the caller can inspect the log.
  if printf '%s\n' "$run" | grep -E "$FAILED_STATUS" >/dev/null 2>&1; then
    echo "codex-wait.sh: task '$TASK' reached a failure terminal (error/stalled/failed). See /tmp/codex-${TASK}.log" >&2
    exit 4
  fi
  if [[ "$TIMEOUT" -gt 0 ]]; then
    elapsed=$(( $(date +%s) - start ))
    if [[ "$elapsed" -ge "$TIMEOUT" ]]; then
      echo "codex-wait.sh: timeout after ${TIMEOUT}s waiting for task '$TASK' to close" >&2
      exit 3
    fi
  fi
  sleep "$POLL_INTERVAL"
done
