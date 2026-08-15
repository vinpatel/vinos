#!/usr/bin/env bash
# iso/test-super-return.sh — automated regression test for the SUPER+Return
# terminal binding. Catches the v1.2.1-class silent no-op bugs that
# config-lint cannot see (uwsm-app session bootstrap, source-order races,
# runtime binary resolution).
#
# Boots the ISO headless under QEMU, waits for Hyprland to settle,
# HMP-injects SUPER+RETURN, screendumps before/after, and asserts pixels
# changed by more than THRESHOLD. Any terminal window painting ≥ THRESHOLD
# pixels counts as a pass — we don't OCR the terminal, we just prove the
# bind fired something visible.
#
# Emits iso/out/super-return-before.ppm, super-return-after.ppm, plus
# PNGs and a per-run summary.
#
# Usage: iso/test-super-return.sh [--iso PATH] [--settle SEC] [--threshold PCT]
#
# Exit 0 on PASS. Exit 1 on FAIL (bind did not open a visible surface).
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO=""
SETTLE=150       # seconds to wait for Hyprland desktop to be stable
THRESHOLD=2      # percent of pixels that must differ to count as PASS

die() { printf '\033[1;31m[super-return] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[super-return]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)       ISO="$2"; shift 2 ;;
    --settle)    SETTLE="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    -h|--help)   sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$ISO" ]] && ISO="$(find "$ISO_DIR/out" -maxdepth 1 -name 'vinos-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO — run iso/build.sh first (or pass --iso PATH)"

IMG="vinos-iso-tester:latest"
docker image inspect "$IMG" >/dev/null 2>&1 || die "tester image missing — run iso/test.sh once first to build it"

KVM_ARGS=()
[[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]] && KVM_ARGS+=(--device /dev/kvm)

OUT="$ISO_DIR/out"
mkdir -p "$OUT"
rm -f "$OUT"/super-return-*.ppm "$OUT"/super-return-*.png "$OUT"/super-return-serial.log

log "booting $(basename "$ISO") headless"
log "settle=${SETTLE}s  threshold=${THRESHOLD}%  iso=$(du -h "$ISO" | cut -f1)"

docker run --rm "${KVM_ARGS[@]}" \
  -v "$ISO":/iso.iso:ro \
  -v "$OUT":/out \
  -e SETTLE="$SETTLE" \
  "$IMG" \
  bash -euo pipefail -c '
    ACCEL=tcg; [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
    mkfifo /tmp/hmp.in
    ( sleep "$((SETTLE + 60))" > /tmp/hmp.in ) &
    hmp_holder=$!
    qemu-system-x86_64 \
      -m 4G -smp 2 -machine accel=$ACCEL \
      -cdrom /iso.iso -boot order=d,menu=off \
      -display none -vga std \
      -serial file:/out/super-return-serial.log \
      -monitor stdio -no-reboot \
      -usb -device usb-kbd -device usb-tablet \
      < /tmp/hmp.in > /tmp/hmp.out 2>&1 &
    qpid=$!
    start=$(date +%s)
    while [[ $(( $(date +%s) - start )) -lt $SETTLE ]]; do sleep 0.5; done

    # T=SETTLE: snapshot the idle desktop
    echo "screendump /out/super-return-before.ppm" > /tmp/hmp.in
    sleep 1

    # T=SETTLE+1: press SUPER+RETURN. QEMU HMP name for Return key is "ret".
    echo "sendkey meta_l-ret" > /tmp/hmp.in
    sleep 3

    # T=SETTLE+4: snapshot after — foot should be painted by now
    echo "screendump /out/super-return-after.ppm" > /tmp/hmp.in
    sleep 1

    echo "quit" > /tmp/hmp.in
    wait $qpid 2>/dev/null || true
    kill $hmp_holder 2>/dev/null || true
    ls -la /out/super-return-*.ppm 2>&1
  '

[[ -f "$OUT/super-return-before.ppm" ]] || die "before frame missing — QEMU boot likely failed (see $OUT/super-return-serial.log)"
[[ -f "$OUT/super-return-after.ppm"  ]] || die "after frame missing — QEMU boot likely failed (see $OUT/super-return-serial.log)"

# Convert + diff using imagemagick in an ephemeral archlinux container.
log "diffing before vs after"
DIFF_OUT="$(docker run --rm -v "$OUT":/out archlinux:latest bash -c '
  pacman -Sy --noconfirm imagemagick >/dev/null 2>&1
  magick /out/super-return-before.ppm /out/super-return-before.png
  magick /out/super-return-after.ppm  /out/super-return-after.png
  # AE metric = count of pixels that differ. Normalize to percent.
  # -fuzz 5% absorbs anti-aliasing + cursor blink noise.
  raw=$(magick compare -metric AE -fuzz 5% \
    /out/super-return-before.ppm /out/super-return-after.ppm \
    /out/super-return-diff.png 2>&1 || true)
  # AE prints just the integer count on stderr; strip anything else.
  count=$(echo "$raw" | grep -oE "^[0-9]+" | head -1)
  total=$(magick identify -format "%[fx:w*h]" /out/super-return-before.ppm)
  pct=$(awk -v c="${count:-0}" -v t="$total" "BEGIN { printf \"%.2f\", (c/t)*100 }")
  echo "diff_pixels=$count"
  echo "total_pixels=$total"
  echo "diff_pct=$pct"
')"
echo "$DIFF_OUT"

PCT=$(printf '%s' "$DIFF_OUT" | awk -F= '/^diff_pct=/ {print $2}')

log "PNG artifacts:"
ls -la "$OUT"/super-return-*.png 2>/dev/null || true

# Compare using awk (bash [[ ]] can'"'"'t do float comparison).
if awk -v p="$PCT" -v t="$THRESHOLD" "BEGIN { exit !(p >= t) }"; then
  log "\033[1;32mPASS\033[0m — ${PCT}% of pixels changed after SUPER+Return (threshold ${THRESHOLD}%)"
  log "→ terminal (or some visible surface) opened. Bind is live."
  exit 0
else
  printf '\033[1;31m[super-return] FAIL\033[0m — only %s%% pixels changed (need ≥ %s%%)\n' "$PCT" "$THRESHOLD" >&2
  printf '\033[1;31m[super-return]\033[0m review frames:\n' >&2
  printf '  %s/super-return-before.png\n' "$OUT" >&2
  printf '  %s/super-return-after.png\n'  "$OUT" >&2
  printf '  %s/super-return-diff.png\n'   "$OUT" >&2
  printf '\033[1;31m[super-return]\033[0m serial: %s/super-return-serial.log\n' "$OUT" >&2
  exit 1
fi
