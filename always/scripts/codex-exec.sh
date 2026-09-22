#!/usr/bin/env bash
#
# codex-exec.sh — standard wrapper for delegating tasks to codex exec.
#
# Why the stdin redirect, durable registry and 45s health check:
# instructions/codex-delegation.md "Caller: Claude Code and Grok Build".
#
# Usage:
#   codex-exec.sh <task-name> <brief-path> [--foreground] [--model SLUG] [--effort LEVEL] [--service-tier TIER]
#
# Defaults:
#   - Background dispatch (caller is the calling agent / shell).
#   - Log path: /tmp/codex-<task-name>.log
#
# Exit codes:
#   0  dispatched successfully (background) or completed cleanly (foreground)
#   1  usage error
#   2  brief file missing
#   3  codex CLI missing
#   4  health check failed (task killed)
#
# Read the companion notes in instructions/codex-delegation.md.

set -euo pipefail

# ---- args ----

TASK=""
BRIEF=""
MODE="background"
MODEL="gpt-6-astra"
EFFORT="high"
SERVICE_TIER="default"

usage() {
  cat >&2 <<EOF
Usage: codex-exec.sh <task-name> <brief-path> [--foreground] [--model SLUG] [--effort LEVEL] [--service-tier TIER]

Arguments:
  <task-name>     Short identifier, used in the log file name and registry.
  <brief-path>    File containing the task brief (will be passed to codex).

Options:
  --foreground    Block until codex completes. Default is background dispatch.
  --model SLUG    Model to run. Default: gpt-6-astra.
  --effort LEVEL  Reasoning effort (none|low|medium|high|xhigh|max). Default: high.
  --service-tier TIER
                  Service tier for this run. Default: default.
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
        echo "codex-exec.sh: $1 requires a value" >&2; usage
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
  echo "codex-exec.sh: brief file not found: $BRIEF" >&2
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex-exec.sh: 'codex' CLI not found on PATH" >&2
  exit 3
fi

# ---- paths ----

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

# Worktree detection: in a `git worktree` checkout (.git is a pointer file,
# e.g. Conductor workspaces) the index lives under the main repo's
# .git/worktrees/<name>/, outside Codex's writable sandbox. Delegated briefs
# never stage in any checkout (instructions/codex-delegation.md "Sandbox
# note"), so this is diagnostic only — it explains an index.lock failure if a
# brief violates that contract; it does not select a different brief grammar.
if [[ -f "$REPO_ROOT/.git" ]]; then
  echo "codex-exec.sh: NOTE — '$REPO_ROOT' is a git worktree; the index lives outside codex's sandbox. Delegated briefs must not stage in any case."
fi

WRAPPER="codex-exec.sh"
LOG_PATH="/tmp/codex-${TASK}.log"

# Shared primitives: registry line grammar, thread-id / agent-message
# extraction, post-run summary, dispatch-hygiene constants. One owner for both
# wrapper families — see lib/codex_registry.py. Health-check loop:
# lib/wrapper-common.sh.
CODEX_SOURCE="claude-code"
LIB_DIR="$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib"
# shellcheck source=lib/codex-registry.sh
source "$LIB_DIR/codex-registry.sh"
# shellcheck source=lib/wrapper-common.sh
source "$LIB_DIR/wrapper-common.sh"

mkdir -p "$(dirname "$CODEX_REGISTRY")"

# ---- registry helpers ----

register_start() {
  registry_append task "$TASK" event start cwd "$REPO_ROOT" \
    status running log_path "$LOG_PATH"
}

register_session_id() {
  local session_id
  session_id="$(extract_session_id "$LOG_PATH")"
  if [[ -n "$session_id" ]]; then
    registry_append task "$TASK" event session_captured status running \
      session_id "$session_id"
    echo "codex-exec.sh: session_id=$session_id — resume with codex-resume.sh $TASK <brief>"
  fi
}

register_close() {
  local status="$1"; local reason="${2:-}"
  local session_id
  session_id="$(extract_session_id "$LOG_PATH")"
  registry_append task "$TASK" event close status "$status" \
    session_id "$session_id" reason "$reason" log_path "$LOG_PATH"
  write_post_run_summary "$status"
}

# Post-run diff summary (staged / unstaged / untracked kept separate — see the
# lib). Writes /tmp/codex-<task>.post-run.md.
write_post_run_summary() {
  local status="$1"
  local post_run_path="/tmp/codex-${TASK}.post-run.md"
  write_post_run_summary_file "$TASK" "$status" "$LOG_PATH" \
    "$(extract_session_id "$LOG_PATH")" "$REPO_ROOT" "$post_run_path" \
    "codex-exec post-run summary" || true
  echo "codex-exec.sh: post-run summary → $post_run_path"
}

# ---- dispatch ----

# The brief is read into an arg to codex. Always redirect stdin from /dev/null
# so codex does not hang on stdin EOF.

# Deterministic model overrides for delegated tasks. Model / effort / tier come
# from flags (--model / --effort / --service-tier) — consumers pass what they need
# per run, otherwise these defaults apply (gpt-6-astra / high / default). These are
# real `-c` config overrides (strict-config validated), not guidance.
CODEX_MODEL_OVERRIDES=(
  -c "model=${MODEL}"
  -c "model_reasoning_effort=${EFFORT}"
  -c "service_tier=${SERVICE_TIER}"
)

dispatch_and_wait() {
  # codex-cli 0.147.0 removed `exec --full-auto`; --sandbox workspace-write is its exec-mode equivalent.
  codex exec --sandbox workspace-write "${CODEX_MODEL_OVERRIDES[@]}" --json "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1
}

# Background mode: the worker (codex + close-event writer) is re-parented
# into ITS OWN SESSION via a python os.setsid() shim (macOS has no setsid
# binary), so it survives any kill of the caller's process group — the
# 2026-07-16 foreground-timeout incident AND the 2026-07-27 incident where
# a stopped Claude Code background task killed two detached runs mid-pass.
# The close-event/post-run logic rides into the detached bash via
# `export -f`. Do NOT replace this with `set -m`: job control inside this
# no-tty command substitution killed the dispatched job and hung the
# wrapper on first field use (2026-07-16, second incident same day).
dispatch_background() {
  export TASK BRIEF LOG_PATH REPO_ROOT MODEL EFFORT SERVICE_TIER
  # CODEX_REGISTRY_PATH is already exported by lib/codex-registry.sh.
  export CODEX_REGISTRY_LIB CODEX_SOURCE
  export -f register_close registry_append write_post_run_summary \
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
if codex exec --sandbox workspace-write \
    -c "model=${MODEL}" \
    -c "model_reasoning_effort=${EFFORT}" \
    -c "service_tier=${SERVICE_TIER}" \
    --json "$(cat "$BRIEF")" </dev/null > "$LOG_PATH" 2>&1; then
  register_close "closed"
else
  register_close "failed" "codex exec returned non-zero"
fi
'''
os.execv('/bin/bash', ['bash', '-c', worker])
PY
}

register_start

if [[ "$MODE" == "foreground" ]]; then
  if dispatch_and_wait; then
    register_session_id
    register_close "closed"
    echo "codex-exec.sh: task '$TASK' complete. Log: $LOG_PATH"
    exit 0
  else
    register_session_id
    register_close "failed" "codex exec returned non-zero"
    echo "codex-exec.sh: task '$TASK' failed. See $LOG_PATH" >&2
    exit 1
  fi
fi

# Background mode with health check.
PID="$(dispatch_background)"
echo "codex-exec.sh: task '$TASK' dispatched in background (pid $PID). Log: $LOG_PATH"

# Health check: wait up to $CODEX_HEALTH_CHECK_SEC for the log to receive at
# least one JSON event. If not, the run is almost certainly hung on stdin —
# kill it and flag. The one-line "Reading additional input from stdin..."
# message counts as 1 line but not as a JSON event.
health_check "$PID" "$CODEX_HEALTH_CHECK_SEC" count_json_events "JSON event" " (likely stdin hang)"
