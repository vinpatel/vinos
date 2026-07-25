#!/usr/bin/env bash
# configs/vinos/brand/install.sh
#
# Post-install branding pass. Applied after Omarchy's installer finishes.
# Idempotent.
set -euo pipefail

log() { printf '\033[1;34m[vinos-brand]\033[0m %s\n' "$*"; }

BRAND_SRC=/usr/share/vinos/brand

log "installing open-source fonts"
mapfile -t fonts < <(grep -v '^\s*#' "$BRAND_SRC/fonts.list" | grep -v '^\s*$')
if [[ ${#fonts[@]} -gt 0 ]]; then
    pacman -S --needed --noconfirm "${fonts[@]}"
fi

log "placing default wallpaper"
install -Dm644 "$BRAND_SRC/wallpaper/vinos-default.svg" \
    /usr/share/backgrounds/vinos/default.svg

log "pointing Hyprland/hyprpaper at the vinOS wallpaper for new users"
HYPRPAPER_SKEL=/etc/skel/.config/hypr/hyprpaper.conf
if [[ -f "$HYPRPAPER_SKEL" ]]; then
    # Overwrite the preload/wallpaper lines to point at our SVG.
    sed -i \
        -e "s|^preload = .*|preload = /usr/share/backgrounds/vinos/default.svg|" \
        -e "s|^wallpaper = .*|wallpaper = ,/usr/share/backgrounds/vinos/default.svg|" \
        "$HYPRPAPER_SKEL"
fi

log "brand overlay applied"
