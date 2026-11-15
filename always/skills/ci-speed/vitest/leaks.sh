#!/bin/sh
# Find what stops Vitest test files from sharing a worker. Run from the repo root.
#   leaks.sh census                     what every file leaves behind (one process per file, as the repo runs today)
#   leaks.sh sweep <seed> [<seed>...]   every shard under each shuffle seed with the repo's config as it stands
#   leaks.sh replay <file> [<file>...]  exactly these files, in this order, in one worker
#   leaks.sh bisect <run>               shortest chain of earlier files that still breaks a file a sweep run failed
#                                       (<run> is the name sweep printed, for example 3-505)
# Environment: LEAKS_OUT_DIR (default /tmp/ci-speed-<repo>), LEAKS_SHARDS (4), LEAKS_WORKERS (4),
# LEAKS_CONFIG (vitest.config.ts), LEAKS_GRACE_MS (400), VITEST ("pnpm exec vitest").
# One heavy run at a time: nothing here runs in parallel with itself.
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=${LEAKS_OUT_DIR:-/tmp/ci-speed-$(basename "$PWD")}
shards=${LEAKS_SHARDS:-4}
workers=${LEAKS_WORKERS:-4}
base=${LEAKS_CONFIG:-vitest.config.ts}
vitest=${VITEST:-pnpm exec vitest}
mkdir -p "$out"
plain() { sed -E 's/'"$(printf '\033')"'\[[0-9;]*m//g' "$1"; }
summary() { plain "$1" | grep -E '^ +(Test Files|Tests|Duration) ' | tr -s ' ' | tr '\n' '|'; }

replay() { # replay <label> <file>...
  label=$1; shift
  printf '%s\n' "$@" > "$out/$label.list"
  LEAKS_MODE=replay LEAKS_ORDER="$out/$label.list" CI=1 $vitest run --config "$here/leaks.config.mts" "$@" > "$out/$label.log" 2>&1
}

case ${1:-} in
census)
  rm -f "$out/census.jsonl"; red=0
  shard=1; while [ "$shard" -le "$shards" ]; do
    LEAKS_MODE=census LEAKS_OUT="$out/census.jsonl" CI=1 $vitest run --config "$here/leaks.config.mts" --shard="$shard/$shards" --maxWorkers="$workers" > "$out/census-$shard.log" 2>&1
    code=$?; ran=$(summary "$out/census-$shard.log")
    [ -n "$ran" ] || { echo "Vitest did not start; see $out/census-$shard.log" >&2; plain "$out/census-$shard.log" | head -15 >&2; exit 1; }
    echo "shard $shard exit $code |$ran"
    [ "$code" -eq 0 ] || red=1
    shard=$((shard + 1))
  done
  [ "$red" -eq 0 ] || echo "A shard is red. If it is green without the census, the census changed a result: read $out/census-<shard>.log before trusting the counts."
  node "$here/leaks-report.mjs" census "$out/census.jsonl"
  ;;
sweep)
  shift; [ $# -gt 0 ] || { echo "sweep needs at least one seed" >&2; exit 2; }
  for seed in "$@"; do shard=1; while [ "$shard" -le "$shards" ]; do
    run="$shard-$seed"
    LEAKS_ORDER_OUT="$out/sweep-$run.json" CI=1 $vitest run --config "$base" --shard="$shard/$shards" --maxWorkers="$workers" \
      --sequence.shuffle.files --sequence.seed="$seed" --reporter=default --reporter="$here/order-reporter.mjs" > "$out/sweep-$run.log" 2>&1
    node "$here/leaks-report.mjs" sweep "$out/sweep-$run.json" "$run" $? "$(summary "$out/sweep-$run.log")"
    shard=$((shard + 1))
  done; done
  ;;
replay)
  shift; [ $# -gt 0 ] || { echo "replay needs files" >&2; exit 2; }
  replay replay "$@"; code=$?
  ran=$(summary "$out/replay.log")
  [ -n "$ran" ] || { echo "Vitest did not start; see $out/replay.log" >&2; plain "$out/replay.log" | head -15 >&2; exit 1; }
  echo "exit $code |$ran"
  plain "$out/replay.log" | grep -E '^ FAIL |^[A-Za-z]*Error' | head -20
  exit $code
  ;;
bisect)
  run=${2:?bisect needs the sweep run name, for example 3-505}
  rm -f "$out"/bisect-*.seq
  node "$here/leaks-report.mjs" sequences "$out/sweep-$run.json" "$out/bisect" || exit 1
  for seq in "$out"/bisect-*.seq; do
    count=$(($(grep -c . "$seq") - 1)); target=$(sed -n "$((count + 1))p" "$seq"); head -"$count" "$seq" > "$out/bisect.before"
    fails() { replay bisect "$@" "$target"; [ $? -ne 0 ] && plain "$out/bisect.log" | grep -q "FAIL .*$target"; }
    echo "== $target ($count files ran before it in its worker)"
    # shellcheck disable=SC2046
    if ! fails $(cat "$out/bisect.before") && ! fails $(cat "$out/bisect.before"); then
      echo "   passes twice when its worker's files are replayed in order: it needs the load or timing of the full run"; continue
    fi
    low=1; high=$count
    while [ "$low" -lt "$high" ]; do
      middle=$(((low + high + 1) / 2))
      # shellcheck disable=SC2046
      if fails $(sed -n "$middle,${count}p" "$out/bisect.before"); then low=$middle; else high=$((middle - 1)); fi
    done
    sed -n "$low,${count}p" "$out/bisect.before" > "$out/bisect.keep"
    index=2
    while [ "$index" -le "$(grep -c . "$out/bisect.keep")" ]; do
      sed "${index}d" "$out/bisect.keep" > "$out/bisect.try"
      # shellcheck disable=SC2046
      if fails $(cat "$out/bisect.try"); then cp "$out/bisect.try" "$out/bisect.keep"; else index=$((index + 1)); fi
    done
    echo "   shortest chain that still breaks it:"; sed 's/^/     /' "$out/bisect.keep"
  done
  ;;
*)
  sed -n '2,10p' "$0"; exit 2
  ;;
esac
