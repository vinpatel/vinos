#!/usr/bin/env bash
# 03-configs.sh — Omarchy-fork desktop config deployment.
#
# vinOS is an upstream-tracked fork of Omarchy (git subtree at omarchy/).
# This script deploys the desktop config chain in the correct order:
#
#   1. Omarchy foundation (from omarchy/ subtree)
#      - omarchy/config/*  → /etc/skel/.config/*   (per-user configs — polished defaults)
#      - omarchy/default/* → /usr/share/omarchy/default/*  (system defaults — Omarchy binaries look here)
#      - omarchy/bin/*     → /usr/share/omarchy/bin/* + /usr/local/bin/ symlinks
#      - omarchy/themes/*  → /usr/share/omarchy/themes/*
#
#   2. vinOS overlay (from configs/vinos/) — layered on top of Omarchy
#      - configs/vinos/default/waybar/*     → /etc/skel/.config/waybar/  (AI pill + brand accent — overrides Omarchy)
#      - configs/vinos/default/mako/config  → /etc/skel/.config/mako/config  (routine channel)
#      - configs/vinos/default/vinos/       → /usr/share/vinos/default/vinos/  (vinos-menu entries)
#      - configs/vinos/brand/themes/*       → /usr/share/omarchy/themes/<name>/ (vinOS themes coexist with Omarchy's)
#
# Attribution: Omarchy © David Heinemeier Hansson, MIT. vinOS overlay © Vin Patel, MIT.
# See NOTICES.md at repo root.
#
# Runs under VINOS_ROOT (ISO build) via _rootpath — all paths respect the build prefix.

set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OMARCHY_SRC="$REPO/omarchy"
VINOS_SRC="$REPO/configs/vinos"

[[ -d "$OMARCHY_SRC" ]] || {
  log "03-configs: FATAL — $OMARCHY_SRC missing. Run: git subtree add --prefix=omarchy https://github.com/basecamp/omarchy master --squash"
  exit 1
}
[[ -d "$VINOS_SRC" ]] || {
  log "03-configs: FATAL — $VINOS_SRC missing"
  exit 1
}

# ────────────────────────────────────────────────────────────────────
# Helper: rsync a subtree into target root (honors VINOS_ROOT prefix).
# ────────────────────────────────────────────────────────────────────
_deploy_dir() {
  local src="$1" prefix="$2"
  [[ -d "$src" ]] || return 0
  local dest; dest="$(_rootpath "$prefix")"
  _sudo install -d -m 0755 "$dest"
  log "03-configs: $(basename "$src")/ → $prefix/"
  _sudo rsync -a --exclude='.git' "$src/" "$dest/"
}

_deploy_file() {
  local src="$1" dest_path="$2"
  [[ -f "$src" ]] || return 0
  local dest; dest="$(_rootpath "$dest_path")"
  _sudo install -Dm 0644 "$src" "$dest"
}

# ════════════════════════════════════════════════════════════════════
# LAYER 1 — Omarchy foundation
# ════════════════════════════════════════════════════════════════════

log "03-configs: [Layer 1] deploying Omarchy foundation from omarchy/ subtree"

# 1a. Per-user configs → /etc/skel/.config/
#     Live user is created from /etc/skel, so this gives them the full
#     Omarchy desktop as-shipped by DHH.
_deploy_dir "$OMARCHY_SRC/config"                /etc/skel/.config

# 1b. System defaults → /usr/share/omarchy/default/
#     Omarchy binaries (omarchy-menu, omarchy-theme-set, etc.) look
#     here for defaults via $OMARCHY_PATH.
_deploy_dir "$OMARCHY_SRC/default"               /usr/share/omarchy/default

# 1c. Themes → /usr/share/omarchy/themes/
_deploy_dir "$OMARCHY_SRC/themes"                /usr/share/omarchy/themes

# 1d. Omarchy binaries → /usr/share/omarchy/bin/ + /usr/local/bin/ symlinks
_share_bin="$(_rootpath /usr/share/omarchy/bin)"
_local_bin="$(_rootpath /usr/local/bin)"
_sudo install -d -m 0755 "$_share_bin" "$_local_bin"
if [[ -d "$OMARCHY_SRC/bin" ]]; then
  log "03-configs: omarchy/bin/* → /usr/share/omarchy/bin/ + /usr/local/bin/ symlinks"
  _sudo rsync -a "$OMARCHY_SRC/bin/" "$_share_bin/"
  _sudo chmod 0755 "$_share_bin"/omarchy-*
  for _b in "$OMARCHY_SRC/bin/"omarchy-*; do
    [[ -f "$_b" ]] || continue
    _name="$(basename "$_b")"
    _sudo ln -sfn "/usr/share/omarchy/bin/$_name" "$_local_bin/$_name"
  done
  unset _b _name
fi

# 1e. Skip omarchy/applications/* — mix of legit .desktop entries and PWA
#     junk (Basecamp/ChatGPT/Discord/HEY/etc). The pacman packages install
#     their own .desktop files; deploying Omarchy's would collide.
#     Per feedback_clean_vinos_brand: no third-party PWA junk in menu.

# 1f. Migrations → /usr/share/omarchy/migrations/
_deploy_dir "$OMARCHY_SRC/migrations"            /usr/share/omarchy/migrations

# 1g. OMARCHY_PATH env → /etc/environment.d/ so all sessions see it
_env_d="$(_rootpath /etc/environment.d)"
_sudo install -d -m 0755 "$_env_d"
echo 'OMARCHY_PATH=/usr/share/omarchy' | _sudo tee "$_env_d/10-omarchy-path.conf" >/dev/null

# ════════════════════════════════════════════════════════════════════
# LAYER 2 — vinOS overlay (on top of Omarchy)
# ════════════════════════════════════════════════════════════════════

log "03-configs: [Layer 2] applying vinOS overlay from configs/vinos/"

# 2a. Waybar override — the AI status pill + brand accent #33ccff.
#     Overrides Omarchy's default waybar so vinOS chrome ships instead.
_deploy_dir "$VINOS_SRC/default/waybar"          /etc/skel/.config/waybar

# 2b. Mako override — vinOS routines notification channel.
if [[ -f "$VINOS_SRC/default/mako/config" ]]; then
  _deploy_file "$VINOS_SRC/default/mako/config"  /etc/skel/.config/mako/config
fi

# 2c. vinos-menu entries → /usr/share/vinos/default/vinos/
_deploy_dir "$VINOS_SRC/default/vinos"           /usr/share/vinos/default/vinos

# 2d. vinOS themes coexist with Omarchy's under /usr/share/omarchy/themes/
#     (lowercase-kebab names match Omarchy convention — see 05-branding.sh).
if [[ -d "$VINOS_SRC/brand/themes" ]]; then
  _themes_dest="$(_rootpath /usr/share/omarchy/themes)"
  _sudo install -d -m 0755 "$_themes_dest"
  for _t in "$VINOS_SRC/brand/themes"/*/; do
    [[ -d "$_t" ]] || continue
    _tname="$(basename "$_t" | tr 'A-Z' 'a-z')"
    log "03-configs: vinOS theme $_tname → /usr/share/omarchy/themes/$_tname/"
    _sudo rsync -a --exclude='.git' --exclude='build-themes.sh' "$_t" "$_themes_dest/$_tname/"
  done
  unset _t _tname _themes_dest
fi

# 2e. Attribution — ship NOTICES.md + CREDITS.md alongside the binaries.
_doc="$(_rootpath /usr/share/doc/vinos)"
_sudo install -d -m 0755 "$_doc"
[[ -f "$REPO/NOTICES.md" ]] && _sudo install -Dm 0644 "$REPO/NOTICES.md" "$_doc/NOTICES.md"

# ────────────────────────────────────────────────────────────────────
# Migration pre-stamping — mark every shipped Omarchy migration as
# "done" so the live user's first login doesn't try to run them all.
# ────────────────────────────────────────────────────────────────────
_skel_mig="$(_rootpath /etc/skel/.local/state/omarchy/migrations)"
if [[ -d "$OMARCHY_SRC/migrations" ]]; then
  _sudo install -d -m 0755 "$_skel_mig"
  log "03-configs: pre-stamping $(ls "$OMARCHY_SRC/migrations" | wc -l) Omarchy migrations as done"
  for _m in "$OMARCHY_SRC/migrations"/*; do
    [[ -f "$_m" ]] || continue
    _sudo touch "$_skel_mig/$(basename "$_m")"
  done
  unset _m
fi

# ────────────────────────────────────────────────────────────────────
# Active theme symlink — /usr/share/vinos/wallpaper.png points to
# the active theme's wallpaper. Cosmos is the default. Overridable via
# VINOS_THEME= env before install.sh / iso/build.sh.
# ────────────────────────────────────────────────────────────────────
_active_theme="${VINOS_THEME:-cosmos}"
_active_theme="$(printf '%s' "$_active_theme" | tr 'A-Z' 'a-z')"
_share="$(_rootpath /usr/share/vinos)"
_sudo install -d -m 0755 "$_share"
_sudo ln -sfn "/usr/share/omarchy/themes/${_active_theme}/wallpaper.png" "$_share/wallpaper.png"

log "03-configs: done — Omarchy foundation + vinOS overlay deployed"
