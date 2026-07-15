#!/usr/bin/env bash
# iso/capture-screenshots.sh — headless UI-state screenshot capture.
# Boots the ISO, waits for Hyprland to settle, then uses QEMU HMP
# sendkey + screendump to grab specific UI states for the website.
#
# Emits site/static/img/screenshots/*.png. Each frame is a PPM converted
# to PNG via imagemagick.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$ISO_DIR/.." && pwd)"
ISO=""
OUT="$ROOT_DIR/site/static/img/screenshots"

die() { printf '\033[1;31m[capture] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[capture]\033[0m %s\n' "$*"; }

[[ -z "$ISO" ]] && ISO="$(find "$ISO_DIR/out" -maxdepth 1 -name 'vinos-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO — run iso/build.sh first"

IMG="vinos-iso-tester:latest"
docker image inspect "$IMG" >/dev/null 2>&1 || die "tester image missing — run iso/test.sh once first"

mkdir -p "$OUT"

KVM_ARGS=()
[[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]] && KVM_ARGS+=(--device /dev/kvm)

log "booting $(basename "$ISO") headless, will send keystrokes and screendump"
docker run --rm "${KVM_ARGS[@]}" \
  -v "$ISO":/iso.iso:ro \
  -v "$OUT":/out \
  "$IMG" \
  bash -euo pipefail -c '
    ACCEL=tcg; [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
    mkfifo /tmp/hmp.in
    ( sleep 400 > /tmp/hmp.in ) & hmp_holder=$!
    qemu-system-x86_64 \
      -m 4G -smp 2 -machine accel=$ACCEL \
      -cdrom /iso.iso -boot order=d,menu=off \
      -display none -vga std \
      -serial file:/out/capture-serial.log \
      -monitor stdio -no-reboot \
      < /tmp/hmp.in > /tmp/hmp.out 2>&1 &
    qpid=$!

    hmp() { echo "$*" > /tmp/hmp.in; sleep 0.3; }
    shot() { hmp "screendump /out/$1.ppm"; sleep 1.2; }
    sleep_until() {
      local target=$1 start=$2
      while [[ $(( $(date +%s) - start )) -lt $target ]]; do sleep 0.5; done
    }

    start=$(date +%s)
    # Wait for autologin + Hyprland to settle
    sleep_until 180 $start
    shot 01-desktop

    # Open walker (Super+Space)
    hmp "sendkey meta_l-spc"
    sleep 2.5
    shot 02-walker

    # Close walker
    hmp "sendkey esc"
    sleep 1

    # Open vinos-menu (Super+Ctrl+O)
    hmp "sendkey meta_l-ctrl-o"
    sleep 2.5
    shot 03-menu

    # Close menu
    hmp "sendkey esc"
    sleep 1

    # Wi-Fi picker (Super+Ctrl+W)
    hmp "sendkey meta_l-ctrl-w"
    sleep 3
    shot 04-wifi

    # Close
    hmp "sendkey esc"
    sleep 1
    hmp "sendkey esc"
    sleep 1

    # Show keybindings (Super+K)
    hmp "sendkey meta_l-k"
    sleep 3
    shot 05-keys

    # Close
    hmp "sendkey esc"
    sleep 1

    # Theme menu (Super+Shift+Ctrl+Space)
    hmp "sendkey meta_l-shift-ctrl-spc"
    sleep 3
    shot 06-theme

    # Close
    hmp "sendkey esc"
    sleep 1

    # Final desktop shot (post-interaction, waybar visible)
    shot 07-desktop-clean

    sleep 1
    hmp "quit"
    wait $qpid 2>/dev/null || true
    kill $hmp_holder 2>/dev/null || true
    ls -la /out/*.ppm 2>&1
  '

log "converting PPMs to PNGs"
docker run --rm -v "$OUT":/out archlinux:latest bash -c '
  pacman -Sy --noconfirm imagemagick >/dev/null 2>&1
  for f in /out/*.ppm; do
    [[ -f "$f" ]] || continue
    magick "$f" "${f%.ppm}.png" && echo "  converted $(basename "${f%.ppm}.png")"
  done
  rm -f /out/*.ppm
'

log "screenshots at $OUT/*.png"
ls -la "$OUT"/*.png 2>/dev/null || die "no screenshots produced"
