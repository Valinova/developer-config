#!/usr/bin/env bash
# Scan tracked text contents, paths, and symlink targets for generic private data.
# Print path:line only; exit 1 on matches, exit 2 on scan errors.
# Only this script is excluded from the content scan.

set -euo pipefail

PATTERN='/home/[[:alnum:]_.-]+|/Users/[[:alnum:]_.-]+|~/(wiki|notes)\b|https?://[[:alnum:]-]+\.convex\.(cloud|site)|github_pat_|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN .*PRIVATE KEY-----|(https?|postgres(ql)?|mysql|mongodb(\+srv)?)://[^/:@[:space:]]+:[^/@[:space:]]+@'

fail() {
  printf 'Private-term scan error: %s\n' "$1" >&2
  exit 2
}

repo_root="$(git rev-parse --show-toplevel)" || fail 'cannot locate repository'
cd "$repo_root"
self="always/scripts/check-private-terms.sh"

hits=0
scan() {
  local path="$1" matches status line
  shift
  if matches="$(grep -I -n -i -E -- "$PATTERN" "$@" 2>/dev/null)"; then
    hits=1
    while IFS= read -r line; do
      printf '%s:%s\n' "$path" "${line%%:*}" >&2
    done <<< "$matches"
  else
    status=$?
    [[ "$status" -eq 1 ]] || fail 'grep failed; check patterns and tracked file readability'
  fi
}

# Validate even if there are no tracked files; never print grep's pattern errors.
scan "$self" /dev/null
paths="$(mktemp)" || fail 'cannot create tracked-path list'
trap 'rm -f "$paths"' EXIT
git ls-files -z > "$paths" || fail 'cannot list tracked paths'
while IFS= read -r -d '' path; do
  scan "$path" <<< "$path"
  if [[ -L "$path" ]]; then
    target="$(readlink "$path")" || fail 'cannot read symlink target'
    scan "$path" <<< "$target"
  fi
  [[ "$path" == "$self" ]] && continue
  scan "$path" "$path"
done < "$paths"
exit "$hits"
