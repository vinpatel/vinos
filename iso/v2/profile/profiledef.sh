#!/usr/bin/env bash
# shellcheck disable=SC2034

# vinOS identity — iso_version reads VINOS_VERSION exported by iso/build.sh
# (from the repo VERSION file); fallback keeps bare `mkarchiso iso/profile`
# usable outside build.sh.
iso_name="vinos"
iso_label="VINOS2_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Vin Patel <https://vinpatel.com>"
iso_application="vinOS 2.0 Live"
iso_version="${VINOS_V2_VERSION:-${VINOS_VERSION:-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)}}"
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
  ["/usr/local/bin/vinos-install"]="0:0:755"
  ["/usr/lib/vinos/t2-brcmfmac-firmware.sh"]="0:0:755"
)

# Auto-populate 0:0:755 for every install.sh under /usr/share/vinos/*/
# so the vinos-install wrapper can invoke them in the target chroot.
_vinos_profile_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
_vinos_airootfs="${_vinos_profile_dir}/airootfs"
if [[ -d "$_vinos_airootfs/usr/share/vinos" ]]; then
  while IFS= read -r -d '' _vinos_sh; do
    _vinos_rel="${_vinos_sh#$_vinos_airootfs}"
    file_permissions["$_vinos_rel"]="0:0:755"
  done < <(find "$_vinos_airootfs/usr/share/vinos" -name 'install.sh' -print0 2>/dev/null)
  unset _vinos_sh _vinos_rel
fi

# Executable bit for Omarchy bin scripts staged at /root/omarchy/bin/.
if [[ -d "$_vinos_airootfs/root/omarchy/bin" ]]; then
  while IFS= read -r -d '' _vinos_bin; do
    _vinos_rel="${_vinos_bin#$_vinos_airootfs}"
    file_permissions["$_vinos_rel"]="0:0:755"
  done < <(find "$_vinos_airootfs/root/omarchy/bin" -type f -print0 2>/dev/null)
  unset _vinos_bin _vinos_rel
fi
unset _vinos_profile_dir _vinos_airootfs
