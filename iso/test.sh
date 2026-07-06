#!/usr/bin/env bash
# iso/test.sh — QEMU acceptance for the built ISO. Boots the ISO headless,
# tails the serial console, and looks for the VINOS_BOOT_OK marker written
# by airootfs/etc/systemd/system/vinos-boot-marker.service.
#
# Modes:
#   bios (default) — BIOS boot with SeaBIOS. I1 DONE WHEN.
#   uefi           — UEFI boot via OVMF (I2+).
#
# Usage: iso/test.sh [--mode bios|uefi] [--iso PATH] [--mem 4G] [--timeout 240]
#
# Runs QEMU inside the same privileged builder image (which has
# qemu-headless installed by test.sh's own bootstrap step so the host
# stays untouched). /dev/kvm is passed through when available for speed.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="bios"
ISO=""
MEM="4G"
TIMEOUT=240

die() { printf '\033[1;31m[iso-test] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[iso-test]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)    MODE="$2"; shift 2 ;;
    --iso)     ISO="$2"; shift 2 ;;
    --mem)     MEM="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$ISO" ]] && ISO="$(ls -1t "$ISO_DIR"/out/vinos-*.iso 2>/dev/null | head -1 || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO found — run iso/build.sh first (or pass --iso PATH)"
case "$MODE" in bios|uefi) ;; *) die "--mode must be bios or uefi" ;; esac

log "boot test: mode=$MODE mem=$MEM timeout=${TIMEOUT}s iso=$(basename "$ISO")"

IMG="vinos-iso-tester:latest"
if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  log "one-time: building QEMU tester image"
  docker build -t "$IMG" -f - "$ISO_DIR" <<'DOCKERFILE'
FROM archlinux:latest
RUN pacman -Sy --needed --noconfirm qemu-base edk2-ovmf && pacman -Scc --noconfirm
DOCKERFILE
fi

# KVM only if /dev/kvm is present AND user can access it via the container.
KVM_ARGS=()
if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  KVM_ARGS+=(--device /dev/kvm)
fi

docker run --rm "${KVM_ARGS[@]}" \
  -v "$ISO":/iso.iso:ro \
  -v "$ISO_DIR/out":/out \
  -e MODE="$MODE" -e MEM="$MEM" -e TIMEOUT="$TIMEOUT" \
  "$IMG" \
  bash -euo pipefail -c '
    serial=/out/serial-${MODE}.log
    : > "$serial"
    ACCEL=tcg
    [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
    qemu_args=(
      -m "$MEM" -smp 2
      -machine accel=$ACCEL
      -cdrom /iso.iso
      -boot order=d,menu=off
      -nographic
      -serial "file:$serial"
      -monitor none
      -no-reboot
      -nic user
    )
    if [[ "$MODE" == uefi ]]; then
      # Copy OVMF vars so QEMU can write to them.
      cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/OVMF_VARS.fd
      qemu_args+=(
        -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
        -drive if=pflash,format=raw,file=/tmp/OVMF_VARS.fd
      )
    fi
    echo "== launching qemu-system-x86_64 (accel=$ACCEL) =="
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
    echo "---- serial tail (last 40 lines) ----"
    tail -40 "$serial" || true
    echo "---- end serial ----"
    if (( found )); then
      echo "PASS: VINOS_BOOT_OK observed on serial ($MODE)"
    else
      echo "FAIL: did not see VINOS_BOOT_OK within ${TIMEOUT}s ($MODE)"
      exit 1
    fi
  '
