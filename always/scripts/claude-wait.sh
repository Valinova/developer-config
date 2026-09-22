#!/usr/bin/env bash
#
# claude-wait.sh — block until a claude dispatch task closes.
#
# Mirror of pi-wait.sh over the claude registry
# (~/.hermes/state/claude-sessions.jsonl). Exit code is the entire signal —
# no stdout on success. Read /tmp/claude-<task>.post-run.md when this
# returns 0. Idempotent: a run already closed returns 0 instantly, so
# re-running after a session restart simply re-attaches.
#
# Resume-aware: the current run starts at the task's most recent start OR
# resume_started event (lib/claude-registry.sh), so a resume never returns on
# the previous run's close line.
#
# Usage:
#   claude-wait.sh <task-name> [timeout-seconds]
#
# Defaults: timeout 3600 (0 = wait indefinitely); poll interval 5s.
#
# Exit codes:
#   0  close event observed
#   1  usage error
#   2  registry file missing
#   3  timeout reached without a close event
#   4  failure terminal (failed/stalled) observed

set -euo pipefail

# Current-run isolation lives in the shared lib, the same reader
# claude-status.sh uses.
# shellcheck source=lib/claude-registry.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/claude-registry.sh"

WRAPPER="claude-wait.sh"
AGENT="claude"
wait_main "$CLAUDE_REGISTRY" "failed|stalled" "" "$@"
