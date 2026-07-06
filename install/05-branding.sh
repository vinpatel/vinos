#!/usr/bin/env bash
# 05-branding.sh — the ONLY identity script (Rule 3). Writes /etc/os-release,
# installs logo/wallpaper/VERSION under /usr/share/vinos, and symlinks the
# vinos-* commands into /usr/local/bin. Idempotent (safe to re-run).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_not_root

VERSION="$(<"$REPO/VERSION")"
SHARE=/usr/share/vinos

log "05-branding: installing shared assets under $SHARE"
sudo install -d -m 0755 "$SHARE" "$SHARE/bin"
sudo rsync -a --delete "$REPO/assets/logo/"       "$SHARE/logo/"
sudo install -Dm 0644  "$REPO/default/wallpaper.png" "$SHARE/wallpaper.png"
sudo install -Dm 0644  "$REPO/VERSION"               "$SHARE/VERSION"

log "05-branding: installing vinos-* commands"
sudo rsync -a "$REPO/bin/" "$SHARE/bin/"
sudo chmod 0755 "$SHARE/bin/"vinos-*
for f in "$SHARE/bin/"vinos-*; do
  sudo ln -sfn "$f" "/usr/local/bin/$(basename "$f")"
done

log "05-branding: writing /etc/os-release (backup once to .arch.bak)"
[[ -f /etc/os-release.arch.bak ]] || sudo cp -a /etc/os-release /etc/os-release.arch.bak
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
# Preserve every original key except those vinOS overrides.
grep -Ev '^(NAME|PRETTY_NAME|ID|ID_LIKE|VERSION_ID)=' /etc/os-release.arch.bak > "$tmp"
{
  printf 'NAME="vinOS"\n'
  printf 'PRETTY_NAME="vinOS %s"\n' "$VERSION"
  printf 'ID=vinos\n'
  printf 'ID_LIKE=arch\n'
  printf 'VERSION_ID="%s"\n' "$VERSION"
} >> "$tmp"
sudo install -m 0644 "$tmp" /etc/os-release

log "05-branding: done — /etc/os-release now identifies vinOS $VERSION"
