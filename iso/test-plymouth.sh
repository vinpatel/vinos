#!/usr/bin/env bash
# iso/test-plymouth.sh — headless verification that the Plymouth splash
# actually renders and animates during BOTH boot and shutdown.
#
# Boots the ISO under QEMU with -vga std and drives the HMP monitor to
# `screendump` the framebuffer on a fixed cadence, then sends
# `system_powerdown` and screendumps again through the shutdown sequence.
#
# WHY THIS LOOKS THE WAY IT DOES (2026-08-21 rewrite)
#
# The previous version sampled at fixed wall-clock offsets from QEMU
# launch — FRAMES=(18 22 26 32 40 55) — on the stated assumption that
# "syslinux/GRUB timeouts are 15s". They are not: the vesamenu countdown
# empirically still had 14 seconds left to run at t+18s, so the kernel did
# not start until ~t+32s. Every sample landed either on the boot menu or
# in the black gap while the kernel loaded. Plymouth was never in frame,
# and the boot phase "passed" because the menu's own countdown DIGITS
# changed between the 18s and 22s shots. A test that photographs the
# bootloader and reports on the splash is worse than no test.
#
# Three things follow from that, and all three are load-bearing:
#
#   1. We take the boot menu out of the timing path entirely by sending
#      `sendkey ret` once the menu is up. t0 is then the moment the
#      kernel starts, not the moment QEMU launched, so the sample window
#      no longer drifts with bootloader timeout or host load.
#   2. We sample on a dense cadence across a wide window instead of six
#      hand-picked offsets, and PRINT the whole timeline. When this fails
#      the next reader gets the frame-by-frame history, not a bare verdict.
#   3. Brightness is the wrong instrument. The old shutdown gate was
#      `mean(body[:200_000]) > 0.05`, which on a 640x480 framebuffer reads
#      only the top 104 of 480 rows — pure background in every frame, so
#      it measured 0.0000 no matter what was on screen and could never
#      pass. It was also above the mean of a legitimately dark splash.
#      Pixel GEOGRAPHY is no better: a screen full of systemd status text
#      puts plenty of lit pixels in the middle band, which is exactly how
#      an early draft of this rewrite scored a shutdown console dump as a
#      splash. What actually separates the two is the BACKGROUND COLOUR.
#      themes/vinos/vinos.script paints a flat
#      Window.SetBackgroundTopColor(0.102, 0.106, 0.149) = RGB(26,27,38),
#      so when our splash owns the screen the modal pixel IS that colour
#      across most of the frame, whereas a text console is pure black
#      (0,0,0) under the VGA palette. Asserting on the theme colour means
#      this test can only pass when the vinOS theme is genuinely on screen.
#
# Usage: iso/test-plymouth.sh [--iso PATH] [--boot-only] [--keep-frames]
#
# Emits: iso/out/plymouth-boot-<NNN>s.ppm + iso/out/plymouth-shutdown-<NN>s.ppm
#        iso/out/plymouth-timeline.txt   (the classified frame-by-frame log)
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO=""
BOOT_ONLY=0
KEEP_FRAMES=0

# Seconds after QEMU launch at which we press Enter to take the default
# boot entry. The menu renders within ~2s under TCG; 6s is comfortably
# inside the countdown (empirically >20s of runway) while still cutting
# the dead time out of the run.
MENU_ENTER_AT=6
# Boot-phase sampling, measured from t0 = the Enter keypress. Plymouth on
# this ISO owns the screen from roughly t0+8s; we run out to t0+100s so a
# slow TCG boot still gets caught, and the timeline shows where it ended.
BOOT_FROM=4
BOOT_TO=100
BOOT_EVERY=4
# Shutdown offsets from `system_powerdown`. plymouth-poweroff.service is
# ordered early in the shutdown transaction, but "early" on a loaded host
# is not 1s — the old (1 3) pair was too tight to see it at all.
SHUTDOWN_FROM=1
SHUTDOWN_TO=14
SHUTDOWN_EVERY=1

die() { printf '\033[1;31m[plymouth-test] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[plymouth-test]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --boot-only) BOOT_ONLY=1; shift ;;
    --keep-frames) KEEP_FRAMES=1; shift ;;
    -h|--help) sed -n '2,48p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
# Clear both the current and the pre-rewrite naming, so a stale frame from
# an older run can never be mistaken for evidence from this one.
rm -f "$OUT"/plymouth-*.ppm "$OUT"/plymouth-timeline.txt

BOOT_FRAMES="$(seq "$BOOT_FROM" "$BOOT_EVERY" "$BOOT_TO" | tr '\n' ' ')"
SHUTDOWN_FRAMES="$(seq "$SHUTDOWN_FROM" "$SHUTDOWN_EVERY" "$SHUTDOWN_TO" | tr '\n' ' ')"

log "ISO: $(basename "$ISO")"
if (( BOOT_ONLY )); then
  log "boot-only: Enter at ${MENU_ENTER_AT}s, then frames at t0+{${BOOT_FRAMES}}s"
else
  log "boot frames t0+{${BOOT_FRAMES}}s, shutdown frames +{${SHUTDOWN_FRAMES}}s"
fi

docker run --rm "${KVM_ARGS[@]}" \
  -v "$ISO":/iso.iso:ro \
  -v "$OUT":/out \
  -e BOOT_FRAMES="$BOOT_FRAMES" \
  -e SHUTDOWN_FRAMES="$SHUTDOWN_FRAMES" \
  -e MENU_ENTER_AT="$MENU_ENTER_AT" \
  -e BOOT_ONLY="$BOOT_ONLY" \
  "$IMG" \
  bash -euo pipefail -c '
    ACCEL=tcg; [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
    mkfifo /tmp/hmp.in
    # Hold the fifo open for the whole run: menu wait + boot window +
    # powerdown + shutdown window + teardown, with headroom.
    ( sleep 300 > /tmp/hmp.in ) &
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

    launch=$(date +%s)
    while [[ $(( $(date +%s) - launch )) -lt $MENU_ENTER_AT ]]; do sleep 0.2; done
    # Take the default entry. This is what makes t0 mean "kernel start"
    # instead of "QEMU start" — the whole reason the old offsets missed.
    echo "== taking default boot entry (sendkey ret) ==" >&2
    echo "sendkey ret" > /tmp/hmp.in
    t0=$(date +%s)

    for s in $BOOT_FRAMES; do
      while [[ $(( $(date +%s) - t0 )) -lt $s ]]; do sleep 0.2; done
      echo "screendump /out/plymouth-boot-$(printf %03d $s)s.ppm" > /tmp/hmp.in
      sleep 0.25
    done

    if [[ "$BOOT_ONLY" != "1" ]]; then
      echo "== initiating ACPI powerdown ==" >&2
      echo "system_powerdown" > /tmp/hmp.in
      pd=$(date +%s)
      for s in $SHUTDOWN_FRAMES; do
        while [[ $(( $(date +%s) - pd )) -lt $s ]]; do sleep 0.2; done
        echo "screendump /out/plymouth-shutdown-$(printf %02d $s)s.ppm" > /tmp/hmp.in
        sleep 0.25
      done
      sleep 5
    fi
    echo "quit" > /tmp/hmp.in
    wait $qpid 2>/dev/null || true
    kill $hmp_holder 2>/dev/null || true
    ls -la /out/plymouth-*.ppm 2>&1 | tail -5
  '

python3 - "$OUT" "$BOOT_ONLY" "$KEEP_FRAMES" <<'PY'
import glob, os, sys, hashlib

outdir, boot_only, keep = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1"

# The splash background, straight out of themes/vinos/vinos.script:
# Window.SetBackgroundTopColor(0.102, 0.106, 0.149). Flat, not a gradient,
# so a rendering splash fills most of the framebuffer with this one value.
THEME_BG = (26, 27, 38)
# Per-channel slack, for framebuffer rounding and any dithering QEMU adds.
BG_TOL = 6
# Fraction of the frame that must BE the theme background to call the
# splash present. The logo and caret occupy a small share of the screen,
# so a genuine splash frame sits far above this; a text console — pure
# black plus VGA palette — sits at zero.
BG_MIN = 0.40
# A lit pixel, used only for the diagnostic columns.
LIT = 60
BLACK_MAX = 0.0015

def parse(path):
    with open(path, "rb") as f:
        data = f.read()
    end = 0
    for _ in range(3):
        end = data.index(b"\n", end) + 1
    hdr = data[:end].split()
    return int(hdr[1]), int(hdr[2]), data[end:]

def analyse(path):
    w, h, body = parse(path)
    rows = len(body) // (w * 3) if w else 0
    if rows < 10:
        return None
    def lit_frac(r0, r1):
        seg = body[r0 * w * 3:r1 * w * 3]
        if not seg:
            return 0.0
        n = 0
        for i in range(0, len(seg) - 2, 3):
            if seg[i] > LIT or seg[i+1] > LIT or seg[i+2] > LIT:
                n += 1
        return n / (len(seg) / 3)
    full = lit_frac(0, rows)
    # How much of the frame IS the theme background, and how much is the
    # pure black a text console leaves behind. These two decide the
    # verdict; `lit` survives only to make a failure readable.
    bg = blk = 0
    r0, g0, b0 = THEME_BG
    for i in range(0, len(body) - 2, 3):
        r, g, b = body[i], body[i+1], body[i+2]
        if abs(r-r0) <= BG_TOL and abs(g-g0) <= BG_TOL and abs(b-b0) <= BG_TOL:
            bg += 1
        elif r == 0 and g == 0 and b == 0:
            blk += 1
    npx = len(body) // 3
    bg_frac, blk_frac = bg / npx, blk / npx
    if bg_frac >= BG_MIN:
        kind = "splash"          # the vinOS theme owns the screen
    elif full < BLACK_MAX:
        kind = "black"           # nothing on screen yet
    else:
        kind = "console"         # text on a pure-black VGA console
    return dict(name=os.path.basename(path), w=w, h=h, full=full,
                bg=bg_frac, blk=blk_frac, kind=kind,
                sig=hashlib.sha256(body).hexdigest()[:12])

def report(frames, label):
    print(f"\n  {label}:")
    print(f"    {'frame':28s} {'lit':>7s} {'themebg':>8s} {'black':>7s}  {'class':8s} sig")
    for f in frames:
        print(f"    {f['name']:28s} {f['full']:7.4f} {f['bg']:8.4f} "
              f"{f['blk']:7.4f}  {f['kind']:8s} {f['sig']}")

boot = [analyse(p) for p in sorted(glob.glob(os.path.join(outdir, "plymouth-boot-*.ppm")))]
boot = [f for f in boot if f]
shut = [analyse(p) for p in sorted(glob.glob(os.path.join(outdir, "plymouth-shutdown-*.ppm")))]
shut = [f for f in shut if f]

log_lines = []
def emit(s):
    print(s)
    log_lines.append(s)

if not boot:
    emit("FAIL: no boot-phase snapshots produced")
    sys.exit(1)

report(boot, "boot phase")
splash = [f for f in boot if f["kind"] == "splash"]
emit(f"\n  boot: {len(boot)} frames — "
     f"{len(splash)} splash, "
     f"{sum(1 for f in boot if f['kind']=='console')} console, "
     f"{sum(1 for f in boot if f['kind']=='black')} black")

rc = 0

# Two assertions, and they are separate on purpose. The old single check
# ("any two frames differ") conflated them and was satisfied by the boot
# menu's countdown, by a splash-to-black transition, or by console text
# scrolling — none of which is Plymouth animating.
if not splash:
    emit(f"FAIL boot phase: no frame is the vinOS splash — nothing matched the theme "
         f"background RGB{THEME_BG}. What is on screen is a text console, so Plymouth "
         f"is running in details mode rather than rendering the theme.")
    rc = 1
else:
    window = f"{splash[0]['name']} .. {splash[-1]['name']}"
    if len({f["sig"] for f in splash}) < 2:
        emit(f"FAIL boot phase: splash present ({window}) but every splash frame is "
             "byte-identical — Plymouth is rendering a static image, not animating.")
        rc = 1
    else:
        emit(f"PASS boot phase: Plymouth splash present and animating ({window}, "
             f"{len({f['sig'] for f in splash})} distinct frames).")

if not boot_only:
    if not shut:
        emit("FAIL shutdown phase: no shutdown snapshots produced")
        rc = 1
    else:
        report(shut, "shutdown phase")
        sp = [f for f in shut if f["kind"] == "splash"]
        if not sp:
            emit(f"FAIL shutdown phase: no shutdown frame is the vinOS splash "
                 f"(theme background RGB{THEME_BG} never filled the screen) — "
                 f"plymouth-poweroff.service may start fine yet still not render.")
            rc = 1
        else:
            emit(f"PASS shutdown phase: Plymouth splash visible during powerdown "
                 f"({sp[0]['name']} .. {sp[-1]['name']}).")

with open(os.path.join(outdir, "plymouth-timeline.txt"), "w") as f:
    for fr in boot + shut:
        f.write(f"{fr['name']}\t{fr['kind']}\tlit={fr['full']:.4f}\t"
                f"themebg={fr['bg']:.4f}\tblack={fr['blk']:.4f}\t{fr['sig']}\n")

if not keep:
    # Keep any frame that carried content — those are the evidence. Drop
    # the black ones so iso/out does not accumulate 40MB of identical
    # black framebuffers every run.
    for fr in boot + shut:
        if fr["kind"] == "black":
            try: os.remove(os.path.join(outdir, fr["name"]))
            except OSError: pass

sys.exit(rc)
PY
