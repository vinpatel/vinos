#!/usr/bin/env bash
# configs/vinos/security/install.sh
#
# Applied by the vinOS post-install hook after Omarchy's installer finishes.
# Idempotent — safe to re-run.
set -euo pipefail

log() { printf '\033[1;34m[vinos-security]\033[0m %s\n' "$*"; }

log "enabling ufw with deny-incoming allow-outgoing"
pacman -S --needed --noconfirm ufw
ufw --force default deny incoming
ufw --force default allow outgoing
ufw --force enable
systemctl enable ufw.service

log "sshd NOT enabled by default — drop-in already in place"
# The drop-in at /etc/ssh/sshd_config.d/00-vinos.conf ships with the ISO.
# We do not enable sshd.service — user must opt in.

log "faillock — Arch defaults already in place via /etc/security/faillock.conf"

log "installing linux-hardened as optional boot alternative"
pacman -S --needed --noconfirm linux-hardened linux-hardened-headers

log "security overlay applied"
