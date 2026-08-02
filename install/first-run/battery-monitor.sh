#!/usr/bin/env bash
# Enable upower for waybar battery indicator + power-profiles-daemon
# (both packages already shipped and enabled in 04-services.sh).
# Idempotent — safe to re-run.
set -euo pipefail
if [[ ! -d /sys/class/power_supply ]] || ! ls /sys/class/power_supply | grep -qE "BAT|bat"; then
  # Desktop with no battery — nothing to do
  exit 0
fi
if command -v upower >/dev/null 2>&1; then
  sudo systemctl enable --now upower.service 2>/dev/null || true
fi
if command -v powerprofilesctl >/dev/null 2>&1; then
  sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
fi
exit 0
