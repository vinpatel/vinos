#!/usr/bin/env bash
# vinOS curl-able entrypoint. Ensures Arch, installs git, clones repo, runs install.
set -euo pipefail

REPO_URL="${VINOS_REPO_URL:-https://github.com/vinpatel/vinos.git}"
REPO_DIR="${VINOS_REPO_DIR:-$HOME/.local/share/vinos}"

[[ -f /etc/arch-release ]] || { echo "vinOS requires Arch Linux" >&2; exit 1; }

sudo pacman -Sy --needed --noconfirm git

if [[ -d "$REPO_DIR/.git" ]]; then
  git -C "$REPO_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi

exec "$REPO_DIR/install.sh" "$@"
