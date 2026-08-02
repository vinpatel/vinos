#!/usr/bin/env bash
# swayosd — on-screen volume/brightness/capslock indicator.
# Enable the user-scope systemd unit if the package landed.
set -euo pipefail
if ! command -v swayosd-server >/dev/null 2>&1; then exit 0; fi
systemctl --user enable --now swayosd-libinput-backend.service 2>/dev/null || true
systemctl --user enable --now swayosd.service                  2>/dev/null || true
exit 0
