#!/usr/bin/env bash
# configs/vinos/mac/install.sh
#
# Applied by the vinOS post-install hook after Omarchy's installer finishes.
# Idempotent.
set -euo pipefail

log() { printf '\033[1;34m[vinos-mac]\033[0m %s\n' "$*"; }

log "installing kanata + grim + slurp + wl-clipboard"
pacman -S --needed --noconfirm kanata grim slurp wl-clipboard

log "placing kanata config at /etc/vinos/kanata/vinos.kbd"
install -Dm644 /usr/share/vinos/mac/kanata/vinos.kbd /etc/vinos/kanata/vinos.kbd

log "enabling per-user kanata service"
# Enable for every human user (uid >= 1000, has a home dir, has a shell)
while IFS=: read -r name _ uid _ _ home shell; do
    [[ $uid -ge 1000 ]] || continue
    [[ $uid -lt 65534 ]] || continue
    [[ -d $home ]] || continue
    [[ $shell != */nologin ]] || continue
    log " → user $name"
    sudo -u "$name" systemctl --user enable vinos-kanata.service 2>/dev/null || true
done < /etc/passwd

log "sourcing Hyprland Mac fragment"
HYPR_CONF="/etc/skel/.config/hypr/hyprland.conf"
if [[ -f "$HYPR_CONF" ]] && ! grep -q "vinos-mac.conf" "$HYPR_CONF"; then
    install -Dm644 /usr/share/vinos/mac/hypr/vinos-mac.conf /etc/skel/.config/hypr/vinos-mac.conf
    echo "source = ~/.config/hypr/vinos-mac.conf" >> "$HYPR_CONF"
fi

log "Mac muscle-memory overlay applied"
