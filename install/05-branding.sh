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
_sudo install -d -m 0755 "$SHARE" "$SHARE/bin" "$LOCAL_BIN"
_sudo rsync -a --delete "$REPO/assets/logo/"        "$SHARE/logo/"
_sudo install -Dm 0644 "$REPO/default/wallpaper.png" "$SHARE/wallpaper.png"
_sudo install -Dm 0644 "$REPO/VERSION"               "$SHARE/VERSION"

log "05-branding: installing vinos-* commands"
_sudo rsync -a "$REPO/bin/" "$SHARE/bin/"
_sudo chmod 0755 "$SHARE/bin/"vinos-*
for f in "$SHARE/bin/"vinos-*; do
  _sudo ln -sfn "/usr/share/vinos/bin/$(basename "$f")" "$LOCAL_BIN/$(basename "$f")"
done

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
