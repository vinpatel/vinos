#!/usr/bin/env bash
# iso/v2/build.sh — build a vinOS 2.0 live ISO.
#
# Usage: iso/v2/build.sh [--skip-omarchy-fetch] [--out <dir>]
#
# Layout:
#   iso/v2/profile/   — archiso profile (T2 kernel + boot fixes, seeded from v1)
#   configs/omarchy/  — vendored Omarchy source tree (goes into /root/omarchy)
#   configs/vinos/    — vinOS overlays (go into /usr/share/vinos/)
#
# The live ISO boots to a shell prompt (auto-login as root). User runs
#   `vinos-install`
# which drives Omarchy's installer against the target disk and then applies
# our security + mac + brand overlays.
#
# Output: iso/out/vinos-<version>-x86_64.iso. Never overwrites
# iso/out/vinos-1.1.0-x86_64.iso.
set -euo pipefail

V2_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$V2_DIR/../.." && pwd)"
OUT_DIR="$REPO/iso/out"
SKIP_OMARCHY_FETCH=0

die() { printf '\033[1;31m[iso-v2] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[iso-v2]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-omarchy-fetch) SKIP_OMARCHY_FETCH=1; shift ;;
    --out) [[ $# -ge 2 ]] || die "--out needs a path"; OUT_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

command -v docker >/dev/null || die "docker not found — install docker or run inside an archiso-capable environment"
[[ -f "$V2_DIR/VERSION" ]] || die "$V2_DIR/VERSION missing"
[[ -d "$REPO/configs/omarchy" ]] || die "configs/omarchy missing — run omarchy vendoring first"
[[ -d "$REPO/configs/vinos" ]] || die "configs/vinos missing — overlays not scaffolded"

VINOS_V2_VERSION="$(<"$V2_DIR/VERSION")"
mkdir -p "$OUT_DIR"

# Refuse to overwrite v1.1.0 — archival gold copy.
if [[ "$VINOS_V2_VERSION" == "1.1.0" ]]; then
  die "VINOS_V2_VERSION=1.1.0 is reserved for the archival gold copy — bump v2 VERSION"
fi
V1_GOLD="$OUT_DIR/vinos-1.1.0-x86_64.iso"
V2_TARGET="$OUT_DIR/vinos-${VINOS_V2_VERSION}-x86_64.iso"
if [[ "$V2_TARGET" == "$V1_GOLD" ]]; then
  die "refusing to overwrite v1.1.0 archival ISO"
fi

log "vinOS $VINOS_V2_VERSION → $V2_TARGET"
log "v1.1.0 archival preserved at $V1_GOLD"

# Fresh work profile so successive builds don't accumulate stale airootfs bits.
WORK_PROFILE="$(mktemp -d -t vinos-v2-profile.XXXXXX)"
trap 'rm -rf "$WORK_PROFILE"' EXIT

log "staging v2 profile into $WORK_PROFILE"
rsync -a "$V2_DIR/profile/" "$WORK_PROFILE/"

# Airootfs assembly — inline, deterministic. No install/*.sh helpers.
AIROOT="$WORK_PROFILE/airootfs"

log "layering Omarchy source → /root/omarchy"
mkdir -p "$AIROOT/root/omarchy"
rsync -a --exclude='.git' "$REPO/configs/omarchy/" "$AIROOT/root/omarchy/"

log "layering vinOS overlays → /usr/share/vinos/{security,mac,brand}"
for pack in security mac brand; do
  mkdir -p "$AIROOT/usr/share/vinos/$pack"
  rsync -a "$REPO/configs/vinos/$pack/" "$AIROOT/usr/share/vinos/$pack/"
done

log "layering T2 live-env airootfs bits (overwrites where they overlap)"
if [[ -d "$REPO/configs/vinos/t2/airootfs" ]]; then
  rsync -a "$REPO/configs/vinos/t2/airootfs/" "$AIROOT/"
fi

log "installing vinos-install wrapper"
mkdir -p "$AIROOT/usr/local/bin"
install -Dm755 "$V2_DIR/vinos-install" "$AIROOT/usr/local/bin/vinos-install"

log "writing /etc/vinos-release stamp"
mkdir -p "$AIROOT/etc"
cat > "$AIROOT/etc/vinos-release" <<EOF
NAME=vinOS
PRETTY_NAME="vinOS 2.0 Live"
ID=vinos
VERSION="$VINOS_V2_VERSION"
VERSION_ID=$VINOS_V2_VERSION
BUILD_ID=$(date -u +%Y%m%dT%H%M%SZ)
HOME_URL="https://vinos.computer/"
DOCUMENTATION_URL="https://vinos.computer/docs"
BUG_REPORT_URL="https://github.com/vinpatel/vinos/issues"
LIVE=1
EOF

log "docker builder image"
IMG="vinos-archiso-builder:latest"
IMG_STAMP="archiso rsync"
if ! docker image inspect "$IMG" >/dev/null 2>&1 \
   || ! docker inspect --format '{{ index .Config.Labels "vinos.stamp" }}' "$IMG" 2>/dev/null | grep -qxF "$IMG_STAMP"; then
  log "  → building image ($IMG_STAMP)"
  docker build -t "$IMG" -f - "$REPO" <<DOCKERFILE
FROM archlinux:latest
LABEL vinos.stamp="$IMG_STAMP"
RUN pacman -Sy --needed --noconfirm $IMG_STAMP && pacman -Scc --noconfirm
DOCKERFILE
fi

WORK_DIR="/tmp/vinos-v2-iso-work.$$"

log "invoking mkarchiso (this takes a while)"
docker run --rm --privileged \
  -v "$WORK_PROFILE":/vinos-v2-profile:ro \
  -v "$OUT_DIR":/out \
  -e VINOS_VERSION="$VINOS_V2_VERSION" \
  -e VINOS_V2_VERSION="$VINOS_V2_VERSION" \
  "$IMG" \
  bash -euo pipefail -c "
    cp -a /vinos-v2-profile /vinos-profile
    mkdir -p '$WORK_DIR'
    mkarchiso -v -w '$WORK_DIR' -o /out /vinos-profile
    ISO_FILE=\$(ls -1 /out/vinos-${VINOS_V2_VERSION}-x86_64.iso 2>/dev/null | head -1) || true
    if [[ -z \"\$ISO_FILE\" ]]; then
      echo 'mkarchiso produced no expected ISO' >&2
      ls /out
      exit 1
    fi
    # Preserve v1.1.0 hash line in sha256sums.txt; only replace the v2 line.
    ( cd /out
      touch sha256sums.txt
      grep -v \" vinos-${VINOS_V2_VERSION}-x86_64.iso\$\" sha256sums.txt > sha256sums.txt.tmp || true
      sha256sum \"\$(basename \"\$ISO_FILE\")\" >> sha256sums.txt.tmp
      mv sha256sums.txt.tmp sha256sums.txt
    )
    ls -lh \"\$ISO_FILE\"
  "

log "done → $V2_TARGET"
[[ -f "$V1_GOLD" ]] && log "v1.1.0 archival still present ($(stat -c%s "$V1_GOLD") bytes) ✓"
ls -1sh "$OUT_DIR"/*.iso 2>/dev/null || true
