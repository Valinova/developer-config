#!/bin/bash
# Kill orphaned MCP/codex processes (PPID=1) older than 2h.
# PPID=1 means the parent Claude session died — stdio pipes are dead, so
# the process can no longer communicate with anyone. Safe to reap.
#
# macOS-portable: BSD `ps` exposes `etime` ([[DD-]hh:]mm:ss) not the GNU
# `etimes` (seconds). We parse etime in awk. BSD `ps` has no --no-headers
# and BSD `xargs` has no -r, so we emit pids and only kill if non-empty.
set -euo pipefail

PIDS="$(ps -eo pid,ppid,etime,command | awk '
  function etime_to_seconds(et,    parts, days, n, h, m, s) {
    days = 0
    if (index(et, "-") > 0) {
      n = split(et, parts, "-"); days = parts[1] + 0; et = parts[2]
    }
    n = split(et, parts, ":")
    if (n == 3)      { h = parts[1]; m = parts[2]; s = parts[3] }
    else if (n == 2) { h = 0;        m = parts[1]; s = parts[2] }
    else             { h = 0;        m = 0;        s = parts[1] }
    return days*86400 + h*3600 + m*60 + s
  }
  NR == 1 { next }   # skip BSD ps header
  $2 == 1 {
    if (etime_to_seconds($3) > 7200 &&
        ($0 ~ /playwright-mcp/ || $0 ~ /@openai\/codex/ || $0 ~ /codex exec/)) {
      print $1
    }
  }
')"

if [[ -n "$PIDS" ]]; then
  echo "$PIDS" | xargs kill -TERM
fi
