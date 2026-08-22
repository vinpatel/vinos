#!/usr/bin/env bash
# iso/mklimine-iso.sh — re-master a mkarchiso ISO onto the vinOS limine menu.
#
# archiso has no limine bootmode: profiledef.sh can only ask for
# bios.syslinux and uefi.systemd-boot, so a freshly built ISO shows two
# different stock menus depending on how the machine boots. The installed
# system already boots the authored vinOS menu (iso/installer/bootloader),
# and this closes the gap on the live medium so the boot experience is the
# same one everywhere.
#
# What it does: unpacks the ISO, drops limine's BIOS + UEFI El Torito
# payloads in, writes /boot/limine/limine.conf from the same theme header
# the installer uses plus config/limine/entries-live.conf, then rebuilds a
# hybrid ISO with limine as the only bootloader on both firmware paths.
#
# Usage:
#   iso/mklimine-iso.sh [--iso IN] [--out OUT] [--work DIR] [--keep-work]
#     --iso IN     ISO to re-master (default: iso/out/vinos-$VERSION-x86_64.iso)
#     --out OUT    where to write it   (default: in place, via a temp file)
#     --work DIR   scratch dir         (default: mktemp -d next to the output)
#     --keep-work  leave the unpacked tree behind for inspection
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ISO_DIR/.." && pwd)"

die() { printf '\033[1;31m[mklimine] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[mklimine]\033[0m %s\n' "$*"; }

IN_ISO=""
OUT_ISO=""
WORK=""
KEEP_WORK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)  [[ $# -ge 2 ]] || die "--iso needs a path";  IN_ISO="$2";  shift 2 ;;
    --out)  [[ $# -ge 2 ]] || die "--out needs a path";  OUT_ISO="$2"; shift 2 ;;
    --work) [[ $# -ge 2 ]] || die "--work needs a path"; WORK="$2";    shift 2 ;;
    --keep-work) KEEP_WORK=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

if [[ -z "$IN_ISO" ]]; then
  [[ -f "$REPO/VERSION" ]] || die "$REPO/VERSION missing and no --iso given"
  IN_ISO="$ISO_DIR/out/vinos-$(<"$REPO/VERSION")-x86_64.iso"
fi
[[ -f "$IN_ISO" ]] || die "input ISO not found: $IN_ISO"
IN_ISO="$(realpath "$IN_ISO")"
: "${OUT_ISO:=$IN_ISO}"

command -v xorriso >/dev/null || die "xorriso not found (pkg: libisoburn)"
command -v limine  >/dev/null || die "limine not found (pkg: limine)"

LIMINE_DATA="$(limine --print-datadir)"
for f in limine-bios-cd.bin limine-uefi-cd.bin limine-bios.sys BOOTX64.EFI BOOTIA32.EFI; do
  [[ -f "$LIMINE_DATA/$f" ]] || die "$LIMINE_DATA/$f missing — reinstall the limine package"
done

THEME="$REPO/config/limine/limine.conf"
ENTRIES="$REPO/config/limine/entries-live.conf"
WALLPAPER="$REPO/assets/limine/boot-nebula.jpg"
[[ -f "$THEME"     ]] || die "$THEME missing"
[[ -f "$ENTRIES"   ]] || die "$ENTRIES missing"
[[ -f "$WALLPAPER" ]] || die "$WALLPAPER missing — regenerate with:
  magick assets/wallpapers/nebula/wallpaper.png -resize 1920x1080 -quality 82 $WALLPAPER"

# ── read back what mkarchiso decided ───────────────────────────────
# The volume id and the boot UUID stamp are generated at build time
# (iso_label embeds the year-month, the .uuid file the exact second), so
# they have to come out of the image rather than out of profiledef.sh.
VOLID="$(xorriso -indev "$IN_ISO" -pvd_info 2>&1 | sed -n "s/^Volume id *: *'\(.*\)'$/\1/p")"
[[ -n "$VOLID" ]] || die "could not read the volume id out of $IN_ISO"

ARCHISO_UUID="$(xorriso -indev "$IN_ISO" -find /boot -maxdepth 1 -name '*.uuid' 2>/dev/null \
  | sed -n "s|^'/boot/\(.*\)\.uuid'$|\1|p" | head -1)"
[[ -n "$ARCHISO_UUID" ]] || die "no /boot/<uuid>.uuid stamp in $IN_ISO — is this a mkarchiso image?"

INSTALL_DIR=arch
ARCH=x86_64
log "volid=$VOLID uuid=$ARCHISO_UUID"

# ── unpack ─────────────────────────────────────────────────────────
CLEAN_WORK=0
if [[ -z "$WORK" ]]; then
  WORK="$(mktemp -d "$(dirname "$OUT_ISO")/.mklimine.XXXXXX")"
  CLEAN_WORK=1
fi
ROOT="$WORK/iso"
cleanup() { (( KEEP_WORK )) || { (( CLEAN_WORK )) && rm -rf "$WORK"; }; }
trap cleanup EXIT

log "unpacking $(basename "$IN_ISO") → $ROOT (this reads the whole ~$(du -h --apparent-size "$IN_ISO" | cut -f1) image)"
rm -rf "$ROOT"; mkdir -p "$ROOT"
# auto_chmod_on: the extracted tree inherits the ISO's read-only modes,
# which would otherwise stop us writing into /EFI/BOOT and /boot.
xorriso -osirrox on:auto_chmod_on -indev "$IN_ISO" -extract / "$ROOT" >/dev/null 2>&1 \
  || die "extraction failed"
chmod -R u+w "$ROOT"

# ── stage limine ───────────────────────────────────────────────────
log "staging limine $(limine --version 2>/dev/null | head -1)"
mkdir -p "$ROOT/boot/limine" "$ROOT/EFI/BOOT"
install -m 0644 "$LIMINE_DATA/limine-bios-cd.bin"  "$ROOT/boot/limine/limine-bios-cd.bin"
install -m 0644 "$LIMINE_DATA/limine-uefi-cd.bin"  "$ROOT/boot/limine/limine-uefi-cd.bin"
install -m 0644 "$LIMINE_DATA/limine-bios.sys"     "$ROOT/boot/limine/limine-bios.sys"

# Replace, don't add: archiso already shipped systemd-boot under these
# exact (case-sensitive) names, and leaving both behind would mean the
# firmware picks the bootloader, not us.
rm -f "$ROOT/EFI/BOOT/BOOTx64.EFI" "$ROOT/EFI/BOOT/BOOTX64.EFI" \
      "$ROOT/EFI/BOOT/BOOTIA32.EFI" "$ROOT/EFI/BOOT/bootia32.efi"
install -m 0644 "$LIMINE_DATA/BOOTX64.EFI"  "$ROOT/EFI/BOOT/BOOTX64.EFI"
install -m 0644 "$LIMINE_DATA/BOOTIA32.EFI" "$ROOT/EFI/BOOT/BOOTIA32.EFI"

# systemd-boot's menu definition. Harmless once its loader is gone, but
# leaving it invites the next reader to edit the file nothing reads.
rm -rf "$ROOT/loader"

# The wallpaper sits at the volume root so the shared theme header's
# `wallpaper: boot():/vinos-wallpaper.jpg` resolves on the live medium and
# on the installed ESP without either copy needing a private edit.
install -m 0644 "$WALLPAPER" "$ROOT/vinos-wallpaper.jpg"

{
  cat "$THEME"
  printf '\n'
  sed -e "s|%INSTALL_DIR%|$INSTALL_DIR|g" \
      -e "s|%ARCH%|$ARCH|g" \
      -e "s|%ARCHISO_UUID%|$ARCHISO_UUID|g" "$ENTRIES"
} > "$ROOT/boot/limine/limine.conf"

if grep -q '%' "$ROOT/boot/limine/limine.conf"; then
  die "unsubstituted placeholder left in limine.conf:
$(grep -n '%' "$ROOT/boot/limine/limine.conf" | head -3)"
fi

_entries="$(grep -c '^/' "$ROOT/boot/limine/limine.conf")"
log "limine.conf written with $_entries entries"

# Every kernel and initramfs the menu names must actually be on the image.
# A typo here is a boot failure on hardware we may not have in the room.
while read -r _p; do
  _rel="${_p#boot():/}"
  [[ -f "$ROOT/$_rel" ]] || die "limine.conf points at /$_rel, which is not on the ISO"
done < <(sed -n 's/^ *\(kernel_path\|module_path\): *//p' "$ROOT/boot/limine/limine.conf")
log "all kernel/initramfs paths resolve on the image"

# ── repack ─────────────────────────────────────────────────────────
# Boot layout is the hybrid recipe from /usr/share/doc/limine/USAGE.md:
# El Torito BIOS entry -> limine-bios-cd.bin, El Torito EFI entry ->
# limine-uefi-cd.bin, and -efi-boot-part --efi-boot-image republishes that
# EFI image as the ESP so a dd'd USB stick boots the same way a CD does.
TMP_ISO="$WORK/out.iso"
log "repacking → $(basename "$OUT_ISO")"
xorriso -as mkisofs \
  -volid "$VOLID" \
  -appid "vinOS Live" \
  -publisher "Vin Patel <https://vinpatel.com>" \
  -preparer "iso/mklimine-iso.sh" \
  -r -J -joliet-long \
  -b boot/limine/limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  --efi-boot boot/limine/limine-uefi-cd.bin \
  -efi-boot-part --efi-boot-image \
  --protective-msdos-label \
  -o "$TMP_ISO" "$ROOT" 2>&1 | grep -vi '^xorriso : UPDATE' || true
[[ -s "$TMP_ISO" ]] || die "xorriso produced no image"

log "installing the limine BIOS stage to the image"
limine bios-install "$TMP_ISO" >/dev/null || die "limine bios-install failed"

mv -f "$TMP_ISO" "$OUT_ISO"
log "done → $OUT_ISO ($(du -h "$OUT_ISO" | cut -f1))"

# Refresh the checksum sidecar if we replaced the ISO it describes.
_sums="$(dirname "$OUT_ISO")/sha256sums.txt"
if [[ -f "$_sums" ]] && grep -qF "$(basename "$OUT_ISO")" "$_sums"; then
  ( cd "$(dirname "$OUT_ISO")" && sha256sum "$(basename "$OUT_ISO")" > sha256sums.txt )
  log "refreshed $_sums"
fi
