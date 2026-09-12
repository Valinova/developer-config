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
#   pi-resume.sh <task-name> <follow-up-brief-path> [--foreground] [--model SLUG] [--provider NAME] [--thinking LEVEL] [--log <path>]
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
LOG_OVERRIDE=""
PROVIDER="xai"
MODEL="grok-4.6"
THINKING="high"

usage() {
  cat >&2 <<EOF
Usage: pi-resume.sh <task-name> <follow-up-brief-path> [--foreground] [--model SLUG] [--provider NAME] [--thinking LEVEL] [--log <path>]

Looks up the most recent session_id for <task-name> in the pi session
registry at ~/.hermes/state/pi-sessions.jsonl, then resumes that session
with the follow-up brief. Run from the same repo as the original dispatch
(pi sessions are cwd-keyed).

Options:
  --foreground      Block until pi completes.
  --provider NAME   Provider. Default: xai.
  --model SLUG      Model to run. Default: grok-4.6.
  --thinking LEVEL  Thinking level (off|minimal|low|medium|high|xhigh|max). Default: high.
  --log PATH        Override default log file. Default: /tmp/pi-<task>-resume.log
EOF
  exit 1
}

if [[ $# -lt 2 ]]; then usage; fi
TASK="$1"; shift
BRIEF="$1"; shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --foreground) MODE="foreground"; shift ;;
    --provider)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "pi-resume.sh: --provider requires a value" >&2; usage
      fi
      PROVIDER="$2"; shift 2 ;;
    --model)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "pi-resume.sh: --model requires a value" >&2; usage
      fi
      MODEL="$2"; shift 2 ;;
    --thinking)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "pi-resume.sh: --thinking requires a value" >&2; usage
      fi
      THINKING="$2"; shift 2 ;;
    --log) LOG_OVERRIDE="$2"; shift 2 ;;
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

REGISTRY="$HOME/.hermes/state/pi-sessions.jsonl"
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

DEFAULT_LOG="/tmp/pi-${TASK}-resume.log"
LOG_PATH="${LOG_OVERRIDE:-$DEFAULT_LOG}"

mkdir -p "$(dirname "$LOG_PATH")"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

# ---- post-run summary ----

write_post_run_summary() {
  local status="$1"
  local post_run_path="/tmp/pi-${TASK}.post-run.md"
  local repo_root="$REPO_ROOT"

  {
    echo "# pi-resume post-run summary — task: $TASK"
    echo ""
    echo "- status: $status"
    echo "- finished_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- note: this is a RESUME run; original run log: /tmp/pi-${TASK}.log"
    echo "- log: $LOG_PATH"
    echo "- session_id: $SESSION_ID"
    echo ""
    echo "## Staged (\`git diff --cached --stat\`) — should be EMPTY (pi must not stage)"
    echo '```'
    ( cd "$repo_root" && git diff --cached --stat 2>/dev/null ) || echo "(no repo / git unavailable)"
    echo '```'
    echo ""
    echo "## Unstaged (\`git diff --stat\`)"
    echo '```'
    ( cd "$repo_root" && git diff --stat 2>/dev/null ) || echo "(no repo / git unavailable)"
    echo '```'
    echo ""
    echo "## Untracked (\`git ls-files --others --exclude-standard\`)"
    echo '```'
    ( cd "$repo_root" && git ls-files --others --exclude-standard 2>/dev/null ) || echo "(no repo / git unavailable)"
    echo '```'
    echo ""
    echo "## Final assistant message"
    echo '```'
    grep '^{"type":"turn_end"' "$LOG_PATH" 2>/dev/null \
      | tail -1 \
      | python3 -c 'import json,sys; line=sys.stdin.read().strip(); m=json.loads(line)["message"] if line else {}; print("\n".join(c.get("text","") for c in m.get("content",[]) if c.get("type")=="text") or "(no turn_end message found in log)")' 2>/dev/null \
      || echo "(no turn_end message found in log)"
    echo '```'
  } > "$post_run_path" 2>/dev/null || true

  echo "pi-resume.sh: post-run summary → $post_run_path"
}

# ---- registry helper ----

register_entry() {
  local event="$1"; local extra="${2:-}"
  local ts status
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Every line carries a normalized "status" so pi-wait.sh matches a resume
  # the same way it matches a fresh run.
  case "$event" in
    *_started|started|running) status="running" ;;
    *_closed|close|closed)     status="closed" ;;
    *_failed|failed|error|stalled) status="error" ;;
    *)                          status="running" ;;
  esac
  if [[ -n "$extra" ]]; then
    printf '{"ts":"%s","agent":"pi","source":"claude-code","task":"%s","event":"%s","status":"%s","session_id":"%s","reason":"%s"}\n' \
      "$ts" "$TASK" "$event" "$status" "$SESSION_ID" "$extra" >> "$REGISTRY"
  else
    printf '{"ts":"%s","agent":"pi","source":"claude-code","task":"%s","event":"%s","status":"%s","session_id":"%s"}\n' \
      "$ts" "$TASK" "$event" "$status" "$SESSION_ID" >> "$REGISTRY"
  fi
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
# Quick liveness check (3s).
sleep 3
if ! kill -0 "$PID" 2>/dev/null; then
  if [[ -f "$LOG_PATH" ]] && grep -c '^{"type":' "$LOG_PATH" >/dev/null 2>&1; then
    JSON_COUNT="$(grep -c '^{"type":' "$LOG_PATH" 2>/dev/null || echo 0)"
    if (( JSON_COUNT > 0 )); then
      echo "pi-resume.sh: task completed near-instantly. Log: $LOG_PATH"
      exit 0
    fi
  fi
  echo "pi-resume.sh: task '$TASK' resume exited without events. See $LOG_PATH" >&2
  exit 1
fi
echo "pi-resume.sh: process alive, monitor with 'tail -f $LOG_PATH'"
exit 0
