#!/usr/bin/env bash
# Force dark GTK theme so file-manager, nautilus, gnome-disk-utility etc.
# match the vinOS look. Runs in the user's session — no sudo.
set -euo pipefail
if ! command -v gsettings >/dev/null 2>&1; then exit 0; fi
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme     'Adwaita-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme    'Adwaita' 2>/dev/null || true
exit 0
