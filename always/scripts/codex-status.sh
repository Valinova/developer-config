#!/usr/bin/env bash
#
# codex-status.sh — one-shot triage verdict for a codex-exec.sh task.
#
# Answers "is it hung or just slow?" without hand-rolling registry greps,
# log mtime checks, and post-run lookups. Read-only: touches nothing,
# kills nothing — safe to run at any time, including against live runs.
#
# Usage:
#   codex-status.sh <task-name>
#
# Verdicts (first line of output) and exit codes:
#   0  CLOSED    — current run reached "status":"closed"; post-run summary ready.
#   3  RUNNING   — no terminal event and the log is actively being written.
#   4  FAILED    — current run reached "status":"error", "stalled", or "failed".
#   5  STALE     — no terminal event and the log has been quiet past the
#                  threshold. Either a slow reasoning stretch or an orphaned
#                  run — inspect the log tail before assuming either.
#   6  UNKNOWN   — task has no start event in the registry.
#   1  usage error; 2 registry missing.
#
# STALE threshold: 300s without log writes. Long xhigh reasoning stretches can
# legitimately exceed it — STALE is a prompt to look, never proof of death.
# Recovery guidance lives in instructions/codex-delegation.md ("Post-run
# discipline" / waiter-orphaning note).

set -euo pipefail

# Shared primitives (registry path + current-run isolation) — see
# lib/codex_registry.py. Read-only here; CODEX_SOURCE is irrelevant.
LIB_DIR="$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib"
# shellcheck source=lib/codex-registry.sh
source "$LIB_DIR/codex-registry.sh"
# shellcheck source=lib/wrapper-common.sh
source "$LIB_DIR/wrapper-common.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: codex-status.sh <task-name>" >&2
  exit 1
fi

TASK="$1"
# codex-exec.sh logs to <task>.log; codex-resume.sh logs to <task>-resume.log.
# Track whichever was written most recently — a resumed task's original log
# goes quiet while the resume log is the live one.
LOG_PATH="/tmp/codex-${TASK}.log"
RESUME_LOG="/tmp/codex-${TASK}-resume.log"
if [[ -f "$RESUME_LOG" ]]; then
  if [[ ! -f "$LOG_PATH" || "$RESUME_LOG" -nt "$LOG_PATH" ]]; then
    LOG_PATH="$RESUME_LOG"
  fi
fi
WRAPPER="codex-status.sh"
AGENT="codex"
status_verdict "$CODEX_REGISTRY" "error|stalled|failed" "error/stalled/failed"
