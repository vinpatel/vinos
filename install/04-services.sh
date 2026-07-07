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

if [[ -z "$VINOS_ROOT" ]]; then
  log "04-services: blacklisting floppy module (silences fd0 I/O probe error)"
  REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  _mp="$(_rootpath /etc/modprobe.d)"
  _sudo install -d -m 0755 "$_mp"
  _sudo install -Dm 0644 "$REPO/iso/profile/airootfs/etc/modprobe.d/vinos-no-floppy.conf" \
                         "$_mp/vinos-no-floppy.conf"
else
  # ISO airootfs already ships the file in-tree; installing to itself would
  # error with "same file" under `install`. Skip in VINOS_ROOT mode.
  log "04-services: floppy blacklist already staged in airootfs — skipping"
fi

# I7 — network stack: iwd + impala.
#  - Enable iwd so wifi is live on boot.
#  - Enable iwd's built-in DHCP so we don't need systemd-networkd for the
#    wifi path (main.conf: [General] EnableNetworkConfiguration=true).
#  - Enable systemd-resolved so DNS works when iwd owns DHCP.
#  - Mask systemd-networkd-wait-online so boot doesn't stall waiting for
#    a network that may need user-interactive wifi setup first.
log "04-services: configuring iwd (built-in DHCP) + resolved"
_iwd_conf="$(_rootpath /etc/iwd)"
_sudo install -d -m 0755 "$_iwd_conf"
_iwd_tmp="$(mktemp)"
printf '[General]\nEnableNetworkConfiguration=true\n[Network]\nNameResolvingService=systemd\n' > "$_iwd_tmp"
_sudo install -Dm 0644 "$_iwd_tmp" "$_iwd_conf/main.conf"
rm -f "$_iwd_tmp"

systemctl_enable iwd
systemctl_enable systemd-resolved

if [[ -z "$VINOS_ROOT" ]]; then
  sudo systemctl mask systemd-networkd-wait-online.service 2>/dev/null || \
    warn "could not mask systemd-networkd-wait-online (already masked or absent)"
else
  _sys="$(_rootpath /etc/systemd/system)"
  _sudo install -d -m 0755 "$_sys"
  _sudo ln -sfn /dev/null "$_sys/systemd-networkd-wait-online.service"
fi

# /etc/resolv.conf → resolved's stub. Some environments (Docker
# containers, LXC, some VM providers) bind-mount /etc/resolv.conf and
# ln will fail with EBUSY — that's harmless there because the host is
# already handling DNS, so warn + continue rather than aborting the
# whole 04-services run.
_resolv="$(_rootpath /etc/resolv.conf)"
if _sudo ln -sfn /run/systemd/resolve/stub-resolv.conf "$_resolv" 2>/dev/null; then
  log "04-services: /etc/resolv.conf → resolved stub"
else
  warn "could not symlink /etc/resolv.conf (bind mount?); leaving as-is"
fi

log "04-services: done"
