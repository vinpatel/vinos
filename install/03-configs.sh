#!/usr/bin/env bash
# 03-configs.sh — copies base config/ into ~/.config. Orchestrator layers overlays after.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log "03-configs: copying base config into \$HOME/.config"
copy_config "$REPO/config"
