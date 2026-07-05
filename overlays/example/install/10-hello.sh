#!/usr/bin/env bash
# overlays/example/10-hello.sh — proves the overlay contract (§6). Installs cowsay.
set -euo pipefail
# shellcheck source=../../../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/common.sh"
log "10-hello: overlay example — would install cowsay (M4 makes this real)"
