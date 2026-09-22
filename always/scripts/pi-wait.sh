#!/usr/bin/env bash
#
# pi-wait.sh — block until a pi-exec.sh task closes.
#
# Mirror of codex-wait.sh over the pi registry
# (~/.hermes/state/pi-sessions.jsonl). Exit code is the entire signal —
# no stdout on success. Read /tmp/pi-<task>.post-run.md when this
# returns 0.
#
# Usage:
#   pi-wait.sh <task-name> [timeout-seconds]
#
# Defaults:
#   - timeout: 3600 (1 hour). Pass 0 to wait indefinitely.
#   - poll interval: 5s.
#
# Exit codes:
#   0  close event observed
#   1  usage error
#   2  registry file missing
#   3  timeout reached without a close event
#   4  failure terminal (error/stalled) observed

set -euo pipefail

WRAPPER="pi-wait.sh"
AGENT="pi"
# Registry path and the shared wait loop; the current run starts at the task's
# most recent start OR resume_started event (registry_run_lines).
# shellcheck source=lib/wrapper-common.sh
source "$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib/wrapper-common.sh"

current_run_lines() {
  registry_run_lines "$PI_REGISTRY" "$1"
}

wait_main "$PI_REGISTRY" "error|stalled|failed" " (error/stalled)" "$@"
