#!/usr/bin/env bash
#
# claude-exec.sh — wrapper for delegating a bounded task to `claude -p`
# (Opus 5.5) at a chosen effort, from a Claude Code orchestrator.
#
# Why a `claude -p` lane, and what it keeps from codex-exec.sh: see
# instructions/codex-delegation.md "Claude delegation". Registry:
# ~/.hermes/state/claude-sessions.jsonl (lib/claude-registry.sh).
#
# Usage:
#   claude-exec.sh <task-name> <brief-path> [--effort LEVEL] [--model SLUG] [--resume] [--foreground]
#
# --resume continues the session most recently captured for <task-name>
# (follow-up brief with the previous context loaded).
#
# Exit codes:
#   0  dispatched successfully (background) or completed cleanly (foreground)
#   1  usage error / failed (foreground)
#   2  brief file missing
#   3  claude CLI missing
#   4  health check failed (task killed)
#   5  --resume requested but no session id captured for this task

set -euo pipefail

TASK=""
BRIEF=""
MODE="background"
MODEL="opus"
EFFORT="medium"
RESUME="no"

usage() {
  cat >&2 <<EOF
Usage: claude-exec.sh <task-name> <brief-path> [--effort LEVEL] [--model SLUG] [--resume] [--foreground]

Arguments:
  <task-name>     Short identifier, used in the log file name and registry.
  <brief-path>    File containing the task brief (passed to claude -p as the prompt).

Options:
  --effort LEVEL  low|medium|high|xhigh|max. Default: medium.
  --model SLUG    Model to run. Default: opus.
  --resume        Resume the session last captured for <task-name>.
  --foreground    Block until claude completes. Default is background dispatch.
EOF
  exit 1
}

if [[ $# -lt 2 ]]; then usage; fi
TASK="$1"; shift
BRIEF="$1"; shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --foreground) MODE="foreground"; shift ;;
    --resume) RESUME="yes"; shift ;;
    --effort|--model)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "claude-exec.sh: $1 requires a value" >&2; usage
      fi
      case "$1" in
        --effort) EFFORT="$2" ;;
        --model) MODEL="$2" ;;
      esac
      shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ ! -f "$BRIEF" ]]; then
  echo "claude-exec.sh: brief file not found: $BRIEF" >&2
  exit 2
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "claude-exec.sh: 'claude' CLI not found on PATH" >&2
  exit 3
fi

WRAPPER="claude-exec.sh"
AGENT="claude"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
LOG_PATH="/tmp/claude-${TASK}.log"
# Registry path plus the shared wrapper mechanics (lib/wrapper-common.sh).
# shellcheck source=lib/claude-registry.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/claude-registry.sh"
REGISTRY="$CLAUDE_REGISTRY"
mkdir -p "$(dirname "$REGISTRY")"

# Start every dispatch from an empty log. A resumed task reuses the same log
# path and the child only truncates it once it execs, so without this the
# health check below can match the PREVIOUS run's events and report a healthy
# start for a resume that never actually began.
: > "$LOG_PATH"

# ---- registry ----

# Best effort, never fatal. The first stream-json line normally carries
# "session_id", but the health check below can clear on a first line that is
# still only partially written (a resume emits its SessionStart hook events the
# instant it starts), so the field may not be there yet. Under
# `set -euo pipefail` the no-match grep would abort the whole dispatch: the
# observed bug was a resume printing "health check ok" and then exiting 1
# without ever reaching its `exit 0`. The pipeline therefore always succeeds,
# and an empty result means "not captured yet" — which every caller handles.
extract_session_id() {
  head -5 "$LOG_PATH" 2>/dev/null \
    | grep -oE '"session_id":"[0-9a-f-]{36}"' \
    | head -1 \
    | grep -oE '[0-9a-f-]{36}' || true
}

# Most recent session_captured line for this task (for --resume).
previous_session_id() {
  grep -F "\"task\":\"${TASK}\"" "$REGISTRY" 2>/dev/null \
    | grep -F '"event":"session_captured"' \
    | tail -1 \
    | grep -oE '"session_id":"[0-9a-f-]{36}"' \
    | grep -oE '[0-9a-f-]{36}' || true
}

register_start() {
  local event="start"
  [[ "$RESUME" == "yes" ]] && event="resume_started"
  registry_line "\"event\":\"$event\",\"cwd\":\"$REPO_ROOT\",\"status\":\"running\",\"model\":\"$MODEL\",\"effort\":\"$EFFORT\",\"log_file\":\"$LOG_PATH\""
}

register_session_id() {
  local session_id
  session_id="$(extract_session_id)"
  if [[ -n "$session_id" ]]; then
    registry_line "\"event\":\"session_captured\",\"session_id\":\"$session_id\""
    echo "claude-exec.sh: session_id=$session_id — follow up with claude-exec.sh $TASK <brief> --resume"
  fi
}

register_close() {
  local status="$1"; local reason="${2:-}"
  registry_line "\"event\":\"close\",\"status\":\"$status\",\"session_id\":\"$(extract_session_id)\",\"reason\":\"$reason\""
  write_post_run_summary "$status"
}

claude_final_message() {
  grep -F '"type":"result"' "$LOG_PATH" 2>/dev/null | tail -1 \
    | python3 -c 'import json,sys; line=sys.stdin.read().strip(); d=json.loads(line) if line else {}; print(d.get("result") or "(no result text)"); c=d.get("total_cost_usd"); print(f"\n[cost_usd={c}]" if c is not None else "")' 2>/dev/null \
    || echo "(no result event found in log)"
}

write_post_run_summary() {
  write_shell_post_run "/tmp/claude-${TASK}.post-run.md" "claude-exec post-run summary" \
    "$1" claude_final_message \
    "model / effort: $MODEL / $EFFORT" "log: $LOG_PATH" "session_id: $(extract_session_id)"
}

# ---- dispatch ----

CLAUDE_FLAGS=(
  -p
  --model "$MODEL"
  --effort "$EFFORT"
  --output-format stream-json --verbose
  --dangerously-skip-permissions
)
if [[ "$RESUME" == "yes" ]]; then
  PREV="$(previous_session_id)"
  if [[ -z "$PREV" ]]; then
    echo "claude-exec.sh: --resume requested but no session id captured for task '$TASK'" >&2
    exit 5
  fi
  CLAUDE_FLAGS+=(--resume "$PREV")
fi

run_claude() {
  ( cd "$REPO_ROOT" && claude "${CLAUDE_FLAGS[@]}" "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1 )
}

# Background: the detached subshell shares the caller's process group, so
# dispatch from a run_in_background Bash call with this as the FINAL command
# (foreground-dispatch-guard.py enforces it). Redirect the subshell's output
# away so the command substitution returns immediately with the pid only.
dispatch_background() {
  (
    if run_claude; then
      register_close "closed"
    else
      register_close "failed" "claude -p returned non-zero"
    fi
  ) >/dev/null 2>&1 &
  echo $!
}

register_start

if [[ "$MODE" == "foreground" ]]; then
  if run_claude; then
    register_session_id
    register_close "closed"
    echo "claude-exec.sh: task '$TASK' complete. Log: $LOG_PATH"
    exit 0
  fi
  register_session_id
  register_close "failed" "claude -p returned non-zero"
  echo "claude-exec.sh: task '$TASK' failed. See $LOG_PATH" >&2
  exit 1
fi

PID="$(dispatch_background)"
echo "claude-exec.sh: task '$TASK' dispatched in background (pid $PID). Log: $LOG_PATH"

health_check "$PID" 45 count_type_events "event"
