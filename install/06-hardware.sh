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
# I9: nvidia-open-dkms is the modern proprietary Wayland-friendly stack.
# Environment vars quiet the common Hyprland+NVIDIA rendering issues.
# The Hyprland env drop-in is applied only if hyprland is already
# installed on the system (i.e. 02-desktop ran). Rule 1 boundary is
# respected: we're writing a conf file, not launching a compositor.
if grep -qi 'NVIDIA' <<<"$pci"; then
  log "06-hardware: NVIDIA GPU detected — installing nvidia-open-dkms + companions"
  install_pkg nvidia-open-dkms nvidia-utils libva-nvidia-driver egl-wayland

  # Optional: hybrid-graphics prime-run helper (nvidia-prime). Fatal
  # nothing if the box has only a single GPU — pacman -Sy --needed
  # is a no-op when nvidia-prime is already provided by nvidia-utils
  # on some setups. `|| true` because a small subset of NVIDIA-only
  # desktops have no CONFIG_HYBRID need but still want the driver.
  install_pkg nvidia-prime || true

  log "06-hardware: writing NVIDIA env drop-ins"
  _envd="$(_rootpath /etc/environment.d)"
  _sudo install -d -m 0755 "$_envd"
  _envtmp="$(mktemp)"
  cat > "$_envtmp" <<'ENV'
# vinOS: NVIDIA + Wayland environment. Written by install/06-hardware.sh.
# Removes hardware cursor glitches on wlroots-based compositors (Hyprland);
# forces GLX + VA-API to use the nvidia userspace stack.
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
GBM_BACKEND=nvidia-drm
ENV
  _sudo install -Dm 0644 "$_envtmp" "$_envd/50-vinos-nvidia.conf"
  rm -f "$_envtmp"

  # Hyprland NVIDIA snippet — inserted as an include in the shipped
  # hyprland.conf if the file exists. Idempotent (grep guard).
  _hyprsnippet="$(_rootpath /etc/xdg/hypr/nvidia.conf)"
  _sudo install -d -m 0755 "$(dirname "$_hyprsnippet")"
  _snip="$(mktemp)"
  cat > "$_snip" <<'HYPR'
# vinOS: NVIDIA-specific Hyprland tuning. Source from user's hyprland.conf
# via `source = /etc/xdg/hypr/nvidia.conf`. Applied automatically when
# vinos-launch-hypr detects a discrete NVIDIA GPU (I11 helper).
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
env = GBM_BACKEND,nvidia-drm
cursor {
  no_hardware_cursors = true
}
render {
  explicit_sync = 0
  explicit_sync_kms = 0
}
HYPR
  _sudo install -Dm 0644 "$_snip" "$_hyprsnippet"
  rm -f "$_snip"

  # Kernel-side: nvidia_drm.modeset=1 is required for Wayland. Add via
  # kernel cmdline (mkinitcpio needs the modules early). Kernel modules
  # get added to /etc/mkinitcpio.conf MODULES=(...); grep-guard prevents
  # duplicate appends. Skip in VINOS_ROOT (ISO ships the stock kernel).
  _mki="$(_rootpath /etc/mkinitcpio.conf)"
  if [[ -f "$_mki" ]] && ! grep -qE '^MODULES=.*\bnvidia_drm\b' "$_mki"; then
    log "06-hardware: adding nvidia_drm module to mkinitcpio"
    _sudo sed -i -E 's/^MODULES=\((.*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$_mki"
    _sudo mkinitcpio -P || warn "mkinitcpio -P failed after NVIDIA module add"
  fi

  # /etc/modprobe.d for KMS. `options nvidia_drm modeset=1` is the
  # canonical Arch way to guarantee KMS at boot even without a cmdline
  # edit — belt + suspenders with the mkinitcpio MODULES change.
  _mp="$(_rootpath /etc/modprobe.d)"
  _sudo install -d -m 0755 "$_mp"
  _mptmp="$(mktemp)"
  printf 'options nvidia_drm modeset=1 fbdev=1\n' > "$_mptmp"
  _sudo install -Dm 0644 "$_mptmp" "$_mp/vinos-nvidia.conf"
  rm -f "$_mptmp"
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
