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

pacman -Sy --needed --noconfirm base-devel git sudo

# makepkg refuses root; create a build user if missing.
if ! id builder >/dev/null 2>&1; then
  useradd -m -G wheel builder
  install -d -m 0750 /etc/sudoers.d
  echo "builder ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/99-builder
  chmod 0440 /etc/sudoers.d/99-builder
fi

install -d -o builder -g builder "$AUR_REPO_DIR"

# Register [vinos-aur] in pacman.conf BEFORE building anything. That
# way when a later package's makepkg -s wants a dep that's already
# been built (e.g. walker-bin needing elephant), pacman resolves it
# from the local repo. Idempotent — only appends the section once.
if ! grep -q '^\[vinos-aur\]' /etc/pacman.conf; then
  cat >> /etc/pacman.conf <<PACCONF

[vinos-aur]
SigLevel = Optional TrustAll
Server = file://$AUR_REPO_DIR
PACCONF
fi

# Seed the db so pacman -Sy can read it even before we build anything.
# repo-add needs at least one .pkg.tar.zst OR an empty db init.
if [[ ! -f "$AUR_REPO_DIR/${AUR_DB_NAME}.db.tar.gz" ]]; then
  ( cd "$AUR_REPO_DIR" && tar -czf "${AUR_DB_NAME}.db.tar.gz" --files-from /dev/null && \
    ln -sf "${AUR_DB_NAME}.db.tar.gz" "${AUR_DB_NAME}.db" )
fi
pacman -Sy --noconfirm >/dev/null 2>&1 || true

FAILED=()
for pkg in "${pkgs[@]}"; do
  if compgen -G "$AUR_REPO_DIR/${pkg}-*.pkg.tar.zst" > /dev/null; then
    log "$pkg — already built, skipping"
    continue
  fi
  log "$pkg — building via makepkg"
  workdir="$(mktemp -d)"
  chown -R builder:builder "$workdir"
  if ! sudo -u builder -H bash -euo pipefail -c "
    cd '$workdir'
    git clone --depth=1 https://aur.archlinux.org/${pkg}.git
    cd '${pkg}'
    # --skippgpcheck: sha256sums already validate file integrity;
    # bypassing the PGP web-of-trust step avoids a per-package
    # keyring bootstrap in the ephemeral builder container.
    makepkg -s --skippgpcheck --noconfirm --needed
    cp *.pkg.tar.zst '$AUR_REPO_DIR/'
  "; then
    log "$pkg — BUILD FAILED, continuing without it"
    FAILED+=("$pkg")
  else
    # Refresh the local repo so the NEXT package's makepkg -s can
    # resolve this one as a dep. Cheap; repo-add is fast.
    ( cd "$AUR_REPO_DIR" && repo-add -q -R "${AUR_DB_NAME}.db.tar.gz" ./"${pkg}"-*.pkg.tar.zst >/dev/null )
    pacman -Sy --noconfirm >/dev/null 2>&1 || true
  fi
  rm -rf "$workdir"
done

# Emit the failed list so build.sh can drop them from packages.x86_64
# before mkarchiso tries to pacstrap them and hard-fails.
printf '%s\n' "${FAILED[@]}" > "$ISO_DIR/aur.failed"

log "done — $(ls "$AUR_REPO_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l) package(s) in $AUR_REPO_DIR"
