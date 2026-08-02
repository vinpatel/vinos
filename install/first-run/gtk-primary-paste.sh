#!/usr/bin/env bash
# Disable GTK primary-paste (middle-click paste) — most users don't want it.
set -euo pipefail
if ! command -v gsettings >/dev/null 2>&1; then exit 0; fi
gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false 2>/dev/null || true
exit 0
