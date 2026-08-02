#!/usr/bin/env bash
# Fire the vinOS welcome tour on first login. No-op if the tour binary is absent.
set -euo pipefail
if ! command -v vinos-welcome >/dev/null 2>&1; then exit 0; fi
setsid uwsm-app -- vinos-welcome >/dev/null 2>&1 &
exit 0
