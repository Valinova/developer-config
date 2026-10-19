#!/bin/bash
# Reap two kinds of runaway process:
# - Orphaned Playwright MCP servers (PPID=1) older than 2h. Codex workers
#   detach via setsid, so PPID=1 is normal for live Codex runs; their
#   lifecycle is outside this reaper.
# - One-shot `tsc` runs older than 10 min, whatever their parent. Calibrated
#   2026-10-19: the slowest normal full check in our largest repos is ~8s;
#   TS 7 incremental runs have hung for hours at 16-32 GB and ignore SIGTERM,
#   hence SIGKILL. `--lsp` and watch-mode servers are long-lived by design.
#
# macOS-portable: BSD `ps` exposes `etime` ([[DD-]hh:]mm:ss) not the GNU
# `etimes` (seconds). We parse etime in awk. BSD `ps` has no --no-headers
# and BSD `xargs` has no -r, so we emit pids and only kill if non-empty.
set -euo pipefail

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/reap-orphan.log"

ps -eo pid,ppid,etime,command | awk '
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
  {
    age = etime_to_seconds($3)
    cmd = $0; sub(/^ *[0-9]+ +[0-9]+ +[^ ]+ +/, "", cmd)
    if ($2 == 1 && age > 7200 && cmd ~ /playwright-mcp/) {
      print "TERM", $1, $3, cmd
    } else if (age > 600 && $4 ~ /(^|\/)tsc$/ &&
               cmd !~ / --lsp| --watch| -w( |$)/) {
      print "KILL", $1, $3, cmd
    }
  }
' | while read -r sig pid etime cmd; do
  if kill "-$sig" "$pid" 2>/dev/null; then
    mkdir -p "$(dirname "$LOG")"
    echo "$(date '+%F %T') SIG$sig pid=$pid age=$etime $cmd" >>"$LOG"
  fi
done
