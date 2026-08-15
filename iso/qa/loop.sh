#!/usr/bin/env bash
# iso/qa/loop.sh — Tier 3 hot-patch iteration (Q5+Q9).
#
# Watch host repo for edits; on every change scp the file into the running
# live guest and fire the right per-category reload trigger. Zero rebuilds
# for config-only work.
#
# Dispatch table (see feedback_hot_reload_mandatory_2026_08_15):
#
#   Host path              Guest path                    Reload trigger
#   ─────────────────────  ────────────────────────────  ──────────────────────
#   config/hypr/**         ~/.config/hypr/               hyprctl reload
#   config/waybar/**       ~/.config/waybar/             pkill -SIGUSR2 waybar
#   config/mako/**         ~/.config/mako/               makoctl reload
#   config/walker/**       ~/.config/walker/             pkill walker
#   config/nwg-drawer/**   ~/.config/nwg-drawer/         (none — next spawn picks up)
#   bin/vinos-*            ~/.local/bin/                 (none — next invocation)
#
# Rebuild ONLY when: package list, install/**, kernel/initrd, or shipping.
#
# Prerequisites (all supplied by iso/qemu-desktop.sh + build.sh Q6):
#   1. Guest launched with --hostfwd (defaults 2222 → 22).
#   2. sshd unmasked in overlay (Q6 landed 2026-08-15).
#   3. authorized_keys seeded at build time from ~/.ssh/id_ed25519.pub (Q6b).
#
# Usage:
#   iso/qa/loop.sh                              # watch config/{hypr,waybar,mako,walker} + bin
#   iso/qa/loop.sh --host 192.168.1.140         # different host
#   iso/qa/loop.sh --port 2223                  # different hostfwd port
#   iso/qa/loop.sh --watch config/hypr          # narrow the watch set
#   iso/qa/loop.sh --user myuser --key ~/.ssh/id_ed25519
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST="127.0.0.1"
PORT=2222
USER="vinos"
IDENTITY=""
WATCH_DIRS="config/hypr,config/waybar,config/mako,config/walker,config/nwg-drawer,bin"
GUEST_HOME="/home/vinos"

die() { printf '\033[1;31m[loop] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[loop]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)   HOST="$2"; shift 2 ;;
    --port)   PORT="$2"; shift 2 ;;
    --user)   USER="$2"; shift 2 ;;
    --key)    IDENTITY="$2"; shift 2 ;;
    --watch)  WATCH_DIRS="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

command -v inotifywait >/dev/null || die "inotifywait missing (pacman -S inotify-tools)"
command -v scp         >/dev/null || die "scp missing"
command -v ssh         >/dev/null || die "ssh missing"

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR -o BatchMode=yes -p "$PORT")
[[ -n "$IDENTITY" ]] && SSH_OPTS+=(-i "$IDENTITY")

# Sanity: can we reach sshd?
log "probing ssh ${USER}@${HOST}:${PORT} …"
if ! ssh "${SSH_OPTS[@]}" "${USER}@${HOST}" true 2>/dev/null; then
  die "ssh handshake failed. Confirm --hostfwd is set on the QEMU AND the ISO includes the Q6 unmasked sshd + Q6b authorized_keys (rebuild ISO with iso/build.sh)."
fi
log "ssh works. Watching: $WATCH_DIRS"

IFS=',' read -r -a DIRS <<<"$WATCH_DIRS"
for d in "${DIRS[@]}"; do [[ -d "$REPO/$d" ]] || die "no such dir: $REPO/$d"; done
readarray -t ABS_DIRS < <(for d in "${DIRS[@]}"; do echo "$REPO/$d"; done)

# dispatch — given a relative repo path, return "GUEST_PATH|RELOAD_CMD"
dispatch() {
  local rel="$1"
  case "$rel" in
    config/hypr/*)
      printf '%s|%s\n' "${GUEST_HOME}/.config/${rel#config/}" "hyprctl reload"
      ;;
    config/waybar/*)
      printf '%s|%s\n' "${GUEST_HOME}/.config/${rel#config/}" "pkill -SIGUSR2 waybar || (pkill waybar; nohup waybar >/dev/null 2>&1 &)"
      ;;
    config/mako/*)
      printf '%s|%s\n' "${GUEST_HOME}/.config/${rel#config/}" "makoctl reload"
      ;;
    config/walker/*)
      printf '%s|%s\n' "${GUEST_HOME}/.config/${rel#config/}" "pkill walker || true"
      ;;
    config/nwg-drawer/*)
      printf '%s|%s\n' "${GUEST_HOME}/.config/${rel#config/}" "true"
      ;;
    bin/vinos-*)
      # Ship to ~/.local/bin (on PATH by default on Arch). No sudo needed.
      printf '%s|%s\n' "${GUEST_HOME}/.local/bin/$(basename "$rel")" "chmod +x '${GUEST_HOME}/.local/bin/$(basename "$rel")'"
      ;;
    *)
      printf '||\n'  # unrouted
      ;;
  esac
}

log "ready — edit any watched file, save, and the loop will push + reload"

inotifywait -m -q -r -e close_write --format '%w%f' "${ABS_DIRS[@]}" | \
while read -r changed; do
  case "$(basename "$changed")" in
    .*|*.swp|*.swo|*~) continue ;;
  esac
  [[ -f "$changed" ]] || continue

  rel="${changed#$REPO/}"
  route="$(dispatch "$rel")"
  guest_path="${route%|*}"
  reload_cmd="${route#*|}"

  if [[ -z "$guest_path" ]]; then
    printf '\033[1;33m[loop] %s ⚠ unrouted (no dispatch rule): %s\033[0m\n' "$(date +%H:%M:%S)" "$rel"
    continue
  fi

  ts="$(date +%H:%M:%S)"
  # Ensure parent dir exists in guest.
  guest_dir="$(dirname "$guest_path")"
  if ! ssh "${SSH_OPTS[@]}" "${USER}@${HOST}" "mkdir -p '$guest_dir'" 2>/dev/null; then
    printf '\033[1;31m[loop] %s ✗ mkdir failed: %s\033[0m\n' "$ts" "$guest_dir"
    continue
  fi

  if ! scp -q "${SSH_OPTS[@]}" "$changed" "${USER}@${HOST}:${guest_path}" 2>/dev/null; then
    printf '\033[1;31m[loop] %s ✗ scp failed: %s → %s\033[0m\n' "$ts" "$rel" "$guest_path"
    continue
  fi

  if ssh "${SSH_OPTS[@]}" "${USER}@${HOST}" "$reload_cmd" >/dev/null 2>&1; then
    printf '\033[1;32m[loop] %s ✓ %s → %s\033[0m\n' "$ts" "$rel" "$guest_path"
  else
    printf '\033[1;33m[loop] %s ⚠ scp OK, reload failed: %s → %s\033[0m\n' "$ts" "$rel" "$guest_path"
  fi
done
