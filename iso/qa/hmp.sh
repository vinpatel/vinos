#!/usr/bin/env bash
# iso/qa/hmp.sh — QEMU HMP (Human Monitor Protocol) client wrapper.
#
# Every automation helper that talks to a running QEMU (keepalive,
# test-super-return, hot-reload loop, screenshot capture) uses this
# instead of raw socat/nc pipes. Centralises the socket path, timeout,
# and error handling.
#
# Requires: socat (Arch ships in the socat package).
#
# Usage:
#   iso/qa/hmp.sh [--socket PATH] <subcmd> [args...]
#
# Subcommands:
#   send   RAW_CMD...     Send raw HMP text (multi-word arg quoted).
#   key    KEY_SPEC       Wrapper for `sendkey <KEY_SPEC>`.
#                         Example: iso/qa/hmp.sh key meta_l-ret
#   dump   PATH           Wrapper for `screendump <PATH>` (guest sees the
#                         path as-is; use a path visible to the QEMU process).
#   status                `info status` (prints VM state).
#   type   STRING         Types STRING one character at a time via sendkey.
#                         Letters, digits, and a small punctuation set only.
#
# Exit codes:
#   0  — command executed (does NOT guarantee guest reaction)
#   1  — socket missing or unreadable
#   2  — usage error
#   3  — socat pipe failed / timeout
set -euo pipefail

SOCK="/tmp/qemu-hmp.sock"

while [[ $# -gt 0 && "$1" == --* ]]; do
  case "$1" in
    --socket) SOCK="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "hmp.sh: unknown flag $1" >&2; exit 2 ;;
  esac
done

[[ $# -ge 1 ]] || { echo "hmp.sh: no subcommand — see --help" >&2; exit 2; }
[[ -S "$SOCK" ]] || { echo "hmp.sh: no HMP socket at $SOCK (is QEMU running with --monitor?)" >&2; exit 1; }
command -v socat >/dev/null 2>&1 || { echo "hmp.sh: socat not installed" >&2; exit 1; }

_send() {
  # $1 = raw HMP line, no trailing newline
  local resp
  resp="$(printf '%s\n' "$1" | timeout 3 socat - UNIX-CONNECT:"$SOCK" 2>&1)" || return 3
  # Strip the QEMU banner + echo lines; keep the useful reply.
  printf '%s\n' "$resp" | sed '/^QEMU [0-9]/d; /^(qemu) $/d'
}

sub="$1"; shift

case "$sub" in
  send)
    [[ $# -ge 1 ]] || { echo "hmp.sh send: missing command" >&2; exit 2; }
    _send "$*"
    ;;
  key)
    [[ $# -ge 1 ]] || { echo "hmp.sh key: missing KEY_SPEC" >&2; exit 2; }
    _send "sendkey $1"
    ;;
  dump)
    [[ $# -ge 1 ]] || { echo "hmp.sh dump: missing PATH" >&2; exit 2; }
    _send "screendump $1"
    ;;
  status)
    _send "info status"
    ;;
  type)
    [[ $# -ge 1 ]] || { echo "hmp.sh type: missing STRING" >&2; exit 2; }
    # Type STRING one keysym at a time. Handles a–z, 0–9, space, dash, dot,
    # slash, underscore. Uppercase requires the shift chord (shift-x).
    s="$1"
    for (( i=0; i<${#s}; i++ )); do
      c="${s:i:1}"
      case "$c" in
        [a-z0-9])           _send "sendkey $c" >/dev/null ;;
        [A-Z])              _send "sendkey shift-$(printf '%s' "$c" | tr '[:upper:]' '[:lower:]')" >/dev/null ;;
        ' ')                _send "sendkey spc" >/dev/null ;;
        '-')                _send "sendkey minus" >/dev/null ;;
        '.')                _send "sendkey dot" >/dev/null ;;
        '/')                _send "sendkey slash" >/dev/null ;;
        '_')                _send "sendkey shift-minus" >/dev/null ;;
        *)                  echo "hmp.sh type: unsupported char '$c'" >&2; exit 2 ;;
      esac
      # Micro-pause so the guest's key queue doesn't drop chars.
      sleep 0.03
    done
    ;;
  *) echo "hmp.sh: unknown subcommand '$sub' — see --help" >&2; exit 2 ;;
esac
