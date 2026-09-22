#!/usr/bin/env bash
#
# claude-status.sh — one-shot triage verdict for a claude dispatch task.
#
# The claude-side twin of codex-status.sh: answers "is it hung or just slow?"
# without hand-rolling registry greps, log mtime checks, and post-run lookups.
# Read-only: touches nothing, kills nothing — safe to run at any time,
# including against live runs.
#
# Usage:
#   claude-status.sh <task-name>
#
# Verdicts (first line of output) and exit codes:
#   0  CLOSED    — current run reached "status":"closed"; post-run summary ready.
#   3  RUNNING   — no terminal event and the log is actively being written.
#   4  FAILED    — current run reached "status":"failed" or "stalled".
#   5  STALE     — no terminal event and the log has been quiet past the
#                  threshold. Either a slow reasoning stretch or an orphaned
#                  run — inspect the log tail before assuming either.
#   6  UNKNOWN   — task has no start event in the registry.
#   1  usage error; 2 registry missing.
#
# STALE threshold: 300s without log writes. Long xhigh reasoning stretches can
# legitimately exceed it — STALE is a prompt to look, never proof of death.
# Recovery guidance lives in instructions/codex-delegation.md ("Claude
# delegation" / the waiter-orphaning note).

set -euo pipefail

# Current-run isolation lives in the shared lib, the same reader
# claude-wait.sh uses — resume-aware, so a resumed task is never judged by the
# previous run's close line.
# shellcheck source=lib/claude-registry.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/claude-registry.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: claude-status.sh <task-name>" >&2
  exit 1
fi

TASK="$1"
# Unlike codex, a resume reuses the same log path — the dispatch wrapper
# truncates it at the start of every run — so there is only ever one log.
LOG_PATH="/tmp/claude-${TASK}.log"
WRAPPER="claude-status.sh"
AGENT="claude"
status_verdict "$CLAUDE_REGISTRY" "failed|stalled" "failed/stalled"
