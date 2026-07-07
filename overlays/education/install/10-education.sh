#!/usr/bin/env bash
# vinOS-edu overlay — install/10-education.sh
# Per Rule 2, forks own 10-99. This script:
#   1) installs education-specific packages (GCompris, Scratch, Kolibri,
#      Kdenlive-lite, LibreOffice-fresh, evince, calibre)
#   2) preselects the vinOS bundles most edu deployments want (office,
#      media for lesson playback, browser for web resources)
#   3) writes /etc/vinos/first-boot.d/edu.list so vinos-install-once
#      knows which bundles to spotlight in the first-boot notification.
set -euo pipefail
# shellcheck source=../../../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/common.sh"

require_not_root

log "10-education: installing edu packages"
install_pkg gcompris-qt libreoffice-fresh evince calibre \
            inkscape pinta \
            python python-pip \
            gnome-calculator kdenlive

install_aur scratch kolibri || warn "some AUR edu packages unavailable — skipping"

log "10-education: registering first-boot bundle preselections"
_fbd="$(_rootpath /etc/vinos/first-boot.d)"
_sudo install -d -m 0755 "$_fbd"
_edu_tmp="$(mktemp)"
cat > "$_edu_tmp" <<'LIST'
# vinOS-edu: bundles the first-boot notifier should spotlight.
office
browser
media
LIST
_sudo install -Dm 0644 "$_edu_tmp" "$_fbd/edu.list"
rm -f "$_edu_tmp"

log "10-education: done"
