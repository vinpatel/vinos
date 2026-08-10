#!/usr/bin/env bash
# tests/vinos-menu.test.sh — assertions for vinos-menu subcommand routing.
#
# vinos-menu is normally interactive (walker/gum/fzf/stdin). We test it by
# forcing the "stdin" chooser branch (no WAYLAND_DISPLAY, no DISPLAY, and
# walker/gum/fzf shimmed to fail via PATH). For every subcommand we
# capture the list of MENU_ITEMS by feeding an intentionally-invalid pick
# number and grepping the numbered listing that stdin-fallback prints.
#
# For handler-only subcommands (background/theme/screenrecord/reminder-set)
# we shim their tail command (vinos-theme, gpu-screen-recorder, vinos-reminder)
# to a recording script and assert the correct binary was reached with the
# expected argv.
#
# Exit 0 on all-green.

set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VINOS_MENU="$REPO/bin/vinos-menu"

pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)); }

[[ -x "$VINOS_MENU" ]] || { fail "vinos-menu not executable at $VINOS_MENU"; exit 1; }

# --- Env setup: force stdin-fallback path -------------------------------

STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT

# Shim walker/gum/fzf to fail so vinos-menu falls through to _pick_stdin.
for tool in walker gum fzf; do
  cat >"$STUB_DIR/$tool" <<EOF
#!/usr/bin/env bash
exit 127
EOF
  chmod +x "$STUB_DIR/$tool"
done

# Wrap `command -v` fallthrough: even with WAYLAND_DISPLAY set, walker
# resolves via PATH. Our shims exit 127, but the outer script still
# needs to *find* them before /usr/bin/walker. Prefix STUB_DIR to PATH
# for the whole test — child processes inherit it.
unset WAYLAND_DISPLAY DISPLAY
export PATH="$STUB_DIR:$PATH"
export VINOS_MENU_FORCE_STDIN=1

# --- Helper: list items for a subcommand --------------------------------

_list_items() {
  # Feeds an invalid pick number so _pick_stdin returns non-zero, which
  # sets $PICKED empty and _run() no-ops. The numbered listing goes to
  # stderr (so `$(...)` capture in vinos-menu doesn't eat it). We
  # 2>&1 it back onto stdout for grepping.
  local subcmd="$1"
  printf '999\n' | "$VINOS_MENU" $subcmd 2>&1 || true
}

_assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label — missing: $needle"
    printf '    haystack:\n%s\n' "$haystack" | head -20 >&2
  fi
}

# --- 1. Top-level menu --------------------------------------------------

TOP="$(_list_items "")"
_assert_contains "$TOP" "Install: ai bundle"     "top-level lists ai bundle"
_assert_contains "$TOP" "Install: dev bundle"    "top-level lists dev bundle"
_assert_contains "$TOP" "Capture menu →"         "top-level lists Capture submenu link"
_assert_contains "$TOP" "Toggle menu →"          "top-level lists Toggle submenu link"
_assert_contains "$TOP" "Hardware menu →"        "top-level lists Hardware submenu link"
_assert_contains "$TOP" "System menu →"          "top-level lists System submenu link"
_assert_contains "$TOP" "Lock screen"            "top-level lists Lock screen"

# --- 2. capture ---------------------------------------------------------

CAP="$(_list_items capture)"
_assert_contains "$CAP" "Screenshot (full)"     "capture lists Screenshot (full)"
_assert_contains "$CAP" "Screenshot (region)"   "capture lists Screenshot (region)"
_assert_contains "$CAP" "Screen recording"      "capture lists Screen recording"
_assert_contains "$CAP" "Color picker"          "capture lists Color picker"
_assert_contains "$CAP" "Extract text (OCR)"    "capture lists OCR"

# --- 3. toggle ----------------------------------------------------------

TOG="$(_list_items toggle)"
_assert_contains "$TOG" "Toggle top bar"        "toggle lists waybar"
_assert_contains "$TOG" "Toggle idle-lock"      "toggle lists idle-lock"
_assert_contains "$TOG" "Toggle night light"    "toggle lists night light"
_assert_contains "$TOG" "Toggle notification silence" "toggle lists notification silence"
_assert_contains "$TOG" "Toggle window transparency"  "toggle lists window transparency"
_assert_contains "$TOG" "Toggle window gaps"    "toggle lists window gaps"

# --- 4. hardware --------------------------------------------------------

HW="$(_list_items hardware)"
_assert_contains "$HW" "Wi-Fi (impala)"         "hardware lists Wi-Fi"
_assert_contains "$HW" "Bluetooth"              "hardware lists Bluetooth"
_assert_contains "$HW" "Audio mixer"            "hardware lists Audio mixer"
_assert_contains "$HW" "Activity (btop)"        "hardware lists Activity"
_assert_contains "$HW" "Hardware report"        "hardware lists Hardware report"

# --- 5. system ----------------------------------------------------------

SYS="$(_list_items system)"
_assert_contains "$SYS" "Lock screen"           "system lists Lock screen"
_assert_contains "$SYS" "Suspend"               "system lists Suspend"
_assert_contains "$SYS" "Logout Hyprland"       "system lists Logout"
_assert_contains "$SYS" "Reboot"                "system lists Reboot"
_assert_contains "$SYS" "Shutdown"              "system lists Shutdown"

# --- 6. share -----------------------------------------------------------

SH="$(_list_items share)"
# With no captures dir on the fresh test host, share should still print
# at least the "no captures yet" fallback + window-title action.
_assert_contains "$SH" "Copy current window title" "share lists window-title copy action"

# --- 7. background / theme delegate to vinos-theme --pick ---------------

# Shim vinos-theme to record its argv, then check the tail invocation.
cat >"$STUB_DIR/vinos-theme" <<'EOF'
#!/usr/bin/env bash
printf 'vinos-theme %s\n' "$*" >"$STUB_DIR/theme.calls"
EOF
chmod +x "$STUB_DIR/vinos-theme"
STUB_DIR="$STUB_DIR" # export for the heredoc above
export STUB_DIR

"$VINOS_MENU" background >/dev/null 2>&1 || true
if [[ -f "$STUB_DIR/theme.calls" ]] && grep -q -- '--pick' "$STUB_DIR/theme.calls"; then
  pass "background delegates to vinos-theme --pick"
else
  fail "background did NOT reach vinos-theme --pick"
fi
rm -f "$STUB_DIR/theme.calls"

"$VINOS_MENU" theme >/dev/null 2>&1 || true
if [[ -f "$STUB_DIR/theme.calls" ]] && grep -q -- '--pick' "$STUB_DIR/theme.calls"; then
  pass "theme delegates to vinos-theme --pick"
else
  fail "theme did NOT reach vinos-theme --pick"
fi

# --- 8. reminder-set ----------------------------------------------------

cat >"$STUB_DIR/vinos-reminder" <<EOF
#!/usr/bin/env bash
printf 'vinos-reminder %s\n' "\$*" >"$STUB_DIR/reminder.calls"
EOF
chmod +x "$STUB_DIR/vinos-reminder"

# reminder-set uses gum-input when available. Replace the exit-127
# gum shim with one that echoes a single stdin line for `gum input`
# calls, so the pipeline `printf '5\ntest message\n' | vinos-menu
# reminder-set` walks both prompts naturally.
cat >"$STUB_DIR/gum" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "input" ]]; then
  IFS= read -r line || true
  printf '%s\n' "$line"
  exit 0
fi
exit 127
EOF
chmod +x "$STUB_DIR/gum"
printf '5\ntest message\n' \
  | "$VINOS_MENU" reminder-set >/dev/null 2>&1 || true
if [[ -f "$STUB_DIR/reminder.calls" ]] && grep -q '5 test message' "$STUB_DIR/reminder.calls"; then
  pass "reminder-set passes minutes+message to vinos-reminder"
else
  fail "reminder-set did NOT reach vinos-reminder with 5 test message"
  [[ -f "$STUB_DIR/reminder.calls" ]] && cat "$STUB_DIR/reminder.calls" >&2
fi

# --- 9. screenrecord toggle --------------------------------------------

# When no gpu-screen-recorder is running, invocation should exec one.
# Shim gpu-screen-recorder to a recorder that writes its argv and exits.
cat >"$STUB_DIR/gpu-screen-recorder" <<EOF
#!/usr/bin/env bash
printf 'gpu-screen-recorder %s\n' "\$*" >"$STUB_DIR/gsr.calls"
EOF
chmod +x "$STUB_DIR/gpu-screen-recorder"

# hyprctl absent → falls back to "screen"; notify-send absent → soft-fail.
VINOS_RECORD_MONITOR="TESTMON" \
  "$VINOS_MENU" screenrecord >/dev/null 2>&1 || true
if [[ -f "$STUB_DIR/gsr.calls" ]] && grep -q 'TESTMON' "$STUB_DIR/gsr.calls"; then
  pass "screenrecord (fresh) exec's gpu-screen-recorder on the right monitor"
else
  fail "screenrecord (fresh) did NOT reach gpu-screen-recorder with -w TESTMON"
  [[ -f "$STUB_DIR/gsr.calls" ]] && cat "$STUB_DIR/gsr.calls" >&2
fi

# --- 10. help & unknown subcommand -------------------------------------

if "$VINOS_MENU" --help 2>/dev/null | grep -qi 'vinos-menu'; then
  pass "--help prints usage"
else
  fail "--help did not print usage"
fi

if "$VINOS_MENU" totally-fake 2>/dev/null; then
  fail "unknown subcommand should exit non-zero"
else
  pass "unknown subcommand exits non-zero"
fi

# --- Summary ------------------------------------------------------------

TOTAL=$((TESTS_PASSED + TESTS_FAILED))
printf '\n%d/%d passed\n' "$TESTS_PASSED" "$TOTAL"
[[ $TESTS_FAILED -eq 0 ]] || exit 1
