#!/usr/bin/env bash
# tests/vinos-mcp.test.sh — bats-lite harness for the vinos-mcp CLI.
#
# Runs each verb against a fresh temp $HOME + fresh registry copy so
# there's no interaction with the developer's real config. Emits one
# PASS/FAIL line per assertion; exit code 0 on 7/7 green, 1 otherwise.
#
# Assumes jq is installed. No bats binary required.

set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VINOS_MCP="$REPO/bin/vinos-mcp"
REGISTRY="$REPO/usr/lib/vinos/registry/mcp-servers.json"

pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# Fresh temp $HOME per assertion so state can't leak.
_fresh_home() {
  local d; d=$(mktemp -d)
  echo "$d"
}

# Run vinos-mcp with the given fake HOME + registry, capture stdout.
_run() {
  local home="$1"; shift
  VINOS_MCP_REGISTRY="$REGISTRY" \
    VINOS_MCP_USER="$home/.config/vinos/mcp/servers.json" \
    HOME="$home" \
    "$VINOS_MCP" "$@"
}

[[ -x "$VINOS_MCP" ]] || { fail "vinos-mcp not executable at $VINOS_MCP"; exit 1; }
[[ -f "$REGISTRY" ]]  || { fail "registry not found at $REGISTRY"; exit 1; }
command -v jq >/dev/null 2>&1 || { fail "jq not installed on this host"; exit 1; }

# --- 1: registry emits valid JSON listing all 6 curated servers -----
H=$(_fresh_home)
out=$(_run "$H" registry 2>&1)
if printf '%s' "$out" | jq -e '.servers | keys' >/dev/null 2>&1; then
  count=$(printf '%s' "$out" | jq '.servers | length')
  if [[ "$count" == "6" ]]; then
    for name in filesystem github fetch sequential-thinking playwright sqlite; do
      if ! printf '%s' "$out" | jq -e --arg n "$name" '.servers[$n]' >/dev/null; then
        fail "1: registry missing '$name' entry"
        break
      fi
    done
    pass "1: registry emits valid JSON with all 6 curated servers"
  else
    fail "1: registry reported $count servers, expected 6"
  fi
else
  fail "1: registry output not valid JSON"
fi
rm -rf "$H"

# --- 2: list on fresh HOME returns friendly empty state --------------
H=$(_fresh_home)
out=$(_run "$H" list 2>&1)
if [[ "$out" == *"no MCP servers installed"* ]]; then
  pass "2: list on fresh HOME reports empty state"
else
  fail "2: list on fresh HOME did not report empty (got: $out)"
fi
rm -rf "$H"

# --- 3: add filesystem persists a valid config -----------------------
H=$(_fresh_home)
_run "$H" add filesystem >/dev/null 2>&1
cfg="$H/.config/vinos/mcp/servers.json"
if [[ -f "$cfg" ]] && jq -e '.mcpServers.filesystem.command == "npx"' "$cfg" >/dev/null; then
  pass "3: add filesystem writes a valid config with command=npx"
else
  fail "3: add filesystem did not persist a valid config (cfg=$cfg)"
fi
rm -rf "$H"

# --- 4: add is idempotent (second add is a no-op, exits 0) ----------
H=$(_fresh_home)
_run "$H" add filesystem >/dev/null 2>&1
out=$(_run "$H" add filesystem 2>&1)
count=$(jq '.mcpServers | length' "$H/.config/vinos/mcp/servers.json")
if [[ "$count" == "1" && "$out" == *"already installed"* ]]; then
  pass "4: add is idempotent — second add reports 'already installed', config unchanged"
else
  fail "4: add not idempotent (count=$count, msg=$out)"
fi
rm -rf "$H"

# --- 5: list after add shows the installed server --------------------
H=$(_fresh_home)
_run "$H" add fetch >/dev/null 2>&1
out=$(_run "$H" list 2>&1)
if printf '%s' "$out" | jq -e '.fetch.command == "npx"' >/dev/null 2>&1; then
  pass "5: list after add shows the installed server as valid JSON"
else
  fail "5: list did not show installed 'fetch' server (got: $out)"
fi
rm -rf "$H"

# --- 6: remove wipes the entry from user config ----------------------
H=$(_fresh_home)
_run "$H" add github >/dev/null 2>&1
_run "$H" remove github >/dev/null 2>&1
if jq -e '.mcpServers.github' "$H/.config/vinos/mcp/servers.json" >/dev/null 2>&1; then
  fail "6: remove did not wipe the entry"
else
  pass "6: remove wipes the entry from user config"
fi
rm -rf "$H"

# --- 7: add on unknown name fails with exit 2 + error message --------
H=$(_fresh_home)
if _run "$H" add nonexistent-server 2>/dev/null; then
  fail "7: add nonexistent-server should have failed (exit 0)"
else
  rc=$?
  if [[ "$rc" == "2" ]]; then
    pass "7: add unknown name fails with exit code 2"
  else
    fail "7: add unknown name failed but with unexpected exit code $rc (want 2)"
  fi
fi
rm -rf "$H"

# --- summary ---------------------------------------------------------
printf '\n=====================================\n'
printf 'vinos-mcp tests: \033[1;32m%d passed\033[0m, \033[1;31m%d failed\033[0m\n' \
  "$TESTS_PASSED" "$TESTS_FAILED"
printf '=====================================\n'

exit $(( TESTS_FAILED > 0 ? 1 : 0 ))
