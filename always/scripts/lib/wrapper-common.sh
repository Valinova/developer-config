#!/usr/bin/env bash
#
# wrapper-common.sh — mechanics shared by the claude / codex / pi dispatch
# wrappers: registry line writer and current-run reader, the post-run summary,
# the first-event health check, the resume liveness check, and the wait and
# status loops. A separate lib rather than claude-registry.sh because it serves
# all three agent families; claude-registry.sh stays the claude registry's face.
# Codex's grammar and log parsing stay in codex_registry.py; this lib only
# drives the loops around them.
#
# Source it; nothing runs at source time. The helpers read the caller's
# globals: WRAPPER (script name, prefixes messages), AGENT, TASK, LOG_PATH,
# REPO_ROOT, and REGISTRY (registry_line only). health_check calls the
# caller's register_session_id and register_close.
#
# Provides:
#   $PI_REGISTRY                     pi registry path
#   registry_line <json-fields>      append one claude/pi line to $REGISTRY
#   registry_run_lines <reg> <task>  lines of the task's most recent run
#   resume_event_status <event>      normalized status for a resume event
#   count_type_events <log>          stream-json lines ('{"type":...') in a log
#   pi_final_message                 last pi turn_end text in $LOG_PATH
#   write_shell_post_run <out> <title> <status> <final-fn> [meta-line ...]
#   health_check <pid> <max-wait> <count-fn> <noun> [stall-hint]   (exits)
#   resume_liveness_check <pid> <count-fn>                         (exits)
#   wait_main <registry> <failed-alternation> <failure-label> "$@" (exits)
#   status_verdict <registry> <failed-alternation> <failure-label> (exits)

# Same line grammar as the claude registry; separate file so task names never
# collide across agents.
PI_REGISTRY="$HOME/.hermes/state/pi-sessions.jsonl"

registry_line() {
  printf '{"ts":"%s","agent":"%s","source":"claude-code","task":"%s",%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$AGENT" "$TASK" "$1" >> "$REGISTRY"
}

# The registry is append-only and durable across sessions, so a task name
# reused later still has the earlier run's close line on disk. A run therefore
# starts at that task's most recent "start" OR "resume_started" event;
# everything before it belongs to a run that already finished.
registry_run_lines() {
  awk -v t="\"task\":\"$2\"" -v s='"event":"start"' -v rs='"event":"resume_started"' '
    index($0, t) {
      if (index($0, s) || index($0, rs)) { delete buf; n = 0 }
      buf[n++] = $0
    }
    END { for (i = 0; i < n; i++) print buf[i] }
  ' "$1"
}

# Every resume line carries a normalized "status" so status-keyed waiters
# match a resume the same way they match a fresh run. The event names
# themselves (resume_started/resume_closed/resume_failed) stay for Hermes.
resume_event_status() {
  case "$1" in
    *_started|started|running)     echo "running" ;;
    *_closed|close|closed)         echo "closed" ;;
    *_failed|failed|error|stalled) echo "error" ;;
    *)                             echo "running" ;;
  esac
}

count_type_events() {
  local n
  n="$(grep -c '^{"type":' "$1" 2>/dev/null)" || true
  echo "${n:-0}"
}

pi_final_message() {
  grep '^{"type":"turn_end"' "$LOG_PATH" 2>/dev/null \
    | tail -1 \
    | python3 -c 'import json,sys; line=sys.stdin.read().strip(); m=json.loads(line)["message"] if line else {}; print("\n".join(c.get("text","") for c in m.get("content",[]) if c.get("type")=="text") or "(no turn_end message found in log)")' 2>/dev/null \
    || echo "(no turn_end message found in log)"
}

_post_run_git_section() {
  local header="$1"; shift
  echo "## $header"
  echo '```'
  ( cd "$REPO_ROOT" && git "$@" 2>/dev/null ) || echo "(no repo / git unavailable)"
  echo '```'
  echo ""
}

# Post-run summary for the shell-written families (codex's comes from
# codex_registry.py). Staged / unstaged / untracked stay separate so the
# orchestrator can tell the agent's work from dangling extras. Each meta line
# is printed as "- <line>" after status and finished_at.
write_shell_post_run() {
  local out="$1" title="$2" status="$3" final_fn="$4"; shift 4
  local line
  {
    echo "# $title — task: $TASK"
    echo ""
    echo "- status: $status"
    echo "- finished_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for line in "$@"; do echo "- $line"; done
    echo ""
    _post_run_git_section 'Staged (`git diff --cached --stat`)' diff --cached --stat
    _post_run_git_section 'Unstaged (`git diff --stat`)' diff --stat
    _post_run_git_section 'Untracked (`git ls-files --others --exclude-standard`)' ls-files --others --exclude-standard
    echo "## Final assistant message"
    echo '```'
    "$final_fn"
    echo '```'
  } > "$out" 2>/dev/null || true
  echo "$WRAPPER: post-run summary → $out"
}

# First-event check after a background dispatch: a healthy agent emits its
# first stream event at once, so this normally clears on the first poll; it
# exists to surface hangs and auth/startup failures instead of a silent wait.
# <noun> is "event" (claude) or "JSON event" (codex, pi); <stall-hint> is
# appended to the stalled close reason. Always exits the wrapper.
health_check() {
  local pid="$1" max_wait="$2" count_fn="$3" noun="$4" hint="${5:-}"
  local waited=0 interval=5 n
  while (( waited < max_wait )); do
    n="$("$count_fn" "$LOG_PATH")"
    if (( n > 0 )); then
      if [[ "$noun" == "event" ]]; then
        echo "$WRAPPER: health check ok — first event within ${waited}s"
      else
        echo "$WRAPPER: health check ok — $n event(s) emitted within ${waited}s"
      fi
      register_session_id
      exit 0
    fi
    sleep "$interval"
    waited=$(( waited + interval ))
    # Break early if the process already exited (fast failure).
    if ! kill -0 "$pid" 2>/dev/null; then
      n="$("$count_fn" "$LOG_PATH")"
      if (( n > 0 )); then
        register_session_id
        echo "$WRAPPER: task finished before health-check window. Log: $LOG_PATH"
        exit 0
      fi
      # The worker also writes its own close event; this one narrates the
      # early-exit failure mode so operators see it without hunting the registry.
      register_close "failed" "exited before first $noun"
      echo "$WRAPPER: task '$TASK' exited without emitting events. See $LOG_PATH" >&2
      exit 4
    fi
  done
  # A codex worker is its own session/group leader (setsid): kill the whole
  # group so the codex child dies with the leader. A claude/pi worker is a
  # plain subshell, never a group leader, so the group kill fails and the
  # plain kill runs.
  kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
  register_close "stalled" "no ${noun}s within ${max_wait}s${hint}"
  echo "$WRAPPER: task '$TASK' stalled — no ${noun}s within ${max_wait}s. Killed pid $pid. See $LOG_PATH" >&2
  exit 4
}

# Quick liveness check (3s) after a background resume — resume is assumed to
# emit events as fast as a fresh run. Always exits the wrapper.
resume_liveness_check() {
  local pid="$1" count_fn="$2"
  sleep 3
  if ! kill -0 "$pid" 2>/dev/null; then
    # Already exited; the worker already wrote the close event.
    if (( $("$count_fn" "$LOG_PATH") > 0 )); then
      echo "$WRAPPER: task completed near-instantly. Log: $LOG_PATH"
      exit 0
    fi
    echo "$WRAPPER: task '$TASK' resume exited without events. See $LOG_PATH" >&2
    exit 1
  fi
  echo "$WRAPPER: process alive, monitor with 'tail -f $LOG_PATH'"
  exit 0
}

# Body of <agent>-wait.sh: block until the task's CURRENT run (the caller's
# current_run_lines) closes. Exit code is the entire signal: 0 closed,
# 1 usage, 2 registry missing, 3 timeout, 4 failure terminal.
wait_main() {
  local registry="$1" failed="\"status\":\"($2)\"" label="$3"; shift 3
  local timeout start run
  if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $WRAPPER <task-name> [timeout-seconds]" >&2
    exit 1
  fi
  TASK="$1"
  timeout="${2:-3600}"
  if [[ ! -f "$registry" ]]; then
    echo "$WRAPPER: registry not found at $registry" >&2
    exit 2
  fi
  start=$(date +%s)
  while true; do
    run="$(current_run_lines "$TASK")"
    # Full reads (no grep -q): an early-exiting reader can fail printf with
    # EPIPE, and pipefail would turn a match into a miss.
    if printf '%s\n' "$run" | grep -E '"status":"closed"' >/dev/null 2>&1; then
      exit 0
    fi
    # Don't sit through the timeout on a failed/stalled run or resume.
    if printf '%s\n' "$run" | grep -E "$failed" >/dev/null 2>&1; then
      echo "$WRAPPER: task '$TASK' reached a failure terminal${label}. See /tmp/${AGENT}-${TASK}.log" >&2
      exit 4
    fi
    if [[ "$timeout" -gt 0 ]] && (( $(date +%s) - start >= timeout )); then
      echo "$WRAPPER: timeout after ${timeout}s waiting for task '$TASK' to close" >&2
      exit 3
    fi
    sleep 5
  done
}

# Body of <agent>-status.sh after it has set TASK and LOG_PATH: a one-shot,
# read-only verdict over the task's CURRENT run (the caller's
# current_run_lines). See the calling script's header for verdicts and codes.
status_verdict() {
  local registry="$1" failed="\"status\":\"($2)\"" label="$3"
  local post_run="/tmp/${AGENT}-${TASK}.post-run.md" run age
  local stale_after=300
  if [[ ! -f "$registry" ]]; then
    echo "$WRAPPER: registry not found at $registry" >&2
    exit 2
  fi
  run="$(current_run_lines "$TASK")"
  if [[ -z "$run" ]]; then
    echo "UNKNOWN — no start event for task '$TASK' in $registry"
    exit 6
  fi
  local last_ts
  last_ts="$(printf '%s\n' "$run" | tail -n 1 | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')"

  if printf '%s\n' "$run" | grep -E '"status":"closed"' >/dev/null 2>&1; then
    echo "CLOSED — task '$TASK' closed at $last_ts"
    if [[ -f "$post_run" ]]; then
      echo "post-run: $post_run"
    else
      echo "post-run: MISSING (expected $post_run) — read the log tail instead: $LOG_PATH"
    fi
    exit 0
  fi

  if printf '%s\n' "$run" | grep -E "$failed" >/dev/null 2>&1; then
    echo "FAILED — task '$TASK' hit a failure terminal ($label) at $last_ts"
    echo "log: $LOG_PATH"
    exit 4
  fi

  if [[ ! -f "$LOG_PATH" ]]; then
    echo "STALE — task '$TASK' has a start event but no log at $LOG_PATH"
    echo "registry says started; the dispatch may have died before first write."
    exit 5
  fi
  # GNU first, BSD second. On GNU coreutils `-f` means --file-system, so
  # `stat -f %m <path>` parses as two file arguments: %m fails, the path
  # succeeds and prints its filesystem block to STDOUT, which then lands
  # inside the arithmetic below. Ordering matters, not just the redirect.
  local mtime
  mtime="$(stat -c %Y "$LOG_PATH" 2>/dev/null || stat -f %m "$LOG_PATH" 2>/dev/null)"
  age=$(( $(date +%s) - mtime ))

  if [[ "$age" -le "$stale_after" ]]; then
    echo "RUNNING — task '$TASK' log active ${age}s ago"
    echo "log: $LOG_PATH ($(du -h "$LOG_PATH" | cut -f1 | tr -d ' ') so far)"
    exit 3
  fi

  echo "STALE — task '$TASK' has no terminal event and the log has been quiet for ${age}s"
  echo "Could be a long reasoning stretch OR an orphaned run. Inspect before acting:"
  echo "  tail -c 2000 $LOG_PATH"
  echo "Never pattern-kill; if truly dead, re-dispatch under a fresh -r2 name."
  exit 5
}
