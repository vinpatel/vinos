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
)
