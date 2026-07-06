#!/usr/bin/env bash
# 01-base.sh — core packages + yay-bin AUR helper. Headless (Rule 1). Idempotent.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_not_root

log "01-base: installing core packages"
install_pkg base-devel git curl wget rsync openssh ufw fastfetch btop \
            unzip man-db bash-completion

if [[ -n "$VINOS_ROOT" ]]; then
  log "01-base: VINOS_ROOT mode — yay bootstrap deferred (ISO uses local vinos-aur repo)"
  exit 0
fi

if command -v yay >/dev/null 2>&1; then
  log "01-base: yay already present"
  exit 0
fi

log "01-base: bootstrapping yay-bin from AUR"
tmp="$(mktemp -d -t vinos-yay.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
( cd "$tmp/yay-bin" && makepkg -si --noconfirm --needed )
log "01-base: yay installed"
