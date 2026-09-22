#!/usr/bin/env bash
#
# claude-registry.sh — the claude dispatch registry's shell face.
#
# Source this; it defines $CLAUDE_REGISTRY and current_run_lines(), "which
# registry lines belong to this task's CURRENT run". The exec, wait and status
# wrappers all read through it, so none can judge a resumed run by the
# previous run's terminal line. A run starts at that task's most recent
# "start" OR "resume_started" event (rule owned by registry_run_lines in
# wrapper-common.sh, which this also sources for the wrappers).
#
# Usage:
#   source "<dir>/lib/claude-registry.sh"
#
# Provides:
#   $CLAUDE_REGISTRY           registry path (honours $CLAUDE_REGISTRY_PATH)
#   current_run_lines <task>   registry lines of that task's most recent run
#   everything in wrapper-common.sh

# shellcheck source=wrapper-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/wrapper-common.sh"

CLAUDE_REGISTRY="${CLAUDE_REGISTRY_PATH:-$HOME/.hermes/state/claude-sessions.jsonl}"

current_run_lines() {
  registry_run_lines "$CLAUDE_REGISTRY" "$1"
}
