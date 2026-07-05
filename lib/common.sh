#!/usr/bin/env bash
# vinOS shared helpers. Source, do not execute.

if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'
  _C_BLUE=$'\033[1;34m'
  _C_YELLOW=$'\033[1;33m'
  _C_RED=$'\033[1;31m'
else
  _C_RESET='' _C_BLUE='' _C_YELLOW='' _C_RED=''
fi

log()  { printf '%s[vinOS %s]%s %s\n' "$_C_BLUE"   "$(date +%H:%M:%S)" "$_C_RESET" "$*"; }
warn() { printf '%s[vinOS WARN]%s %s\n'  "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
die()  { printf '%s[vinOS FAIL]%s %s\n'  "$_C_RED"    "$_C_RESET" "$*" >&2; exit 1; }

require_not_root() {
  [[ $EUID -ne 0 ]] || die "must not be run as root; scripts use sudo internally"
}

install_pkg() { sudo pacman -S --needed --noconfirm "$@"; }
install_aur() { yay          -S --needed --noconfirm "$@"; }

# copy_config SRC_ROOT  — mirrors SRC_ROOT/ into $HOME/.config/. No-op if SRC_ROOT missing.
copy_config() {
  local src="$1"
  [[ -d "$src" ]] || return 0
  mkdir -p "$HOME/.config"
  rsync -a "$src/" "$HOME/.config/"
}

# append_once "line" file  — grep-before-append; creates file if absent.
append_once() {
  local line="$1" file="$2"
  mkdir -p "$(dirname "$file")"
  [[ -e "$file" ]] || : > "$file"
  grep -qxF -- "$line" "$file" || printf '%s\n' "$line" >> "$file"
}
