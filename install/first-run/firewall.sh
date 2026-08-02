#!/usr/bin/env bash
# ufw is already enabled + configured in 04-services.sh at install time.
# This first-run pass only re-asserts state on the running system in case
# nftables sync was skipped during the offline chroot.
set -euo pipefail
if ! command -v ufw >/dev/null 2>&1; then exit 0; fi
sudo ufw --force default deny incoming  || true
sudo ufw --force default allow outgoing || true
sudo ufw --force enable 2>/dev/null || true
exit 0
