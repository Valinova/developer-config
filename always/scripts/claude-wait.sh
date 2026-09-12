#!/usr/bin/env bash
#
# claude-wait.sh — block until a claude dispatch task closes.
#
# Mirror of pi-wait.sh over the claude registry
# (~/.hermes/state/claude-sessions.jsonl). Exit code is the entire signal —
# no stdout on success. Read /tmp/claude-<task>.post-run.md when this
# returns 0. Idempotent: a run already closed returns 0 instantly, so
# re-running after a session restart simply re-attaches.
#
# Resume-aware: the current run starts at the task's most recent start OR
# resume_started event (lib/claude-registry.sh), so a resume never returns on
# the previous run's close line.
#
# Usage:
#   claude-wait.sh <task-name> [timeout-seconds]
#
# Defaults: timeout 3600 (0 = wait indefinitely); poll interval 5s.
#
# Exit codes:
#   0  close event observed
#   1  usage error
#   2  registry file missing
#   3  timeout reached without a close event
#   4  failure terminal (failed/stalled) observed

set -euo pipefail

# Current-run isolation lives in the shared lib, the same reader
# claude-status.sh uses.
# shellcheck source=lib/claude-registry.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/claude-registry.sh"

POLL_INTERVAL=5

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: claude-wait.sh <task-name> [timeout-seconds]" >&2
  exit 1
fi

TASK="$1"
TIMEOUT="${2:-3600}"

if [[ ! -f "$CLAUDE_REGISTRY" ]]; then
  echo "claude-wait.sh: registry not found at $CLAUDE_REGISTRY" >&2
  exit 2
fi

start=$(date +%s)
while true; do
  run="$(current_run_lines "$TASK")"
  if printf '%s\n' "$run" | grep -q '"status":"closed"'; then
    exit 0
  fi
  if printf '%s\n' "$run" | grep -Eq '"status":"(failed|stalled)"'; then
    echo "claude-wait.sh: task '$TASK' reached a failure terminal. See /tmp/claude-${TASK}.log" >&2
    exit 4
  fi
  if [[ "$TIMEOUT" -gt 0 ]] && (( $(date +%s) - start >= TIMEOUT )); then
    echo "claude-wait.sh: timeout after ${TIMEOUT}s waiting for task '$TASK' to close" >&2
    exit 3
  fi
  sleep "$POLL_INTERVAL"
done
