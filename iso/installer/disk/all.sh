# disk/all.sh — partition, format, and mount the target disk.
#
# Layout (v1.4.0, UEFI-only):
#   part 1  =  512 MiB   ef00  → mkfs.fat -F32 -n VINOS_EFI  →  /mnt/boot
#   part 2  =  remainder 8300  → mkfs.ext4 -L VINOS_ROOT      →  /mnt
#
# Every step is verified. If the disk is 8-32 GiB we accept it but log
# a warning; below 8 GiB preflight already refused it.

phase_start 30 disk || return 0

answers_load
: "${DISK:?disk phase reached without a DISK in answers.env}"

[[ -b "$DISK" ]] || die "$DISK is not a block device"

# Guard: reject if any partition on $DISK is currently mounted at a
# critical path.
_mounted=$(lsblk -n -o MOUNTPOINT "$DISK" 2>/dev/null | awk 'NF' | tr '\n' ' ')
for critical in / /boot /home /efi /boot/efi "$TARGET_ROOT"; do
  if grep -qE "(^| )${critical}( |$)" <<<" $_mounted "; then
    die "$DISK is mounted at $critical — refusing to touch"
  fi
done

# Devices with partition-suffix quirks. NVMe/eMMC use ${DISK}p1;
# ordinary SATA/USB use ${DISK}1. Detect and set the suffix separator.
if [[ "$DISK" =~ (nvme|mmcblk|loop)[0-9]+$ ]]; then
  PART_SEP="p"
else
  PART_SEP=""
fi
EFI_PART="${DISK}${PART_SEP}1"
ROOT_PART="${DISK}${PART_SEP}2"
log "partition device names: EFI=$EFI_PART ROOT=$ROOT_PART"

# Unmount anything that might be lingering from a prior aborted attempt
# on this disk. Non-fatal — a fresh disk will report "not mounted".
for p in $(lsblk -ln -o NAME "$DISK" 2>/dev/null | tail -n +2); do
  try_run umount -f "/dev/$p" || true
done
# Also drop any lingering /mnt bind mounts.
if mountpoint -q "$TARGET_ROOT"; then
  try_run umount -R "$TARGET_ROOT" || true
fi

# ── wipe + partition ──────────────────────────────────────────────
run wipefs -a "$DISK"
run sgdisk --zap-all "$DISK"
run sgdisk \
  --new=1:0:+512MiB   --typecode=1:ef00 --change-name=1:VINOS_EFI \
  --new=2:0:0         --typecode=2:8300 --change-name=2:VINOS_ROOT \
  "$DISK"

# Let the kernel pick up the new partition table before we mkfs.
run partprobe "$DISK"
run udevadm settle

[[ -b "$EFI_PART"  ]] || die "expected EFI partition at $EFI_PART did not appear after partprobe"
[[ -b "$ROOT_PART" ]] || die "expected root partition at $ROOT_PART did not appear after partprobe"

# ── format ────────────────────────────────────────────────────────
run mkfs.fat  -F32 -n VINOS_EFI  "$EFI_PART"
run mkfs.ext4 -F -L VINOS_ROOT   "$ROOT_PART"

# ── mount ─────────────────────────────────────────────────────────
run mkdir -p "$TARGET_ROOT"
run mount "$ROOT_PART" "$TARGET_ROOT"
run mkdir -p "$TARGET_ROOT/boot"
run mount "$EFI_PART"  "$TARGET_ROOT/boot"

# Persist for later phases + fstab generation.
answers_write \
  EFI_PART   "$EFI_PART"  \
  ROOT_PART  "$ROOT_PART" \
  EFI_UUID   "$(blkid -s UUID -o value "$EFI_PART")" \
  ROOT_UUID  "$(blkid -s UUID -o value "$ROOT_PART")"

# ── verify ────────────────────────────────────────────────────────
mountpoint -q "$TARGET_ROOT"        || die "$TARGET_ROOT is not mounted"
mountpoint -q "$TARGET_ROOT/boot"   || die "$TARGET_ROOT/boot is not mounted"
[[ -n "$(blkid -s UUID -o value "$ROOT_PART")" ]] || die "root partition has no UUID"

log "disk ready: $DISK partitioned, formatted, and mounted at $TARGET_ROOT"
phase_done 30 disk
