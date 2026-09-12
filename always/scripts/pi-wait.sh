#!/usr/bin/env bash
#
# pi-wait.sh — block until a pi-exec.sh task closes.
#
# Mirror of codex-wait.sh over the pi registry
# (~/.hermes/state/pi-sessions.jsonl). Exit code is the entire signal —
# no stdout on success. Read /tmp/pi-<task>.post-run.md when this
# returns 0.
#
# Usage:
#   pi-wait.sh <task-name> [timeout-seconds]
#
# Defaults:
#   - timeout: 3600 (1 hour). Pass 0 to wait indefinitely.
#   - poll interval: 5s.
#
# Exit codes:
#   0  close event observed
#   1  usage error
#   2  registry file missing
#   3  timeout reached without a close event
#   4  failure terminal (error/stalled) observed

set -euo pipefail

REGISTRY="$HOME/.hermes/state/pi-sessions.jsonl"
POLL_INTERVAL=5

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: pi-wait.sh <task-name> [timeout-seconds]" >&2
  exit 1
fi

TASK="$1"
TIMEOUT="${2:-3600}"

if [[ ! -f "$REGISTRY" ]]; then
  echo "pi-wait.sh: registry not found at $REGISTRY" >&2
  exit 2
fi

# The registry is append-only and durable across sessions, so a reused task
# name still has a previous run's terminal line on disk. Only consider
# terminal events after the most recent start/resume_started for this task.
TASK_FIELD="\"task\":\"${TASK}\""
CLOSED_STATUS="\"status\":\"closed\""
FAILED_STATUS="\"status\":\"(error|stalled|failed)\""

current_run_lines() {
  awk -v t="$TASK_FIELD" -v s='"event":"start"' -v rs='"event":"resume_started"' '
    index($0, t) {
      if (index($0, s) || index($0, rs)) { delete buf; n = 0 }
      buf[n++] = $0
    }
    END { for (i = 0; i < n; i++) print buf[i] }
  ' "$REGISTRY"
}

start=$(date +%s)
while true; do
  run="$(current_run_lines)"
  if printf '%s\n' "$run" | grep -E "$CLOSED_STATUS" >/dev/null 2>&1; then
    exit 0
  fi
  if printf '%s\n' "$run" | grep -E "$FAILED_STATUS" >/dev/null 2>&1; then
    echo "pi-wait.sh: task '$TASK' reached a failure terminal (error/stalled). See /tmp/pi-${TASK}.log" >&2
    exit 4
  fi
  if [[ "$TIMEOUT" -gt 0 ]]; then
    elapsed=$(( $(date +%s) - start ))
    if [[ "$elapsed" -ge "$TIMEOUT" ]]; then
      echo "pi-wait.sh: timeout after ${TIMEOUT}s waiting for task '$TASK' to close" >&2
      exit 3
    fi
  fi
  sleep "$POLL_INTERVAL"
done
