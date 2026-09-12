#!/usr/bin/env bash
#
# claude-registry.sh — shared reader for the claude dispatch registry.
#
# Source this; it defines $CLAUDE_REGISTRY and current_run_lines(), the single
# owner of "which registry lines belong to this task's CURRENT run". The wait
# and status wrappers both read through it so neither can judge a resumed run
# by the previous run's terminal line.
#
# The registry is append-only and durable across sessions, so a task name
# reused later still has the earlier run's close line on disk. A run therefore
# starts at that task's most recent "start" OR "resume_started" event;
# everything before it belongs to a run that already finished.
#
# Usage:
#   source "<dir>/lib/claude-registry.sh"
#
# Provides:
#   $CLAUDE_REGISTRY           registry path (honours $CLAUDE_REGISTRY_PATH)
#   current_run_lines <task>   registry lines of that task's most recent run

CLAUDE_REGISTRY="${CLAUDE_REGISTRY_PATH:-$HOME/.hermes/state/claude-sessions.jsonl}"

current_run_lines() {
  awk -v t="\"task\":\"$1\"" -v s='"event":"start"' -v rs='"event":"resume_started"' '
    index($0, t) {
      if (index($0, s) || index($0, rs)) { delete buf; n = 0 }
      buf[n++] = $0
    }
    END { for (i = 0; i < n; i++) print buf[i] }
  ' "$CLAUDE_REGISTRY"
}
