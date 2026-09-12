#!/usr/bin/env bash
#
# check-private-terms.sh — keep client and personal identifiers out of the
# public tree.
#
# Greps every tracked text file (excluding itself) for the private-term
# pattern below and fails with a file:line list. The PATTERN variable is the
# single owner of what counts as private — add a term here, nowhere else.
# Run locally from the repo root or via .github/workflows/check.yml.
#
# Exit 0: clean. Exit 1: hits printed to stderr.

set -euo pipefail

PATTERN='kushki|pedro|pmachado|machado|diego rios|valinova/engineering|/home/pedro|~/wiki|exciting-roadrunner|billpocket|procurement-cvx'

repo_root="$(git rev-parse --show-toplevel)"
self="always/scripts/check-private-terms.sh"
cd "$repo_root"

hits="$(
  git ls-files -z \
    | grep -zv -x -F "$self" \
    | xargs -0 grep -I -n -i -E -- "$PATTERN" 2>/dev/null \
    || true
)"

if [[ -n "$hits" ]]; then
  printf 'Private terms found (pattern owner: %s):\n%s\n' "$self" "$hits" >&2
  exit 1
fi
