#!/usr/bin/env bash
# 07-ai.sh — AI stack preinstall (ollama + claude-code + vinos-mcp
# registry seed). Rule 1: headless. Idempotent. In VINOS_ROOT (ISO
# build) mode, install_pkg/install_aur are no-ops (packages come from
# gen-packages) but the settings.json + service-enable land in the
# airootfs so live users get a working AI setup out-of-box.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_not_root

log "07-ai: installing ollama + node runtime"
# ollama              — local model runtime (starter model pulled by
#                       first-run wizard, not baked in — would add 18+ GB).
# nodejs + npm        — runtime for the Claude Code CLI and general
#                       tooling. `claude-code` (AUR) uses npm at build
#                       time; nodejs is also useful on its own.
install_pkg ollama nodejs npm

log "07-ai: installing Claude Code (AUR)"
# The `claude-code` AUR package wraps the official binary distribution.
# If the AUR name shifts (e.g. claude-code-bin), maintainer bumps here.
install_aur claude-code || warn "claude-code AUR install failed — users can retry with 'yay -S claude-code'"

# Enable ollama.service — installer-path only. VINOS_ROOT mode routes
# via systemctl_enable to write the enable symlink into airootfs.
systemctl_enable ollama

# Seed vinos-mcp settings so a fresh login has the curated registry
# pointer already wired. Idempotent: only writes if the file doesn't
# exist. vinos-mcp CLI will merge into per-user ~/.claude/settings.json
# on first run — see P2 findings for the registry format.
seed_mcp_pointer() {
  local target="$1" registry="/usr/lib/vinos/registry/mcp-servers.json"
  install -d -m 0755 "$(dirname "$target")"
  if [[ -f "$target" ]]; then
    log "07-ai: $target already seeded"
    return 0
  fi
  cat >"$target" <<JSON
{
  "vinos": {
    "mcp_registry": "$registry",
    "notes": "Managed by vinos-mcp. Run 'vinos-mcp list' to see servers, 'vinos-mcp enable <name>' to activate one for Claude Code."
  }
}
JSON
  log "07-ai: seeded $target"
}

if [[ -n "$VINOS_ROOT" ]]; then
  # Live ISO: seed the skel copy so every live user + first-installed
  # user starts with the pointer.
  seed_mcp_pointer "$VINOS_ROOT/etc/skel/.config/vinos/mcp-hint.json"
else
  # Installer path: seed for the current user.
  seed_mcp_pointer "${XDG_CONFIG_HOME:-$HOME/.config}/vinos/mcp-hint.json"
fi

log "07-ai: done"
