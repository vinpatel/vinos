#!/usr/bin/env bash
# 05-branding.sh — the ONLY identity script (Rule 3). Writes
# /etc/os-release, installs logo/wallpaper/VERSION under
# /usr/share/vinos, and symlinks vinos-* into /usr/local/bin.
# Idempotent (safe to re-run).
#
# When VINOS_ROOT is set (iso/build.sh), everything is written into that
# prefix instead of the live root — this stages branding into airootfs
# ahead of mkarchiso squashfs generation.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_not_root

VERSION="$(<"$REPO/VERSION")"
SHARE="$(_rootpath /usr/share/vinos)"
LOCAL_BIN="$(_rootpath /usr/local/bin)"
OS_REL="$(_rootpath /etc/os-release)"
OS_REL_BAK="$(_rootpath /etc/os-release.arch.bak)"

log "05-branding: installing shared assets under $SHARE"
_sudo install -d -m 0755 "$SHARE" "$SHARE/bin" "$SHARE/themes" "$SHARE/docs" \
                             "$SHARE/archinstall" "$LOCAL_BIN"
_sudo rsync -a --delete "$REPO/assets/logo/"  "$SHARE/logo/"
_sudo install -Dm 0644 "$REPO/VERSION"         "$SHARE/VERSION"
if [[ -f "$REPO/docs/KEYBINDINGS.txt" ]]; then
  _sudo install -Dm 0644 "$REPO/docs/KEYBINDINGS.txt" "$SHARE/docs/KEYBINDINGS.txt"
fi
# archinstall profile templates for vinos-install-disk (Path B).
if [[ -d "$REPO/iso/profiles/archinstall" ]]; then
  _sudo rsync -a --delete "$REPO/iso/profiles/archinstall/" "$SHARE/archinstall/"
fi

# I8: themes/ system. Each theme is a directory with theme.conf +
# wallpaper.png (+ optional hyprland.conf, waybar.css etc. as the
# system grows). /usr/share/vinos/wallpaper.png stays as a stable
# alias to the active theme's wallpaper — cosmetic switching later
# rewrites this symlink.
_sudo rsync -a --delete "$REPO/themes/" "$SHARE/themes/"

# Wallpapers can live in either themes/<name>/wallpaper.png (committed
# directly) or assets/wallpapers/<name>/wallpaper.png (source-of-truth
# handoff spot for new bitmaps). If the assets/ variant exists, it wins
# — this lets big PNGs live outside themes/ if we ever want to split
# them. Iterate every assets/wallpapers/<name>/ dir and drop its PNG
# into the corresponding themes/<name>/ under $SHARE.
if [[ -d "$REPO/assets/wallpapers" ]]; then
  for _wp in "$REPO/assets/wallpapers"/*/wallpaper.png; do
    [[ -f "$_wp" ]] || continue
    _tname="$(basename "$(dirname "$_wp")")"
    _sudo install -Dm 0644 "$_wp" "$SHARE/themes/$_tname/wallpaper.png"
  done
fi

# cosmos is the default first-boot vinOS theme (Milky Way over an alpine
# lake, by Pascal Debrunner via Unsplash — deep, atmospheric, showcases
# the agentic OS story). Overridable via VINOS_THEME= env before
# install.sh / iso/build.sh. Legacy theme names (v1: aurora/daybreak;
# v2.0.2: TitleCase Void; v2.0.3: lowercase void) auto-migrate to cosmos.
# All 10 vinOS themes live at /usr/share/omarchy/themes/ alongside
# Omarchy's, using lowercase-kebab names to match convention.
_active_theme="${VINOS_THEME:-cosmos}"
case "$_active_theme" in
  aurora|Aurora|Void|void|daybreak|polar-night) _active_theme="cosmos" ;;
esac
_active_theme="$(printf '%s' "$_active_theme" | tr 'A-Z' 'a-z')"
_sudo ln -sfn "/usr/share/omarchy/themes/${_active_theme}/wallpaper.png" "$SHARE/wallpaper.png"

log "05-branding: installing vinos-* commands"
_sudo rsync -a "$REPO/bin/" "$SHARE/bin/"
_sudo chmod 0755 "$SHARE/bin/"vinos-*
for f in "$SHARE/bin/"vinos-*; do
  _sudo ln -sfn "/usr/share/vinos/bin/$(basename "$f")" "$LOCAL_BIN/$(basename "$f")"
done

# libexec/ — helper scripts (python, etc.) that vinos-* commands invoke.
# Not on PATH. Currently: vinos-routine-run.py for the routine agent loop.
if [[ -d "$REPO/libexec" ]]; then
  log "05-branding: installing libexec/ → $SHARE/libexec/"
  _sudo rsync -a "$REPO/libexec/" "$SHARE/libexec/"
  _sudo chmod 0755 "$SHARE/libexec/"*
fi

# vinos-routine system defaults: shipped routine TOMLs. User routines live
# in ~/.vinos/routines/ and take precedence.
if [[ -d "$REPO/configs/vinos/routines" ]]; then
  _routines_dst="$(_rootpath /etc/vinos/routines)"
  log "05-branding: installing routines → /etc/vinos/routines"
  _sudo install -d -m 0755 "$_routines_dst"
  for _rt in "$REPO/configs/vinos/routines"/*.toml; do
    [[ -f "$_rt" ]] || continue
    _sudo install -Dm 0644 "$_rt" "$_routines_dst/$(basename "$_rt")"
  done
fi

# vinos-routine spec doc — referenced by systemd unit Documentation= field
# and the CLI's help output.
if [[ -f "$REPO/docs/v2/vinos-routine-spec.md" ]]; then
  _sudo install -Dm 0644 "$REPO/docs/v2/vinos-routine-spec.md" \
                         "$(_rootpath /usr/share/doc/vinos/vinos-routine-spec.md)"
fi

log "05-branding: installing vinos Plymouth theme"
# Rule 3: identity — the logo + caret splash is branding, so it lives
# here. 02-desktop.sh installs the plymouth package and wires the hook;
# this script owns the artwork and default-theme selection.
_theme_src="$REPO/themes/vinos"
_theme_dst="$(_rootpath /usr/share/plymouth/themes/vinos)"
_pcfg="$(_rootpath /etc/plymouth)"
_sudo install -d -m 0755 "$_theme_dst" "$_pcfg"
_sudo install -Dm 0644 "$_theme_src/vinos.plymouth" "$_theme_dst/vinos.plymouth"
_sudo install -Dm 0644 "$_theme_src/vinos.script"   "$_theme_dst/vinos.script"
for _f in "$_theme_src"/frame-*.png; do
  _sudo install -Dm 0644 "$_f" "$_theme_dst/$(basename "$_f")"
done
_ptmp="$(mktemp)"
printf '[Daemon]\nTheme=vinos\nShowDelay=0\n' > "$_ptmp"
_sudo install -Dm 0644 "$_ptmp" "$_pcfg/plymouthd.conf"
rm -f "$_ptmp"

log "05-branding: writing $OS_REL"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if [[ -f "$OS_REL" ]]; then
  # Installer mode: preserve every original key except vinOS overrides.
  [[ -f "$OS_REL_BAK" ]] || _sudo cp -a "$OS_REL" "$OS_REL_BAK"
  grep -Ev '^(NAME|PRETTY_NAME|ID|ID_LIKE|VERSION_ID)=' "$OS_REL_BAK" > "$tmp"
else
  # ISO airootfs staging: no os-release yet (pacstrap hasn't run). Write a
  # fresh file; pacstrap will not overwrite an existing airootfs override.
  : > "$tmp"
fi
{
  printf 'NAME="vinOS"\n'
  printf 'PRETTY_NAME="vinOS %s"\n' "$VERSION"
  printf 'ID=vinos\n'
  printf 'ID_LIKE=arch\n'
  printf 'VERSION_ID="%s"\n' "$VERSION"
} >> "$tmp"
_sudo install -m 0644 "$tmp" "$OS_REL"

log "05-branding: done — $OS_REL identifies vinOS $VERSION"
