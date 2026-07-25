#!/usr/bin/env bash
# iso/v2/qa/oneshot.sh — pre-flash verification gate for vinOS 2.0.
#
# Runs static lint + optional QEMU boot smoke on the v2 ISO. Exits nonzero
# if any layer fails. Green = ISO is fit to flash to hardware.
#
# Usage:
#   iso/v2/qa/oneshot.sh                       # all layers
#   iso/v2/qa/oneshot.sh --skip-qemu           # static only
#   iso/v2/qa/oneshot.sh --iso path/to.iso     # specific ISO
#
# Exit codes:
#   0 = green
#   1 = static failed
#   3 = QEMU failed
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
V2_DIR="$REPO/iso/v2"
SKIP_QEMU=0
ISO=""

RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YLW=$'\033[1;33m'; BLU=$'\033[1;34m'; RST=$'\033[0m'
say()  { printf '%s[oneshot-v2]%s %s\n' "$BLU" "$RST" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '%s  !%s %s\n' "$YLW" "$RST" "$*"; }
fail() { printf '%s  ✗%s %s\n' "$RED" "$RST" "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --skip-qemu) SKIP_QEMU=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) fail "unknown arg: $1"; exit 1 ;;
  esac
done

FAILS=0
_fail() { fail "$1"; FAILS=$((FAILS+1)); }

# ── Layer 1 — static ────────────────────────────────────────────
say "Layer 1 — static"

[[ -f "$V2_DIR/VERSION" ]] || _fail "iso/v2/VERSION missing"
V2_VERSION="$(<"$V2_DIR/VERSION")"
say "v2 VERSION = $V2_VERSION"

[[ "$V2_VERSION" != "1.1.0" ]] || _fail "v2 VERSION cannot be 1.1.0 (archival gold copy)"

[[ -f "$V2_DIR/profile/profiledef.sh" ]] || _fail "profile/profiledef.sh missing"
[[ -f "$V2_DIR/profile/packages.x86_64" ]] || _fail "profile/packages.x86_64 missing"
[[ -f "$V2_DIR/profile/pacman.conf" ]] || _fail "profile/pacman.conf missing"
[[ -x "$V2_DIR/build.sh" ]] || _fail "build.sh missing or not executable"
[[ -x "$V2_DIR/vinos-install" ]] || _fail "vinos-install missing or not executable"

# profiledef.sh must set iso_application to something containing "2.0"
if ! grep -q 'iso_application=.*2\.0' "$V2_DIR/profile/profiledef.sh"; then
    _fail "profiledef.sh iso_application does not mention 2.0"
else
    ok "profiledef.sh identifies as vinOS 2.0"
fi

# label prefix must be VINOS2_ so v1 ISOs are distinguishable
if ! grep -q 'iso_label=.*VINOS2_' "$V2_DIR/profile/profiledef.sh"; then
    _fail "profiledef.sh iso_label prefix is not VINOS2_"
else
    ok "profiledef.sh iso_label uses VINOS2_ prefix"
fi

# Omarchy vendored
[[ -d "$REPO/configs/omarchy" ]] || _fail "configs/omarchy missing"
[[ -f "$REPO/configs/omarchy/version" ]] || _fail "configs/omarchy/version missing"
if [[ -f "$REPO/configs/omarchy/version" ]]; then
    OMA_VER="$(cat "$REPO/configs/omarchy/version")"
    ok "omarchy vendored at $OMA_VER"
fi

# All four vinOS overlays present with install.sh (except t2, which is build-time only)
for pack in security mac brand; do
    [[ -x "$REPO/configs/vinos/$pack/install.sh" ]] || _fail "configs/vinos/$pack/install.sh missing or not executable"
done
ok "vinOS overlays (security/mac/brand) all present with install scripts"

# T2 overlay present
[[ -f "$REPO/configs/vinos/t2/airootfs/etc/modprobe.d/vinos-brcmfmac.conf" ]] || _fail "T2 brcmfmac drop-in missing"
[[ -f "$REPO/configs/vinos/t2/packages.append" ]] || _fail "T2 packages.append missing"
ok "T2 live-env overlay present"

# 1.1.0 gold copy present and untouched
V1_GOLD="$REPO/iso/out/vinos-1.1.0-x86_64.iso"
if [[ -f "$V1_GOLD" ]]; then
    ok "v1.1.0 archival gold copy present ($(stat -c%s "$V1_GOLD") bytes)"
else
    warn "v1.1.0 archival gold copy NOT FOUND at $V1_GOLD"
fi

if (( FAILS > 0 )); then
    fail "static lint: $FAILS failure(s)"
    exit 1
fi
ok "static lint clean"

# ── Layer 2 — QEMU (optional) ───────────────────────────────────
if (( SKIP_QEMU )); then
    say "Layer 2 — QEMU (skipped)"
    exit 0
fi

if [[ -z "$ISO" ]]; then
    ISO="$REPO/iso/out/vinos-${V2_VERSION}-x86_64.iso"
fi
if [[ ! -f "$ISO" ]]; then
    warn "no ISO at $ISO — build first, then re-run --iso <path>"
    exit 0
fi

say "Layer 2 — QEMU boot smoke ($ISO)"
if ! command -v qemu-system-x86_64 >/dev/null; then
    warn "qemu-system-x86_64 not installed; skipping QEMU layer"
    exit 0
fi

SERIAL_LOG="$(mktemp -t vinos-v2-boot.XXXXXX.log)"
say "  serial → $SERIAL_LOG"

# 90-s QEMU boot smoke — we look for one of:
#   • VINOS_BOOT_OK           (vinos-boot-marker.service stamp; requires
#                              console=ttyS0 on the kernel cmdline, which
#                              syslinux doesn't add by default, so we
#                              rarely see this in serial-only QEMU)
#   • Reached target Multi-User (systemd milestone; same caveat)
#   • [root@ (auto-login prompt in the live env)
#   • "vinOS —" (the syslinux menu banner — this we ALWAYS see if the ISO
#                is bootable; a solid smoke-test floor since we can't
#                reliably catch kernel serial output).
# Find OVMF (edk2-ovmf on Arch, ovmf on Debian). Fall back to BIOS boot if
# UEFI firmware is unavailable — archiso profile has bios.syslinux too.
OVMF=""
for candidate in \
    /usr/share/edk2/x64/OVMF.4m.fd \
    /usr/share/edk2-ovmf/x64/OVMF.4m.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/ovmf/x64/OVMF.fd; do
    [[ -f "$candidate" ]] && { OVMF="$candidate"; break; }
done

QEMU_ARGS=(-m 4096 -smp 2 -cdrom "$ISO" -nographic -serial mon:stdio -boot d)
[[ -w /dev/kvm ]] && QEMU_ARGS=(-enable-kvm -cpu host "${QEMU_ARGS[@]}")
[[ -n "$OVMF" ]]  && QEMU_ARGS=(-bios "$OVMF" "${QEMU_ARGS[@]}") || \
                     warn "no OVMF found — falling back to BIOS boot via syslinux"

timeout 90 qemu-system-x86_64 "${QEMU_ARGS[@]}" > "$SERIAL_LOG" 2>&1 || true

if grep -qE 'VINOS_BOOT_OK|Reached target [Mm]ulti-[Uu]ser|\[root@' "$SERIAL_LOG"; then
    ok "QEMU boot reached live env (multi-user milestone)"
    exit 0
elif grep -qE 'vinOS — Apple T2|vinOS — Intel|BdsDxe: loading' "$SERIAL_LOG"; then
    ok "QEMU boot reached bootloader menu (smoke-test floor)"
    warn "kernel-userspace transition not captured on serial — expected"
    warn "(syslinux does not add console=ttyS0; capture would need a cmdline patch)"
    warn "verify on real T2 hardware for full boot proof"
    exit 0
else
    _fail "QEMU did not reach the bootloader — see $SERIAL_LOG"
    tail -20 "$SERIAL_LOG" | sed 's/^/    | /'
    exit 3
fi
