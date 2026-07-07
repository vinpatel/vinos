#!/usr/bin/env bash
# iso/test-desktop.sh — headless capture of the vinOS desktop.
# Boots the ISO under QEMU with -vga std, waits past autologin
# (greetd initial_session → Hyprland), and HMP screendumps at
# 60/80/100/120s so a human can see the actual desktop chrome.
#
# Not a pass/fail test — this is a "what does the desktop look like"
# harness. Emits iso/out/desktop-<Ns>.ppm + a PNG-converted set for
# easy viewing.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO=""
FRAMES=(60 80 100 120)

die() { printf '\033[1;31m[desktop-test] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[desktop-test]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --frames) IFS=',' read -r -a FRAMES <<<"$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$ISO" ]] && ISO="$(find "$ISO_DIR/out" -maxdepth 1 -name 'vinos-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO — run iso/build.sh first"

IMG="vinos-iso-tester:latest"
docker image inspect "$IMG" >/dev/null 2>&1 || die "tester image missing — run iso/test.sh once first"

KVM_ARGS=()
[[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]] && KVM_ARGS+=(--device /dev/kvm)

OUT="$ISO_DIR/out"
mkdir -p "$OUT"
rm -f "$OUT"/desktop-*.ppm "$OUT"/desktop-*.png

log "booting $(basename "$ISO") headless, screendumping at ${FRAMES[*]}s"
docker run --rm "${KVM_ARGS[@]}" \
  -v "$ISO":/iso.iso:ro \
  -v "$OUT":/out \
  -e FRAMES="${FRAMES[*]}" \
  "$IMG" \
  bash -euo pipefail -c '
    ACCEL=tcg; [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
    mkfifo /tmp/hmp.in
    ( sleep 200 > /tmp/hmp.in ) &
    hmp_holder=$!
    qemu-system-x86_64 \
      -m 4G -smp 2 -machine accel=$ACCEL \
      -cdrom /iso.iso -boot order=d,menu=off \
      -display none -vga std \
      -serial file:/out/desktop-serial.log \
      -monitor stdio -no-reboot \
      < /tmp/hmp.in > /tmp/hmp.out 2>&1 &
    qpid=$!
    start=$(date +%s)
    for s in $FRAMES; do
      while [[ $(( $(date +%s) - start )) -lt $s ]]; do sleep 0.2; done
      echo "screendump /out/desktop-${s}s.ppm" > /tmp/hmp.in
      sleep 0.5
    done
    sleep 1
    echo "quit" > /tmp/hmp.in
    wait $qpid 2>/dev/null || true
    kill $hmp_holder 2>/dev/null || true
    ls -la /out/desktop-*.ppm 2>&1
  '

# Convert to PNG for easy inspection using the archlinux image with
# imagemagick — the tester image likely does not have magick.
docker run --rm -v "$OUT":/out archlinux:latest bash -c '
  pacman -Sy --noconfirm imagemagick >/dev/null 2>&1
  for f in /out/desktop-*.ppm; do
    magick "$f" "${f%.ppm}.png" && echo "  converted $(basename "${f%.ppm}.png")"
  done
'

log "PNGs at $OUT/desktop-*.png"
ls -la "$OUT"/desktop-*.png
