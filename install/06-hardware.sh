#!/usr/bin/env bash
# 06-hardware.sh — hardware-conditional package installs. Runs AFTER
# 05-branding so the box is fully vinOS by the time we touch driver
# stacks. Rule 1: no graphical operations here — driver packages are
# system-level. gen-packages.sh only extracts from 01/02, so nothing
# in this file leaks into packages.x86_64 or aur.list (deliberate —
# these installs are post-install-only, not baked into the ISO).
#
# Detection is intentionally shallow: dmidecode for OEM/model,
# lspci for graphics. Anything unrecognised is a no-op. Idempotent
# via install_pkg/install_aur (both use --needed).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_not_root

# VINOS_ROOT (ISO build) mode: skip entirely. The ISO ships stock
# `linux` (per DECISIONS.md I6 — T2 kernel is post-install only) and
# no DKMS drivers, which require kernel headers + a build against the
# target's exact kernel.
if [[ -n "$VINOS_ROOT" ]]; then
  log "06-hardware: VINOS_ROOT mode — skipping (post-install only)"
  exit 0
fi

# dmidecode + lspci are in base-devel/base-ish; fall back to noop if
# missing (unusual, e.g. running inside a container without procfs).
have() { command -v "$1" >/dev/null 2>&1; }
dmi() { have dmidecode && sudo dmidecode -s "$1" 2>/dev/null || printf ''; }
lspci_all() { have lspci && lspci 2>/dev/null || printf ''; }

sys_vendor="$(dmi system-manufacturer)"
sys_product="$(dmi system-product-name)"
pci="$(lspci_all)"

log "06-hardware: detected vendor='$sys_vendor' product='$sys_product'"

# --- Apple / T2 Mac -------------------------------------------------
# 2018+ MBP/MBA have the T2 chip. linux-t2 replaces the stock kernel
# to get internal keyboard/trackpad/audio working. macbook12-spi is
# for the pre-2018 butterfly-keyboard MBPs.
if [[ "$sys_vendor" == "Apple Inc." ]]; then
  log "06-hardware: Apple detected — installing T2 kernel + drivers"
  install_aur linux-t2 linux-t2-headers
  case "$sys_product" in
    MacBookPro13,*|MacBookPro14,*|MacBook9,*|MacBook10,*)
      install_aur macbook12-spi-driver-dkms ;;
  esac
  warn "T2 kernel installed as linux-t2 — update your bootloader to boot it (see docs/MAC.md when it lands)"
fi

# --- NVIDIA ---------------------------------------------------------
if grep -qi 'NVIDIA' <<<"$pci"; then
  log "06-hardware: NVIDIA GPU detected — installing nvidia-open-dkms"
  install_pkg nvidia-open-dkms nvidia-utils
fi

# --- AMD / Radeon ---------------------------------------------------
if grep -qiE 'AMD.*(Radeon|VGA)|Advanced Micro Devices.*(Radeon|VGA)' <<<"$pci"; then
  log "06-hardware: AMD GPU detected — installing vulkan-radeon"
  install_pkg vulkan-radeon libva-mesa-driver mesa-vdpau
fi

# --- Intel graphics -------------------------------------------------
if grep -qiE 'Intel.*(Graphics|Iris|UHD|HD Graphics)' <<<"$pci"; then
  log "06-hardware: Intel graphics detected — installing vulkan-intel + media"
  install_pkg vulkan-intel intel-media-driver libva-intel-driver
fi

# --- Dell XPS -------------------------------------------------------
if [[ "$sys_vendor" == "Dell Inc." ]] && [[ "$sys_product" == XPS* ]]; then
  log "06-hardware: Dell XPS detected — installing haptic touchpad driver"
  install_aur dell-xps-touchpad-haptics || warn "haptics driver optional; skipping"
fi

# --- ASUS -----------------------------------------------------------
if grep -qi 'ASUS' <<<"$sys_vendor"; then
  log "06-hardware: ASUS detected — installing asusctl"
  install_aur asusctl
fi

log "06-hardware: done"
