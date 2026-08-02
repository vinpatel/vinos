#!/usr/bin/env bash
# systemd-resolved was enabled + /etc/resolv.conf symlinked in 04-services.sh.
# This is a runtime idempotent re-assert (harmless on a correctly-set box).
set -euo pipefail
sudo systemctl enable --now systemd-resolved 2>/dev/null || true
if [[ ! -L /etc/resolv.conf ]] || \
   ! readlink /etc/resolv.conf | grep -q 'stub-resolv.conf'; then
  sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
fi
exit 0
