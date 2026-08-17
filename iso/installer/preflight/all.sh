# preflight/all.sh — verify we can even attempt an install on this box.
# Runs before any user prompts. Failures die loudly so we never start
# collecting answers we can't act on.

phase_start 10 preflight || return 0

must_be_root
must_be_uefi     # v1.4.0: UEFI-only. Legacy BIOS is off the table.
must_have_cmd sgdisk mkfs.fat mkfs.ext4 pacstrap arch-chroot systemd-nspawn \
              bootctl gum iwctl ip curl timeout

# We need at least a plausible target disk. Enumerate non-USB, non-loop,
# non-rom devices ≥ 8 GiB. USB is deliberately excluded because that's
# the boot media in the common case.
mapfile -t candidates < <(
  lsblk -d -n -b -o NAME,SIZE,MODEL,TRAN 2>/dev/null \
    | awk '$4 != "usb" && $1 !~ /^loop/ && $1 !~ /^sr/ && $2 >= 8589934592 { print "/dev/"$1 }'
)
(( ${#candidates[@]} > 0 )) || die "no non-USB target disks ≥ 8 GiB found"
log "candidate target disks: ${candidates[*]}"

# Hardware profile detect. Drives the pacstrap package list and the
# bootloader entry's kernel choice on installed system.
_detect_profile() {
  local vendor
  vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || printf '')"
  case "$vendor" in
    "Apple Inc."|"Apple Computer, Inc.")
      echo "t2mac"; return ;;
  esac
  lspci 2>/dev/null | grep -qi 'nvidia' && { echo "nvidia"; return; }
  echo "generic"
}
PROFILE=$(_detect_profile)
log "hardware profile: $PROFILE"

# Network snapshot. If a default route is already up (ethernet or a
# previous session's wifi), we skip the wifi prompt later.
HAS_ROUTE=0
if ip route show default 2>/dev/null | grep -q .; then
  HAS_ROUTE=1
fi

HAS_WIFI=0
for _if in /sys/class/net/*; do
  [[ -d "$_if/wireless" ]] && { HAS_WIFI=1; break; }
done

log "network: has_route=$HAS_ROUTE has_wifi=$HAS_WIFI"

# Persist for downstream phases.
answers_write \
  UEFI            "1" \
  PROFILE         "$PROFILE" \
  HAS_ROUTE       "$HAS_ROUTE" \
  HAS_WIFI        "$HAS_WIFI" \
  CANDIDATE_DISKS "${candidates[*]}"

phase_done 10 preflight
