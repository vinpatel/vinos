#!/usr/bin/env bash
# iso/aur-build.sh — build every AUR package listed in iso/aur.list into
# iso/aurrepo/, then repo-add to vinos-aur.db.tar.gz. Runs inside the
# archiso builder container (needs base-devel + git + a build user;
# makepkg refuses to run as root).
#
# Idempotent: skips packages whose *.pkg.tar.zst already exists in
# aurrepo/. No-op when aur.list is empty (I3 default — no AUR deps).
#
# build.sh appends [vinos-aur] to pacman.conf when this script produces
# any packages, so mkarchiso can pacstrap them like normal.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ISO_DIR/.." && pwd)"
AUR_LIST="$ISO_DIR/aur.list"
AUR_REPO_DIR="$ISO_DIR/aurrepo"
AUR_DB_NAME="vinos-aur"

log() { printf '\033[1;34m[aur-build]\033[0m %s\n' "$*"; }

# Filter blank/comment lines. Empty list -> no work.
mapfile -t pkgs < <(grep -Ev '^\s*(#|$)' "$AUR_LIST" 2>/dev/null || true)
if [[ ${#pkgs[@]} -eq 0 ]]; then
  log "aur.list is empty — nothing to build"
  exit 0
fi

# makepkg refuses root; create a build user if missing.
if ! id builder >/dev/null 2>&1; then
  useradd -m -G wheel builder
  echo "builder ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/99-builder
fi

pacman -Sy --needed --noconfirm base-devel git

install -d -o builder -g builder "$AUR_REPO_DIR"

for pkg in "${pkgs[@]}"; do
  if compgen -G "$AUR_REPO_DIR/${pkg}-*.pkg.tar.zst" > /dev/null; then
    log "$pkg — already built, skipping"
    continue
  fi
  log "$pkg — building via makepkg"
  workdir="$(mktemp -d)"
  chown -R builder:builder "$workdir"
  sudo -u builder -H bash -euo pipefail -c "
    cd '$workdir'
    git clone --depth=1 https://aur.archlinux.org/${pkg}.git
    cd '${pkg}'
    makepkg -s --noconfirm --needed
    cp *.pkg.tar.zst '$AUR_REPO_DIR/'
  "
  rm -rf "$workdir"
done

log "repo-add ${AUR_DB_NAME}.db.tar.gz"
( cd "$AUR_REPO_DIR" && repo-add "${AUR_DB_NAME}.db.tar.gz" ./*.pkg.tar.zst )

log "done — $(ls "$AUR_REPO_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l) package(s) in $AUR_REPO_DIR"
