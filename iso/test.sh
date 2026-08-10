#!/usr/bin/env bash
# iso/test.sh — QEMU acceptance for the built ISO. Boots the ISO headless,
# tails the serial console, and asserts:
#   - test 5.1: VINOS_BOOT_OK marker reached (multi-user/graphical).
#   - test 5.2: /etc/os-release ID=vinos (echoed by the marker service).
#   - test 5.3: ISO filename + label carry the repo VERSION.
#   - test 5.4: ISO size ≤ SIZE_BUDGET_GB (default 5.0 GB). The gate
#              was 3.5 GB when the ISO was 1.92 GB; grew with the
#              full Hyprland stack + T2 support + linux-t2 kernel to
#              4.3 GB by v1.1.0, and 4.36 GB by v1.2.0 (added
#              claude-code + ollama + nodejs + npm for A4). 5.0 GB
#              gives headroom for v1.3.0 while still catching balloon.
#   - test 5.5: boot passes at MEM_FLOOR (default 3G), simulating minimum
#              hardware.
#
# Modes:
#   bios (default) — BIOS boot with SeaBIOS.
#   uefi           — UEFI boot via OVMF.
#   both           — bios + uefi sequentially.
#   plymouth       — hand off to iso/test-plymouth.sh (boot + shutdown splash).
#   matrix         — the I3 DONE-WHEN matrix: bios/uefi @ 4G,
#                    bios @ 3G RAM floor, bios @ -nic none (offline),
#                    plus the plymouth splash test.
#
# Networking:
#   --net user (default) — QEMU SLIRP outbound; --net none = no NIC.
#
# Usage: iso/test.sh [--mode bios|uefi|both|matrix] [--iso PATH]
#                    [--mem 4G] [--timeout 300] [--net user|none]
#
# Runs QEMU inside a privileged builder image (which has qemu-headless +
# edk2-ovmf). /dev/kvm is passed through when available for speed.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="bios"
ISO=""
MEM="4G"
TIMEOUT=300
NET="user"
SIZE_BUDGET_GB="${VINOS_ISO_SIZE_BUDGET_GB:-5.0}"

die() { printf '\033[1;31m[iso-test] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[iso-test]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)    MODE="$2"; shift 2 ;;
    --iso)     ISO="$2"; shift 2 ;;
    --mem)     MEM="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --net)     NET="$2"; shift 2 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$ISO" ]] && ISO="$(ls -1t "$ISO_DIR"/out/vinos-*.iso 2>/dev/null | head -1 || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO found — run iso/build.sh first (or pass --iso PATH)"
# Normalize to an absolute path: docker rejects relative volume specs
# ("iso/out/…") with "invalid characters for a local volume name".
ISO="$(readlink -f "$ISO")"
case "$MODE" in bios|uefi|both|matrix|plymouth) ;; *) die "--mode must be bios/uefi/both/plymouth/matrix" ;; esac
case "$NET"  in user|none) ;;              *) die "--net must be user or none" ;; esac

REPO="$(cd "$ISO_DIR/.." && pwd)"
VERSION="$(<"$REPO/VERSION")"
iso_basename="$(basename "$ISO")"

# Test 5.0: install-to-disk regression preconditions.
# On T2 Macs, pacstrap can't resolve linux-t2 unless the target chroot's
# pacman.conf has [arch-mact2] registered first — which archinstall
# doesn't inherit from the ISO. The v1.1.0 baseline shipped a t2mac.json
# that specified linux-t2 as its kernel and pacstrap failed. Assert:
#   (a) t2mac.json specifies stock "linux" as the base kernel.
#   (b) bin/vinos-t2-enable exists + is executable (post-boot T2 stack).
#   (c) bin/vinos-first-run mentions vinos-t2-enable (Apple detection wired).
t2mac_json="$REPO/iso/profiles/archinstall/t2mac.json"
t2_enable="$REPO/bin/vinos-t2-enable"
first_run="$REPO/bin/vinos-first-run"

if [[ ! -f "$t2mac_json" ]]; then
  die "test 5.0a: $t2mac_json missing"
fi
if ! grep -qE '"kernels"[[:space:]]*:[[:space:]]*\[[[:space:]]*"linux"[[:space:]]*\]' "$t2mac_json"; then
  die "test 5.0a: $t2mac_json must pacstrap stock 'linux' — pacstrap of linux-t2 fails on target chroot (T2 install regression)"
fi
if grep -q '"linux-t2"' "$t2mac_json"; then
  die "test 5.0a: $t2mac_json still references linux-t2 in a package list — defer to bin/vinos-t2-enable"
fi
if [[ ! -x "$t2_enable" ]]; then
  die "test 5.0b: $t2_enable missing or not executable — T2 support install path broken"
fi
if ! grep -q 'vinos-t2-enable' "$first_run"; then
  die "test 5.0c: $first_run does not reference vinos-t2-enable — Apple hardware prompt not wired"
fi
log "test 5.0 (install-to-disk regression): PASS — t2mac.json=stock linux, vinos-t2-enable present, first-run wired"

# Test 5.3: identity in artifacts — ISO name carries the repo VERSION.
if [[ "$iso_basename" != *"$VERSION"* ]]; then
  die "test 5.3: ISO filename '$iso_basename' does not contain VERSION '$VERSION'"
fi
if command -v file >/dev/null 2>&1; then
  label_line="$(file "$ISO" || true)"
  if ! grep -q "'VINOS_" <<<"$label_line"; then
    die "test 5.3: ISO label missing VINOS_ prefix (file said: $label_line)"
  fi
fi
log "test 5.3 (artifacts): PASS — filename carries $VERSION, label VINOS_*"

# Test 5.4: size budget.
iso_bytes="$(stat -c '%s' "$ISO")"
iso_gb_x100=$(( iso_bytes * 100 / 1024 / 1024 / 1024 ))  # size in 0.01 GB
budget_x100="$(printf '%.0f' "$(awk -v b="$SIZE_BUDGET_GB" 'BEGIN{printf "%.0f", b*100}')")"
if (( iso_gb_x100 > budget_x100 )); then
  die "test 5.4: ISO is $(( iso_gb_x100 / 100 )).$(printf '%02d' $(( iso_gb_x100 % 100 ))) GB > budget ${SIZE_BUDGET_GB} GB"
fi
log "test 5.4 (size budget): PASS — $(( iso_gb_x100 / 100 )).$(printf '%02d' $(( iso_gb_x100 % 100 ))) GB ≤ ${SIZE_BUDGET_GB} GB"

IMG="vinos-iso-tester:latest"
if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  log "one-time: building QEMU tester image"
  docker build -t "$IMG" -f - "$ISO_DIR" <<'DOCKERFILE'
FROM archlinux:latest
RUN pacman -Sy --needed --noconfirm qemu-base edk2-ovmf && pacman -Scc --noconfirm
DOCKERFILE
fi

KVM_ARGS=()
if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  KVM_ARGS+=(--device /dev/kvm)
fi

# run_one BOOT_MODE MEM NET LABEL — one QEMU launch, returns 0 on marker seen.
run_one() {
  local boot_mode="$1" mem="$2" net="$3" label="$4"
  log "boot: mode=$boot_mode mem=$mem net=$net iso=$iso_basename [$label]"
  docker run --rm "${KVM_ARGS[@]}" \
    -v "$ISO":/iso.iso:ro \
    -v "$ISO_DIR/out":/out \
    -e MODE="$boot_mode" -e MEM="$mem" -e TIMEOUT="$TIMEOUT" -e NET="$net" -e LABEL="$label" \
    "$IMG" \
    bash -euo pipefail -c '
      serial=/out/serial-${LABEL}.log
      : > "$serial"
      ACCEL=tcg
      [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
      qemu_args=(
        -m "$MEM" -smp 2
        -machine accel=$ACCEL
        -cdrom /iso.iso
        -boot order=d,menu=off
        -display none
        -vga std
        -serial "file:$serial"
        -monitor none
        -no-reboot
      )
      case "$NET" in
        user) qemu_args+=(-nic user) ;;
        none) qemu_args+=(-nic none) ;;
      esac
      if [[ "$MODE" == uefi ]]; then
        cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/OVMF_VARS.fd
        qemu_args+=(
          -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
          -drive if=pflash,format=raw,file=/tmp/OVMF_VARS.fd
        )
      fi
      echo "== qemu-system-x86_64 accel=$ACCEL mode=$MODE mem=$MEM net=$NET =="
      timeout --preserve-status "$TIMEOUT" qemu-system-x86_64 "${qemu_args[@]}" >/dev/null 2>&1 &
      qpid=$!
      deadline=$(( $(date +%s) + TIMEOUT ))
      found=0
      while [[ $(date +%s) -lt $deadline ]]; do
        if grep -q "VINOS_BOOT_OK" "$serial" 2>/dev/null; then found=1; break; fi
        if ! kill -0 $qpid 2>/dev/null; then break; fi
        sleep 2
      done
      kill $qpid 2>/dev/null || true
      wait $qpid 2>/dev/null || true
      echo "---- serial tail (last 25 lines, ${LABEL}) ----"
      tail -25 "$serial" || true
      echo "---- end ${LABEL} ----"
      if ! (( found )); then
        echo "FAIL: no VINOS_BOOT_OK within ${TIMEOUT}s [${LABEL}]"
        exit 1
      fi
      if ! grep -Fq "ID=vinos" "$serial"; then
        echo "FAIL: test 5.2 — ID=vinos not on serial [${LABEL}]"
        exit 1
      fi
      echo "PASS [${LABEL}]: VINOS_BOOT_OK + ID=vinos"
    '
}

run_plymouth() {
  # Delegate boot+shutdown splash verification to iso/test-plymouth.sh.
  # This is the ship-gate wiring for Plymouth regressions (v1.1.0 shipped
  # with a shutdown-splash gap that was never covered by iso/test.sh).
  local iso_arg=()
  [[ -n "$ISO" ]] && iso_arg=(--iso "$ISO")
  log "test 5.6 (plymouth splash): handing off to iso/test-plymouth.sh"
  "$ISO_DIR/test-plymouth.sh" "${iso_arg[@]}" || die "test 5.6: Plymouth boot/shutdown splash regressed"
  log "test 5.6 (plymouth splash): PASS"
}

case "$MODE" in
  matrix)
    run_one bios "$MEM" user "bios-4g-net"
    run_one uefi "$MEM" user "uefi-4g-net"
    run_one bios "3G"   user "bios-3g-ramfloor"
    run_one bios "$MEM" none "bios-4g-offline"
    run_plymouth
    log "MATRIX PASS — 5.1 + 5.2 + 5.4 + 5.5 + offline boot + Plymouth all green"
    ;;
  both)     run_one bios "$MEM" "$NET" bios; run_one uefi "$MEM" "$NET" uefi ;;
  plymouth) run_plymouth ;;
  *)        run_one "$MODE" "$MEM" "$NET" "$MODE" ;;
esac
