#!/usr/bin/env bash
# vinOS-health overlay — install/10-health.sh
# Persona: clinicians, researchers, health-adjacent workflows.
#   1) installs health-focused reference + comms tooling (calibre for
#      references, LibreOffice, Signal for encrypted messaging via the
#      comms bundle, keepassxc for password mgmt).
#   2) preselects bundles: office, comms, productivity, browser.
#      No AI bundle by default — patient-data privacy considerations.
set -euo pipefail
# shellcheck source=../../../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/common.sh"

require_not_root

log "10-health: installing health-persona packages"
install_pkg libreoffice-fresh evince calibre keepassxc \
            gnome-calculator ffmpeg

log "10-health: registering first-boot bundle preselections"
_fbd="$(_rootpath /etc/vinos/first-boot.d)"
_sudo install -d -m 0755 "$_fbd"
_h_tmp="$(mktemp)"
cat > "$_h_tmp" <<'LIST'
# vinOS-health: bundles the first-boot notifier should spotlight.
# AI intentionally omitted — patient-data privacy defaults.
office
comms
productivity
browser
LIST
_sudo install -Dm 0644 "$_h_tmp" "$_fbd/health.list"
rm -f "$_h_tmp"

log "10-health: done"
