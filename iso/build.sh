#!/usr/bin/env bash
# iso/build.sh — build a vinOS live ISO from the current repo state.
#
# Usage: iso/build.sh [--overlay <path>]... [--out <dir>] [--skip-aur]
#                     [--no-drift-check]
#
# Runs mkarchiso inside `docker run --privileged archlinux:latest` so the
# host stays untouched (mkarchiso needs loop devices + chroot). Emits
# out/vinos-<VERSION>-x86_64.iso and out/sha256sums.txt.
#
# I1 scope: base profile boots to multi-user.target. Overlay/build-time
# assembly of airootfs branding lands in I2. --skip-aur is accepted now
# and becomes meaningful once AUR packages appear in iso/aur.list.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ISO_DIR/.." && pwd)"
OUT_DIR="$ISO_DIR/out"
OVERLAYS=()
SKIP_AUR=0
DRIFT_CHECK=1

die() { printf '\033[1;31m[iso-build] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[iso-build]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --overlay) [[ $# -ge 2 ]] || die "--overlay needs a path"; OVERLAYS+=("$2"); shift 2 ;;
    --out)     [[ $# -ge 2 ]] || die "--out needs a path";     OUT_DIR="$2"; shift 2 ;;
    --skip-aur) SKIP_AUR=1; shift ;;
    --no-drift-check) DRIFT_CHECK=0; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

command -v docker >/dev/null || die "docker not found — install docker or run inside an archiso-capable environment"
[[ -f "$REPO/VERSION" ]] || die "$REPO/VERSION missing"
VINOS_VERSION="$(<"$REPO/VERSION")"
mkdir -p "$OUT_DIR"

log "regenerating packages.x86_64 (drift check)"
tmp_old="$(mktemp)"; cp "$ISO_DIR/profile/packages.x86_64" "$tmp_old" 2>/dev/null || : > "$tmp_old"
"$ISO_DIR/gen-packages.sh"
if (( DRIFT_CHECK )); then
  if ! diff -q "$tmp_old" "$ISO_DIR/profile/packages.x86_64" >/dev/null 2>&1; then
    log "packages.x86_64 changed — commit the regenerated file before building for release"
    diff -u "$tmp_old" "$ISO_DIR/profile/packages.x86_64" | head -40 || true
    # Not fatal for local dev; use --no-drift-check to silence.
  fi
fi
rm -f "$tmp_old"

if (( SKIP_AUR )); then log "skip-aur requested"; fi
if [[ ${#OVERLAYS[@]} -gt 0 ]]; then
  log "overlays requested (deferred to I2 airootfs assembly): ${OVERLAYS[*]}"
fi

log "building vinOS $VINOS_VERSION via docker (privileged, KVM optional)"
WORK_DIR="/tmp/vinos-iso-work.$$"

# Use a version-suffixed image tag so successive builds share the archiso
# install layer instead of re-downloading it every run.
IMG="vinos-archiso-builder:latest"
# Rebuild the image when this stamp changes so runtime deps stay in sync.
IMG_STAMP="archiso rsync"
if ! docker image inspect "$IMG" >/dev/null 2>&1 \
   || ! docker inspect --format '{{ index .Config.Labels "vinos.stamp" }}' "$IMG" 2>/dev/null | grep -qxF "$IMG_STAMP"; then
  log "building archiso builder image ($IMG_STAMP)"
  docker build -t "$IMG" -f - "$REPO" <<DOCKERFILE
FROM archlinux:latest
LABEL vinos.stamp="$IMG_STAMP"
RUN pacman -Sy --needed --noconfirm $IMG_STAMP && pacman -Scc --noconfirm
DOCKERFILE
fi

# Persist AUR build outputs across runs. Without this the container is
# ephemeral and every rebuild re-does the ~5 min of makepkg work.
AUR_CACHE="$ISO_DIR/.aur-cache"
mkdir -p "$AUR_CACHE"

docker run --rm --privileged \
  -v "$REPO":/vinos-src:ro \
  -v "$OUT_DIR":/out \
  -v "$AUR_CACHE":/vinos-aur-cache \
  -e VINOS_VERSION="$VINOS_VERSION" \
  "$IMG" \
  bash -euo pipefail -c "
    cp -a /vinos-src /vinos
    cd /vinos
    export VINOS_VERSION='$VINOS_VERSION'

    echo '== regenerating packages.x86_64 =='
    bash iso/gen-packages.sh

    echo '== assembling airootfs (VINOS_ROOT mode: 03/05/02/04) =='
    AIROOT=/vinos/iso/profile/airootfs
    export VINOS_ROOT=\$AIROOT
    bash install/03-configs.sh
    bash install/05-branding.sh
    bash install/02-desktop.sh
    bash install/04-services.sh
    unset VINOS_ROOT

    echo '== applying live-only airootfs overlay =='
    rsync -a /vinos/iso/airootfs-overlay/ \$AIROOT/

    # Build local [vinos-aur] repo when aur.list is non-empty and we
    # weren't asked to skip. Empty aur.list -> no-op (I3 default).
    # Seed aurrepo from host cache mount so already-built pkgs skip.
    if [[ -d /vinos-aur-cache ]]; then
      mkdir -p /vinos/iso/aurrepo
      cp -a /vinos-aur-cache/. /vinos/iso/aurrepo/ 2>/dev/null || true
    fi
    if [[ '$SKIP_AUR' -ne 1 ]] && grep -qEv '^\s*(#|$)' /vinos/iso/aur.list 2>/dev/null; then
      echo '== building [vinos-aur] via iso/aur-build.sh =='
      bash /vinos/iso/aur-build.sh
      # Push freshly built pkgs back to host cache for next run.
      cp -a /vinos/iso/aurrepo/. /vinos-aur-cache/ 2>/dev/null || true
      cat >> /vinos/iso/profile/pacman.conf <<PACCONF

[vinos-aur]
SigLevel = Optional TrustAll
Server = file:///vinos/iso/aurrepo
PACCONF
      # If aur-build.sh gave up on any packages, strip them from
      # packages.x86_64 so mkarchiso doesn't hard-fail chasing them.
      if [[ -s /vinos/iso/aur.failed ]]; then
        while read -r fp; do
          [[ -n \"\$fp\" ]] || continue
          echo \"== dropping failed AUR pkg from packages.x86_64: \$fp\"
          sed -i \"/^\${fp}\$/d\" /vinos/iso/profile/packages.x86_64
        done < /vinos/iso/aur.failed
      fi
    fi

    # Ensure staged config/branding files are root-owned before squashfs.
    chown -R root:root \$AIROOT/etc \$AIROOT/usr/share/vinos \$AIROOT/usr/local/bin 2>/dev/null || true

    mkdir -p '$WORK_DIR'
    mkarchiso -v -w '$WORK_DIR' -o /out iso/profile
    ISO_FILE=\$(ls -1 /out/vinos-*.iso 2>/dev/null | head -1) || true
    if [[ -z \"\$ISO_FILE\" ]]; then
      echo 'mkarchiso produced no vinos-*.iso' >&2
      ls /out || true
      exit 1
    fi
    ( cd /out && sha256sum \"\$(basename \"\$ISO_FILE\")\" > sha256sums.txt )
    echo \"ISO: \$ISO_FILE\"
    ls -lh \"\$ISO_FILE\"
  "

log "done → $OUT_DIR"
ls -1sh "$OUT_DIR"/*.iso "$OUT_DIR"/sha256sums.txt 2>/dev/null || true
