#!/usr/bin/env bash
# shellcheck disable=SC2034

# vinOS identity — iso_version reads VINOS_VERSION exported by iso/build.sh
# (from the repo VERSION file); fallback keeps bare `mkarchiso iso/profile`
# usable outside build.sh.
iso_name="vinos"
iso_label="VINOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Vin Patel <https://vinpatel.com>"
iso_application="vinOS Live"
iso_version="${VINOS_VERSION:-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)}"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/vinos-boot-marker"]="0:0:755"
  ["/etc/sudoers.d/10-vinos-wheel"]="0:0:440"
  ["/usr/lib/vinos/t2-brcmfmac-firmware.sh"]="0:0:755"
)

# Auto-populate 0:0:755 for every vinos-* wrapper we ship. Without this,
# archiso repacks them as 0644 in the squashfs and every `vinos-doctor`
# call on the live ISO fails with "Permission denied". Regression fix
# 2026-07-18. profiledef.sh is sourced from iso/profile/ so ../../bin
# resolves to the repo bin/ directory.
#
# NOTE: only set perms on the REAL files under /usr/share/vinos/bin/.
# The /usr/local/bin/vinos-* entries are symlinks — mkarchiso's
# _set_permissions resolves them via realpath, which fails ("Outside
# of valid path") because the symlink target /usr/share/vinos/... is
# absolute and doesn't exist on the build host. Symlinks inherit perms
# from their target at access time on Linux, so this is fine.
_vinos_profile_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
_vinos_repo_bin="${_vinos_profile_dir}/../../bin"
if [[ -d "$_vinos_repo_bin" ]]; then
  for _vinos_bin in "$_vinos_repo_bin"/vinos-*; do
    [[ -f "$_vinos_bin" ]] || continue
    _vinos_name="$(basename "$_vinos_bin")"
    file_permissions["/usr/share/vinos/bin/$_vinos_name"]="0:0:755"
  done
  unset _vinos_bin _vinos_name
fi
unset _vinos_profile_dir _vinos_repo_bin
