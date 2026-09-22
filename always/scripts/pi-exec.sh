#!/usr/bin/env bash
#
# pi-exec.sh — standard wrapper for delegating tasks to `pi -p` (grok-4.7).
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
#   pi-exec.sh <task-name> <brief-path> [--foreground] [--model SLUG] [--provider NAME] [--thinking LEVEL]
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
PROVIDER="xai"
MODEL="grok-4.7"
THINKING="high"

usage() {
  cat >&2 <<EOF
Usage: pi-exec.sh <task-name> <brief-path> [--foreground] [--model SLUG] [--provider NAME] [--thinking LEVEL]

Arguments:
  <task-name>     Short identifier, used in the log file name and registry.
  <brief-path>    File containing the task brief (passed to pi as the prompt).

Options:
  --foreground      Block until pi completes. Default is background dispatch.
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
        echo "pi-exec.sh: $1 requires a value" >&2; usage
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
  echo "pi-exec.sh: brief file not found: $BRIEF" >&2
  exit 2
fi

if ! command -v pi >/dev/null 2>&1; then
  echo "pi-exec.sh: 'pi' CLI not found on PATH" >&2
  exit 3
fi

# ---- paths ----

WRAPPER="pi-exec.sh"
AGENT="pi"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
LOG_PATH="/tmp/pi-${TASK}.log"
# Registry path, line writer, post-run summary and health check.
# shellcheck source=lib/wrapper-common.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/wrapper-common.sh"
REGISTRY="$PI_REGISTRY"

mkdir -p "$(dirname "$REGISTRY")"

# ---- registry helpers ----

# pi's first JSON event is {"type":"session","id":"<uuid>",...} — the session
# id pi-resume.sh will pass back via --session. Best effort, never fatal: under
# `set -euo pipefail` a no-match grep would abort register_close before it
# writes the close line (same fix as claude-exec.sh).
extract_session_id() {
  head -5 "$LOG_PATH" 2>/dev/null \
    | grep -oE '"type":"session"[^}]*"id":"[0-9a-f-]{36}"' \
    | head -1 \
    | grep -oE '[0-9a-f-]{36}' || true
}

register_start() {
  registry_line "\"event\":\"start\",\"cwd\":\"$REPO_ROOT\",\"status\":\"running\",\"log_file\":\"$LOG_PATH\""
}

register_session_id() {
  local session_id
  session_id="$(extract_session_id)"
  if [[ -n "$session_id" ]]; then
    registry_line "\"event\":\"session_captured\",\"session_id\":\"$session_id\""
    echo "pi-exec.sh: session_id=$session_id — resume with pi-resume.sh $TASK <brief>"
  fi
}

register_close() {
  local status="$1"; local reason="${2:-}"
  registry_line "\"event\":\"close\",\"status\":\"$status\",\"session_id\":\"$(extract_session_id)\",\"reason\":\"$reason\""
  write_post_run_summary "$status"
}

write_post_run_summary() {
  write_shell_post_run "/tmp/pi-${TASK}.post-run.md" "pi-exec post-run summary" \
    "$1" pi_final_message "log: $LOG_PATH" "session_id: $(extract_session_id)"
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

# Background mode with health check (pi emits {"type":"session",...}
# immediately on a healthy start, so this normally clears on the first poll).
PID="$(dispatch_background)"
echo "pi-exec.sh: task '$TASK' dispatched in background (pid $PID). Log: $LOG_PATH"
health_check "$PID" 45 count_type_events "JSON event"
