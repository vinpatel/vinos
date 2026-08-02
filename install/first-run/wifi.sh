#!/usr/bin/env bash
# Prompt for wifi if no connection is up after 10s. Non-blocking.
set -euo pipefail
if ! command -v nmcli >/dev/null 2>&1 && ! command -v iwctl >/dev/null 2>&1; then exit 0; fi
if ip -o -4 route show default | grep -q .; then exit 0; fi
if command -v impala >/dev/null 2>&1; then
  setsid uwsm-app -- foot -e impala >/dev/null 2>&1 &
fi
exit 0
