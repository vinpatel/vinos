#!/usr/bin/env bash
# 02-desktop.sh — Hyprland module (Rule 1: the ONLY graphical script).
# Idempotent. In VINOS_ROOT (ISO build) mode, install_pkg is a no-op
# (packages come from gen-packages → packages.x86_64) but greetd config
# and enable still land in the airootfs.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_not_root

log "02-desktop: installing Hyprland stack + core UX apps"
# I11 pivot: base is LEAN. GUI apps (chromium/signal/spotify/obsidian/
# 1password/localsend) moved to opt-in bundles under bin/vinos-install-*.
# What remains here is the Hyprland compositor, terminals, notification
# stack, media pipeline, file manager, and UX-critical utilities.
#
# uwsm is NOT optional. The greetd config written below launches the
# session with `uwsm start hyprland-uwsm.desktop`, and every line in
# config/hypr/autostart.conf plus several keybindings wrap their command
# in `uwsm-app --`. It was listed for the ISO (iso/packages.live,
# iso/profile/packages.x86_64) but missing from this installer list, so a
# disk-installed machine wrote a greetd config calling a binary it did
# not have: tuigreet authenticated fine, then the session died in ~1 s
# and dropped back to the greeter. Login was impossible. Observed on a
# limine-installed 1.3.0 guest, 2026-08-19.
#
# awww / fcitx5 / fcitx5-gtk / fcitx5-qt / jq were in the same state for
# the same reason: listed directly in iso/packages.live and
# iso/profile/packages.x86_64, never here. iso/packages.live's own header
# says this file is meant to be the single source of truth precisely to
# "avoid drift between live and installed builds", and that is the drift.
# On the installed guest that meant no wallpaper at all (awww renders it,
# autostart.conf:19-20), no input method, and a dead Super+Ctrl+Z zoom
# binding that pipes hyprctl through jq.
install_pkg \
  hyprland uwsm waybar alacritty foot mako grim slurp swaybg wl-clipboard \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprland-guiutils \
  qt5-wayland qt6-wayland polkit-gnome \
  greetd greetd-tuigreet ttf-jetbrains-mono-nerd woff2-font-awesome \
  noto-fonts noto-fonts-emoji noto-fonts-cjk fontconfig \
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
  pavucontrol wiremix \
  nautilus sushi nautilus-python gnome-disk-utility \
  gnome-calculator libqalculate \
  plymouth \
  hypridle hyprlock hyprpicker hyprsunset swayosd satty \
  gtk4-layer-shell kvantum kvantum-qt5 qt6ct \
  gnome-keyring gnome-themes-extra libsecret \
  pamixer playerctl brightnessctl gum \
  mesa vulkan-radeon vulkan-intel libva-mesa-driver libva-intel-driver \
  intel-media-driver \
  bluez bluez-utils bluetui \
  alsa-firmware alsa-ucm-conf alsa-utils sof-firmware \
  power-profiles-daemon thermald acpid bolt \
  ffmpegthumbnailer gvfs-mtp gvfs-nfs gvfs-smb \
  zram-generator kernel-modules-hook \
  awww fcitx5 fcitx5-gtk fcitx5-qt jq

log "02-desktop: installing AUR apps (UX-critical only)"
# I11 pivot: spotify/obsidian/1password/localsend live in bundles now.
# walker (source): matches upstream so no walker/walker-bin conflict
# on machines that already have the source variant.
# yaru-icon-theme was removed from AUR (2026-08); replaced by
# `papirus-icon-theme` (Arch repo, comparable coverage + dark variant).
# bibata-cursor-theme: sharp modern cursors.
# hyprpm needs its git alternate; we install plugins post-boot with
# vinos-hypr-plugins (see below).
# elephant is walker 2.16+'s data-provider backend, and autostart.conf
# launches it directly. It was in iso/aur.list (so the live ISO had it)
# but absent here, so a disk-installed machine got walker with no backend
# and Super+Space did nothing — the 2026-08-09 walker/elephant bug
# reappearing, because that fix only ever landed in the config.
install_aur walker elephant bibata-cursor-theme nwg-drawer
install_pkg papirus-icon-theme

# Optional Hyprland plugins via hyprpm. hyprpm ships with hyprland,
# so no extra package needed. We install the beauty-pass plugins on
# first boot after Hyprland is running so headers match the exact
# version. Installer mode only — VINOS_ROOT (ISO build) skips because
# hyprpm needs a running graphical session.
if [[ -z "$VINOS_ROOT" ]] && command -v hyprpm >/dev/null 2>&1; then
  log "02-desktop: enabling hyprland plugins (hyprexpo + borders-plus-plus + hyprwinwrap)"
  hyprpm update --no-shallow 2>&1 | tail -3 || warn "hyprpm update failed; will retry on next Hyprland launch"
  for plugin in hyprland-plugins; do
    hyprpm add "https://github.com/hyprwm/${plugin}" 2>&1 | tail -3 || true
  done
  # Enable the specific plugins by name.
  for name in hyprexpo borders-plus-plus hyprwinwrap; do
    hyprpm enable "$name" 2>&1 | tail -3 || warn "hyprpm enable $name failed"
  done
fi

log "02-desktop: wiring Plymouth boot splash (installer mode only)"
# Rule 1: Plymouth is graphical; owned by this script. Theme assets
# (vin logo + blinking caret) are shipped by 05-branding (Rule 3).
# ISO airootfs already has plymouth wired: iso/profile/airootfs/etc/
# mkinitcpio.conf.d/archiso.conf lists the hook, and the boot menus
# add `quiet splash` to cmdline. Installer mode here just splices
# plymouth into the target /etc/mkinitcpio.conf.
if [[ -z "$VINOS_ROOT" ]] && [[ -f /etc/mkinitcpio.conf ]] \
   && ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
  _sudo sed -i -E 's/^(HOOKS=\(base udev)/\1 plymouth/' /etc/mkinitcpio.conf
  _sudo mkinitcpio -P || warn "mkinitcpio -P failed; splash may not render"
fi

log "02-desktop: writing /etc/greetd/config.toml (tuigreet → Hyprland)"
_conf="$(mktemp)"
cat > "$_conf" <<'TOML'
# vinOS greetd — installer-mode default: tuigreet prompts, launches Hyprland
# via uwsm (Universal Wayland Session Manager) so Hyprland >=0.44 doesn't
# emit the "started without start-hyprland" warning banner.
# The live ISO overrides this with an autologin variant at build time
# (iso/airootfs-overlay/etc/greetd/config.toml).
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'"
user = "greeter"
TOML
_dest="$(_rootpath /etc/greetd/config.toml)"
_sudo install -Dm 0644 "$_conf" "$_dest"
rm -f "$_conf"

# Rule 1: greetd is enabled here (the graphical module owns it), not by
# 04-services, so --skip 02 in installer mode leaves the box headless.
# Greetd's unit ships WantedBy=graphical.target + Alias=display-manager,
# so installer mode gets it right via plain systemctl enable. In
# VINOS_ROOT (ISO) mode we must build both symlinks manually and also
# switch default.target so the ISO reaches the greeter.
if [[ -n "$VINOS_ROOT" ]]; then
  _wants="$VINOS_ROOT/etc/systemd/system/graphical.target.wants"
  _sys="$VINOS_ROOT/etc/systemd/system"
  install -d "$_wants" "$_sys"
  ln -sfn /usr/lib/systemd/system/greetd.service "$_wants/greetd.service"
  ln -sfn /usr/lib/systemd/system/greetd.service "$_sys/display-manager.service"
  ln -sfn /usr/lib/systemd/system/graphical.target "$_sys/default.target"
  log "airootfs: enabled greetd (graphical.target.wants) + default.target=graphical"
else
  systemctl_enable greetd
fi

log "02-desktop: done"
