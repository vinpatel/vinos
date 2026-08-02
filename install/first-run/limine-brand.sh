#!/usr/bin/env bash
# limine-brand.sh — first-run: replace Omarchy's Limine branding with
# vinOS branding on the installed system.
#
# Runs AFTER Omarchy's limine-snapper.sh has laid down the bootloader.
# We just swap the two config files and re-run limine-update.
#
# Idempotent: safe to re-run. No-op if limine not installed.
set -euo pipefail

if ! command -v limine >/dev/null 2>&1; then
  echo "[limine-brand] limine not installed — skipping" >&2
  exit 0
fi

REPO_LIMINE="${VINOS_PATH:-$HOME/.local/share/vinos}/configs/vinos/limine"

if [[ ! -f "$REPO_LIMINE/limine.conf" ]] || [[ ! -f "$REPO_LIMINE/default.conf" ]]; then
  echo "[limine-brand] vinOS limine configs not found at $REPO_LIMINE — skipping" >&2
  exit 0
fi

# 1. Menu display config → /boot/limine.conf
sudo cp "$REPO_LIMINE/limine.conf" /boot/limine.conf

# 2. Kernel-entry generator config → /etc/default/limine
#    Preserve the @@CMDLINE@@ substitution that Omarchy's install did —
#    read the CMDLINE from the CURRENT /etc/default/limine (Omarchy set it),
#    then apply to our template.
if [[ -f /etc/default/limine ]]; then
  CURRENT_CMDLINE=$(grep -oP 'KERNEL_CMDLINE\[default\]\+=.*"@@CMDLINE@@[^"]*"|KERNEL_CMDLINE\[default\]\+="[^"]*"' /etc/default/limine \
    | head -1 | grep -oP '"[^"]*"' | head -1 | tr -d '"' || true)
fi

sudo cp "$REPO_LIMINE/default.conf" /etc/default/limine
if [[ -n "${CURRENT_CMDLINE:-}" ]]; then
  # Only substitute if @@CMDLINE@@ is still the literal placeholder
  # (fresh install) — otherwise leave Omarchy's already-resolved cmdline.
  sudo sed -i "s|@@CMDLINE@@|${CURRENT_CMDLINE//|/\\|}|g" /etc/default/limine
fi

# 3. Hardware auto-detect the default_entry line.
#    T2 Mac  → linux-t2 as default (entry index depends on kernels installed).
#    Generic → linux-cachyos.
#
# We identify by /sys/class/dmi/id/product_name against known T2 models,
# and by presence of /sys/bus/thunderbolt/devices/domain0 which T2s have.
DEFAULT_KERNEL="linux"
if [[ -f /sys/class/dmi/id/product_name ]]; then
  PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
  case "$PRODUCT" in
    MacBookPro15,*|MacBookPro16,*|MacBookAir8,*|MacBookAir9,*|iMacPro1,*|Macmini8,*)
      DEFAULT_KERNEL="linux-t2"
      ;;
  esac
fi
# 2.1.1 roadmap note: swap DEFAULT_KERNEL="linux" → "linux-cachyos" once
# supply-chain research on cachyos signing key is done.

# limine-update auto-numbers entries alphabetically. We can't hard-pin an
# index safely; instead pin by ENTRY NAME which limine matches on.
# Format for default_entry: 'Arch Linux (linux-XXX)'
sudo sed -i "s|^default_entry:.*|default_entry: /Arch Linux (${DEFAULT_KERNEL})|" /boot/limine.conf || true

# 4. Regenerate entries
sudo limine-update 2>/dev/null || true

echo "[limine-brand] vinOS branding applied · default kernel: ${DEFAULT_KERNEL}"
