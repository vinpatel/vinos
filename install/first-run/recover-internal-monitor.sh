#!/usr/bin/env bash
# Force-enable the internal display if hyprctl saw it disabled at last
# session — laptop-lid corner case. Idempotent.
set -euo pipefail
if ! command -v hyprctl >/dev/null 2>&1; then exit 0; fi
if ! pgrep -x Hyprland >/dev/null 2>&1; then exit 0; fi
# Pull first "disabled" monitor; force it enabled.
disabled=$(hyprctl monitors -j 2>/dev/null | \
  python3 -c "import json,sys;
try:
  d=json.load(sys.stdin)
  for m in d:
    if m.get('disabled'):
      print(m['name']); break
except Exception: pass" 2>/dev/null || true)
[[ -n "${disabled:-}" ]] && hyprctl keyword monitor "$disabled,preferred,auto,1" 2>/dev/null || true
exit 0
