#!/usr/bin/env bash
# 04-services.sh — enable systemd units. Rule 1: greetd is owned by
# 02-desktop; this script must succeed on a headless system. UFW gets
# warn-and-continue (nftables sync fails on some Arch setups; never
# brick the run). In VINOS_ROOT (ISO build) mode, runtime ufw commands
# are skipped — only the enable-symlink is written into airootfs.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_not_root

if [[ -z "$VINOS_ROOT" ]]; then
  log "04-services: configuring firewall"
  if command -v ufw >/dev/null 2>&1; then
    sudo ufw --force default deny incoming  || warn "ufw default deny incoming failed"
    sudo ufw --force default allow outgoing || warn "ufw default allow outgoing failed"
    if [[ "${VINOS_ENABLE_SSH:-0}" == "1" ]]; then
      sudo ufw allow ssh || warn "ufw allow ssh failed"
    fi
    sudo ufw --force enable || warn "ufw enable failed (nftables sync?); continuing"
  else
    warn "ufw not installed; skipping firewall config"
  fi
else
  log "04-services: VINOS_ROOT mode — deferring ufw runtime config to first boot"
fi

# ufw.service enable works in both modes via systemctl_enable's routing.
systemctl_enable ufw

if [[ "${VINOS_ENABLE_SSH:-0}" == "1" ]]; then
  log "04-services: sshd enable requested (VINOS_ENABLE_SSH=1)"
  systemctl_enable sshd
fi

log "04-services: done"
