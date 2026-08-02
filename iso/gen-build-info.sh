#!/usr/bin/env bash
# gen-build-info.sh — populate /etc/vinos/build-info at ISO build time
# with the exact upstream versions this build was cut against.
#
# Called from iso/build.sh once the packages.x86_64 is finalized.
#
# Output goes into the airootfs-overlay so it lands at /etc/vinos/build-info
# on every installed vinOS system. Machine-readable (KEY=value) so
# `vinos-doctor` and support tickets can quote it directly.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO/iso/airootfs-overlay/etc/vinos/build-info"

mkdir -p "$(dirname "$DEST")"

VINOS_VERSION="$(<"$REPO/VERSION" tr -d '[:space:]')"
OMARCHY_VERSION="$(cat "$REPO/omarchy/version" 2>/dev/null | tr -d '[:space:]' || echo unknown)"
BUILD_DATE="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
BUILD_HOST="$(hostname -s 2>/dev/null || echo unknown)"
GIT_SHA="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
ARCH_MIRROR_TIMESTAMP="$(date -u '+%Y-%m-%d')"

# Kernel candidates we ship (pinned by packages.x86_64). Just record the
# NAMES so we don't have to re-parse pacman resolution.
KERNELS="linux-cachyos linux-hardened linux-t2"

cat > "$DEST" <<EOF
# vinOS build info — machine-readable upstream pinning
# Generated $BUILD_DATE by iso/gen-build-info.sh

VINOS_VERSION=$VINOS_VERSION
VINOS_GIT_SHA=$GIT_SHA
BUILD_DATE=$BUILD_DATE
BUILD_HOST=$BUILD_HOST

# Upstream — desktop layer
OMARCHY_VERSION=$OMARCHY_VERSION
OMARCHY_UPSTREAM=https://github.com/basecamp/omarchy

# Upstream — base OS
ARCH_SNAPSHOT=$ARCH_MIRROR_TIMESTAMP
ARCH_UPSTREAM=https://archlinux.org

# Kernels shipped in this ISO (see /boot/loader/entries/*.conf for defaults)
KERNELS="$KERNELS"

# Fork model — vinOS is an official upstream-tracked fork of Omarchy.
# Refresh Omarchy in the source tree with:
#   git subtree pull --prefix=omarchy https://github.com/basecamp/omarchy master --squash
EOF

echo "[gen-build-info] wrote $DEST"
