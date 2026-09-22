#!/usr/bin/env bash
#
# codex-resume.sh — resume a prior codex session with a follow-up brief.
#
# Looks up the most recent session_id for a named task in the codex
# registry and runs `codex exec resume <uuid> "<follow-up>"`. Preserves
# the review/analysis context from the original run without resending it.
#
# In background mode, a subshell waits for codex to exit and writes a
# `resume_closed`/`resume_failed` event to the registry when codex
# actually finishes — so the registry stays authoritative.
#
# Writes a post-run summary to /tmp/codex-<task>.post-run.md when codex
# closes (success or failure). NOTE: this path is shared with
# codex-exec.sh and is OVERWRITTEN on each run, so after a resume it
# reflects the RESUME snapshot, not the original codex-exec run. The
# original run's log remains at /tmp/codex-<task>.log; this resume's log
# is at /tmp/codex-<task>-resume.log. Codex also
# persists the full transcript at
# ~/.codex/sessions/<date>/rollout-<ts>-<uuid>.jsonl for deep debugging
# or audit.
#
# Usage:
#   codex-resume.sh <task-name> <follow-up-brief-path> [--foreground] [--model SLUG] [--effort LEVEL] [--service-tier TIER]
#
# Defaults:
#   - Background dispatch.
#   - Log path: /tmp/codex-<task-name>-resume.log
#
# Exit codes:
#   0  dispatched successfully (background) or completed cleanly (foreground)
#   1  usage error / codex resume failed (foreground)
#   2  brief file missing
#   3  no session_id in registry for task
#   4  codex CLI missing

set -euo pipefail

TASK=""
BRIEF=""
MODE="background"
MODEL="gpt-6-astra"
EFFORT="high"
SERVICE_TIER="default"

usage() {
  cat >&2 <<EOF
Usage: codex-resume.sh <task-name> <follow-up-brief-path> [--foreground] [--model SLUG] [--effort LEVEL] [--service-tier TIER]

Looks up the most recent session_id for <task-name> in the canonical
codex session registry at ~/.hermes/state/codex-sessions.jsonl, then
calls codex exec resume <uuid> with the follow-up brief. The resumed
session retains all context from the original run.

Arguments:
  <task-name>               Must match the task name used with codex-exec.sh.
  <follow-up-brief-path>    File containing the follow-up instructions.

Options:
  --foreground              Block until codex completes.
  --model SLUG              Model to run. Default: gpt-6-astra.
  --effort LEVEL            Reasoning effort (none|low|medium|high|xhigh|max). Default: high.
  --service-tier TIER       Service tier for this resumed run. Default: default.
                            Pass "priority" for the Fast (2x) tier.
EOF
  exit 1
}

if [[ $# -lt 2 ]]; then usage; fi
TASK="$1"; shift
BRIEF="$1"; shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --foreground) MODE="foreground"; shift ;;
    --model|--effort|--service-tier)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "codex-resume.sh: $1 requires a value" >&2; usage
      fi
      case "$1" in
        --model) MODEL="$2" ;;
        --effort) EFFORT="$2" ;;
        --service-tier) SERVICE_TIER="$2" ;;
      esac
      shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ---- validation ----

if [[ ! -f "$BRIEF" ]]; then
  echo "codex-resume.sh: brief file not found: $BRIEF" >&2
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex-resume.sh: 'codex' CLI not found on PATH" >&2
  exit 4
fi

# Shared primitives (registry grammar, log extraction, post-run summary,
# constants) — one owner for both wrapper families. See lib/codex_registry.py.
CODEX_SOURCE="claude-code"
LIB_DIR="$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib"
# shellcheck source=lib/codex-registry.sh
source "$LIB_DIR/codex-registry.sh"
# shellcheck source=lib/wrapper-common.sh
source "$LIB_DIR/wrapper-common.sh"

if [[ ! -f "$CODEX_REGISTRY" ]]; then
  echo "codex-resume.sh: registry not found at $CODEX_REGISTRY" >&2
  exit 3
fi

# ---- look up session_id ----

# Most recent session_id recorded for this task, from the whole (append-only)
# registry — legacy `log_file`-schema lines are read the same as current ones.
SESSION_ID="$(python3 "$CODEX_REGISTRY_LIB" session-id --task "$TASK" || true)"

if [[ -z "$SESSION_ID" ]]; then
  echo "codex-resume.sh: no session_id captured for task '$TASK'." >&2
  echo "  - Registry scanned: $CODEX_REGISTRY" >&2
  echo "  - Did the original task complete via codex-exec.sh? Check its health-check output." >&2
  exit 3
fi

# ---- paths ----

WRAPPER="codex-resume.sh"
LOG_PATH="/tmp/codex-${TASK}-resume.log"

# ---- repo root + post-run helpers ----

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

# Post-run diff summary, mirroring codex-exec.sh (shared generator in the lib).
# Differences:
#   - header marks this as a RESUME run
#   - notes the original run's log path so reviewers can cross-reference
#   - falls back to the registry-resolved $SESSION_ID if the resume log
#     hasn't yet captured a thread_id (e.g. early failure)
# Overwrites /tmp/codex-<task>.post-run.md so it reflects this resume.
write_post_run_summary() {
  local status="$1"
  local post_run_path="/tmp/codex-${TASK}.post-run.md"
  local sid
  sid="$(extract_session_id "$LOG_PATH")"
  if [[ -z "$sid" ]]; then sid="$SESSION_ID"; fi

  write_post_run_summary_file "$TASK" "$status" "$LOG_PATH" "$sid" \
    "$REPO_ROOT" "$post_run_path" "codex-resume post-run summary" \
    "note: this is a RESUME run; original run log: /tmp/codex-${TASK}.log" || true

  echo "codex-resume.sh: post-run summary → $post_run_path"
}

# ---- registry helper ----

register_entry() {
  local event="$1"; local extra="${2:-}"
  local status
  status="$(resume_event_status "$event")"
  # `reason` is always present (empty when there is none) — keeping the key set
  # fixed avoids array-quoting traps in the bash 3.2 background worker.
  registry_append task "$TASK" event "$event" status "$status" \
    session_id "$SESSION_ID" log_path "$LOG_PATH" reason "$extra"
}

# ---- dispatch ----

# Always redirect stdin from /dev/null for the same reason as codex-exec.sh.

# Mirror codex-exec.sh: model / effort / tier come from flags (--model / --effort /
# --service-tier), else these defaults (gpt-6-astra / high / default). Consumers that
# want a non-default tier should pass the same choice on resume. Real `-c` overrides.
CODEX_MODEL_OVERRIDES=(
  -c "model=${MODEL}"
  -c "model_reasoning_effort=${EFFORT}"
  -c "service_tier=${SERVICE_TIER}"
)

dispatch_and_wait() {
  codex exec resume "${CODEX_MODEL_OVERRIDES[@]}" --json "$SESSION_ID" "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1
}

# Background mode: worker re-parented into ITS OWN SESSION via a python
# os.setsid() shim so it survives kills of the caller's process group
# (2026-07-16 foreground-timeout and 2026-07-27 stopped-background-task
# incidents — see codex-exec.sh dispatch_background). Close-event logic
# rides into the detached bash via `export -f`. Do NOT add `set -m` here:
# it killed the job and hung the wrapper on first field use (2026-07-16).
dispatch_background() {
  export TASK BRIEF LOG_PATH REPO_ROOT MODEL EFFORT SERVICE_TIER SESSION_ID
  # CODEX_REGISTRY_PATH is already exported by lib/codex-registry.sh.
  export CODEX_REGISTRY_LIB CODEX_SOURCE
  export -f register_entry resume_event_status registry_append write_post_run_summary \
            write_post_run_summary_file extract_session_id
  python3 - <<'PY'
import os, sys

pid = os.fork()
if pid > 0:
    print(pid)
    sys.exit(0)

os.setsid()
devnull_r = os.open(os.devnull, os.O_RDONLY)
devnull_w = os.open(os.devnull, os.O_WRONLY)
os.dup2(devnull_r, 0)
os.dup2(devnull_w, 1)
os.dup2(devnull_w, 2)

worker = r'''
if codex exec resume \
    -c "model=${MODEL}" \
    -c "model_reasoning_effort=${EFFORT}" \
    -c "service_tier=${SERVICE_TIER}" \
    --json "$SESSION_ID" "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1; then
  register_entry "resume_closed"
  write_post_run_summary "closed"
else
  register_entry "resume_failed" "codex exec resume returned non-zero"
  write_post_run_summary "failed"
fi
'''
os.execv('/bin/bash', ['bash', '-c', worker])
PY
}

register_entry "resume_started"

if [[ "$MODE" == "foreground" ]]; then
  if dispatch_and_wait; then
    register_entry "resume_closed"
    write_post_run_summary "closed"
    echo "codex-resume.sh: task '$TASK' resumed successfully. Log: $LOG_PATH"
    exit 0
  else
    register_entry "resume_failed" "codex exec resume returned non-zero"
    write_post_run_summary "failed"
    echo "codex-resume.sh: task '$TASK' resume failed. See $LOG_PATH" >&2
    exit 1
  fi
fi

PID="$(dispatch_background)"
echo "codex-resume.sh: task '$TASK' resumed in background (pid $PID, session $SESSION_ID). Log: $LOG_PATH"
resume_liveness_check "$PID" count_json_events
