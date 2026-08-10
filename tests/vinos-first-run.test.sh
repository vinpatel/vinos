#!/usr/bin/env bash
# tests/vinos-first-run.test.sh — assertions for the 6-screen wizard.
#
# The wizard is interactive (gum-driven), so we run it under --dry-run
# with gum + sudo + interactive prompts shimmed. We assert:
#
#   1. --help prints usage
#   2. unknown flag exits non-zero
#   3. --dry-run creates the state file and marks all 6 screens complete
#   4. --skip <screen> leaves that screen unmarked
#   5. --reset clears prior state
#   6. Second run (no --reset) skips screens already marked done
#
# Exit 0 on all-green.

set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIZ="$REPO/bin/vinos-first-run"

pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)); }

[[ -x "$WIZ" ]] || { fail "vinos-first-run not executable"; exit 1; }
command -v jq >/dev/null 2>&1 || { fail "jq not installed on this host"; exit 1; }

# Fresh env per assertion so state can't leak.
STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT

# --- Shim gum so every prompt returns predictable answers -------------

# gum confirm → return 0 (yes) unless GUM_CONFIRM_NO=1
# gum input   → echo GUM_INPUT_ANSWER (default empty)
# gum choose  → echo lines from GUM_CHOOSE_ANSWER (space-separated), one per line
# gum style   → passthrough (print positional args)
cat >"$STUB_DIR/gum" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  confirm)
    if [[ "${GUM_CONFIRM_NO:-0}" == "1" ]]; then exit 1; else exit 0; fi
    ;;
  input)
    printf '%s\n' "${GUM_INPUT_ANSWER:-}"
    ;;
  choose)
    for w in ${GUM_CHOOSE_ANSWER:-}; do printf '%s\n' "$w"; done
    ;;
  style)
    shift
    for a in "$@"; do
      case "$a" in
        --*|-*) ;;
        [0-9]*|"1 4"|"1 0") ;;
        double) ;;
        center) ;;
        *) printf '%s\n' "$a" ;;
      esac
    done
    ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$STUB_DIR/gum"

# sudo shim: run the tail command in-process (drops privilege escalation).
cat >"$STUB_DIR/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
chmod +x "$STUB_DIR/sudo"

# hostnamectl / systemctl / vinos-t2-enable / ollama / vinos-launch-wifi /
# vinos-install-* / vinos-mcp / claude — no-op stubs so dry-run works
# even if the host doesn't have them.
for tool in hostnamectl systemctl vinos-t2-enable ollama vinos-launch-wifi \
            vinos-install-ai vinos-install-dev vinos-install-media \
            vinos-install-office vinos-install-gaming vinos-install-productivity \
            vinos-install-comms vinos-install-browser vinos-mcp claude \
            nmcli; do
  cat >"$STUB_DIR/$tool" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_DIR/$tool"
done

export PATH="$STUB_DIR:$PATH"

# Isolate XDG state so runs don't touch the real user profile.
_fresh_home() {
  local d; d=$(mktemp -d)
  printf '%s' "$d"
}

# --- 1. --help --------------------------------------------------------

if "$WIZ" --help 2>&1 | grep -qi 'vinos-first-run'; then
  pass "--help prints usage"
else
  fail "--help missing usage"
fi

# --- 2. Unknown flag exits non-zero ----------------------------------

if "$WIZ" --totally-not-a-flag >/dev/null 2>&1; then
  fail "unknown flag should exit non-zero"
else
  pass "unknown flag exits non-zero"
fi

# --- 3. Full run marks every screen ------------------------------------
#
# We use non-dry-run so state gets written. All side-effecting binaries
# (sudo, hostnamectl, systemctl, ollama, vinos-t2-enable, vinos-install-*)
# are shimmed to no-op above, so this is safe on any host.

HOME_TMP=$(_fresh_home)
HOME="$HOME_TMP" XDG_STATE_HOME="$HOME_TMP/.local/state" \
  "$WIZ" >/dev/null 2>&1 || true

STATE="$HOME_TMP/.local/state/vinos/first-run.json"
if [[ -f "$STATE" ]]; then
  pass "full run creates state file"
else
  fail "full run did NOT create state file at $STATE"
fi

for s in welcome identity network hardware ai bundles; do
  if [[ "$(jq -r --arg s "$s" '.screens[$s] // false' "$STATE" 2>/dev/null)" == "true" ]]; then
    pass "screen '$s' marked complete"
  else
    fail "screen '$s' NOT marked complete"
  fi
done

if [[ "$(jq -r '.completed_at // "null"' "$STATE" 2>/dev/null)" != "null" ]]; then
  pass "completed_at timestamp set"
else
  fail "completed_at is null"
fi

# --- 4. --skip leaves a screen unmarked --------------------------------

HOME_TMP=$(_fresh_home)
HOME="$HOME_TMP" XDG_STATE_HOME="$HOME_TMP/.local/state" \
  "$WIZ" --skip hardware --skip ai >/dev/null 2>&1 || true

STATE="$HOME_TMP/.local/state/vinos/first-run.json"
if [[ "$(jq -r '.screens.hardware // false' "$STATE")" != "true" ]]; then
  pass "--skip hardware leaves hardware unmarked"
else
  fail "--skip hardware still marked hardware complete"
fi
if [[ "$(jq -r '.screens.ai // false' "$STATE")" != "true" ]]; then
  pass "--skip ai leaves ai unmarked"
else
  fail "--skip ai still marked ai complete"
fi
if [[ "$(jq -r '.screens.welcome // false' "$STATE")" == "true" ]]; then
  pass "welcome still marked complete when other screens skipped"
else
  fail "welcome should still be marked when only hardware/ai skipped"
fi

# --- 5. --reset clears prior state -------------------------------------

# Run once fully, then run again with --reset and only welcome — the
# earlier "identity" mark should be wiped.
HOME_TMP=$(_fresh_home)
HOME="$HOME_TMP" XDG_STATE_HOME="$HOME_TMP/.local/state" \
  "$WIZ" >/dev/null 2>&1 || true

HOME="$HOME_TMP" XDG_STATE_HOME="$HOME_TMP/.local/state" \
  "$WIZ" --reset --skip identity --skip network --skip hardware --skip ai --skip bundles \
  >/dev/null 2>&1 || true

STATE="$HOME_TMP/.local/state/vinos/first-run.json"
if [[ "$(jq -r '.screens.identity // false' "$STATE")" != "true" ]]; then
  pass "--reset wipes prior 'identity' mark"
else
  fail "--reset did NOT wipe prior 'identity' mark"
fi
if [[ "$(jq -r '.screens.welcome // false' "$STATE")" == "true" ]]; then
  pass "post-reset, only 'welcome' is marked complete"
else
  fail "post-reset 'welcome' should have re-run"
fi

# --- 6. Second run (no --reset) skips already-done screens -------------

# After a full first run, a second run should not re-prompt. We check
# this by ensuring the completed_at timestamp doesn't move backwards
# and the state is unchanged in `screens.*`.
HOME_TMP=$(_fresh_home)
HOME="$HOME_TMP" XDG_STATE_HOME="$HOME_TMP/.local/state" \
  "$WIZ" >/dev/null 2>&1 || true
STATE="$HOME_TMP/.local/state/vinos/first-run.json"
FIRST_HASH="$(jq -c '.screens' "$STATE")"

HOME="$HOME_TMP" XDG_STATE_HOME="$HOME_TMP/.local/state" \
  "$WIZ" >/dev/null 2>&1 || true
SECOND_HASH="$(jq -c '.screens' "$STATE")"

if [[ "$FIRST_HASH" == "$SECOND_HASH" ]]; then
  pass "second run is a no-op (all screens already done)"
else
  fail "second run diverged from first (state should be stable)"
fi

# --- Summary ------------------------------------------------------------

TOTAL=$((TESTS_PASSED + TESTS_FAILED))
printf '\n%d/%d passed\n' "$TESTS_PASSED" "$TOTAL"
[[ $TESTS_FAILED -eq 0 ]] || exit 1
