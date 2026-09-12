#!/usr/bin/env bash
#
# pi-exec.sh — standard wrapper for delegating tasks to `pi -p` (grok-4.6).
#
# Mirrors codex-exec.sh: background dispatch by default, durable registry
# events, a 45s first-event health check, and a post-run diff summary.
# Differences from codex worth knowing:
#   - pi is NOT sandboxed — it can write .git/. Delegation policy (not
#     mechanics) keeps git centralized: briefs must instruct pi to make NO
#     git writes at all (no add, no commit); the invoking orchestrator
#     stages and commits. The vendored destructive-guard extension
#     hard-blocks only unrecoverable ops (rm -rf, reset --hard, clean -f,
#     force push) in non-interactive mode. bash-timeout-guard caps hung
#     bash timeouts so they cannot block forever.
#   - pi emits its session id on the FIRST event line
#     ({"type":"session","id":"<uuid>"}), so session capture is immediate.
#   - Sessions persist under ~/.pi/agent/sessions keyed by cwd; resume with
#     pi-resume.sh <task> from the same repo.
#
# Registry: ~/.hermes/state/pi-sessions.jsonl (separate from the codex
# registry so task names never collide across agents; same line grammar).
#
# Usage:
#   pi-exec.sh <task-name> <brief-path> [--foreground] [--model SLUG] [--provider NAME] [--thinking LEVEL] [--log <path>]
#
# Exit codes:
#   0  dispatched successfully (background) or completed cleanly (foreground)
#   1  usage error / failed (foreground)
#   2  brief file missing
#   3  pi CLI missing
#   4  health check failed (task killed)

set -euo pipefail

# ---- args ----

TASK=""
BRIEF=""
MODE="background"
LOG_OVERRIDE=""
PROVIDER="xai"
MODEL="grok-4.6"
THINKING="high"

usage() {
  cat >&2 <<EOF
Usage: pi-exec.sh <task-name> <brief-path> [--foreground] [--model SLUG] [--provider NAME] [--thinking LEVEL] [--log <path>]

Arguments:
  <task-name>     Short identifier, used in the log file name and registry.
  <brief-path>    File containing the task brief (passed to pi as the prompt).

Options:
  --foreground      Block until pi completes. Default is background dispatch.
  --provider NAME   Provider. Default: xai.
  --model SLUG      Model to run. Default: grok-4.6.
  --thinking LEVEL  Thinking level (off|minimal|low|medium|high|xhigh|max). Default: high.
  --log PATH        Override default log file. Default: /tmp/pi-<task-name>.log
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
        echo "pi-exec.sh: --provider requires a value" >&2; usage
      fi
      PROVIDER="$2"; shift 2 ;;
    --model)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "pi-exec.sh: --model requires a value" >&2; usage
      fi
      MODEL="$2"; shift 2 ;;
    --thinking)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "pi-exec.sh: --thinking requires a value" >&2; usage
      fi
      THINKING="$2"; shift 2 ;;
    --log) LOG_OVERRIDE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ---- validation ----

if [[ ! -f "$BRIEF" ]]; then
  echo "pi-exec.sh: brief file not found: $BRIEF" >&2
  exit 2
fi

if ! command -v pi >/dev/null 2>&1; then
  echo "pi-exec.sh: 'pi' CLI not found on PATH" >&2
  exit 3
fi

# ---- paths ----

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

DEFAULT_LOG="/tmp/pi-${TASK}.log"
LOG_PATH="${LOG_OVERRIDE:-$DEFAULT_LOG}"
# Canonical pi session registry — durable, append-only. Same line grammar as
# the codex registry but a separate file so agents' task names never collide.
REGISTRY="$HOME/.hermes/state/pi-sessions.jsonl"

mkdir -p "$(dirname "$LOG_PATH")" "$(dirname "$REGISTRY")"

# ---- registry helpers ----

# pi's first JSON event is {"type":"session","id":"<uuid>",...} — the session
# id pi-resume.sh will pass back via --session.
extract_session_id() {
  head -5 "$LOG_PATH" 2>/dev/null \
    | grep -oE '"type":"session"[^}]*"id":"[0-9a-f-]{36}"' \
    | head -1 \
    | grep -oE '[0-9a-f-]{36}'
}

register_start() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"ts":"%s","agent":"pi","source":"claude-code","task":"%s","event":"start","cwd":"%s","status":"running","log_file":"%s"}\n' \
    "$ts" "$TASK" "$REPO_ROOT" "$LOG_PATH" >> "$REGISTRY"
}

register_session_id() {
  local session_id
  session_id="$(extract_session_id)"
  if [[ -n "$session_id" ]]; then
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '{"ts":"%s","agent":"pi","source":"claude-code","task":"%s","event":"session_captured","session_id":"%s"}\n' \
      "$ts" "$TASK" "$session_id" >> "$REGISTRY"
    echo "pi-exec.sh: session_id=$session_id — resume with pi-resume.sh $TASK <brief>"
  fi
}

register_close() {
  local status="$1"; local reason="${2:-}"
  local ts session_id
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  session_id="$(extract_session_id)"
  printf '{"ts":"%s","agent":"pi","source":"claude-code","task":"%s","event":"close","status":"%s","session_id":"%s","reason":"%s"}\n' \
    "$ts" "$TASK" "$status" "$session_id" "$reason" >> "$REGISTRY"
  write_post_run_summary "$status"
}

# Post-run diff summary — staged vs. unstaged kept separate, mirroring
# codex-exec.sh. With the no-git-writes brief policy the staged section
# should read empty after a compliant run; anything there is a policy
# violation worth flagging.
write_post_run_summary() {
  local status="$1"
  local post_run_path="/tmp/pi-${TASK}.post-run.md"
  local repo_root="$REPO_ROOT"

  {
    echo "# pi-exec post-run summary — task: $TASK"
    echo ""
    echo "- status: $status"
    echo "- finished_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- log: $LOG_PATH"
    echo "- session_id: $(extract_session_id)"
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

  echo "pi-exec.sh: post-run summary → $post_run_path"
}

# ---- dispatch ----

# Stdin is redirected from /dev/null as a matter of hygiene (codex's stdin
# hang is codex-specific, but the redirect is harmless and also surfaces
# fast auth/startup failures instead of a wait).

PI_FLAGS=(
  -p --mode json
  --provider "$PROVIDER"
  --model "$MODEL"
  --thinking "$THINKING"
)

dispatch_and_wait() {
  pi "${PI_FLAGS[@]}" "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1
}

# Background mode: a subshell runs pi, then writes the close event when it
# exits. if/else avoids the inherited `set -e` killing the subshell before
# the close event runs. CAUTION — the detached run shares the caller's
# process group: dispatch from a timeout-safe shell (Claude Code:
# run_in_background), same as codex-exec.sh.
dispatch_background() {
  # The detached subshell's stdout/stderr MUST be redirected away: this
  # function is called inside a command substitution, and a backgrounded
  # child holding the substitution's pipe open (1) blocks the "background"
  # dispatch until pi exits and (2) pollutes $PID with register_close's
  # echo output (observed 2026-07-20 on the first smoke test).
  (
    if pi "${PI_FLAGS[@]}" "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1; then
      register_close "closed"
    else
      register_close "failed" "pi -p returned non-zero"
    fi
  ) >/dev/null 2>&1 &
  echo $!
}

register_start

if [[ "$MODE" == "foreground" ]]; then
  if dispatch_and_wait; then
    register_session_id
    register_close "closed"
    echo "pi-exec.sh: task '$TASK' complete. Log: $LOG_PATH"
    exit 0
  else
    register_session_id
    register_close "failed" "pi -p returned non-zero"
    echo "pi-exec.sh: task '$TASK' failed. See $LOG_PATH" >&2
    exit 1
  fi
fi

# Background mode with health check: wait up to 45 seconds for the first
# JSON event (pi emits {"type":"session",...} immediately on a healthy
# start, so this normally clears on the first poll).
PID="$(dispatch_background)"
echo "pi-exec.sh: task '$TASK' dispatched in background (pid $PID). Log: $LOG_PATH"

WAITED=0
MAX_WAIT=45
SLEEP_INTERVAL=5
while (( WAITED < MAX_WAIT )); do
  if [[ -f "$LOG_PATH" ]] && grep -c '^{"type":' "$LOG_PATH" >/dev/null 2>&1; then
    JSON_COUNT="$(grep -c '^{"type":' "$LOG_PATH" 2>/dev/null || echo 0)"
    if (( JSON_COUNT > 0 )); then
      echo "pi-exec.sh: health check ok — $JSON_COUNT event(s) emitted within ${WAITED}s"
      register_session_id
      exit 0
    fi
  fi
  sleep "$SLEEP_INTERVAL"
  WAITED=$(( WAITED + SLEEP_INTERVAL ))
  # Break early if the process already exited (fast failure).
  if ! kill -0 "$PID" 2>/dev/null; then
    if [[ -f "$LOG_PATH" ]] && grep -c '^{"type":' "$LOG_PATH" >/dev/null 2>&1; then
      JSON_COUNT="$(grep -c '^{"type":' "$LOG_PATH" 2>/dev/null || echo 0)"
      if (( JSON_COUNT > 0 )); then
        register_session_id
        echo "pi-exec.sh: task finished before health-check window. Log: $LOG_PATH"
        exit 0
      fi
    fi
    register_close "failed" "exited before first JSON event"
    echo "pi-exec.sh: task '$TASK' exited without emitting events. See $LOG_PATH" >&2
    exit 4
  fi
done

kill "$PID" 2>/dev/null || true
register_close "stalled" "no JSON events within ${MAX_WAIT}s"
echo "pi-exec.sh: task '$TASK' stalled — no JSON events within ${MAX_WAIT}s. Killed pid $PID. See $LOG_PATH" >&2
exit 4
