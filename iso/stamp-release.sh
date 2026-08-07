#!/usr/bin/env bash
# iso/stamp-release.sh — write /etc/vinos-release into the airootfs.
#
# Called from iso/build.sh INSIDE the archiso builder container after the
# install/* scripts finish assembling airootfs. Templating stays here so
# build.sh doesn't have to fight the docker-run heredoc-in-double-quotes
# escape treadmill.
#
# Inputs (env):
#   VINOS_VERSION   version string (e.g. 1.0.19)
#   AIROOT          absolute path to airootfs root (e.g. /vinos/iso/profile/airootfs)
set -euo pipefail

: "${VINOS_VERSION:?VINOS_VERSION required}"
: "${AIROOT:?AIROOT required}"

TEMPLATE="/vinos/iso/vinos-release.template"
[[ -f "$TEMPLATE" ]] || { echo "stamp-release: $TEMPLATE missing" >&2; exit 1; }

BUILD_ID="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$AIROOT/etc"
sed -e "s/@VERSION@/${VINOS_VERSION}/g" \
    -e "s/@BUILD_ID@/${BUILD_ID}/g" \
    "$TEMPLATE" > "$AIROOT/etc/vinos-release"

echo "stamp-release: $AIROOT/etc/vinos-release written (VERSION=$VINOS_VERSION BUILD_ID=$BUILD_ID)"
