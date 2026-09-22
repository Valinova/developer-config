#!/usr/bin/env bash
#
# claude-exec.sh — wrapper for delegating a bounded task to `claude -p`
# (Opus 5.5) at a chosen effort, from a Claude Code orchestrator.
#
# Why this exists: native Agent-tool subagents inherit the session's model,
# effort, and the whole context window. A `claude -p` process starts from
# zero plus the brief and takes --effort as a flag, so it is the lane for
# concentrated, well-briefed implementation at a rung different from the
# orchestrator's (doctrine: instructions/model-selection.md "Effort" and
# "Fresh window or inherited context").
#
# Deliberately simpler than codex-exec.sh: no stdin-hang workaround, no
# sandbox git dance, no worktree-index warning — `claude -p` has none of
# those problems. What it keeps: background dispatch, a durable registry
# line, session-id capture for --resume, a 45s first-event check, and a
# post-run summary. Runs with --dangerously-skip-permissions; the PreToolUse
# hooks in always/settings.json (git backstop, dispatch guard) still apply
# inside the child because ~/.claude/settings.json is a symlink to it.
#
# Registry: ~/.hermes/state/claude-sessions.jsonl (same line grammar as the
# pi registry; separate file so task names never collide across agents).
#
# Usage:
#   claude-exec.sh <task-name> <brief-path> [--effort LEVEL] [--model SLUG] [--resume] [--foreground] [--log <path>]
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
LOG_OVERRIDE=""
MODEL="opus"
EFFORT="medium"
RESUME="no"

usage() {
  cat >&2 <<EOF
Usage: claude-exec.sh <task-name> <brief-path> [--effort LEVEL] [--model SLUG] [--resume] [--foreground] [--log <path>]

Arguments:
  <task-name>     Short identifier, used in the log file name and registry.
  <brief-path>    File containing the task brief (passed to claude -p as the prompt).

Options:
  --effort LEVEL  low|medium|high|xhigh|max. Default: medium.
  --model SLUG    Model to run. Default: opus.
  --resume        Resume the session last captured for <task-name>.
  --foreground    Block until claude completes. Default is background dispatch.
  --log PATH      Override default log file. Default: /tmp/claude-<task-name>.log
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
    --effort|--model|--log)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "claude-exec.sh: $1 requires a value" >&2; usage
      fi
      case "$1" in
        --effort) EFFORT="$2" ;;
        --model) MODEL="$2" ;;
        --log) LOG_OVERRIDE="$2" ;;
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

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
LOG_PATH="${LOG_OVERRIDE:-/tmp/claude-${TASK}.log}"
REGISTRY="${CLAUDE_REGISTRY_PATH:-$HOME/.hermes/state/claude-sessions.jsonl}"
mkdir -p "$(dirname "$LOG_PATH")" "$(dirname "$REGISTRY")"

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

registry_line() {
  printf '{"ts":"%s","agent":"claude","source":"claude-code","task":"%s",%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TASK" "$1" >> "$REGISTRY"
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

write_post_run_summary() {
  local status="$1"
  local post_run_path="/tmp/claude-${TASK}.post-run.md"
  {
    echo "# claude-exec post-run summary — task: $TASK"
    echo ""
    echo "- status: $status"
    echo "- finished_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- model / effort: $MODEL / $EFFORT"
    echo "- log: $LOG_PATH"
    echo "- session_id: $(extract_session_id)"
    echo ""
    echo "## Staged (\`git diff --cached --stat\`)"
    echo '```'
    ( cd "$REPO_ROOT" && git diff --cached --stat 2>/dev/null ) || echo "(no repo / git unavailable)"
    echo '```'
    echo ""
    echo "## Unstaged (\`git diff --stat\`)"
    echo '```'
    ( cd "$REPO_ROOT" && git diff --stat 2>/dev/null ) || echo "(no repo / git unavailable)"
    echo '```'
    echo ""
    echo "## Untracked (\`git ls-files --others --exclude-standard\`)"
    echo '```'
    ( cd "$REPO_ROOT" && git ls-files --others --exclude-standard 2>/dev/null ) || echo "(no repo / git unavailable)"
    echo '```'
    echo ""
    echo "## Final assistant message"
    echo '```'
    grep -F '"type":"result"' "$LOG_PATH" 2>/dev/null | tail -1 \
      | python3 -c 'import json,sys; line=sys.stdin.read().strip(); d=json.loads(line) if line else {}; print(d.get("result") or "(no result text)"); c=d.get("total_cost_usd"); print(f"\n[cost_usd={c}]" if c is not None else "")' 2>/dev/null \
      || echo "(no result event found in log)"
    echo '```'
  } > "$post_run_path" 2>/dev/null || true
  echo "claude-exec.sh: post-run summary → $post_run_path"
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

# First-event check: claude emits a session line immediately on a healthy
# start, so this normally clears on the first poll; it exists to surface
# auth/startup failures instead of a silent wait.
WAITED=0
MAX_WAIT=45
SLEEP_INTERVAL=5
has_events() { [[ -f "$LOG_PATH" ]] && grep -q '^{"type":' "$LOG_PATH" 2>/dev/null; }
while (( WAITED < MAX_WAIT )); do
  if has_events; then
    echo "claude-exec.sh: health check ok — first event within ${WAITED}s"
    register_session_id
    exit 0
  fi
  sleep "$SLEEP_INTERVAL"
  WAITED=$(( WAITED + SLEEP_INTERVAL ))
  if ! kill -0 "$PID" 2>/dev/null; then
    if has_events; then
      register_session_id
      echo "claude-exec.sh: task finished before health-check window. Log: $LOG_PATH"
      exit 0
    fi
    register_close "failed" "exited before first event"
    echo "claude-exec.sh: task '$TASK' exited without emitting events. See $LOG_PATH" >&2
    exit 4
  fi
done

kill "$PID" 2>/dev/null || true
register_close "stalled" "no events within ${MAX_WAIT}s"
echo "claude-exec.sh: task '$TASK' stalled — no events within ${MAX_WAIT}s. Killed pid $PID. See $LOG_PATH" >&2
exit 4
