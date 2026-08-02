#!/usr/bin/env bash
# Remove the temporary reboot-without-password sudoers drop-in that the
# installer created to bounce the box mid-install. Safe to no-op if absent.
set -euo pipefail
sudo rm -f /etc/sudoers.d/vinos-reboot 2>/dev/null || true
exit 0
