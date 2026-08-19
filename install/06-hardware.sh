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
#
# linux-t2 and Apple firmware live in the community [arch-mact2]
# pacman repo (t2linux community project), NOT the AUR. On Path B
# (ISO install) the repo is already in the target's /etc/pacman.conf
# because archinstall inherited it from the ISO. On Path A (layer
# vinOS onto an existing Arch) we need to register the repo first.
if [[ "$sys_vendor" == "Apple Inc." ]]; then
  log "06-hardware: Apple detected — installing T2 kernel + firmware stack"

  _pacman_conf="$(_rootpath /etc/pacman.conf)"
  if ! grep -q '^\[arch-mact2\]' "$_pacman_conf" 2>/dev/null; then
    log "06-hardware: registering [arch-mact2] repo in /etc/pacman.conf"
    _sudo tee -a "$_pacman_conf" >/dev/null <<'PACCONF'

[arch-mact2]
SigLevel = Never
Server = https://mirror.funami.tech/arch-mact2/os/$arch
PACCONF
    sudo pacman -Syy 2>&1 | tail -3 || warn "pacman -Syy failed; arch-mact2 mirror may be temporarily down"
  fi

  # Ship the whole T2 stack. arch-mact2-mirrorlist pulls a curated
  # list of mirrors so we're not pinned to funami forever.
  install_pkg linux-t2 linux-t2-headers apple-bcm-firmware \
              apple-t2-audio-config tiny-dfr t2fanrd arch-mact2-mirrorlist

  # Older butterfly-keyboard MBPs use the SPI driver rather than the
  # in-tree linux-t2 driver.
  case "$sys_product" in
    MacBookPro13,*|MacBookPro14,*|MacBook9,*|MacBook10,*)
      install_aur macbook12-spi-driver-dkms ;;
  esac

  # After arch-mact2-mirrorlist is installed, switch the pacman.conf
  # entry to Include the mirrorlist file. Idempotent — grep-guarded.
  if ! grep -q '^Include = /etc/pacman.d/arch-mact2-mirrorlist' "$_pacman_conf"; then
    _sudo sed -i '/^\[arch-mact2\]/,/^Server/ { /^Server/c\Include = /etc/pacman.d/arch-mact2-mirrorlist
    }' "$_pacman_conf" || warn "could not switch to mirrorlist; direct Server= remains"
  fi

  # Enable T2-specific services. Correct target per each unit's [Install]:
  # t2fanrd → default.target (its base unit's WantedBy); tiny-dfr →
  # graphical.target (its t2-intel drop-in's WantedBy). Enabling tiny-dfr
  # into multi-user.target.wants — as v1.3.0 tried — left the ordering
  # against After=graphical.target unresolvable on Vin's 2019 T2 MBP.
  VINOS_SYSTEMCTL_TARGET=default.target   systemctl_enable t2fanrd
  VINOS_SYSTEMCTL_TARGET=graphical.target systemctl_enable tiny-dfr

  # t2fanrd config — the Rust daemon reads /etc/t2fand.conf (path shared
  # with the older Python t2fand). Without it, `t2fanrd` errors on start
  # ("Cannot read config file") and fans stay at BIOS default (usually
  # full-speed on T2 because macOS ordinarily owns fan control). Values
  # match the Omarchy fix-t2.sh preset.
  _t2fand="$(_rootpath /etc/t2fand.conf)"
  if [[ ! -f "$_t2fand" ]]; then
    _t2fand_tmp="$(mktemp)"
    cat > "$_t2fand_tmp" <<'FANCONF'
[Fan1]
low_temp=55
high_temp=75
speed_curve=linear
always_full_speed=false
FANCONF
    _sudo install -Dm 0644 "$_t2fand_tmp" "$_t2fand"
    rm -f "$_t2fand_tmp"
    log "06-hardware: wrote /etc/t2fand.conf (default T2 fan curve)"
  fi

  # tiny-dfr expects the invoking user to be in the video group so it
  # can access /dev/dri devices when interacting with the Touch Bar
  # from userspace helpers. Add every non-system user (uid ≥ 1000) so
  # this Just Works after install without asking the user to logout.
  # No-op on the live ISO (vinos-live-init.service creates the vinos
  # user already in `video,audio,input,storage,network`).
  if [[ -z "$VINOS_ROOT" ]]; then
    while IFS=: read -r _u _ _uid _; do
      [[ "$_uid" -ge 1000 && "$_uid" -lt 65000 ]] || continue
      sudo usermod -aG video "$_u" 2>&1 | grep -v "already" || true
    done < /etc/passwd
  fi

  # Add the T2 SPI modules to initramfs so the internal keyboard
  # works from early boot. Without this, applespi loads too late and
  # only the trackpad works (they're both on the T2 SPI bus but the
  # trackpad's driver initializes on its own).
  # apple_ibridge/apple_ib_tb (older Touch Bar drivers) intentionally
  # omitted — modern linux-t2 exposes the Touch Bar via appletbdrm +
  # hid-appletb-{bl,kbd} which auto-load via module aliases when the
  # Touch Bar USB device (05ac:8302) appears through the apple-bce
  # USB tunnel. tiny-dfr renders the strip from userspace.
  _mki="$(_rootpath /etc/mkinitcpio.conf)"
  if [[ -f "$_mki" ]] && ! grep -qE '^MODULES=.*\bapplespi\b' "$_mki"; then
    log "06-hardware: adding applespi + T2 SPI modules to mkinitcpio"
    _sudo sed -i -E \
      's/^MODULES=\((.*)\)/MODULES=(\1 applespi spi_pxa2xx_platform intel_lpss intel_lpss_pci)/' \
      "$_mki"
    # Handle the case where MODULES= is empty.
    _sudo sed -i -E 's/^MODULES=\( +/MODULES=(/' "$_mki"
  fi

  # T2 USB/Bluetooth stack — linux-t2 conventions. apple-bce carries the T2
  # USB tunnel + audio + touchpad; hci_bcm4377 is the T2 Bluetooth
  # radio; hid_apple / hid_generic / usbhid / xhci_* give the internal
  # keyboard + external USB devices from early boot (before udev).
  _mki_d="$(_rootpath /etc/mkinitcpio.conf.d)"
  _sudo install -d -m 0755 "$_mki_d"
  _t2_mki_tmp="$(mktemp)"
  printf 'MODULES+=(apple-bce usbhid hid_apple hid_generic xhci_pci xhci_hcd)\n' > "$_t2_mki_tmp"
  _sudo install -Dm 0644 "$_t2_mki_tmp" "$_mki_d/apple-t2.conf"
  rm -f "$_t2_mki_tmp"

  # apple-bce + hci_bcm4377 need to be loaded early on the running
  # system too (not just initramfs) — modules-load.d handles that.
  _modl="$(_rootpath /etc/modules-load.d)"
  _sudo install -d -m 0755 "$_modl"
  _t2_ml_tmp="$(mktemp)"
  printf 'apple-bce\nhci_bcm4377\n' > "$_t2_ml_tmp"
  _sudo install -Dm 0644 "$_t2_ml_tmp" "$_modl/vinos-t2.conf"
  rm -f "$_t2_ml_tmp"

  # brcmfmac quirk — T2 Broadcom Wi-Fi disassociates without this
  # feature-disable mask. Root cause of "wifi keeps dropping" on T2.
  _modp="$(_rootpath /etc/modprobe.d)"
  _sudo install -d -m 0755 "$_modp"
  _t2_mp_tmp="$(mktemp)"
  cat > "$_t2_mp_tmp" <<'BRCMCONF'
# T2 MacBook Wi-Fi connectivity workaround (linux-t2 project recipe).
# Without this the T2 brcmfmac driver disassociates repeatedly on
# 5GHz APs — mask the broken firmware features it can't handle.
options brcmfmac feature_disable=0x82000
BRCMCONF
  _sudo install -Dm 0644 "$_t2_mp_tmp" "$_modp/vinos-brcmfmac.conf"
  rm -f "$_t2_mp_tmp"

  # Rebuild initramfs for the new linux-t2 kernel + regenerate
  # bootloader entries so the T2 kernel is bootable.
  if [[ -z "$VINOS_ROOT" ]] && command -v mkinitcpio >/dev/null; then
    _sudo mkinitcpio -P 2>&1 | tail -5 || warn "mkinitcpio -P failed; boot may still be OK if entries exist"
  fi

  # Make the T2 kernel bootable. vinOS boots limine, so the entry is a
  # block in /boot/limine.conf; vinos-boot-entry owns that edit and the
  # default_entry index arithmetic. 05-branding runs before this script
  # and symlinks it into /usr/local/bin, so it is on PATH by now.
  # systemd-boot stays supported for machines installed before the limine
  # migration.
  if [[ -z "$VINOS_ROOT" ]]; then
    _root_uuid=$(findmnt -no UUID /)
    if command -v vinos-boot-entry >/dev/null && [[ -f /boot/limine.conf ]]; then
      log "06-hardware: writing limine entry for linux-t2"
      vinos-boot-entry \
        --title 'vinOS (Apple T2 Mac)' \
        --comment 'T2 kernel — Touch Bar, keyboard, trackpad, Wi-Fi, audio, fans.' \
        --kernel /vmlinuz-linux-t2 \
        --initramfs /initramfs-linux-t2.img \
        --cmdline "root=UUID=${_root_uuid} rw quiet splash intel_iommu=on iommu=pt" \
        --default \
        || warn "could not add the linux-t2 limine entry — run 'vinos-t2-enable' after reboot"
    elif [[ -d /boot/loader ]] && command -v bootctl >/dev/null; then
      if ! ls /boot/loader/entries/*linux-t2* >/dev/null 2>&1; then
        log "06-hardware: writing systemd-boot entry for linux-t2 (pre-limine install)"
        _sudo tee /boot/loader/entries/vinos-t2.conf >/dev/null <<T2ENTRY
title   vinOS (Apple T2 Mac)
linux   /vmlinuz-linux-t2
initrd  /initramfs-linux-t2.img
options root=UUID=${_root_uuid} rw quiet splash intel_iommu=on iommu=pt
T2ENTRY
        _sudo bootctl set-default vinos-t2.conf 2>&1 | tail -3 || true
      fi
    else
      warn "06-hardware: no bootloader config found — linux-t2 installed but not bootable; run 'vinos-t2-enable'"
    fi
  fi

  log "06-hardware: T2 stack installed. Reboot into the linux-t2 kernel for full hardware support."
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
  install_pkg vulkan-radeon libva-mesa-driver
fi

# --- Intel graphics -------------------------------------------------
if grep -qiE 'Intel.*(Graphics|Iris|UHD|HD Graphics)' <<<"$pci"; then
  log "06-hardware: Intel graphics detected — installing vulkan-intel + media"
  install_pkg vulkan-intel intel-media-driver libva-intel-driver
fi

# --- Broadcom wireless (BCM43xx) ------------------------------------
# In-tree drivers (b43, brcmsmac, brcmfmac) work for some cards but the
# 4360/43602/43a0 family (Apple pre-T2 MBPs, various Dell/HP laptops)
# needs the out-of-tree wl driver from broadcom-wl-dkms. Detection is
# by PCI device-id — the archiso ships /etc/modprobe.d/broadcom-wl.conf
# which pre-blacklists b43/bcma/ssb, but only matters if wl is installed.
# T2 Macs don't hit this path — wifi there is via apple-bcm-firmware.
_bcm_wl_ids='14e4:4331|14e4:4353|14e4:4357|14e4:4359|14e4:4360|14e4:43a0|14e4:43a3|14e4:43b1|14e4:43ba'
if grep -qiE "Broadcom.*Network|Broadcom.*Wireless" <<<"$pci" \
   && lspci -nn 2>/dev/null | grep -qiE "($_bcm_wl_ids)"; then
  log "06-hardware: Broadcom BCM43xx (wl-only) detected — installing broadcom-wl-dkms"
  install_aur broadcom-wl-dkms || warn "broadcom-wl-dkms failed; leaving b43/brcmsmac attempt in place"

  # b43/bcma/ssb conflict with wl — blacklist them and unload any that
  # are live. The archiso file only exists on the live medium; write our
  # own so the target keeps the blacklist after install.
  _mpd="$(_rootpath /etc/modprobe.d)"
  _sudo install -d -m 0755 "$_mpd"
  _bcm_tmp="$(mktemp)"
  cat > "$_bcm_tmp" <<'BCM'
# vinOS: BCM43xx uses out-of-tree `wl` (broadcom-wl-dkms). b43, bcma,
# and ssb attach to the same PCI device and prevent wl from loading.
blacklist b43
blacklist bcma
blacklist ssb
BCM
  _sudo install -Dm 0644 "$_bcm_tmp" "$_mpd/vinos-broadcom.conf"
  rm -f "$_bcm_tmp"

  if [[ -z "$VINOS_ROOT" ]]; then
    for _mod in b43 bcma ssb; do
      lsmod 2>/dev/null | grep -q "^$_mod " && _sudo rmmod "$_mod" 2>/dev/null || true
    done
    _sudo modprobe wl 2>/dev/null || warn "modprobe wl failed; reboot needed for wifi"
  fi
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
