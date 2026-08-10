#!/usr/bin/env bash
# tests/all.sh — run every unit-test harness under tests/*.test.sh in a
# single pass. Emits one section per harness, then a global tally. Any
# harness that fails causes a non-zero exit.
#
# Intent: this is the "cheap layer" — pure bash + jq, no docker, runs
# in seconds. tests/test.sh keeps its docker install-acceptance role
# on top of this.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

FAILED=()
PASSED=()

for t in tests/*.test.sh; do
  [[ -e "$t" ]] || continue
  name="$(basename "$t" .test.sh)"
  printf '\n\033[1;36m== %s ==\033[0m\n' "$name"
  if bash "$t"; then
    PASSED+=("$name")
  else
    FAILED+=("$name")
  fi
done

printf '\n\033[1;36m== summary ==\033[0m\n'
printf '  passed: %d — %s\n' "${#PASSED[@]}" "${PASSED[*]:-none}"
printf '  failed: %d — %s\n' "${#FAILED[@]}" "${FAILED[*]:-none}"

[[ ${#FAILED[@]} -eq 0 ]] || exit 1
