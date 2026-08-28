#!/usr/bin/env bash
# iso/qa/installer-boot-render.sh — run the installer's bootloader phase
# against a fake target and assert the menu it writes is the right one for
# the hardware.
#
# Why this exists as a separate gate from config-lint.sh: config-lint reads
# the source and checks that the right strings are present. That would not
# have caught the v1.4.0 black screen, because the strings were all fine —
# the bug was in which branch ran. This executes the phase and reads the
# limine.conf that comes out.
#
# The bug: preflight detected PROFILE=t2mac and persisted it, pacstrap
# installed a stock kernel regardless, and bootloader wrote one
# `vmlinuz-linux ... quiet splash` entry for every machine. A T2 MacBook
# installed to disk therefore rebooted into a kernel with no apple-bce
# (dead internal keyboard and trackpad) and no Broadcom firmware (no
# Wi-Fi), under a splash that hid the console. Black screen, nothing to
# type into, no way to reach the vinos-t2-enable escape hatch.
#
# Three cases, run without touching a real disk:
#   A  Apple T2 Mac, linux-t2 installed   → T2 entry, default, T2 quirks
#   B  Apple T2 Mac, linux-t2 MISSING     → stock kernel, NO splash, quirks
#   C  anything else                      → unchanged from before the fix
#
# Exit 0 on green. No root, no QEMU, no network — runs in ~1 second, so it
# belongs at build time next to config-lint.sh.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[1;31m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'; RESET='\033[0m'
FAIL=0; PASS=0
fail() { printf "${RED}FAIL${RESET} %s\n" "$*"; FAIL=$((FAIL+1)); }
pass() { printf "${GREEN}PASS${RESET} %s\n" "$*"; PASS=$((PASS+1)); }

# Render the bootloader phase for one hardware case. Echoes the path of the
# limine.conf it produced; the caller asserts against it.
_render() {
  local profile="$1" t2kernel="$2" root="$3"

  mkdir -p "$root/target/boot" "$root/target/usr/share/limine" "$root/share"
  : > "$root/target/usr/share/limine/BOOTX64.EFI"
  cp "$REPO/config/limine/limine.conf" "$root/share/limine.conf"
  : > "$root/target/boot/vmlinuz-linux"
  : > "$root/target/boot/initramfs-linux.img"
  : > "$root/target/boot/initramfs-linux-fallback.img"
  if [[ "$t2kernel" == 1 ]]; then
    : > "$root/target/boot/vmlinuz-linux-t2"
    : > "$root/target/boot/initramfs-linux-t2.img"
    : > "$root/target/boot/initramfs-linux-t2-fallback.img"
  fi

  # Subshell so the phase's helpers, traps and stubs never leak into ours.
  # `set -Eeuo pipefail` matches iso/installer/vinos-install exactly: the
  # gate previously ran the phase without -e, so a mid-phase non-zero exit
  # that would abort a real install passed here silently.
  (
    set -Eeuo pipefail
    export VINOS_STATE_DIR="$root/state"
    export VINOS_TARGET_ROOT="$root/target"
    export VINOS_LIMINE_DIR="$root/share"
    # shellcheck source=/dev/null
    source "$REPO/iso/installer/helpers/all.sh"
    # The phase legitimately wants a mounted ESP and a firmware it can
    # register with. Neither exists here; both are non-essential to the
    # thing under test.
    mountpoint() { return 0; }
    efibootmgr() { return 1; }
    answers_write DISK /dev/sdz EFI_PART /dev/sdz1 ROOT_UUID "TEST-UUID" \
                  PROFILE "$profile" T2_KERNEL "$t2kernel"
    # shellcheck source=/dev/null
    source "$REPO/iso/installer/bootloader/all.sh"
  ) >"$root/phase.log" 2>&1
}

# First cmdline: in limine, default_entry is an index over entries in file
# order and the phase always writes the intended default first — so the
# first cmdline in the file is what the machine actually boots.
_first_cmdline() { grep -E '^[[:space:]]*cmdline:' "$1" | head -1; }
_default_index() { sed -n 's/^default_entry:[[:space:]]*//p' "$1" | head -1; }
_nth_entry_title() { awk -v n="$2" '/^\// && substr($0,2,1) != "/" { i++; if (i == n) { print; exit } }' "$1"; }

printf '\n%b== iso/qa/installer-boot-render.sh ==%b\n' "$CYAN" "$RESET"

# ── Case A: Apple T2 Mac with the T2 kernel installed ─────────────────
_a="$(mktemp -d)"; trap 'rm -rf "$_a" "$_b" "$_c"' EXIT
_b="$(mktemp -d)"; _c="$(mktemp -d)"

_render t2mac 1 "$_a"
_conf="$_a/target/boot/limine.conf"
if [[ ! -f "$_conf" ]]; then
  fail "A: bootloader phase wrote no limine.conf"; sed 's/^/     /' "$_a/phase.log"
else
  _first="$(_first_cmdline "$_conf")"
  _idx="$(_default_index "$_conf")"
  _dflt="$(_nth_entry_title "$_conf" "${_idx:-0}")"

  [[ "$_dflt" == "/vinOS (Apple T2 Mac)" ]] \
    && pass "A: default_entry ${_idx} is the T2 entry" \
    || fail "A: default_entry ${_idx} is '${_dflt}' — a T2 Mac would boot the wrong kernel"

  grep -q 'path: boot():/vmlinuz-linux-t2' "$_conf" \
    && pass "A: T2 entry boots vmlinuz-linux-t2" \
    || fail "A: no entry boots vmlinuz-linux-t2"

  _missing=""
  for knob in intel_iommu=on iommu=pt pcie_ports=compat cfg80211.ieee80211_regdom=US; do
    [[ "$_first" == *"$knob"* ]] || _missing="$_missing $knob"
  done
  [[ -z "$_missing" ]] \
    && pass "A: T2 quirks on the default command line" \
    || fail "A: default command line is missing T2 quirks:$_missing"

  # An unsplashed twin must exist. If the graphical boot ever stalls on
  # this hardware, this entry is the only way to see why.
  grep -q '^/vinOS (Apple T2 Mac, verbose console)$' "$_conf" \
    && pass "A: unsplashed T2 recovery entry present" \
    || fail "A: no verbose T2 entry — a stalled graphical boot would be undiagnosable"

  # Stock entries survive as a rescue path for a bad linux-t2 update.
  grep -q '^/vinOS$' "$_conf" \
    && pass "A: stock rescue entry retained" \
    || fail "A: stock /vinOS rescue entry is gone"
fi

# ── Case B: Apple T2 Mac, T2 kernel could not be installed ────────────
_render t2mac 0 "$_b"
_conf="$_b/target/boot/limine.conf"
if [[ ! -f "$_conf" ]]; then
  fail "B: bootloader phase wrote no limine.conf"; sed 's/^/     /' "$_b/phase.log"
else
  _first="$(_first_cmdline "$_conf")"

  # THE regression check. Splash here is the black screen: a kernel with
  # no display, keyboard or Wi-Fi driver, booting behind a splash that
  # hides the console you would need to fix it from.
  [[ "$_first" != *splash* ]] \
    && pass "B: Apple-hardware stock fallback boots UNSPLASHED (readable console)" \
    || fail "B: stock fallback on Apple hardware still carries 'splash' — this is the v1.4.0 black screen"

  [[ "$_first" == *intel_iommu=on* ]] \
    && pass "B: T2 quirks still applied to the stock kernel" \
    || fail "B: stock fallback on Apple hardware carries no T2 quirks"

  ! grep -q 'vmlinuz-linux-t2' "$_conf" \
    && pass "B: no entry points at a T2 kernel that was never installed" \
    || fail "B: menu offers a vmlinuz-linux-t2 entry but the file is not on the ESP — it would panic after the menu disappears"
fi

# ── Case C: everything else — must be unchanged ───────────────────────
_render generic 0 "$_c"
_conf="$_c/target/boot/limine.conf"
if [[ ! -f "$_conf" ]]; then
  fail "C: bootloader phase wrote no limine.conf"; sed 's/^/     /' "$_c/phase.log"
else
  _first="$(_first_cmdline "$_conf")"
  [[ "$_first" == *"quiet splash"* && "$_first" != *intel_iommu* ]] \
    && pass "C: generic hardware unchanged (quiet splash, no T2 quirks)" \
    || fail "C: generic entry changed — got: $_first"

  [[ "$(_nth_entry_title "$_conf" "$(_default_index "$_conf")")" == "/vinOS" ]] \
    && pass "C: default_entry is /vinOS" \
    || fail "C: default_entry is not /vinOS"
fi

printf '\n%bsummary%b: %d pass · %d fail\n' "$CYAN" "$RESET" "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
