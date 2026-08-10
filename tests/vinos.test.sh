#!/usr/bin/env bash
# tests/vinos.test.sh — dispatcher assertions for bin/vinos.
#
# Runs each subcommand path against stubbed helpers so we exercise the
# dispatch table without needing vinos-mcp / vinos-doctor / vinos-update
# actually installed on the host.

set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VINOS="$REPO/bin/vinos"

pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)); }

[[ -x "$VINOS" ]] || { fail "bin/vinos not executable"; exit 1; }

STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT

# Stub every helper the dispatcher may delegate to. Each stub records
# its argv so we can assert routing.
for tool in vinos-mcp vinos-doctor vinos-update vinos-install-ai \
            vinos-install-dev sudo; do
  cat >"$STUB_DIR/$tool" <<EOF
#!/usr/bin/env bash
printf '$tool %s\n' "\$*" >"$STUB_DIR/${tool}.calls"
EOF
  chmod +x "$STUB_DIR/$tool"
done

export PATH="$STUB_DIR:$PATH"

# --- 1. Bare invocation prints one-line status -------------------------

OUT="$("$VINOS" 2>&1 || true)"
if grep -q 'vinos.*persona=' <<<"$OUT"; then
  pass "bare 'vinos' prints status one-liner"
else
  fail "bare 'vinos' output missing 'persona=' — got: $OUT"
fi

# --- 2. `vinos status --json` emits JSON ------------------------------

OUT="$("$VINOS" status --json 2>&1 || true)"
if grep -qE '^\{.*"persona":' <<<"$OUT"; then
  pass "'vinos status --json' emits JSON"
else
  fail "'vinos status --json' not JSON — got: $OUT"
fi

# --- 3. `vinos help` prints usage --------------------------------------

if "$VINOS" help 2>&1 | grep -q 'vinos — meta-CLI'; then
  pass "'vinos help' prints usage banner"
else
  fail "'vinos help' banner missing"
fi

# --- 4. `vinos --version` returns version ------------------------------

if "$VINOS" --version 2>&1 | grep -qE '^vinos [a-z0-9._-]+$'; then
  pass "'vinos --version' returns 'vinos <version>'"
else
  fail "'vinos --version' malformed"
fi

# --- 5. `vinos mcp <args>` delegates to vinos-mcp ----------------------

"$VINOS" mcp list --json >/dev/null 2>&1 || true
if [[ -f "$STUB_DIR/vinos-mcp.calls" ]] && grep -q 'list --json' "$STUB_DIR/vinos-mcp.calls"; then
  pass "'vinos mcp list --json' delegates to vinos-mcp"
else
  fail "'vinos mcp' did NOT reach vinos-mcp with argv"
fi

# --- 6. `vinos doctor` delegates to vinos-doctor -----------------------

"$VINOS" doctor >/dev/null 2>&1 || true
if [[ -f "$STUB_DIR/vinos-doctor.calls" ]]; then
  pass "'vinos doctor' delegates to vinos-doctor"
else
  fail "'vinos doctor' did NOT reach vinos-doctor"
fi

# --- 7. `vinos install <role>` delegates to vinos-install-<role> -------

"$VINOS" install ai >/dev/null 2>&1 || true
if [[ -f "$STUB_DIR/vinos-install-ai.calls" ]]; then
  pass "'vinos install ai' delegates to vinos-install-ai"
else
  fail "'vinos install ai' did NOT reach vinos-install-ai"
fi

if ! "$VINOS" install nonexistent-role >/dev/null 2>&1; then
  pass "'vinos install <unknown>' exits non-zero"
else
  fail "'vinos install <unknown>' should exit non-zero"
fi

# --- 8. vm-only subcommands emit clear "not implemented" ---------------

for vm_cmd in join leave agent mission secrets; do
  OUT="$("$VINOS" $vm_cmd 2>&1 || true)"
  if grep -q 'not implemented' <<<"$OUT"; then
    pass "'vinos $vm_cmd' emits 'not implemented' on dev"
  else
    fail "'vinos $vm_cmd' should say not implemented — got: $OUT"
  fi
done

# --- 9. Unknown subcommand exits non-zero ------------------------------

if "$VINOS" totally-fake 2>/dev/null; then
  fail "unknown subcommand should exit non-zero"
else
  pass "unknown subcommand exits non-zero"
fi

# --- 10. Persona detection with explicit /etc/vinos/persona ------------
# We can't write /etc/vinos/persona in the test host, but we can verify
# the CMD_DIR fallback picks up dev-tree cmd/*.sh when present. Create a
# fake cmd script and check it's called.

CMD_TEST_DIR="$REPO/usr/lib/vinos/cmd"
mkdir -p "$CMD_TEST_DIR"
cat >"$CMD_TEST_DIR/_pilot.sh" <<'EOF'
#!/usr/bin/env bash
printf '_pilot got: %s\n' "$*"
EOF
chmod +x "$CMD_TEST_DIR/_pilot.sh"

OUT="$("$VINOS" _pilot foo bar 2>&1 || true)"
if grep -q '_pilot got: foo bar' <<<"$OUT"; then
  pass "cmd/<name>.sh dispatch reaches the file with argv"
else
  fail "cmd/<name>.sh dispatch failed — got: $OUT"
fi
rm -f "$CMD_TEST_DIR/_pilot.sh"
rmdir --ignore-fail-on-non-empty "$CMD_TEST_DIR" 2>/dev/null || true

# --- Summary ------------------------------------------------------------

TOTAL=$((TESTS_PASSED + TESTS_FAILED))
printf '\n%d/%d passed\n' "$TESTS_PASSED" "$TOTAL"
[[ $TESTS_FAILED -eq 0 ]] || exit 1
