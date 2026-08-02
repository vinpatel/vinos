#!/usr/bin/env bash
# Warm elephant (walker's data provider) at first run so the first
# Super+Space feels instant. Idempotent — skips if already running.
set -euo pipefail
if ! command -v elephant >/dev/null 2>&1; then exit 0; fi
if pgrep -x elephant >/dev/null 2>&1; then exit 0; fi
setsid uwsm-app -- elephant >/dev/null 2>&1 &
exit 0
