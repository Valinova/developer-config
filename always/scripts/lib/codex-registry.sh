#!/usr/bin/env bash
#
# codex-registry.sh — shell face of the shared codex primitives.
#
# Source this; it defines the registry/log helpers every codex dispatch wrapper
# needs, all delegating to the canonical implementation in codex_registry.py
# (same directory). Nothing here reimplements grammar or regexes.
#
# Usage:
#   CODEX_SOURCE=claude-code   # or "hermes" — which wrapper family is calling
#   source "<dir>/lib/codex-registry.sh"
#
# Provides:
#   $CODEX_REGISTRY_LIB          absolute path to codex_registry.py
#   $CODEX_REGISTRY              registry path (honours $CODEX_REGISTRY_PATH)
#   $CODEX_DEFAULT_TIMEOUT_SEC   90min wall-clock cap
#   $CODEX_HEALTH_CHECK_SEC      45s no-JSON-event stall threshold
#   registry_append KEY VALUE ...          append one canonical line
#   extract_session_id <log>               thread_id from a --json log
#   extract_final_message <log>            last agent_message text
#   count_json_events <log>                number of JSON events emitted
#   current_run_lines <task>               registry lines of the task's last run
#   write_post_run_summary_file <task> <status> <log> <session_id> <repo> <out> [title] [note]
#
# Functions are plain shell functions so `export -f` still carries them into the
# detached background workers (see codex-exec.sh dispatch_background). Export
# CODEX_REGISTRY_LIB and CODEX_SOURCE alongside them.

CODEX_REGISTRY_LIB="${CODEX_REGISTRY_LIB:-$(
  python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' \
    "${BASH_SOURCE[0]}"
)/codex_registry.py}"

if [[ ! -f "$CODEX_REGISTRY_LIB" ]]; then
  echo "codex-registry.sh: shared lib not found at $CODEX_REGISTRY_LIB" >&2
  return 1 2>/dev/null || exit 1
fi

CODEX_SOURCE="${CODEX_SOURCE:-claude-code}"

# Constants come from the lib so there is exactly one owner of each number.
eval "$(python3 "$CODEX_REGISTRY_LIB" constants)"
# Pin the resolved registry into the environment so every child process (and the
# detached background workers) writes to the same file the parent read.
export CODEX_REGISTRY_PATH="$CODEX_REGISTRY"

registry_append() {
  python3 "$CODEX_REGISTRY_LIB" append --source "$CODEX_SOURCE" "$@"
}

extract_session_id() {
  python3 "$CODEX_REGISTRY_LIB" thread-id "$1"
}

extract_final_message() {
  python3 "$CODEX_REGISTRY_LIB" final-message "$1"
}

count_json_events() {
  python3 "$CODEX_REGISTRY_LIB" json-events "$1"
}

current_run_lines() {
  python3 "$CODEX_REGISTRY_LIB" current-run --task "$1"
}

write_post_run_summary_file() {
  python3 "$CODEX_REGISTRY_LIB" post-run \
    --task "$1" --status "$2" --log "$3" --session-id "$4" \
    --repo "$5" --out "$6" --title "${7:-codex post-run summary}" --note "${8:-}"
}
