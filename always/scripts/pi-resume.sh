#!/usr/bin/env bash
#
# pi-resume.sh — resume a prior pi session with a follow-up brief.
#
# Looks up the most recent session_id for a named task in the pi registry
# (~/.hermes/state/pi-sessions.jsonl) and runs
# `pi -p --session <uuid> "<follow-up>"`. pi sessions are stored per
# project cwd (~/.pi/agent/sessions), so run this from the same repo the
# original pi-exec.sh dispatch used.
#
# Post-run summary at /tmp/pi-<task>.post-run.md is OVERWRITTEN on each
# run (shared with pi-exec.sh), so after a resume it reflects the resume
# snapshot. This resume's log: /tmp/pi-<task>-resume.log.
#
# Usage:
#   pi-resume.sh <task-name> <follow-up-brief-path> [--foreground] [--model SLUG] [--provider NAME] [--thinking LEVEL]
#
# Exit codes:
#   0  dispatched successfully (background) or completed cleanly (foreground)
#   1  usage error / resume failed (foreground)
#   2  brief file missing
#   3  no session_id in registry for task / registry missing
#   4  pi CLI missing

set -euo pipefail

TASK=""
BRIEF=""
MODE="background"
PROVIDER="xai"
MODEL="grok-4.7"
THINKING="high"

usage() {
  cat >&2 <<EOF
Usage: pi-resume.sh <task-name> <follow-up-brief-path> [--foreground] [--model SLUG] [--provider NAME] [--thinking LEVEL]

Looks up the most recent session_id for <task-name> in the pi session
registry at ~/.hermes/state/pi-sessions.jsonl, then resumes that session
with the follow-up brief. Run from the same repo as the original dispatch
(pi sessions are cwd-keyed).

Options:
  --foreground      Block until pi completes.
  --provider NAME   Provider. Default: xai.
  --model SLUG      Model to run. Default: grok-4.7.
  --thinking LEVEL  Thinking level (off|minimal|low|medium|high|xhigh|max). Default: high.
EOF
  exit 1
}

if [[ $# -lt 2 ]]; then usage; fi
TASK="$1"; shift
BRIEF="$1"; shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --foreground) MODE="foreground"; shift ;;
    --provider|--model|--thinking)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "pi-resume.sh: $1 requires a value" >&2; usage
      fi
      case "$1" in
        --provider) PROVIDER="$2" ;;
        --model) MODEL="$2" ;;
        --thinking) THINKING="$2" ;;
      esac
      shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ---- validation ----

if [[ ! -f "$BRIEF" ]]; then
  echo "pi-resume.sh: brief file not found: $BRIEF" >&2
  exit 2
fi

if ! command -v pi >/dev/null 2>&1; then
  echo "pi-resume.sh: 'pi' CLI not found on PATH" >&2
  exit 4
fi

WRAPPER="pi-resume.sh"
AGENT="pi"
# Registry path, line writer, post-run summary and liveness check.
# shellcheck source=lib/wrapper-common.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/wrapper-common.sh"
REGISTRY="$PI_REGISTRY"
if [[ ! -f "$REGISTRY" ]]; then
  echo "pi-resume.sh: registry not found at $REGISTRY" >&2
  exit 3
fi

# ---- look up session_id ----

# Last matching line is newest (append-only chronological registry).
SESSION_ID="$(
  { grep "\"task\":\"$TASK\"" "$REGISTRY" \
    | grep -oE '"session_id":"[0-9a-f-]{36}"' \
    | tail -1 \
    | sed -E 's/"session_id":"([0-9a-f-]{36})"/\1/'; } || true
)"

if [[ -z "$SESSION_ID" ]]; then
  echo "pi-resume.sh: no session_id captured for task '$TASK'." >&2
  echo "  - Registry scanned: $REGISTRY" >&2
  echo "  - Did the original task complete via pi-exec.sh? Check its health-check output." >&2
  exit 3
fi

# ---- paths ----

LOG_PATH="/tmp/pi-${TASK}-resume.log"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

# ---- post-run summary ----

write_post_run_summary() {
  write_shell_post_run "/tmp/pi-${TASK}.post-run.md" "pi-resume post-run summary" \
    "$1" pi_final_message \
    "note: this is a RESUME run; original run log: /tmp/pi-${TASK}.log" \
    "log: $LOG_PATH" "session_id: $SESSION_ID"
}

# ---- registry helper ----

# Every line carries a normalized "status" so pi-wait.sh matches a resume the
# same way it matches a fresh run; "reason" only when there is one.
register_entry() {
  local event="$1"; local extra="${2:-}"
  local fields
  fields="\"event\":\"$event\",\"status\":\"$(resume_event_status "$event")\",\"session_id\":\"$SESSION_ID\""
  if [[ -n "$extra" ]]; then fields+=",\"reason\":\"$extra\""; fi
  registry_line "$fields"
}

# ---- dispatch ----

PI_FLAGS=(
  -p --mode json
  --session "$SESSION_ID"
  --provider "$PROVIDER"
  --model "$MODEL"
  --thinking "$THINKING"
)

dispatch_and_wait() {
  pi "${PI_FLAGS[@]}" "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1
}

# CAUTION — the detached run shares the caller's process group; dispatch
# from a timeout-safe shell (Claude Code: run_in_background).
dispatch_background() {
  # stdout/stderr redirected away — a backgrounded child holding the
  # command substitution's pipe open blocks dispatch until pi exits and
  # pollutes $PID (see pi-exec.sh dispatch_background).
  (
    if pi "${PI_FLAGS[@]}" "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1; then
      register_entry "resume_closed"
      write_post_run_summary "closed"
    else
      register_entry "resume_failed" "pi -p resume returned non-zero"
      write_post_run_summary "failed"
    fi
  ) >/dev/null 2>&1 &
  echo $!
}

register_entry "resume_started"

if [[ "$MODE" == "foreground" ]]; then
  if dispatch_and_wait; then
    register_entry "resume_closed"
    write_post_run_summary "closed"
    echo "pi-resume.sh: task '$TASK' resumed successfully. Log: $LOG_PATH"
    exit 0
  else
    register_entry "resume_failed" "pi -p resume returned non-zero"
    write_post_run_summary "failed"
    echo "pi-resume.sh: task '$TASK' resume failed. See $LOG_PATH" >&2
    exit 1
  fi
fi

PID="$(dispatch_background)"
echo "pi-resume.sh: task '$TASK' resumed in background (pid $PID, session $SESSION_ID). Log: $LOG_PATH"
resume_liveness_check "$PID" count_type_events
