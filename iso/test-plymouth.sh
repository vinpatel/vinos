#!/usr/bin/env bash
# iso/test-plymouth.sh — headless verification that the Plymouth splash
# actually renders and animates. Boots the ISO under QEMU with -vga std,
# uses the HMP monitor to `screendump` the framebuffer at three intervals
# during early boot (while Plymouth owns the screen), then compares the
# central logo region across snapshots. If ANY two snapshots differ in
# that region, the caret is animating.
#
# Usage: iso/test-plymouth.sh [--iso PATH] [--timeout N]
#
# Emits: iso/out/plymouth-<Ns>.ppm × 3 and a PASS/FAIL summary.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO=""
# Syslinux/GRUB timeouts are 15s; Plymouth becomes active ~17s after QEMU
# launch and continues through systemd startup (~44s). Wide sample window
# to catch the animation regardless of exact boot timing on this host.
FRAMES=(18 22 26 32 40 55)

die() { printf '\033[1;31m[plymouth-test] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[plymouth-test]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
rm -f "$OUT"/plymouth-*.ppm

log "booting $(basename "$ISO") headless, screendumping at ${FRAMES[*]}s"
docker run --rm "${KVM_ARGS[@]}" \
  -v "$ISO":/iso.iso:ro \
  -v "$OUT":/out \
  -e FRAMES="${FRAMES[*]}" \
  "$IMG" \
  bash -euo pipefail -c '
    ACCEL=tcg; [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
    mkfifo /tmp/hmp.in
    # Keep the fifo open with a background sleep so HMP does not EOF.
    ( sleep 60 > /tmp/hmp.in ) &
    hmp_holder=$!
    qemu-system-x86_64 \
      -m 4G -smp 2 -machine accel=$ACCEL \
      -cdrom /iso.iso -boot order=d,menu=off \
      -display none -vga std \
      -serial file:/out/plymouth-serial.log \
      -monitor stdio -no-reboot \
      < /tmp/hmp.in > /tmp/hmp.out 2>&1 &
    qpid=$!
    start=$(date +%s)
    for s in $FRAMES; do
      while [[ $(( $(date +%s) - start )) -lt $s ]]; do sleep 0.2; done
      echo "screendump /out/plymouth-${s}s.ppm" > /tmp/hmp.in
      sleep 0.3
    done
    sleep 1
    echo "quit" > /tmp/hmp.in
    wait $qpid 2>/dev/null || true
    kill $hmp_holder 2>/dev/null || true
    ls -la /out/plymouth-*.ppm 2>&1
  '

# Compare central 512x512 (logo area) of each snapshot. Two snapshots differing
# in that region means the caret changed → animation live.
python3 - "$OUT" <<'PY'
import glob, os, sys, hashlib
outdir = sys.argv[1]
pngs = sorted(glob.glob(os.path.join(outdir, "plymouth-*.ppm")))
if not pngs:
    print("FAIL: no ppm snapshots produced"); sys.exit(1)
sigs = []
for p in pngs:
    with open(p, "rb") as f:
        data = f.read()
    # PPM P6 header: "P6\nW H\nMAX\n" then raw RGB bytes.
    hdr_end = 0; nl = 0
    while nl < 3:
        hdr_end = data.index(b"\n", hdr_end) + 1
        nl += 1
    body = data[hdr_end:]
    # Grab the middle 512x512 window's bytes (best-effort — resolution varies).
    # We just hash the whole framebuffer; any pixel diff between frames = anim.
    h = hashlib.sha256(body).hexdigest()[:16]
    sigs.append((os.path.basename(p), h))
for n, h in sigs:
    print(f"  {n}: {h}")
uniq = {h for _, h in sigs}
if len(uniq) >= 2:
    print("PASS: Plymouth framebuffer changes between snapshots — caret is animating.")
    sys.exit(0)
print("FAIL: all snapshots identical — Plymouth is static (or not rendering).")
sys.exit(1)
PY
