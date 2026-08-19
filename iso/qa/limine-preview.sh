#!/usr/bin/env bash
# iso/qa/limine-preview.sh — render the vinOS limine boot menu in QEMU and
# screenshot it. No ISO build, no USB, no install.
#
# Builds a throwaway ESP containing just limine + config/limine/limine.conf
# + the boot wallpaper, boots it under OVMF, and screendumps the menu to
# PNG. Turnaround is seconds, so the theme can be iterated by editing
# config/limine/limine.conf and re-running this.
#
# The entries here are cosmetic placeholders — this harness proves how the
# menu LOOKS, not that anything boots. Install correctness is proven by
# iso/qa/install-smoke.sh and on real hardware.
#
# Usage:
#   iso/qa/limine-preview.sh [--out DIR] [--delay SECS] [--keep]
#     --out DIR     where to write esp.img + the PNG (default: iso/out/limine-preview)
#     --delay SECS  how long to let the menu settle before the screendump
#                   (default 6 — firmware init plus wallpaper decode)
#     --keep        leave QEMU running for interactive poking over VNC
set -euo pipefail

QA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$QA_DIR/../.." && pwd)"

OUT_DIR="$REPO/iso/out/limine-preview"
DELAY=6
KEEP=0
VNC_PORT="${LIMINE_PREVIEW_VNC:-6}"   # display :6 → 5906, clear of the smoke harness

die() { printf '\033[1;31m[limine-preview] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[limine-preview]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)   [[ $# -ge 2 ]] || die "--out needs a dir";    OUT_DIR="$2"; shift 2 ;;
    --delay) [[ $# -ge 2 ]] || die "--delay needs secs";   DELAY="$2";   shift 2 ;;
    --keep)  KEEP=1; shift ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

LIMINE_EFI=/usr/share/limine/BOOTX64.EFI
CONF="$REPO/config/limine/limine.conf"
WALL="$REPO/assets/limine/boot-nebula.jpg"
OVMF_CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
OVMF_VARS_SRC=/usr/share/edk2/x64/OVMF_VARS.4m.fd

[[ -f "$LIMINE_EFI" ]] || die "$LIMINE_EFI missing — install the 'limine' package"
[[ -f "$CONF" ]]       || die "$CONF missing"
[[ -f "$WALL" ]]       || die "$WALL missing — regenerate with:
  magick assets/wallpapers/nebula/wallpaper.png -resize 1920x1080 -quality 82 $WALL"
[[ -f "$OVMF_CODE" ]]  || die "$OVMF_CODE missing — install edk2-ovmf"

mkdir -p "$OUT_DIR"
VARS="$OUT_DIR/OVMF_VARS.fd"

# ── build the ESP tree ─────────────────────────────────────────────
# QEMU's VVFAT (-drive file=fat:...) presents a plain directory to the
# guest as a FAT filesystem. That means no loop mount, no mkfs, and no
# sudo — which matters because this harness has to run unattended in
# sessions that have no tty to type a sudo password into.
ESP_DIR="$OUT_DIR/esp"
VARS="$OUT_DIR/OVMF_VARS.fd"

log "staging ESP tree at $ESP_DIR"
rm -rf "$ESP_DIR"
mkdir -p "$ESP_DIR/EFI/BOOT"
cp "$LIMINE_EFI" "$ESP_DIR/EFI/BOOT/BOOTX64.EFI"
cp "$WALL"       "$ESP_DIR/vinos-wallpaper.jpg"

# Theme header verbatim from the repo + placeholder entries so the menu
# has something to render. Entries deliberately point nowhere: selecting
# one will fail, which is fine — we are looking at the menu.
{
  cat "$CONF"
  cat <<'ENTRIES'

### Entries below are PREVIEW PLACEHOLDERS (iso/qa/limine-preview.sh).
### The installer generates the real ones. Do not copy these anywhere.

/vinOS
    comment: vinOS on this disk
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    kernel_cmdline: root=UUID=00000000-0000-0000-0000-000000000000 rw quiet splash

/vinOS (verbose console)
    comment: same kernel, no splash — for diagnosing a failed boot
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    kernel_cmdline: root=UUID=00000000-0000-0000-0000-000000000000 rw

/vinOS — Apple T2 Mac
    comment: linux-t2 kernel for Apple T2 hardware
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-t2
    kernel_cmdline: root=UUID=00000000-0000-0000-0000-000000000000 rw quiet splash pcie_ports=compat
ENTRIES
} > "$ESP_DIR/limine.conf"

log "ESP tree staged ($(du -sh "$ESP_DIR" | cut -f1))"

# ── boot it ────────────────────────────────────────────────────────
cp -f "$OVMF_VARS_SRC" "$VARS" 2>/dev/null || truncate -s 4M "$VARS"
chmod u+w "$VARS"

HMP="$OUT_DIR/hmp.sock"
rm -f "$HMP"

log "booting QEMU (VNC :$VNC_PORT)"
qemu-system-x86_64 \
  -m 512 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$VARS" \
  -drive file="fat:rw:$ESP_DIR",format=raw,if=ide \
  -vga std -display "vnc=:$VNC_PORT" \
  -monitor "unix:$HMP,server,nowait" \
  -no-reboot &
QEMU_PID=$!
# shellcheck disable=SC2064
trap "kill $QEMU_PID 2>/dev/null || true" EXIT

hmp() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$HMP" >/dev/null 2>&1 || true; }

log "letting the menu settle (${DELAY}s)"
sleep "$DELAY"

PPM="$OUT_DIR/limine-menu.ppm"
PNG="$OUT_DIR/limine-menu.png"
rm -f "$PPM" "$PNG"
hmp "screendump $PPM"

for _ in {1..20}; do [[ -s "$PPM" ]] && break; sleep 0.5; done
[[ -s "$PPM" ]] || die "screendump produced nothing — is the guest still in firmware init? try --delay 12"

if command -v magick >/dev/null; then
  magick "$PPM" "$PNG" && rm -f "$PPM"
  log "screenshot: $PNG"
else
  log "screenshot: $PPM (install imagemagick for PNG)"
fi

if (( KEEP )); then
  log "QEMU left running on VNC :$VNC_PORT — kill $QEMU_PID when done"
  trap - EXIT
else
  kill "$QEMU_PID" 2>/dev/null || true
  trap - EXIT
fi
