#!/usr/bin/env bash
# iso/qemu-desktop.sh — boot the built ISO in a real QEMU window on the
# host, no host install required. Uses the vinos-iso-tester container
# (already has qemu-base + edk2-ovmf) with X11/Wayland socket forwarded
# so the QEMU GTK window renders on the user's desktop.
#
# Usage:
#   iso/qemu-desktop.sh                 # BIOS, 4G, KVM if available
#   iso/qemu-desktop.sh --mode uefi     # UEFI via OVMF
#   iso/qemu-desktop.sh --mem 8G
#   iso/qemu-desktop.sh --iso PATH
#
# Prefers host `qemu-system-x86_64` when present (faster startup);
# otherwise runs the tester container with GTK display forwarded.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO=""
MODE="bios"
MEM="4G"

die() { printf '\033[1;31m[qemu-desktop] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[qemu-desktop]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)  ISO="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --mem)  MEM="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$ISO" ]] && ISO="$(ls -1t "$ISO_DIR"/out/vinos-*.iso 2>/dev/null | head -1 || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO — run iso/build.sh (or pass --iso PATH)"
case "$MODE" in bios|uefi) ;; *) die "--mode must be bios or uefi" ;; esac

# Prefer host qemu when installed.
if command -v qemu-system-x86_64 >/dev/null 2>&1; then
  log "using host qemu-system-x86_64"
  args=(-m "$MEM" -smp 2 -cdrom "$ISO" -boot order=d,menu=off -vga std -display gtk)
  [[ -c /dev/kvm ]] && args+=(-enable-kvm)
  if [[ "$MODE" == uefi ]]; then
    ovmf_code=""
    for c in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd; do
      [[ -f "$c" ]] && { ovmf_code="$c"; break; }
    done
    [[ -n "$ovmf_code" ]] || die "OVMF_CODE not found — install edk2-ovmf"
    ovmf_vars=/tmp/vinos-OVMF_VARS.fd
    [[ -f "$ovmf_vars" ]] || cp "${ovmf_code%CODE.*}VARS.${ovmf_code##*CODE.}" "$ovmf_vars"
    args+=(
      -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code"
      -drive "if=pflash,format=raw,file=$ovmf_vars"
    )
  fi
  exec qemu-system-x86_64 "${args[@]}"
fi

# Fallback: run in a dedicated container image with GTK UI installed.
log "host qemu missing — falling back to docker + X11 forward"
IMG="vinos-qemu-desktop:latest"
if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  log "one-time: building qemu-desktop image (qemu-base + qemu-ui-gtk + edk2-ovmf)"
  docker build -t "$IMG" -f - . <<'DOCKERFILE'
FROM archlinux:latest
RUN pacman -Sy --needed --noconfirm qemu-base qemu-ui-gtk edk2-ovmf && pacman -Scc --noconfirm
DOCKERFILE
fi

[[ -n "${DISPLAY:-}" ]] || die "no DISPLAY — either install qemu-desktop on host (sudo pacman -S qemu-desktop edk2-ovmf) or run under X/Wayland+XWayland"

# Allow docker to open X11 windows on this display. Try xhost first,
# fall back to no-op (usually works with same-uid + socket mount).
if command -v xhost >/dev/null 2>&1; then
  xhost +local:root >/dev/null 2>&1 || true
fi

KVM_ARGS=()
[[ -c /dev/kvm && -w /dev/kvm ]] && KVM_ARGS+=(--device /dev/kvm)

CMD=(
  qemu-system-x86_64
  -m "$MEM" -smp 2
  -machine accel=kvm:tcg
  -cdrom /iso.iso
  -boot order=d,menu=off
  -vga std
  -display gtk
)
if [[ "$MODE" == uefi ]]; then
  CMD+=(
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
    -drive "if=pflash,format=raw,file=/tmp/OVMF_VARS.fd"
  )
fi

docker run --rm "${KVM_ARGS[@]}" \
  --net=host \
  -e DISPLAY="$DISPLAY" \
  -e XAUTHORITY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$ISO":/iso.iso:ro \
  --user "$(id -u):$(id -g)" \
  --group-add "$(getent group video | cut -d: -f3)" \
  "$IMG" \
  bash -c '
    if [[ "'"$MODE"'" == uefi ]]; then
      cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/OVMF_VARS.fd
    fi
    exec '"${CMD[*]}"'
  '
