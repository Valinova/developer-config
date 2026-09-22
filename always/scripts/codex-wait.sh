#!/usr/bin/env bash
#
# codex-wait.sh — block until a codex-exec.sh task closes.
#
# Polls the canonical codex session registry at
# ~/.hermes/state/codex-sessions.jsonl for a `"status":"closed"` event
# for the named task and exits when found. Designed to be used inline as the
# command of a Monitor `until` loop (the Monitor regex was bug-prone in
# practice — `"status":"close"` vs `"status":"closed"` had silently never
# matched), or directly via run_in_background to wait on a long codex run.
#
# Usage:
#   codex-wait.sh <task-name> [timeout-seconds]
#
# Defaults:
#   - timeout: 3600 (1 hour). Pass 0 to wait indefinitely.
#   - poll interval: 5s.
#
# Output:
#   - Exit 0: close event observed.
#   - Exit 1: usage error.
#   - Exit 2: registry file missing.
#   - Exit 3: timeout reached without a close event.
#   - Exit 4: failure terminal observed.
#
# The exit code is the entire signal — no stdout. Read the post-run summary
# at /tmp/codex-<task>.post-run.md separately when this returns 0.
#
# Read the companion notes in instructions/codex-delegation.md.

set -euo pipefail

# Shared primitives (registry path + current-run isolation) — see
# lib/codex_registry.py. Read-only here; CODEX_SOURCE is irrelevant.
LIB_DIR="$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")/lib"
# shellcheck source=lib/codex-registry.sh
source "$LIB_DIR/codex-registry.sh"
# shellcheck source=lib/wrapper-common.sh
source "$LIB_DIR/wrapper-common.sh"

WRAPPER="codex-wait.sh"
AGENT="codex"
# Both wrappers write a normalized "status" on every line: codex-exec.sh
# "failed"/"stalled" and codex-resume.sh "error" on failure. current_run_lines
# (shared lib) emits only the lines of the task's most recent run, so a reused
# task name is never answered by the previous run's close.
wait_main "$CODEX_REGISTRY" "error|stalled|failed" " (error/stalled/failed)" "$@"
