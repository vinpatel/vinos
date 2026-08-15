#!/usr/bin/env bash
# iso/qa/keepalive.sh — defeat hypridle in live-ISO QEMU sessions.
#
# On live ISO the vinos user has an empty password, so once hypridle
# triggers hyprlock (5-min idle default) PAM refuses empty-password
# auth and the session is unrecoverable — you must reboot the guest.
# Prior to v1.2.3 this was the norm; v1.2.3+ skips hypridle entirely on
# /run/archiso, but this helper stays in place as a safety net for
# older ISOs and for cases where you WANT hypridle running (installed
# system regression tests).
#
# What it does:
#   Sends a `sendkey shift` every INTERVAL seconds via QEMU HMP.
#   A lone shift press is invisible to Hyprland but counts as input,
#   resetting the hypridle idle timer.
#
# Loops until the HMP socket disappears (guest quit / QEMU killed).
#
# Usage:
#   iso/qa/keepalive.sh [--socket PATH] [--interval SEC] [--log PATH]
#
# Defaults:
#   --socket    /tmp/qemu-hmp.sock   (matches iso/qemu-desktop.sh --monitor)
#   --interval  45                    (< hypridle's 300s / 5min default)
#   --log       /tmp/qemu-keepalive.log
set -euo pipefail

SOCK="/tmp/qemu-hmp.sock"
INTERVAL=45
LOG="/tmp/qemu-keepalive.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --socket)   SOCK="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --log)      LOG="$2"; shift 2 ;;
    -h|--help)  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

command -v socat >/dev/null 2>&1 || { echo "keepalive: socat missing" >&2; exit 1; }

: > "$LOG"
echo "$(date +%H:%M:%S) keepalive started — socket=$SOCK interval=${INTERVAL}s" >> "$LOG"

tick=0
while [[ -S "$SOCK" ]]; do
  tick=$((tick+1))
  if printf 'sendkey shift\n' | timeout 3 socat - UNIX-CONNECT:"$SOCK" >/dev/null 2>&1; then
    echo "$(date +%H:%M:%S) tick=$tick sendkey shift OK" >> "$LOG"
  else
    echo "$(date +%H:%M:%S) tick=$tick sendkey shift FAIL" >> "$LOG"
  fi
  sleep "$INTERVAL"
done

echo "$(date +%H:%M:%S) socket gone — keepalive exiting after $tick ticks" >> "$LOG"
