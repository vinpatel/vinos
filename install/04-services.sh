#!/usr/bin/env bash
# 04-services.sh — enable systemd units. Headless (Rule 1): greetd only if
# 02-desktop actually installed it. UFW is warn-and-continue (nftables sync
# can fail on some Arch setups; never brick the run).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_not_root

log "04-services: configuring firewall"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw --force default deny incoming  || warn "ufw default deny incoming failed"
  sudo ufw --force default allow outgoing || warn "ufw default allow outgoing failed"
  if [[ "${VINOS_ENABLE_SSH:-0}" == "1" ]]; then
    sudo ufw allow ssh || warn "ufw allow ssh failed"
  fi
  sudo ufw --force enable || warn "ufw enable failed (nftables sync?); continuing"
  systemctl_enable ufw
else
  warn "ufw not installed; skipping firewall config"
fi

if [[ "${VINOS_ENABLE_SSH:-0}" == "1" ]]; then
  log "04-services: sshd enable requested (VINOS_ENABLE_SSH=1)"
  systemctl_enable sshd
fi

# Rule 1: only enable greetd if the desktop module installed it.
if command -v greetd >/dev/null 2>&1; then
  log "04-services: greetd detected — enabling"
  systemctl_enable greetd
else
  log "04-services: greetd not installed — headless mode, skipping"
fi

log "04-services: done"
