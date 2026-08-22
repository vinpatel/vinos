#!/usr/bin/env bash
# iso/qa/usb-boot-smoke.sh — boot the ISO the way a user actually boots it.
#
# WHY THIS EXISTS
#
# iso/qa/install-smoke.sh attaches the ISO with -cdrom. A CD has no
# partition table, so the live medium is found no matter how the image is
# partitioned. A USB stick is the opposite: it is the partition table.
#
# On 2026-08-22 an ISO passed install-smoke 10/10 and then dropped to the
# initramfs emergency shell on real hardware, in a loop:
#
#     ERROR: ... device did not show up after 30 seconds
#        Falling back to interactive prompt
#     sh: can't access tty; job control turned off
#
# The re-master had lost `-partition_offset 16`, so the ISO9660 filesystem
# existed only at offset 0 of the whole device and no partition carried a
# superblock. archiso's initramfs searches *partitions* for
# /boot/<uuid>.uuid, found none, and gave up. Booted as a CD it was fine.
# No amount of -cdrom testing could ever have caught it.
#
# So: boot the image as a USB mass-storage device, under both firmwares,
# and require the live system to reach its VINOS_BOOT_OK marker. This is
# cheap — no install, no disk — and it is the gate that would have caught
# a boot loop before it reached a USB stick.
#
# Usage:
#   iso/qa/usb-boot-smoke.sh [--iso PATH] [--timeout SECS] [--bios]
#     --iso PATH      image to test (default: iso/out/vinos-$(cat VERSION)-x86_64.iso)
#     --timeout SECS  per-case wall clock (default 240)
#     --uefi-only     skip the legacy-BIOS USB case. Both firmwares are
#                     required by default: docs/HARDWARE.md scopes the ISO to
#                     "USB -> BIOS/UEFI boot", so a UEFI-only image is a
#                     regression, not a pass.
set -euo pipefail

QA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$QA_DIR/../.." && pwd)"

ISO=""
TIMEOUT=240
WANT_BIOS=1

RED='\033[1;31m'; GREEN='\033[1;32m'; BLUE='\033[1;34m'; RESET='\033[0m'
die() { printf "${RED}[usb-boot] FAIL:${RESET} %s\n" "$*" >&2; exit 2; }
log() { printf "${BLUE}[usb-boot]${RESET} %s\n" "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)     [[ $# -ge 2 ]] || die "--iso needs a path"; ISO="$2"; shift 2 ;;
    --timeout) [[ $# -ge 2 ]] || die "--timeout needs secs"; TIMEOUT="$2"; shift 2 ;;
    --uefi-only) WANT_BIOS=0; shift ;;
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

if [[ -z "$ISO" ]]; then
  ISO="$REPO/iso/out/vinos-$(<"$REPO/VERSION")-x86_64.iso"
fi
[[ -f "$ISO" ]] || die "ISO not found: $ISO"

OVMF_CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
OVMF_VARS=/usr/share/edk2/x64/OVMF_VARS.4m.fd
[[ -f "$OVMF_CODE" ]] || die "$OVMF_CODE missing — install edk2-ovmf"
command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 not found"

# ── static layout checks ───────────────────────────────────────────
# These are the specific properties a USB boot depends on, checked before
# spending minutes on QEMU so a broken image fails in a second with a
# diagnosis instead of a timeout.
command -v partx >/dev/null || die "partx not found (pkg: util-linux)"

P1_START="$(partx -g -o START "$ISO" 2>/dev/null | sed -n 1p | tr -d ' ' || true)"
[[ -n "$P1_START" ]] || die "no partition table — a dd'd USB stick would expose no partitions at all"

python3 - "$ISO" "$P1_START" <<'PYEOF' || die "partition 1 has no ISO9660 superblock of its own.
       archiso's initramfs searches partitions for /boot/<uuid>.uuid; it will
       find nothing and drop to the emergency shell. Rebuild with
       xorriso's -partition_offset 16."
import sys
iso, start = sys.argv[1], int(sys.argv[2])
with open(iso, 'rb') as f:
    f.seek(start * 512 + 32768)
    sys.exit(0 if f.read(6)[1:6] == b'CD001' else 1)
PYEOF
log "partition 1 carries an ISO9660 superblock (offset ${P1_START}s)"

# Two spellings, because the two layouts we ship differ: a GPT image names
# the ESP by type GUID, an MBR image by type byte, and partx prints the byte
# as 0xef. Matching only one of them failed the stock archiso ISO — the image
# known to boot on real hardware — so the gate has to know both.
partx -g -o TYPE "$ISO" 2>/dev/null \
  | grep -qiE 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b|^ *(0x)?ef$' \
  || die "no EFI system partition — UEFI firmware would find nothing to boot"
log "EFI system partition present"

# ── boot cases ─────────────────────────────────────────────────────
WORK="$(mktemp -d /tmp/vinos-usbboot.XXXXXX)"   # short path: QEMU UNIX
trap 'rm -rf "$WORK"' EXIT                      # sockets cap out at 108 bytes

FAIL=0

_boot_case() {
  local label="$1" fw="$2"
  local d="$WORK/$label"; mkdir -p "$d"
  local serial="$d/serial.log"

  local args=(-m 4096 -smp 4 -machine q35,accel=kvm -vga std -display none
              -serial "file:$serial" -no-reboot
              -device qemu-xhci,id=xhci
              -drive "if=none,id=stick,format=raw,file=$ISO,snapshot=on"
              -device usb-storage,bus=xhci.0,drive=stick,bootindex=0)
  if [[ "$fw" == uefi ]]; then
    cp -f "$OVMF_VARS" "$d/VARS.fd" 2>/dev/null || truncate -s 4M "$d/VARS.fd"
    chmod u+w "$d/VARS.fd"
    args+=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
           -drive "if=pflash,format=raw,file=$d/VARS.fd")
  fi

  log "booting $label (up to ${TIMEOUT}s)"
  qemu-system-x86_64 "${args[@]}" </dev/null >"$d/qemu.out" 2>&1 &
  local pid=$! verdict="" waited=0

  while (( waited < TIMEOUT )); do
    sleep 5; waited=$((waited + 5))
    kill -0 "$pid" 2>/dev/null || { verdict="qemu exited early — see $d/qemu.out"; break; }
    if grep -aq 'VINOS_BOOT_OK' "$serial" 2>/dev/null; then verdict=OK; break; fi
    # The emergency-shell loop. Named explicitly so the failure reads as a
    # diagnosis rather than "it didn't boot".
    if grep -aqE 'device did not show up|Falling back to interactive prompt' "$serial" 2>/dev/null; then
      verdict="initramfs could not find the live medium (emergency shell loop)"; break
    fi
    grep -aq 'Kernel panic' "$serial" 2>/dev/null && { verdict="kernel panic"; break; }
  done
  [[ -n "$verdict" ]] || verdict="timed out with $(wc -c <"$serial" 2>/dev/null || echo 0) bytes of serial output"

  kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true

  if [[ "$verdict" == OK ]]; then
    printf "${GREEN}PASS${RESET} %-12s reached VINOS_BOOT_OK\n" "$label"
  else
    printf "${RED}FAIL${RESET} %-12s %s\n" "$label" "$verdict"
    FAIL=$((FAIL + 1))
  fi
}

printf '\n\033[1;36m== iso/qa/usb-boot-smoke.sh ==\033[0m\n'
log "image: $ISO"
_boot_case uefi-usb uefi
# Plain `(( WANT_BIOS )) && ...` would evaluate to 1 under --uefi-only and
# take `set -e` down with it.
if (( WANT_BIOS )); then _boot_case bios-usb bios; fi

if (( FAIL )); then
  printf "\n${RED}%d boot case(s) failed${RESET} — this image would not boot off a USB stick.\n" "$FAIL"
  exit 1
fi
printf "\n${GREEN}usb-boot-smoke GREEN${RESET}\n"
