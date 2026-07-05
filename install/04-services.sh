#!/usr/bin/env bash
# 04-services.sh — enable systemd units. Headless; skips greetd if not installed. Filled in M2.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
log "04-services: skeleton stub (M1) — service enables land in M2"
