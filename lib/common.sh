#!/usr/bin/env bash
# vinOS shared helpers. Source, do not execute.
#
# VINOS_ROOT (default empty) is the only variable helpers honour. It is
# set by iso/build.sh to the airootfs path so 03/05 can stage files into
# a to-be-squashed root. When empty, every helper behaves exactly like
# it always has (installer mode, backward-compatible).

VINOS_ROOT="${VINOS_ROOT:-}"

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

# In VINOS_ROOT (ISO build) mode we are already root inside the builder
# container and packages come from packages.x86_64, so requiring non-root
# and shelling out to sudo would be wrong.
require_not_root() {
  [[ -n "$VINOS_ROOT" ]] && return 0
  [[ $EUID -ne 0 ]] || die "must not be run as root; scripts use sudo internally"
}

# Internal helpers. _sudo is a no-op when VINOS_ROOT is set (already root
# in the ISO builder container). _rootpath prefixes VINOS_ROOT onto
# absolute system paths so helpers stage into the airootfs.
_sudo()      { if [[ -n "$VINOS_ROOT" ]]; then "$@"; else sudo "$@"; fi; }
_rootpath()  { printf '%s%s' "$VINOS_ROOT" "$1"; }

# install_pkg / install_aur — pacman/yay in installer mode; no-op under
# VINOS_ROOT (packages are baked into packages.x86_64 by gen-packages,
# and mkarchiso installs them into the airootfs — this helper is called
# by 02-desktop for the installer path and gen-packages statically for
# the ISO path).
install_pkg() {
  if [[ -n "$VINOS_ROOT" ]]; then
    log "install_pkg (VINOS_ROOT mode, no-op): $*"
    return 0
  fi
  sudo pacman -S --needed --noconfirm "$@"
}
install_aur() {
  if [[ -n "$VINOS_ROOT" ]]; then
    log "install_aur (VINOS_ROOT mode, no-op): $*"
    return 0
  fi
  yay -S --needed --noconfirm "$@"
}

# copy_config SRC_ROOT — mirror SRC_ROOT/ into either ~/.config (installer
# mode) or $VINOS_ROOT/etc/skel/.config (ISO mode; VINOS_ISO_SPEC §3.3).
# No-op if SRC_ROOT missing.
copy_config() {
  local src="$1" dest
  [[ -d "$src" ]] || return 0
  if [[ -n "$VINOS_ROOT" ]]; then
    dest="$VINOS_ROOT/etc/skel/.config"
  else
    dest="$HOME/.config"
  fi
  mkdir -p "$dest"
  rsync -a "$src/" "$dest/"
}

# append_once "line" file — grep-before-append; creates file if absent.
# In VINOS_ROOT mode, file is treated as an absolute-in-airootfs path.
append_once() {
  local line="$1" file="$2"
  file="$(_rootpath "$file")"
  mkdir -p "$(dirname "$file")"
  [[ -e "$file" ]] || : > "$file"
  grep -qxF -- "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

# systemctl_enable UNIT... — three modes:
#   VINOS_ROOT set  : write a static wants-symlink into airootfs
#                     ($VINOS_ROOT/etc/systemd/system/multi-user.target.wants),
#                     the archiso convention for enabling services.
#   host + systemd  : sudo systemctl enable; warn on failure.
#   host, no systemd: log + skip (containers).
systemctl_enable() {
  if [[ -n "$VINOS_ROOT" ]]; then
    local unit target wants_dir
    target="${VINOS_SYSTEMCTL_TARGET:-multi-user.target}"
    wants_dir="$VINOS_ROOT/etc/systemd/system/${target}.wants"
    mkdir -p "$wants_dir"
    for unit in "$@"; do
      ln -sfn "/usr/lib/systemd/system/$unit.service" "$wants_dir/$unit.service"
      log "airootfs: enabled $unit.service (${target}.wants)"
    done
    return 0
  fi
  if [[ ! -d /run/systemd/system ]]; then
    log "systemd not running here; skipping: systemctl enable $*"
    return 0
  fi
  sudo systemctl enable "$@" || warn "systemctl enable $* failed"
}
