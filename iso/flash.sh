#!/usr/bin/env bash
# iso/flash.sh — write a built vinOS ISO to a USB stick, safety first.
# Refuses anything that isn't `tran=usb` unless --i-know-what-im-doing.
# Requires TWO confirmations: type the device NAME, then type the exact
# MODEL string (as shown by lsblk). This is the primary guard against the
# classic "dd onto your NVMe" disaster.
#
# Usage:
#   iso/flash.sh --dev sdX [--iso PATH] [--no-persistence] [--i-know-what-im-doing]
#   iso/flash.sh                     # interactive: lists devices, prompts
#
# Persistence (DEFAULT — pass --no-persistence to opt out):
#   After `dd`, adds an ext4 partition labelled vinos-persist covering the
#   remaining space on the USB. The ISO's "Boot vinOS (persistent)" menu
#   entry mounts /dev/disk/by-label/vinos-persist as archiso's COW device
#   so changes (wifi passwords, files) survive reboots.
#
# Requires root (partitioning + dd). Never runs anything destructive
# without at least one interactive confirmation.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO=""
DEV=""
# Persistence is opt-in (--with-persistence). The default boot entry
# does NOT require the vinos-persist partition, so a plain flash boots
# cleanly. Enabling persistence changes the flash to create an ext4
# partition after the ISO; the "T2 + persistence" boot menu entry can
# then be selected to use it.
WITH_PERSIST=0
ALLOW_NON_USB=0

die() { printf '\033[1;31m[flash] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[flash]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[flash] WARN:\033[0m %s\n' "$*" >&2; }

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)  ISO="$2"; shift 2 ;;
    --dev)  DEV="$2"; shift 2 ;;
    --with-persistence)      WITH_PERSIST=1; shift ;;
    --no-persistence)        WITH_PERSIST=0; shift ;;
    --i-know-what-im-doing)  ALLOW_NON_USB=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "flash.sh must run as root (dd + partition)"

# --with-persistence needs sgdisk (gptfdisk). Check up front — failing
# AFTER the dd means the user is stuck without their persistence with a
# freshly-flashed USB and no clear next step. Fail fast instead.
if (( WITH_PERSIST )) && ! command -v sgdisk >/dev/null 2>&1; then
  die "--with-persistence needs sgdisk (Arch: pacman -S gptfdisk) — install first, or drop the flag"
fi

# ISO discovery.
[[ -z "$ISO" ]] && ISO="$(ls -1t "$ISO_DIR"/out/vinos-*.iso 2>/dev/null | head -1 || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO found — build with iso/build.sh or pass --iso PATH"

# List candidate devices for the user. TRAN goes first so multi-word
# MODEL strings ("SanDisk 3.2Gen1") don't shift columns and hide devs.
log "detected block devices:"
lsblk -d -o TRAN,NAME,SIZE,VENDOR,MODEL --paths | awk 'NR==1 || $1=="usb" {print "  " $0}'

# Device selection.
if [[ -z "$DEV" ]]; then
  printf 'Target device (e.g. sdb, sdc — do NOT include a partition suffix): '
  read -r DEV
fi
# Normalize: allow both "sdb" and "/dev/sdb".
DEV="${DEV#/dev/}"
DEV_PATH="/dev/$DEV"
[[ -b "$DEV_PATH" ]] || die "$DEV_PATH is not a block device"

# Refuse the host disk. If any partition of DEV is mounted at /, /boot, /home
# → hard fail regardless of --i-know-what-im-doing.
mounted="$(lsblk -n -o MOUNTPOINT "$DEV_PATH" | awk 'NF' | tr '\n' ' ')"
for critical in / /boot /home /efi /boot/efi; do
  if grep -qE "(^| )${critical}( |$)" <<<" $mounted "; then
    die "$DEV_PATH has a partition mounted at $critical — refusing (this is your OS disk)"
  fi
done

# Enforce USB transport unless overridden.
tran="$(lsblk -n -d -o TRAN "$DEV_PATH" | awk 'NF')"
if [[ "$tran" != "usb" && "$ALLOW_NON_USB" -ne 1 ]]; then
  die "$DEV_PATH transport is '$tran', not 'usb' — pass --i-know-what-im-doing to override"
fi

# Confirmation 1: dev name.
size="$(lsblk -n -d -o SIZE "$DEV_PATH")"
model="$(lsblk -n -d -o MODEL "$DEV_PATH" | awk '{$1=$1;print}')"
vendor="$(lsblk -n -d -o VENDOR "$DEV_PATH" | awk '{$1=$1;print}')"
[[ -z "$model" ]]  && model="(unknown)"
[[ -z "$vendor" ]] && vendor="(unknown)"

printf '\nAbout to WIPE %s\n  size: %s\n  vendor: %s\n  model: %s\n\n' \
       "$DEV_PATH" "$size" "$vendor" "$model"
printf 'Type the device name EXACTLY as shown above to confirm: '
read -r confirm_dev
[[ "$confirm_dev" == "$DEV_PATH" ]] || die "device name mismatch — aborting"

# Confirmation 2: model string (skip if unknown so users with generic USBs
# can still flash).
if [[ "$model" != "(unknown)" ]]; then
  printf 'Type the MODEL string EXACTLY as shown above to confirm: '
  read -r confirm_model
  [[ "$confirm_model" == "$model" ]] || die "model mismatch — aborting"
fi

log "unmounting any mounted partitions on $DEV_PATH"
for p in "$DEV_PATH"?*; do
  [[ -b "$p" ]] && umount "$p" 2>/dev/null || true
done

log "writing $ISO -> $DEV_PATH (dd bs=4M oflag=direct conv=fsync)"
dd if="$ISO" of="$DEV_PATH" bs=4M status=progress oflag=direct conv=fsync
sync
log "dd complete + sync"

if (( WITH_PERSIST )); then
  log "creating persistence partition (ext4 label=vinos-persist)"
  command -v sgdisk >/dev/null || die "sgdisk not found — install gptfdisk to use --with-persistence"
  # ISO writes GPT+MBR hybrid via xorriso; sgdisk can extend by adding a
  # partition after the ISO's data. Use largest available free space.
  sgdisk --new=0:0:0 --typecode=0:8300 --change-name=0:vinos-persist "$DEV_PATH"
  partprobe "$DEV_PATH" 2>/dev/null || true
  sleep 1
  # The new partition is the highest-numbered one on the disk.
  persist_part="$(lsblk -n -l -o NAME "$DEV_PATH" | awk 'NR>1' | tail -1)"
  [[ -n "$persist_part" ]] || die "could not find newly-created partition"
  persist_dev="/dev/$persist_part"
  mkfs.ext4 -F -L vinos-persist "$persist_dev"
  sync
  log "persistence ready: $persist_dev (label=vinos-persist)"
  log "select 'Boot vinOS (persistent)' from the boot menu to enable"
fi

log "done — safe to remove $DEV_PATH"
