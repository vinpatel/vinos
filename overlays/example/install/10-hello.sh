#!/usr/bin/env bash
# overlays/example/10-hello.sh — proves the Rule 2 overlay contract (§6):
# a fork-owned script (number 10+) adding a package the base does not.
# Idempotent via install_pkg's --needed; Rule 1 headless-safe.
set -euo pipefail
# shellcheck source=../../../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/common.sh"

require_not_root
log "10-hello: overlay example — installing cowsay"
install_pkg cowsay
