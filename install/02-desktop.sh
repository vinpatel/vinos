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
install_pkg \
  hyprland waybar alacritty foot mako grim slurp swaybg wl-clipboard \
  xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-gnome \
  greetd greetd-tuigreet ttf-jetbrains-mono-nerd \
  noto-fonts noto-fonts-emoji noto-fonts-cjk \
  pipewire pipewire-pulse wireplumber \
  nautilus sushi plymouth \
  hypridle hyprlock hyprpicker hyprsunset swayosd satty \
  gtk4-layer-shell kvantum qt6ct \
  pamixer playerctl brightnessctl gum

log "02-desktop: installing AUR apps (UX-critical only)"
# I11 pivot: spotify/obsidian/1password/localsend live in bundles now.
# walker-bin: prebuilt walker (dmenu-style launcher, AUR-only).
# yaru-icon-theme: Ubuntu's icon set — clean, dark-friendly.
install_aur walker-bin yaru-icon-theme

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
# vinOS greetd — installer-mode default: tuigreet prompts, launches Hyprland.
# The live ISO overrides this with an autologin variant at build time
# (iso/airootfs-overlay/etc/greetd/config.toml).
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd Hyprland"
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
