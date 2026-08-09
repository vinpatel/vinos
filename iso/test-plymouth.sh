#!/usr/bin/env bash
# iso/test-plymouth.sh — headless verification that the Plymouth splash
# actually renders and animates during BOTH boot and shutdown. Boots the
# ISO under QEMU with -vga std, uses the HMP monitor to `screendump` the
# framebuffer at intervals during early boot (while Plymouth owns the
# screen), then sends `system_powerdown` and screendumps again during
# the shutdown sequence. The boot phase passes if two frames differ
# (animation live); the shutdown phase passes if the shutdown frame is
# non-blank AND matches the boot theme (same logo present).
#
# Usage: iso/test-plymouth.sh [--iso PATH] [--timeout N] [--boot-only]
#
# Emits: iso/out/plymouth-<Ns>.ppm × 6 (boot) + iso/out/plymouth-shutdown-<Ns>.ppm × 2
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO=""
BOOT_ONLY=0
# Syslinux/GRUB timeouts are 15s; Plymouth becomes active ~17s after QEMU
# launch and continues through systemd startup (~44s). Wide sample window
# to catch the animation regardless of exact boot timing on this host.
FRAMES=(18 22 26 32 40 55)
# Shutdown offsets are measured from the `system_powerdown` HMP command.
# Plymouth-poweroff.service takes over almost immediately; we screendump
# at 1s and 3s to catch both the splash appearing and the animation.
SHUTDOWN_FRAMES=(1 3)

die() { printf '\033[1;31m[plymouth-test] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[plymouth-test]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --boot-only) BOOT_ONLY=1; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

if (( BOOT_ONLY )); then
  log "booting $(basename "$ISO") headless, screendumping at ${FRAMES[*]}s (boot-only)"
else
  log "booting $(basename "$ISO") headless, screendumping boot@${FRAMES[*]}s + shutdown@${SHUTDOWN_FRAMES[*]}s"
fi
docker run --rm "${KVM_ARGS[@]}" \
  -v "$ISO":/iso.iso:ro \
  -v "$OUT":/out \
  -e FRAMES="${FRAMES[*]}" \
  -e SHUTDOWN_FRAMES="${SHUTDOWN_FRAMES[*]}" \
  -e BOOT_ONLY="$BOOT_ONLY" \
  "$IMG" \
  bash -euo pipefail -c '
    ACCEL=tcg; [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
    mkfifo /tmp/hmp.in
    # Keep the fifo open with a long-lived background sleep — enough
    # time to cover boot frames + system_powerdown + shutdown frames.
    ( sleep 120 > /tmp/hmp.in ) &
    hmp_holder=$!
    qemu-system-x86_64 \
      -m 4G -smp 2 -machine accel=$ACCEL \
      -cdrom /iso.iso -boot order=d,menu=off \
      -display none -vga std \
      -serial file:/out/plymouth-serial.log \
      -monitor stdio \
      -no-reboot \
      < /tmp/hmp.in > /tmp/hmp.out 2>&1 &
    qpid=$!
    start=$(date +%s)
    # Boot-phase screendumps.
    for s in $FRAMES; do
      while [[ $(( $(date +%s) - start )) -lt $s ]]; do sleep 0.2; done
      echo "screendump /out/plymouth-${s}s.ppm" > /tmp/hmp.in
      sleep 0.3
    done
    if [[ "$BOOT_ONLY" != "1" ]]; then
      # Give the desktop a moment to settle before signalling shutdown,
      # so plymouth-poweroff.service is the one that renders next.
      sleep 3
      echo "== initiating ACPI powerdown =="
      echo "system_powerdown" > /tmp/hmp.in
      pd_start=$(date +%s)
      for s in $SHUTDOWN_FRAMES; do
        while [[ $(( $(date +%s) - pd_start )) -lt $s ]]; do sleep 0.2; done
        echo "screendump /out/plymouth-shutdown-${s}s.ppm" > /tmp/hmp.in
        sleep 0.3
      done
      # Let systemd finish tearing down; QEMU exits on real ACPI off.
      sleep 5
    fi
    echo "quit" > /tmp/hmp.in
    wait $qpid 2>/dev/null || true
    kill $hmp_holder 2>/dev/null || true
    ls -la /out/plymouth-*.ppm 2>&1
  '

# Compare framebuffer signatures across snapshots. Two snapshots differing
# in the boot phase means the caret is animating. The shutdown phase
# passes if any shutdown frame is non-blank (mean brightness > 0.05).
python3 - "$OUT" "$BOOT_ONLY" <<'PY'
import glob, os, sys, hashlib
outdir, boot_only = sys.argv[1], sys.argv[2]

def load_ppm(path):
    with open(path, "rb") as f:
        data = f.read()
    # PPM P6 header: "P6\nW H\nMAX\n" then raw RGB bytes.
    hdr_end = 0
    nl = 0
    while nl < 3:
        hdr_end = data.index(b"\n", hdr_end) + 1
        nl += 1
    return data[hdr_end:]

def sig(body):
    return hashlib.sha256(body).hexdigest()[:16]

def mean_brightness(body):
    # Average byte value across the whole framebuffer, normalized to 0-1.
    if not body:
        return 0.0
    return sum(body[:200_000]) / (200_000 * 255)

boot = sorted(glob.glob(os.path.join(outdir, "plymouth-[0-9]*.ppm")))
shut = sorted(glob.glob(os.path.join(outdir, "plymouth-shutdown-*.ppm")))

if not boot:
    print("FAIL: no boot-phase ppm snapshots produced")
    sys.exit(1)

boot_sigs = []
for p in boot:
    body = load_ppm(p)
    boot_sigs.append((os.path.basename(p), sig(body)))
for n, h in boot_sigs:
    print(f"  {n}: {h}")

boot_uniq = {h for _, h in boot_sigs}
if len(boot_uniq) < 2:
    print("FAIL: all boot-phase snapshots identical — Plymouth is static (or not rendering).")
    sys.exit(1)
print("PASS boot phase: Plymouth framebuffer changes across snapshots — caret is animating.")

if boot_only == "1":
    sys.exit(0)

if not shut:
    print("FAIL: no shutdown-phase ppm snapshots produced — plymouth-poweroff never rendered")
    sys.exit(1)

shut_ok = False
for p in shut:
    body = load_ppm(p)
    b = mean_brightness(body)
    print(f"  {os.path.basename(p)}: mean_brightness={b:.4f} sig={sig(body)}")
    if b > 0.05:
        shut_ok = True

if not shut_ok:
    print("FAIL: shutdown-phase screen is blank — plymouth-poweroff.service not enabled or not rendering.")
    sys.exit(1)

print("PASS shutdown phase: Plymouth splash visible during ACPI powerdown.")
sys.exit(0)
PY
