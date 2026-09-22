#!/usr/bin/env bash
# Hermetic characterization tests for the claude / codex / pi dispatch
# wrappers (exec, resume, wait, status).
#
# Safety: no real model CLI can run. PATH is a fake-agent dir plus a dir of
# symlinks to the handful of system tools the wrappers use, so the real
# claude / codex / pi are unreachable. HOME is a throwaway dir, so every
# ~/.hermes/state registry is a temp one. Task names carry this shell's pid so
# the wrappers' fixed /tmp/<agent>-<task>.* paths never meet a real run. Every
# process this file cleans up is one it started, found by recorded pid.
#
# `sleep` on PATH is a fake that sleeps FAKE_SLEEP_SEC (0.2s): the wrappers'
# 45s first-event check and 5s wait polls then run in a couple of seconds
# without any production knob. The fake agents use the real sleep.
#
# Registry-line and argv expectations below are self-declared drift pins: the
# claude and pi line grammars have no importable owner, and these tests exist
# to prove a refactor keeps them byte-identical.
#
# WRTEST_ARTIFACTS=<dir>: also write a normalized transcript of every wrapper
# run (stdout, stderr, exit code, registry lines, post-run files) there, for
# diffing two versions of the wrappers.

set -u

LIB_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPTS=$(dirname "$LIB_DIR")
T=$(mktemp -d "${TMPDIR:-/tmp}/wrapper-test.XXXXXX")
ID="wrtest-$$"
FAKE="$T/fakebin"
SAFE="$T/safebin"
export FAKE_DIR="$T/fake"
REPO="$T/repo"
TRANSCRIPT="$T/transcript"
mkdir -p "$FAKE" "$SAFE" "$FAKE_DIR" "$REPO" "$T/home"
: > "$FAKE_DIR/pids"
: > "$TRANSCRIPT"

cleanup() {
  local pid
  # Only pids this file recorded: fake agents (self-registered) and the
  # wrapper workers parsed from dispatch output.
  for pid in $(cat "$FAKE_DIR/pids" "$T/worker-pids" 2>/dev/null); do
    kill "$pid" 2>/dev/null || true
  done
  rm -f /tmp/claude-"$ID"-* /tmp/codex-"$ID"-* /tmp/pi-"$ID"-*
  rm -rf "$T"
}
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "${3:-assertion}: expected '$2', got '$1'"; }
assert_has() { grep -qF -- "$2" <<<"$1" || fail "${3:-assertion}: '$2' not in: $1"; }
pass() { echo "  ok — $1"; }

# ─── hermetic environment ───

ORIG_PATH="$PATH"
REAL_SLEEP=$(command -v sleep)
for tool in bash sh python3 git grep sed awk date cat head tail mkdir dirname \
            basename rm du cut tr stat wc env ls mktemp seq sleep; do
  src=$(command -v "$tool") || fail "test needs '$tool' on PATH"
  ln -s "$src" "$SAFE/$tool"
done
cat > "$FAKE/sleep" <<EOF
#!/bin/bash
exec "$REAL_SLEEP" "\${FAKE_SLEEP_SEC:-0.2}"
EOF

# One fake agent, dispatching on its own name. FAKE_MODE: ok | fail (first
# event, then exit 1) | silent (no JSON, exit 1) | stall (no output, lingers).
cat > "$FAKE/fake-agent" <<EOF
#!/bin/bash
agent=\$(basename "\$0")
printf '%s\n' "\$@" > "\$FAKE_DIR/\$agent.argv"
echo \$\$ >> "\$FAKE_DIR/pids"
case "\${FAKE_MODE:-ok}" in
  stall) exec "$REAL_SLEEP" 20 ;;
  silent) echo "fatal: not logged in"; exit 1 ;;
esac
case "\$agent" in
  claude) echo '{"type":"system","subtype":"init","session_id":"11111111-1111-4111-8111-111111111111"}' ;;
  codex)  echo '{"type":"thread.started","thread_id":"22222222-2222-4222-8222-222222222222"}' ;;
  pi)     echo '{"type":"session","id":"33333333-3333-4333-8333-333333333333","cwd":"/x"}' ;;
esac
[[ "\${FAKE_MODE:-ok}" == fail ]] && exit 1
"$REAL_SLEEP" "\${FAKE_LINGER:-0}"
case "\$agent" in
  claude) echo '{"type":"result","subtype":"success","result":"CLAUDE DONE","session_id":"11111111-1111-4111-8111-111111111111","total_cost_usd":0.25}' ;;
  codex)  echo '{"type":"item.completed","item":{"id":"item_3","type":"agent_message","text":"CODEX DONE"}}'
          echo '{"type":"turn.completed"}' ;;
  pi)     echo '{"type":"turn_end","message":{"role":"assistant","content":[{"type":"text","text":"PI DONE"}]}}' ;;
esac
EOF
chmod +x "$FAKE/sleep" "$FAKE/fake-agent"
for agent in claude codex pi; do ln -s fake-agent "$FAKE/$agent"; done
CLAUDE_SID=11111111-1111-4111-8111-111111111111
CODEX_SID=22222222-2222-4222-8222-222222222222
PI_SID=33333333-3333-4333-8333-333333333333

export HOME="$T/home"
unset CLAUDE_REGISTRY_PATH CODEX_REGISTRY_PATH CODEX_REGISTRY_LIB FAKE_MODE FAKE_LINGER
export PATH="$FAKE:$SAFE"
for agent in claude codex pi; do
  assert_eq "$(command -v "$agent")" "$FAKE/$agent" "fake $agent must shadow everything"
  if PATH="$SAFE" command -v "$agent" >/dev/null; then fail "a real $agent is reachable"; fi
done
CLAUDE_REG="$HOME/.hermes/state/claude-sessions.jsonl"
CODEX_REG="$HOME/.hermes/state/codex-sessions.jsonl"
PI_REG="$HOME/.hermes/state/pi-sessions.jsonl"

# A repo with one change of each kind, so the post-run sections are distinct.
git -C "$REPO" init -q
echo a > "$REPO/tracked.txt"
git -C "$REPO" add tracked.txt
git -C "$REPO" -c user.email=t@t -c user.name=t commit -q -m seed
echo b >> "$REPO/tracked.txt"
echo s > "$REPO/staged.txt"; git -C "$REPO" add staged.txt
echo u > "$REPO/untracked.txt"
REPO_TOP=$(git -C "$REPO" rev-parse --show-toplevel)
BRIEF="$T/brief.md"
echo "do the thing" > "$BRIEF"

# ─── helpers ───

# A hung wrapper (e.g. a detached worker holding the output pipe) fails the
# test instead of blocking it, where coreutils timeout exists.
HANG_GUARD=()
if TO=$(PATH="$ORIG_PATH" command -v timeout); then HANG_GUARD=("$TO" 60); fi

# run <label> <cmd...> — runs from the repo; sets RC, OUT, ERR.
run() {
  local label="$1"; shift
  RC=0
  ( cd "$REPO" && ${HANG_GUARD[@]+"${HANG_GUARD[@]}"} "$@" ) > "$T/out" 2> "$T/err" || RC=$?
  OUT=$(cat "$T/out"); ERR=$(cat "$T/err")
  [[ "$RC" -ne 124 ]] || fail "$label: wrapper hung (timeout)"
  { echo "== $label: $(basename "$2") ${*:3}"; echo "rc=$RC"; cat "$T/out" "$T/err"; } >> "$TRANSCRIPT"
}

# Normalized registry lines for a task: key=value in written order, ts
# checked then masked. Also asserts every line is compact JSON.
reg() {
  python3 - "$1" "$2" <<'PY'
import json, re, sys
path, task = sys.argv[1], sys.argv[2]
try:
    raw_lines = open(path).read().splitlines()
except FileNotFoundError:
    raw_lines = []
for raw in raw_lines:
    d = json.loads(raw)
    if d.get("task") != task:
        continue
    assert raw == json.dumps(d, separators=(",", ":")), f"not compact JSON: {raw}"
    assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", d["ts"]), raw
    d["ts"] = "TS"
    print(" ".join(f"{k}={v}" for k, v in d.items()))
PY
}

record_reg() { { echo "-- registry $2"; reg "$1" "$2"; } >> "$TRANSCRIPT"; }

# Worker pid from "... (pid N ..." dispatch output; waits (bounded) for it to exit.
worker_pid() { sed -n 's/.*(pid \([0-9][0-9]*\).*/\1/p' <<<"$OUT" | head -1; }
await_exit() {
  local pid="$1" i
  echo "$pid" >> "$T/worker-pids"
  for i in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || return 0; "$REAL_SLEEP" 0.1; done
  fail "worker $pid still running after 10s"
}
# Kill fake agents still alive (a stalled claude/pi child outlives the killed
# wrapper subshell by design); all pids here were self-recorded by the fakes.
reap_fakes() {
  local pid
  for pid in $(cat "$FAKE_DIR/pids"); do kill "$pid" 2>/dev/null || true; done
}

# Section body of a post-run file: lines after the header, inside the fence.
section() {
  awk -v h="$2" '
    index($0, h) == 1 { on = 1; next }
    on && /^## / { exit }
    on && $0 != "```" && $0 != "" { print }
  ' "$1"
}

# check_post_run <file> <title> <status> <final-header> <final-text>
check_post_run() {
  local f="$1" task="$2"
  [[ -f "$f" ]] || fail "post-run missing: $f"
  assert_eq "$(head -1 "$f")" "# $3 — task: $task" "post-run title"
  grep -qx -- "- status: $4" "$f" || fail "post-run status $4 missing in $f"
  grep -q -- '^- finished_at: [0-9TZ:-]*$' "$f" || fail "finished_at missing"
  assert_has "$(section "$f" '## Staged (`git diff --cached --stat`)')" "staged.txt" "staged section"
  assert_has "$(section "$f" '## Unstaged (`git diff --stat`)')" "tracked.txt" "unstaged section"
  if section "$f" '## Unstaged (`git diff --stat`)' | grep -q staged.txt; then fail "staged file leaked into unstaged"; fi
  assert_eq "$(section "$f" '## Untracked (`git ls-files --others --exclude-standard`)')" "untracked.txt" "untracked section"
  assert_has "$(section "$f" "$5")" "$6" "final message"
  { echo "-- post-run $(basename "$f")"; sed 's/^- finished_at: .*/- finished_at: TS/' "$f"; } >> "$TRANSCRIPT"
}

set_mtime_ago() { python3 -c 'import os,sys,time; t=time.time()-int(sys.argv[2]); os.utime(sys.argv[1],(t,t))' "$1" "$2"; }

# ════════════════════════ claude-exec.sh ════════════════════════
CE="$SCRIPTS/claude-exec.sh"
echo "test: claude-exec.sh"

t="$ID-c1"
run c1 bash "$CE" "$t" "$BRIEF" --foreground
assert_eq "$RC" "0" "claude fg rc"
assert_eq "$(cat "$FAKE_DIR/claude.argv")" "$(printf '%s\n' -p --model opus --effort medium \
  --output-format stream-json --verbose --dangerously-skip-permissions "do the thing")" "claude default argv"
assert_eq "$(reg "$CLAUDE_REG" "$t")" "\
ts=TS agent=claude source=claude-code task=$t event=start cwd=$REPO_TOP status=running model=opus effort=medium log_file=/tmp/claude-$t.log
ts=TS agent=claude source=claude-code task=$t event=session_captured session_id=$CLAUDE_SID
ts=TS agent=claude source=claude-code task=$t event=close status=closed session_id=$CLAUDE_SID reason=" "claude fg registry"
assert_has "$OUT" "session_id=$CLAUDE_SID" "claude session line"
check_post_run "/tmp/claude-$t.post-run.md" "$t" "claude-exec post-run summary" closed \
  "## Final assistant message" "CLAUDE DONE"
grep -qx -- "- model / effort: opus / medium" "/tmp/claude-$t.post-run.md" || fail "claude model/effort line"
grep -qx -- "\[cost_usd=0.25\]" "/tmp/claude-$t.post-run.md" || fail "claude cost line"
record_reg "$CLAUDE_REG" "$t"
pass "foreground run: default flags, start/session/close lines, post-run sections"

run c1-resume bash "$CE" "$t" "$BRIEF" --resume --foreground --model sonnet --effort high
assert_eq "$RC" "0" "claude resume rc"
assert_eq "$(cat "$FAKE_DIR/claude.argv")" "$(printf '%s\n' -p --model sonnet --effort high \
  --output-format stream-json --verbose --dangerously-skip-permissions --resume "$CLAUDE_SID" "do the thing")" "claude resume argv"
assert_eq "$(reg "$CLAUDE_REG" "$t" | sed -n 4p)" \
  "ts=TS agent=claude source=claude-code task=$t event=resume_started cwd=$REPO_TOP status=running model=sonnet effort=high log_file=/tmp/claude-$t.log" "claude resume_started line"
assert_eq "$(reg "$CLAUDE_REG" "$t" | wc -l | tr -d ' ')" "6" "claude resume adds three lines"
record_reg "$CLAUDE_REG" "$t"
pass "--resume passes the captured session and --model/--effort override the defaults"

run c2-noresume bash "$CE" "$ID-c2" "$BRIEF" --resume --foreground
assert_eq "$RC" "5" "resume without session"
assert_eq "$(reg "$CLAUDE_REG" "$ID-c2")" "" "no registry line on refused resume"

FAKE_MODE=fail run c3-fail bash "$CE" "$ID-c3" "$BRIEF" --foreground
assert_eq "$RC" "1" "claude fg failure rc"
assert_eq "$(reg "$CLAUDE_REG" "$ID-c3" | tail -1)" \
  "ts=TS agent=claude source=claude-code task=$ID-c3 event=close status=failed session_id=$CLAUDE_SID reason=claude -p returned non-zero" "claude fg failed close"
pass "refused resume (5) and failed foreground run (1)"

for args in "" "$ID-x" "$ID-x $BRIEF --bogus" "$ID-x $BRIEF --effort" "$ID-x $BRIEF --model --foreground"; do
  # shellcheck disable=SC2086
  run "claude-usage[$args]" bash "$CE" $args
  assert_eq "$RC" "1" "claude usage error for '$args'"
done
run claude-nobrief bash "$CE" "$ID-x" "$T/missing.md"
assert_eq "$RC" "2" "claude missing brief"
RC=0; ( cd "$REPO" && PATH="$SAFE" bash "$CE" "$ID-x" "$BRIEF" ) >/dev/null 2>&1 || RC=$?
assert_eq "$RC" "3" "claude CLI missing"
pass "usage (1), missing brief (2), missing CLI (3)"

t="$ID-c4"
FAKE_LINGER=2 run c4-bg bash "$CE" "$t" "$BRIEF"
assert_eq "$RC" "0" "claude bg rc"
pid=$(worker_pid); [[ -n "$pid" ]] || fail "no pid in: $OUT"
run c4-wait bash "$SCRIPTS/claude-wait.sh" "$t" 30
assert_eq "$RC" "0" "claude-wait on bg run"
await_exit "$pid"
assert_eq "$(reg "$CLAUDE_REG" "$t" | cut -d' ' -f5-6)" "event=start cwd=$REPO_TOP
event=session_captured session_id=$CLAUDE_SID
event=close status=closed" "claude bg registry"
check_post_run "/tmp/claude-$t.post-run.md" "$t" "claude-exec post-run summary" closed \
  "## Final assistant message" "CLAUDE DONE"
pass "background run: health check passes, worker closes, wait returns 0"

t="$ID-c5"
FAKE_MODE=stall run c5-stall bash "$CE" "$t" "$BRIEF"
assert_eq "$RC" "4" "claude stall rc"
await_exit "$(worker_pid)"
reap_fakes
assert_eq "$(reg "$CLAUDE_REG" "$t" | tail -1)" \
  "ts=TS agent=claude source=claude-code task=$t event=close status=stalled session_id= reason=no events within 45s" "claude stalled close"
assert_eq "$(reg "$CLAUDE_REG" "$t" | wc -l | tr -d ' ')" "2" "claude stall lines"
pass "no events within the check window: worker killed, stalled close (4)"

t="$ID-c6"
FAKE_MODE=silent run c6-silent bash "$CE" "$t" "$BRIEF"
assert_eq "$RC" "4" "claude early-exit rc"
assert_eq "$(reg "$CLAUDE_REG" "$t" | cut -d' ' -f5-)" "event=start cwd=$REPO_TOP status=running model=opus effort=medium log_file=/tmp/claude-$t.log
event=close status=failed session_id= reason=claude -p returned non-zero
event=close status=failed session_id= reason=exited before first event" "claude early-exit lines"
pass "exit before any event: failed close from worker and wrapper (4)"

# ════════════════════════ codex-exec.sh / codex-resume.sh ════════════════════════
XE="$SCRIPTS/codex-exec.sh"
XR="$SCRIPTS/codex-resume.sh"
echo "test: codex-exec.sh / codex-resume.sh"

t="$ID-x1"
run x1 bash "$XE" "$t" "$BRIEF" --foreground
assert_eq "$RC" "0" "codex fg rc"
assert_eq "$(cat "$FAKE_DIR/codex.argv")" "$(printf '%s\n' exec --sandbox workspace-write \
  -c model=gpt-6-astra -c model_reasoning_effort=high -c service_tier=default --json "do the thing")" "codex default argv"
assert_eq "$(reg "$CODEX_REG" "$t")" "\
ts=TS agent=codex source=claude-code task=$t event=start cwd=$REPO_TOP status=running log_path=/tmp/codex-$t.log
ts=TS agent=codex source=claude-code task=$t event=session_captured status=running session_id=$CODEX_SID
ts=TS agent=codex source=claude-code task=$t event=close status=closed session_id=$CODEX_SID reason= log_path=/tmp/codex-$t.log" "codex fg registry"
check_post_run "/tmp/codex-$t.post-run.md" "$t" "codex-exec post-run summary" closed \
  "## Final agent_message" "CODEX DONE"
record_reg "$CODEX_REG" "$t"
pass "foreground run: default -c overrides, registry lines, post-run"

run x1-flags bash "$XE" "$ID-x2" "$BRIEF" --foreground --model m1 --effort low --service-tier priority
assert_eq "$RC" "0" "codex flags rc"
assert_eq "$(cat "$FAKE_DIR/codex.argv")" "$(printf '%s\n' exec --sandbox workspace-write \
  -c model=m1 -c model_reasoning_effort=low -c service_tier=priority --json "do the thing")" "codex flag argv"

run x1-resume bash "$XR" "$t" "$BRIEF" --foreground --effort xhigh
assert_eq "$RC" "0" "codex resume rc"
assert_eq "$(cat "$FAKE_DIR/codex.argv")" "$(printf '%s\n' exec resume \
  -c model=gpt-6-astra -c model_reasoning_effort=xhigh -c service_tier=default --json "$CODEX_SID" "do the thing")" "codex resume argv"
assert_eq "$(reg "$CODEX_REG" "$t" | tail -2)" "\
ts=TS agent=codex source=claude-code task=$t event=resume_started status=running session_id=$CODEX_SID log_path=/tmp/codex-$t-resume.log reason=
ts=TS agent=codex source=claude-code task=$t event=resume_closed status=closed session_id=$CODEX_SID log_path=/tmp/codex-$t-resume.log reason=" "codex resume lines"
check_post_run "/tmp/codex-$t.post-run.md" "$t" "codex-resume post-run summary" closed \
  "## Final agent_message" "CODEX DONE"
grep -qx -- "- note: this is a RESUME run; original run log: /tmp/codex-$t.log" "/tmp/codex-$t.post-run.md" || fail "codex resume note"
pass "--model/--effort/--service-tier reach codex; resume lines and post-run"

FAKE_MODE=fail run x1-resume-fail bash "$XR" "$t" "$BRIEF" --foreground
assert_eq "$RC" "1" "codex resume failure rc"
assert_eq "$(reg "$CODEX_REG" "$t" | tail -1 | cut -d' ' -f5-)" \
  "event=resume_failed status=error session_id=$CODEX_SID log_path=/tmp/codex-$t-resume.log reason=codex exec resume returned non-zero" "codex resume_failed"

for args in "" "$ID-x" "$ID-x $BRIEF --bogus" "$ID-x $BRIEF --service-tier" "$ID-x $BRIEF --model --foreground"; do
  # shellcheck disable=SC2086
  run "codex-usage[$args]" bash "$XE" $args; assert_eq "$RC" "1" "codex-exec usage '$args'"
  # shellcheck disable=SC2086
  run "codex-resume-usage[$args]" bash "$XR" $args; assert_eq "$RC" "1" "codex-resume usage '$args'"
done
run x-nobrief bash "$XE" "$ID-x" "$T/missing.md"; assert_eq "$RC" "2" "codex-exec missing brief"
run xr-nobrief bash "$XR" "$ID-x" "$T/missing.md"; assert_eq "$RC" "2" "codex-resume missing brief"
RC=0; ( cd "$REPO" && PATH="$SAFE" bash "$XE" "$ID-x" "$BRIEF" ) >/dev/null 2>&1 || RC=$?
assert_eq "$RC" "3" "codex-exec CLI missing"
RC=0; ( cd "$REPO" && PATH="$SAFE" bash "$XR" "$ID-x" "$BRIEF" ) >/dev/null 2>&1 || RC=$?
assert_eq "$RC" "4" "codex-resume CLI missing"
run xr-nosession bash "$XR" "$ID-never" "$BRIEF"; assert_eq "$RC" "3" "codex-resume no session"
CODEX_REGISTRY_PATH="$T/none.jsonl" run xr-noreg bash "$XR" "$t" "$BRIEF"; assert_eq "$RC" "3" "codex-resume no registry"
pass "usage (1), missing brief (2), missing CLI (3 exec / 4 resume), no session or registry (3)"

t="$ID-x3"
FAKE_LINGER=2 run x3-bg bash "$XE" "$t" "$BRIEF"
assert_eq "$RC" "0" "codex bg rc"
pid=$(worker_pid)
run x3-wait bash "$SCRIPTS/codex-wait.sh" "$t" 30
assert_eq "$RC" "0" "codex-wait on bg run"
await_exit "$pid"
assert_eq "$(reg "$CODEX_REG" "$t" | cut -d' ' -f5-6)" "event=start cwd=$REPO_TOP
event=session_captured status=running
event=close status=closed" "codex bg registry"
check_post_run "/tmp/codex-$t.post-run.md" "$t" "codex-exec post-run summary" closed \
  "## Final agent_message" "CODEX DONE"
FAKE_LINGER=2 run x3-bg-resume bash "$XR" "$t" "$BRIEF"
assert_eq "$RC" "0" "codex bg resume rc"
assert_has "$OUT" "session $CODEX_SID" "codex bg resume names the session"
pid=$(worker_pid)
run x3-wait-resume bash "$SCRIPTS/codex-wait.sh" "$t" 30
assert_eq "$RC" "0" "codex-wait on bg resume"
await_exit "$pid"
assert_eq "$(reg "$CODEX_REG" "$t" | tail -1 | cut -d' ' -f5-6)" "event=resume_closed status=closed" "codex bg resume close"
pass "background exec and resume: the setsid worker closes, wait returns 0"

t="$ID-x4"
FAKE_MODE=stall run x4-stall bash "$XE" "$t" "$BRIEF"
assert_eq "$RC" "4" "codex stall rc"
await_exit "$(worker_pid)"
for i in $(seq 1 50); do
  alive=""; for p in $(cat "$FAKE_DIR/pids"); do kill -0 "$p" 2>/dev/null && alive=1; done
  [[ -z "$alive" ]] && break; "$REAL_SLEEP" 0.1
done
[[ -z "$alive" ]] || fail "codex stall: the group kill left the codex child alive"
assert_eq "$(reg "$CODEX_REG" "$t" | tail -1 | cut -d' ' -f5-)" \
  "event=close status=stalled session_id= reason=no JSON events within 45s (likely stdin hang) log_path=/tmp/codex-$t.log" "codex stalled close"
pass "stall: whole worker group killed (codex child included), stalled close (4)"

t="$ID-x5"
FAKE_MODE=silent run x5-silent bash "$XE" "$t" "$BRIEF"
assert_eq "$RC" "4" "codex early-exit rc"
assert_eq "$(reg "$CODEX_REG" "$t" | cut -d' ' -f5-8)" "event=start cwd=$REPO_TOP status=running log_path=/tmp/codex-$t.log
event=close status=failed session_id= reason=codex
event=close status=failed session_id= reason=exited" "codex early-exit lines"
pass "exit before any event: failed closes (4)"

# ════════════════════════ pi-exec.sh / pi-resume.sh ════════════════════════
PE="$SCRIPTS/pi-exec.sh"
PR="$SCRIPTS/pi-resume.sh"
echo "test: pi-exec.sh / pi-resume.sh"

t="$ID-p1"
run p1 bash "$PE" "$t" "$BRIEF" --foreground
assert_eq "$RC" "0" "pi fg rc"
assert_eq "$(cat "$FAKE_DIR/pi.argv")" "$(printf '%s\n' -p --mode json --provider xai \
  --model grok-4.7 --thinking high "do the thing")" "pi default argv"
assert_eq "$(reg "$PI_REG" "$t")" "\
ts=TS agent=pi source=claude-code task=$t event=start cwd=$REPO_TOP status=running log_file=/tmp/pi-$t.log
ts=TS agent=pi source=claude-code task=$t event=session_captured session_id=$PI_SID
ts=TS agent=pi source=claude-code task=$t event=close status=closed session_id=$PI_SID reason=" "pi fg registry"
check_post_run "/tmp/pi-$t.post-run.md" "$t" "pi-exec post-run summary" closed \
  "## Final assistant message" "PI DONE"
record_reg "$PI_REG" "$t"
pass "foreground run: default flags, registry lines, post-run"

run p1-flags bash "$PE" "$ID-p2" "$BRIEF" --foreground --provider openai --model m2 --thinking low
assert_eq "$RC" "0" "pi flags rc"
assert_eq "$(cat "$FAKE_DIR/pi.argv")" "$(printf '%s\n' -p --mode json --provider openai \
  --model m2 --thinking low "do the thing")" "pi flag argv"

run p1-resume bash "$PR" "$t" "$BRIEF" --foreground --thinking max
assert_eq "$RC" "0" "pi resume rc"
assert_eq "$(cat "$FAKE_DIR/pi.argv")" "$(printf '%s\n' -p --mode json --session "$PI_SID" \
  --provider xai --model grok-4.7 --thinking max "do the thing")" "pi resume argv"
assert_eq "$(reg "$PI_REG" "$t" | tail -2)" "\
ts=TS agent=pi source=claude-code task=$t event=resume_started status=running session_id=$PI_SID
ts=TS agent=pi source=claude-code task=$t event=resume_closed status=closed session_id=$PI_SID" "pi resume lines"
check_post_run "/tmp/pi-$t.post-run.md" "$t" "pi-resume post-run summary" closed \
  "## Final assistant message" "PI DONE"
grep -qx -- "- note: this is a RESUME run; original run log: /tmp/pi-$t.log" "/tmp/pi-$t.post-run.md" || fail "pi resume note"
grep -qx -- "- log: /tmp/pi-$t-resume.log" "/tmp/pi-$t.post-run.md" || fail "pi resume log line"
FAKE_MODE=fail run p1-resume-fail bash "$PR" "$t" "$BRIEF" --foreground
assert_eq "$RC" "1" "pi resume failure rc"
assert_eq "$(reg "$PI_REG" "$t" | tail -1 | cut -d' ' -f5-)" \
  "event=resume_failed status=error session_id=$PI_SID reason=pi -p resume returned non-zero" "pi resume_failed"
pass "--provider/--model/--thinking reach pi; resume lines, failure, post-run"

for args in "" "$ID-x" "$ID-x $BRIEF --bogus" "$ID-x $BRIEF --thinking" "$ID-x $BRIEF --provider --foreground"; do
  # shellcheck disable=SC2086
  run "pi-usage[$args]" bash "$PE" $args; assert_eq "$RC" "1" "pi-exec usage '$args'"
  # shellcheck disable=SC2086
  run "pi-resume-usage[$args]" bash "$PR" $args; assert_eq "$RC" "1" "pi-resume usage '$args'"
done
run p-nobrief bash "$PE" "$ID-x" "$T/missing.md"; assert_eq "$RC" "2" "pi-exec missing brief"
run pr-nobrief bash "$PR" "$ID-x" "$T/missing.md"; assert_eq "$RC" "2" "pi-resume missing brief"
RC=0; ( cd "$REPO" && PATH="$SAFE" bash "$PE" "$ID-x" "$BRIEF" ) >/dev/null 2>&1 || RC=$?
assert_eq "$RC" "3" "pi-exec CLI missing"
RC=0; ( cd "$REPO" && PATH="$SAFE" bash "$PR" "$ID-x" "$BRIEF" ) >/dev/null 2>&1 || RC=$?
assert_eq "$RC" "4" "pi-resume CLI missing"
run pr-nosession bash "$PR" "$ID-never" "$BRIEF"; assert_eq "$RC" "3" "pi-resume no session"
mkdir -p "$T/emptyhome"
HOME="$T/emptyhome" run pr-noreg bash "$PR" "$t" "$BRIEF"; assert_eq "$RC" "3" "pi-resume no registry"
pass "usage (1), missing brief (2), missing CLI (3 exec / 4 resume), no session or registry (3)"

t="$ID-p3"
FAKE_LINGER=2 run p3-bg bash "$PE" "$t" "$BRIEF"
assert_eq "$RC" "0" "pi bg rc"
pid=$(worker_pid)
run p3-wait bash "$SCRIPTS/pi-wait.sh" "$t" 30
assert_eq "$RC" "0" "pi-wait on bg run"
await_exit "$pid"
check_post_run "/tmp/pi-$t.post-run.md" "$t" "pi-exec post-run summary" closed \
  "## Final assistant message" "PI DONE"
FAKE_LINGER=2 run p3-bg-resume bash "$PR" "$t" "$BRIEF"
assert_eq "$RC" "0" "pi bg resume rc"
pid=$(worker_pid)
run p3-wait-resume bash "$SCRIPTS/pi-wait.sh" "$t" 30
assert_eq "$RC" "0" "pi-wait on bg resume"
await_exit "$pid"
assert_eq "$(reg "$PI_REG" "$t" | cut -d' ' -f5)" "event=start
event=session_captured
event=close
event=resume_started
event=resume_closed" "pi bg exec + resume lines"
pass "background exec and resume close; pi-wait returns 0 for each"

t="$ID-p4"
FAKE_MODE=stall run p4-stall bash "$PE" "$t" "$BRIEF"
assert_eq "$RC" "4" "pi stall rc"
await_exit "$(worker_pid)"
reap_fakes
assert_eq "$(reg "$PI_REG" "$t" | tail -1 | cut -d' ' -f5-)" \
  "event=close status=stalled session_id= reason=no JSON events within 45s" "pi stalled close"

t="$ID-p5"
FAKE_MODE=silent run p5-silent bash "$PE" "$t" "$BRIEF"
assert_eq "$RC" "4" "pi early-exit rc"
assert_eq "$(reg "$PI_REG" "$t" | cut -d' ' -f5-)" "event=start cwd=$REPO_TOP status=running log_file=/tmp/pi-$t.log
event=close status=failed session_id= reason=pi -p returned non-zero
event=close status=failed session_id= reason=exited before first JSON event" "pi early-exit lines"
pass "stall (4, stalled close) and exit before any event (4, failed closes)"

# ════════════════════════ --log ════════════════════════
echo "test: --log is not a flag"
# Status and wait assume the default log path, so no wrapper takes an override.
for w in claude-exec codex-exec codex-resume pi-exec pi-resume; do
  case "$w" in codex-resume) t="$ID-x1" ;; pi-resume) t="$ID-p1" ;; *) t="$ID-log-$w" ;; esac
  run "$w-log" bash "$SCRIPTS/$w.sh" "$t" "$BRIEF" --foreground --log "$T/custom-$w.log"
  assert_eq "$RC" "1" "$w rejects --log"
  [[ ! -e "$T/custom-$w.log" ]] || fail "$w wrote to a --log path"
done
assert_eq "$(reg "$CLAUDE_REG" "$ID-log-claude-exec")$(reg "$CODEX_REG" "$ID-log-codex-exec")$(reg "$PI_REG" "$ID-log-pi-exec")" "" "rejected --log wrote registry lines"
pass "every exec/resume wrapper rejects --log as a usage error (1)"

# ════════════════════════ *-wait.sh ════════════════════════
echo "test: claude-wait.sh / codex-wait.sh / pi-wait.sh"

# line <registry> <agent> <task> <event> <status>
line() {
  mkdir -p "$(dirname "$1")"
  printf '{"ts":"2026-01-01T00:00:0%sZ","agent":"%s","source":"claude-code","task":"%s","event":"%s","status":"%s"}\n' \
    "$(( $(wc -l < "$1" 2>/dev/null || echo 0) % 10 ))" "$2" "$3" "$4" "$5" >> "$1"
}

for agent in claude codex pi; do
  case "$agent" in claude) R="$CLAUDE_REG" ;; codex) R="$CODEX_REG" ;; pi) R="$PI_REG" ;; esac
  W="$SCRIPTS/$agent-wait.sh"
  line "$R" "$agent" "$ID-w-closed" start running; line "$R" "$agent" "$ID-w-closed" close closed
  # The real 5s poll: an already-closed task must return before the first sleep.
  started=$(date +%s)
  RC=0; PATH="$SAFE" bash "$W" "$ID-w-closed" 30 >/dev/null 2>&1 || RC=$?
  assert_eq "$RC" "0" "$agent-wait closed"
  (( $(date +%s) - started < 3 )) || fail "$agent-wait did not return immediately"
  line "$R" "$agent" "$ID-w-failed" start running; line "$R" "$agent" "$ID-w-failed" close failed
  run "$agent-wait-failed" bash "$W" "$ID-w-failed" 30; assert_eq "$RC" "4" "$agent-wait failed"
  line "$R" "$agent" "$ID-w-stalled" start running; line "$R" "$agent" "$ID-w-stalled" close stalled
  run "$agent-wait-stalled" bash "$W" "$ID-w-stalled" 30; assert_eq "$RC" "4" "$agent-wait stalled"
  # Resume-aware: the previous run's close must not answer for the resumed run.
  line "$R" "$agent" "$ID-w-res" start running; line "$R" "$agent" "$ID-w-res" close closed
  line "$R" "$agent" "$ID-w-res" resume_started running
  run "$agent-wait-resumed" bash "$W" "$ID-w-res" 1; assert_eq "$RC" "3" "$agent-wait resumed run times out"
  line "$R" "$agent" "$ID-w-res" resume_closed closed
  run "$agent-wait-resumed-closed" bash "$W" "$ID-w-res" 1; assert_eq "$RC" "0" "$agent-wait resumed run closed"
  run "$agent-wait-usage" bash "$W"; assert_eq "$RC" "1" "$agent-wait usage"
  HOME="$T/emptyhome" run "$agent-wait-noreg" bash "$W" "$ID-w-closed" 1; assert_eq "$RC" "2" "$agent-wait no registry"
done
# error is a failure terminal for codex and pi, not for claude (claude never writes it).
line "$CODEX_REG" codex "$ID-w-error" start running; line "$CODEX_REG" codex "$ID-w-error" resume_failed error
run codex-wait-error bash "$SCRIPTS/codex-wait.sh" "$ID-w-error" 1; assert_eq "$RC" "4" "codex-wait error"
line "$PI_REG" pi "$ID-w-error" start running; line "$PI_REG" pi "$ID-w-error" resume_failed error
run pi-wait-error bash "$SCRIPTS/pi-wait.sh" "$ID-w-error" 1; assert_eq "$RC" "4" "pi-wait error"
line "$CLAUDE_REG" claude "$ID-w-error" start running; line "$CLAUDE_REG" claude "$ID-w-error" close error
run claude-wait-error bash "$SCRIPTS/claude-wait.sh" "$ID-w-error" 1; assert_eq "$RC" "3" "claude-wait ignores error"
pass "closed (0, immediate), failed/stalled (4), resume-aware (3 then 0), usage (1), no registry (2), error per agent"

# ════════════════════════ *-status.sh ════════════════════════
echo "test: claude-status.sh / codex-status.sh"

for agent in claude codex; do
  case "$agent" in claude) R="$CLAUDE_REG" ;; codex) R="$CODEX_REG" ;; esac
  S="$SCRIPTS/$agent-status.sh"
  t="$ID-s-closed"; line "$R" "$agent" "$t" start running; line "$R" "$agent" "$t" close closed
  run "$agent-status-closed-nopost" bash "$S" "$t"; assert_eq "$RC" "0" "$agent CLOSED rc"
  assert_has "$OUT" "CLOSED — task '$t' closed at 2026-01-01T00:00:0" "$agent CLOSED verdict"
  assert_has "$OUT" "post-run: MISSING (expected /tmp/$agent-$t.post-run.md)" "$agent missing post-run"
  echo x > "/tmp/$agent-$t.post-run.md"
  run "$agent-status-closed" bash "$S" "$t"
  assert_eq "$(sed -n 2p <<<"$OUT")" "post-run: /tmp/$agent-$t.post-run.md" "$agent post-run line"
  for st in failed stalled; do
    t="$ID-s-$st"; line "$R" "$agent" "$t" start running; line "$R" "$agent" "$t" close "$st"
    run "$agent-status-$st" bash "$S" "$t"; assert_eq "$RC" "4" "$agent FAILED ($st) rc"
    assert_has "$(head -1 <<<"$OUT")" "FAILED — task '$t' hit a failure terminal" "$agent FAILED verdict"
  done
  t="$ID-s-run"; line "$R" "$agent" "$t" start running; echo '{"type":"x"}' > "/tmp/$agent-$t.log"
  run "$agent-status-running" bash "$S" "$t"; assert_eq "$RC" "3" "$agent RUNNING rc"
  assert_has "$(head -1 <<<"$OUT")" "RUNNING — task '$t' log active" "$agent RUNNING verdict"
  t="$ID-s-quiet"; line "$R" "$agent" "$t" start running; echo x > "/tmp/$agent-$t.log"
  set_mtime_ago "/tmp/$agent-$t.log" 600
  run "$agent-status-quiet" bash "$S" "$t"; assert_eq "$RC" "5" "$agent STALE (quiet) rc"
  assert_has "$(head -1 <<<"$OUT")" "STALE — task '$t' has no terminal event and the log has been quiet for" "$agent STALE verdict"
  t="$ID-s-nolog"; line "$R" "$agent" "$t" start running
  run "$agent-status-nolog" bash "$S" "$t"; assert_eq "$RC" "5" "$agent STALE (no log) rc"
  assert_has "$(head -1 <<<"$OUT")" "STALE — task '$t' has a start event but no log" "$agent STALE no-log verdict"
  run "$agent-status-unknown" bash "$S" "$ID-s-never"; assert_eq "$RC" "6" "$agent UNKNOWN rc"
  assert_has "$OUT" "UNKNOWN — no start event for task '$ID-s-never' in $R" "$agent UNKNOWN verdict"
  t="$ID-s-res"; line "$R" "$agent" "$t" start running; line "$R" "$agent" "$t" close closed
  line "$R" "$agent" "$t" resume_started running; echo '{"type":"x"}' > "/tmp/$agent-$t.log"
  run "$agent-status-resumed" bash "$S" "$t"; assert_eq "$RC" "3" "$agent resumed run is RUNNING"
  run "$agent-status-usage" bash "$S"; assert_eq "$RC" "1" "$agent status usage"
  HOME="$T/emptyhome" run "$agent-status-noreg" bash "$S" "$t"; assert_eq "$RC" "2" "$agent status no registry"
done
# error: FAILED for codex, not a terminal for claude.
t="$ID-s-error"
line "$CODEX_REG" codex "$t" start running; line "$CODEX_REG" codex "$t" resume_failed error
run codex-status-error bash "$SCRIPTS/codex-status.sh" "$t"; assert_eq "$RC" "4" "codex error is FAILED"
line "$CLAUDE_REG" claude "$t" start running; line "$CLAUDE_REG" claude "$t" close error
echo '{"type":"x"}' > "/tmp/claude-$t.log"
run claude-status-error bash "$SCRIPTS/claude-status.sh" "$t"; assert_eq "$RC" "3" "claude error is not terminal"
# codex tracks whichever of <task>.log / <task>-resume.log was written last.
t="$ID-s-rlog"; line "$CODEX_REG" codex "$t" start running
echo x > "/tmp/codex-$t.log"; set_mtime_ago "/tmp/codex-$t.log" 900
echo x > "/tmp/codex-$t-resume.log"
run codex-status-resume-log bash "$SCRIPTS/codex-status.sh" "$t"; assert_eq "$RC" "3" "codex live resume log"
assert_has "$OUT" "log: /tmp/codex-$t-resume.log" "codex picks the newer resume log"
pass "CLOSED/FAILED/RUNNING/STALE/UNKNOWN verdicts, resume-aware, error per agent, resume log"

if [[ -n "${WRTEST_ARTIFACTS:-}" ]]; then
  mkdir -p "$WRTEST_ARTIFACTS"
  sed -e "s#$T#<T>#g" -e "s#$ID#<ID>#g" -e 's/pid [0-9][0-9]*/pid N/g' \
      -e 's/within [0-9]*s$/within Ns/' -e 's/[0-9][0-9]* event(s)/N event(s)/' \
      -e 's/active [0-9]*s ago/active Ns ago/' -e 's/quiet for [0-9]*s/quiet for Ns/' \
      "$TRANSCRIPT" > "$WRTEST_ARTIFACTS/transcript.txt"
fi

echo ""
echo "All wrapper tests passed."
