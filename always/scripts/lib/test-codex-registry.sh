#!/usr/bin/env bash
# Hermetic tests for lib/codex_registry.py + lib/codex-registry.sh.
# Registry and logs live in a throwaway temp dir; no network, no real codex,
# nothing written outside $TMP_ROOT.

set -eu

LIB_DIR=$(cd "$(dirname "$0")" && pwd)
export LIB_DIR   # the inline python in test 3 imports the module from here
PY_LIB="$LIB_DIR/codex_registry.py"
SH_LIB="$LIB_DIR/codex-registry.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/codex-registry-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "${3:-assertion}: expected '$2', got '$1'"; }
pass() { echo "  ok — $1"; }

REG="$TMP_ROOT/registry.jsonl"
export CODEX_REGISTRY_PATH="$REG"

field() {
  REG="$REG" N="$1" F="$2" python3 - <<'PY'
import json, os
line = open(os.environ['REG']).read().splitlines()[int(os.environ['N'])]
v = json.loads(line).get(os.environ['F'], '')
print(v if not isinstance(v, bool) else str(v).lower())
PY
}

# ─── 1: grammar round-trip ───
echo "test: registry line grammar round-trip"
python3 "$PY_LIB" append --source hermes \
  task demo event start status running log_path /tmp/codex-demo.log timeout_sec 5400
python3 "$PY_LIB" append --source claude-code \
  task demo event close status closed exit_code 0 session_id "$(printf 'a%.0s' {1..8})-bbbb-cccc-dddd-eeeeeeeeeeee"
assert_eq "$(field 0 agent)" "codex" "agent"
assert_eq "$(field 0 source)" "hermes" "source"
assert_eq "$(field 0 log_path)" "/tmp/codex-demo.log" "log_path"
assert_eq "$(field 1 source)" "claude-code" "source"
assert_eq "$(field 1 status)" "closed" "status"
# RAW fields land as JSON numbers, not strings
REG="$REG" python3 - <<'PY' || fail "timeout_sec/exit_code not decoded as numbers"
import json, os
lines = [json.loads(l) for l in open(os.environ['REG'])]
assert lines[0]['timeout_sec'] == 5400 and isinstance(lines[0]['timeout_sec'], int)
assert lines[1]['exit_code'] == 0 and isinstance(lines[1]['exit_code'], int)
PY
# Compact separators — the shell readers substring-match on `"task":"demo"`
grep -q '"task":"demo"' "$REG" || fail "line is not compact-separated"
# An unknown source is rejected rather than silently written
if python3 "$PY_LIB" append --source bogus task demo event start 2>/dev/null; then
  fail "unknown source accepted"
fi
pass "canonical grammar written and re-read for both sources"

# ─── 2: thread-id + final-message extraction from a sample stream ───
echo "test: log stream extraction"
LOG="$TMP_ROOT/sample.log"
cat > "$LOG" <<'LOGEOF'
{"type":"thread.started","thread_id":"12345678-1234-1234-1234-123456789abc"}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"first"}}
Reading additional input from stdin...
{"type":"item.completed","item":{"id":"item_7","type":"agent_message","text":"SUMMARY:\nSTAGED: a.txt"}}
{"type":"turn.completed"}
LOGEOF
assert_eq "$(python3 "$PY_LIB" thread-id "$LOG")" "12345678-1234-1234-1234-123456789abc" "thread-id"
# last agent_message wins, and \n is unescaped into a real newline
assert_eq "$(python3 "$PY_LIB" final-message "$LOG" | head -1)" "SUMMARY:" "final-message line 1"
assert_eq "$(python3 "$PY_LIB" final-message "$LOG" | sed -n 2p)" "STAGED: a.txt" "final-message line 2"
# non-JSON noise is not counted as an event
assert_eq "$(python3 "$PY_LIB" json-events "$LOG")" "5" "json-events"
assert_eq "$(python3 "$PY_LIB" thread-id "$TMP_ROOT/missing.log")" "" "missing log is empty, not an error"
assert_eq "$(python3 "$PY_LIB" json-events "$TMP_ROOT/missing.log")" "0" "missing log events"
pass "thread-id, final message and event count read from a realistic stream"

# an escaped quote, a newline and a backslash survive whole (the regex
# extractor used to stop at the first \")
ESC_LOG="$TMP_ROOT/escaped.log"
cat > "$ESC_LOG" <<'LOGEOF'
{"type":"item.completed","item":{"id":"item_17","type":"agent_message","text":"1. Minimal fix: invokes \"full docs\" or \"full-docs\".\n2. path C:\\tmp\\x end"}}
LOGEOF
assert_eq "$(python3 "$PY_LIB" final-message "$ESC_LOG")" \
  "$(printf '%s\n%s' '1. Minimal fix: invokes "full docs" or "full-docs".' '2. path C:\tmp\x end')" \
  "final-message keeps escapes"
pass "final message decoded as JSON, not regex-sliced"

# ─── 3: readers accept legacy log_file lines and never rewrite them ───
echo "test: legacy line acceptance"
LEGACY="$TMP_ROOT/legacy.jsonl"
cat > "$LEGACY" <<'LEGEOF'
{"ts":"2026-07-01T00:00:00Z","agent":"codex","source":"claude-code","task":"old","event":"start","cwd":"/x","status":"running","log_file":"/tmp/codex-old.log"}
{"ts":"2026-07-01T00:01:00Z","agent":"codex","source":"claude-code","task":"old","event":"session_captured","session_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"}
not json at all
{"ts":"2026-07-01T00:02:00Z","agent":"pi","task":"old","event":"close","status":"closed"}
{"ts":"2026-07-01T00:03:00Z","agent":"codex","source":"claude-code","task":"old","event":"close","status":"closed","session_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"}
LEGEOF
BEFORE="$(shasum "$LEGACY")"
assert_eq "$(CODEX_REGISTRY_PATH="$LEGACY" python3 "$PY_LIB" session-id --task old)" \
  "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" "legacy session-id"
CODEX_REGISTRY_PATH="$LEGACY" python3 - <<'PY' || fail "log_file not normalized to log_path"
import os, sys
sys.path.insert(0, os.environ['LIB_DIR'])
from codex_registry import iter_entries
entries = [e for _, e in iter_entries()]
assert len(entries) == 3, entries          # junk line and agent=pi both skipped
assert entries[0]['log_path'] == '/tmp/codex-old.log'
assert entries[0]['log_file'] == '/tmp/codex-old.log'   # original key untouched
PY
assert_eq "$(shasum "$LEGACY")" "$BEFORE" "legacy registry was rewritten"
pass "legacy log_file lines read, junk skipped, file left byte-identical"

# ─── 4: current-run isolation across a reused task name ───
echo "test: current-run isolation"
RUNS="$TMP_ROOT/runs.jsonl"
cat > "$RUNS" <<'RUNEOF'
{"ts":"1","agent":"codex","task":"dup","event":"start","status":"running"}
{"ts":"2","agent":"codex","task":"dup","event":"close","status":"closed"}
{"ts":"3","agent":"codex","task":"other","event":"start","status":"running"}
{"ts":"4","agent":"codex","task":"dup","event":"start","status":"running"}
{"ts":"5","agent":"codex","task":"dup","event":"session_captured","status":"running"}
RUNEOF
OUT="$(CODEX_REGISTRY_PATH="$RUNS" python3 "$PY_LIB" current-run --task dup)"
assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "2" "current run line count"
if printf '%s\n' "$OUT" | grep -q '"status":"closed"'; then fail "stale close leaked into current run"; fi
# resume_start / resume_started both begin a run
RESUMES="$TMP_ROOT/resumes.jsonl"
cat > "$RESUMES" <<'RESEOF'
{"ts":"1","agent":"codex","task":"r","event":"start","status":"running"}
{"ts":"2","agent":"codex","task":"r","event":"close","status":"closed"}
{"ts":"3","agent":"codex","task":"r","event":"resume_started","status":"running"}
RESEOF
assert_eq "$(CODEX_REGISTRY_PATH="$RESUMES" python3 "$PY_LIB" current-run --task r | wc -l | tr -d ' ')" \
  "1" "resume_started starts a new run"
pass "only the latest run's lines are returned"

# ─── 5: the shell face exposes the same primitives and constants ───
echo "test: codex-registry.sh shim"
SHIM_OUT="$(
  CODEX_SOURCE=claude-code CODEX_REGISTRY_PATH="$TMP_ROOT/shim.jsonl" \
  bash -c '
    set -eu
    source "$1"
    registry_append task shim event start status running log_path /tmp/x.log
    echo "$CODEX_DEFAULT_TIMEOUT_SEC $CODEX_HEALTH_CHECK_SEC"
    echo "$(extract_session_id "$2")"
    echo "$(count_json_events "$2")"
    echo "$(current_run_lines shim | wc -l | tr -d " ")"
  ' _ "$SH_LIB" "$LOG"
)"
assert_eq "$(printf '%s\n' "$SHIM_OUT" | sed -n 1p)" "5400 45" "constants"
assert_eq "$(printf '%s\n' "$SHIM_OUT" | sed -n 2p)" "12345678-1234-1234-1234-123456789abc" "shim thread-id"
assert_eq "$(printf '%s\n' "$SHIM_OUT" | sed -n 3p)" "5" "shim json event count"
assert_eq "$(printf '%s\n' "$SHIM_OUT" | sed -n 4p)" "1" "shim current-run"
assert_eq "$(CODEX_REGISTRY_PATH="$TMP_ROOT/shim.jsonl" python3 "$PY_LIB" current-run --task shim \
  | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["source"])')" \
  "claude-code" "shim writes its own source"
pass "shell shim writes and reads through the same lib"

# ─── 6: post-run summary keeps staged/unstaged/untracked separate ───
echo "test: post-run summary"
SUMMARY="$TMP_ROOT/post-run.md"
python3 "$PY_LIB" post-run --task demo --status closed --log "$LOG" \
  --session-id 12345678-1234-1234-1234-123456789abc --repo "$TMP_ROOT" \
  --out "$SUMMARY" --title "codex-exec post-run summary" --note "note: RESUME run"
grep -q '^# codex-exec post-run summary — task: demo$' "$SUMMARY" || fail "title missing"
grep -q '^- note: RESUME run$' "$SUMMARY" || fail "note missing"
for section in 'Staged (`git diff --cached --stat`)' 'Unstaged (`git diff --stat`)' \
               'Untracked (`git ls-files --others --exclude-standard`)' 'Final agent_message'; do
  grep -qF "## $section" "$SUMMARY" || fail "missing section: $section"
done
grep -q 'STAGED: a.txt' "$SUMMARY" || fail "final agent_message not inlined"
# "nothing to report" must not masquerade as "git broke"
grep -q '(no repo / git unavailable)' "$SUMMARY" || fail "non-repo dir should say git unavailable"
git init -q "$TMP_ROOT/clean" && ( cd "$TMP_ROOT/clean" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed )
python3 "$PY_LIB" post-run --task demo --status closed --log "$LOG" \
  --repo "$TMP_ROOT/clean" --out "$SUMMARY.clean"
grep -q '(none)' "$SUMMARY.clean" || fail "clean repo should report (none), not a git failure"
if grep -q '(no repo / git unavailable)' "$SUMMARY.clean"; then fail "clean repo misreported as git failure"; fi
pass "summary carries all four sections, title, optional note, and honest empties"

# ─── 7: a failed fresh run is terminal for both shell consumers ───
echo "test: failed fresh-run consumers"
python3 "$PY_LIB" append --source claude-code task failed-fresh event start status running
python3 "$PY_LIB" append --source claude-code task failed-fresh event close status failed exit_code 1
for consumer in codex-wait.sh codex-status.sh; do
  status=0
  if [[ "$consumer" == codex-wait.sh ]]; then
    bash "$LIB_DIR/../$consumer" failed-fresh 1 > "$TMP_ROOT/$consumer.out" 2>&1 || status=$?
  else
    bash "$LIB_DIR/../$consumer" failed-fresh > "$TMP_ROOT/$consumer.out" 2>&1 || status=$?
    grep -q '^FAILED' "$TMP_ROOT/$consumer.out" || fail "status did not report FAILED"
  fi
  assert_eq "$status" "4" "$consumer must recognize a failed fresh run"
done
pass "wait exits on failure and status reports FAILED"

echo ""
echo "All codex_registry tests passed."
