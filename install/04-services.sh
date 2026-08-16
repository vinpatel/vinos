#!/usr/bin/env bash
# 04-services.sh — enable systemd units. Rule 1: greetd is owned by
# 02-desktop; this script must succeed on a headless system. UFW gets
# warn-and-continue (nftables sync fails on some Arch setups; never
# brick the run). In VINOS_ROOT (ISO build) mode, runtime ufw commands
# are skipped — only the enable-symlink is written into airootfs.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

require_not_root

if [[ -z "$VINOS_ROOT" ]]; then
  log "04-services: configuring firewall"
  if command -v ufw >/dev/null 2>&1; then
    sudo ufw --force default deny incoming  || warn "ufw default deny incoming failed"
    sudo ufw --force default allow outgoing || warn "ufw default allow outgoing failed"
    if [[ "${VINOS_ENABLE_SSH:-0}" == "1" ]]; then
      sudo ufw allow ssh || warn "ufw allow ssh failed"
    fi
    sudo ufw --force enable || warn "ufw enable failed (nftables sync?); continuing"
  else
    warn "ufw not installed; skipping firewall config"
  fi
else
  log "04-services: VINOS_ROOT mode — deferring ufw runtime config to first boot"
fi

# ufw.service enable works in both modes via systemctl_enable's routing.
systemctl_enable ufw

if [[ "${VINOS_ENABLE_SSH:-0}" == "1" ]]; then
  log "04-services: sshd enable requested (VINOS_ENABLE_SSH=1)"
  systemctl_enable sshd
fi

if [[ -z "$VINOS_ROOT" ]]; then
  log "04-services: blacklisting floppy module (silences fd0 I/O probe error)"
  REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  _mp="$(_rootpath /etc/modprobe.d)"
  _sudo install -d -m 0755 "$_mp"
  _sudo install -Dm 0644 "$REPO/iso/profile/airootfs/etc/modprobe.d/vinos-no-floppy.conf" \
                         "$_mp/vinos-no-floppy.conf"
else
  # ISO airootfs already ships the file in-tree; installing to itself would
  # error with "same file" under `install`. Skip in VINOS_ROOT mode.
  log "04-services: floppy blacklist already staged in airootfs — skipping"
fi

# I7 — network stack: iwd for wifi auth + systemd-networkd for DHCP.
# Belt-and-suspenders after 1.1.0 T2 boot showed "Operation failed":
#  - wireless-regdb ships via iso/packages.live so iwd has a regdb.
#  - Country=US pinned in main.conf so 5GHz channels light up out of box.
#  - EnableNetworkConfiguration removed — iwd's built-in DHCP races the
#    brcmfmac driver on T2 Macs. Using systemd-networkd + iwd is the
#    battle-tested combo (Arch Wiki: iwd + systemd-networkd).
#  - systemd-resolved owns /etc/resolv.conf (see block below).
#  - systemd-networkd-wait-online gets a --timeout=15 drop-in (below)
#    so network-online.target actually WAITS for Wi-Fi association on T2
#    (previously the service was masked outright, which lied about the
#    network being online 1 s into boot — vinos-tzdetect and anything
#    else After=network-online.target then raced brcmfmac and lost).
#    Offline machines stall max 15 s, then the target activates anyway.
log "04-services: configuring iwd (auth) + systemd-networkd (dhcp) + resolved"
_iwd_conf="$(_rootpath /etc/iwd)"
_sudo install -d -m 0755 "$_iwd_conf"
_iwd_tmp="$(mktemp)"
cat > "$_iwd_tmp" <<'IWDCONF'
[General]
# Set regulatory domain up front so 5GHz + high channels come alive.
Country=US
[Network]
# systemd-resolved owns DNS.
NameResolvingService=systemd
# Do NOT set EnableNetworkConfiguration=true — systemd-networkd does DHCP.
[Settings]
AutoConnect=true
IWDCONF
_sudo install -Dm 0644 "$_iwd_tmp" "$_iwd_conf/main.conf"
rm -f "$_iwd_tmp"

# systemd-networkd config for any wireless interface iwd brings up.
_networkd_conf="$(_rootpath /etc/systemd/network)"
_sudo install -d -m 0755 "$_networkd_conf"
_networkd_tmp="$(mktemp)"
cat > "$_networkd_tmp" <<'NETCONF'
# vinOS wireless — DHCP on any interface named wlan* (iwd owns naming).
[Match]
Name=wlan*

[Network]
DHCP=yes
IgnoreCarrierLoss=3s

[DHCPv4]
RouteMetric=20
NETCONF
_sudo install -Dm 0644 "$_networkd_tmp" "$_networkd_conf/25-wireless.network"
rm -f "$_networkd_tmp"

systemctl_enable iwd
systemctl_enable systemd-networkd
systemctl_enable systemd-resolved

# NOTE: wait-online was previously masked (installed /etc/systemd/system/
# systemd-networkd-wait-online.service -> /dev/null). That masking caused
# network-online.target to activate the instant iwd started, before Wi-Fi
# was truly online — the root cause of the v1.3.0 tzdetect regression on
# T2 (brcmfmac takes 5-20 s to associate + DHCP). Ensure any prior mask
# from an old install is removed here so the drop-in below actually applies.
if [[ -z "$VINOS_ROOT" ]]; then
  _sys_mask="/etc/systemd/system/systemd-networkd-wait-online.service"
else
  _sys_mask="$(_rootpath /etc/systemd/system/systemd-networkd-wait-online.service)"
fi
if [[ -L "$_sys_mask" && "$(readlink "$_sys_mask")" == "/dev/null" ]]; then
  log "04-services: removing legacy /dev/null mask on systemd-networkd-wait-online"
  _sudo rm -f "$_sys_mask"
fi

# /etc/resolv.conf → resolved's stub. Some environments (Docker
# containers, LXC, some VM providers) bind-mount /etc/resolv.conf and
# ln will fail with EBUSY — that's harmless there because the host is
# already handling DNS, so warn + continue rather than aborting the
# whole 04-services run.
_resolv="$(_rootpath /etc/resolv.conf)"
if _sudo ln -sfn /run/systemd/resolve/stub-resolv.conf "$_resolv" 2>/dev/null; then
  log "04-services: /etc/resolv.conf → resolved stub"
else
  warn "could not symlink /etc/resolv.conf (bind mount?); leaving as-is"
fi

# Install the vinos-firstboot systemd unit. Runs 06-hardware.sh once
# on first boot after graphical.target is ready, so driver detection
# + install happens without user intervention. Idempotent via a
# ConditionPathExists sentinel at /var/lib/vinos/firstboot.done.
#
# Enable in installer mode only — the ISO live boot doesn't need to
# run driver-install on ephemeral squashfs. vinos-install-disk enables
# it explicitly in the chroot after archinstall lays down the target.
# Enable everyday hardware services so laptops behave properly. Any
# machine that doesn't have the underlying hardware will simply not
# use the service — enabling costs nothing.
log "04-services: enabling bluetooth + thermald + acpid + power-profiles-daemon + bolt"
systemctl_enable bluetooth
systemctl_enable thermald
systemctl_enable acpid
systemctl_enable power-profiles-daemon
systemctl_enable bolt

# ollama.service — local model runtime. Kept enabled on the live ISO
# so `ollama pull <model>` from vinos-menu ai's Chat entry works
# without asking the user to manually `systemctl start`. Costs ~50 MB
# RSS at idle; models themselves are pulled on-demand (nothing baked
# into the ISO). No-op on machines without the ollama package
# (systemctl_enable warns + continues).
systemctl_enable ollama

# --- Apple T2 Mac userspace services --------------------------------
# tiny-dfr renders the Touch Bar; t2fanrd manages fans. Both ship in
# packages.live so the binaries + units are present on every ISO. They
# are enabled universally — on non-Apple hardware they either exit
# quickly or stay dormant (no /dev/dri Touch Bar, no applesmc sensors).
#
# Enable target matters: tiny-dfr's base unit has NO [Install] section;
# the arch-mact2 drop-in /usr/lib/systemd/system/tiny-dfr.service.d/
# t2-intel.conf sets WantedBy=graphical.target + After=graphical.target.
# Enabling into multi-user.target.wants (v1.3.0's approach) violates the
# drop-in's ordering and Touch Bar failed to light up on Vin's T2 MBP.
# t2fanrd's base unit says WantedBy=default.target — mirror that.
VINOS_SYSTEMCTL_TARGET=graphical.target systemctl_enable tiny-dfr
VINOS_SYSTEMCTL_TARGET=default.target   systemctl_enable t2fanrd

# hid_apple fnmode=2 — Apple keyboard convention. Makes Apple/Lofree keyboards
# treat the F-row as F-keys by default (media keys behind fn). The
# module only loads when Apple HID hardware is present, so this file
# is a harmless no-op on non-Apple systems.
_modp="$(_rootpath /etc/modprobe.d)"
_sudo install -d -m 0755 "$_modp"
_hid_tmp="$(mktemp)"
printf 'options hid_apple fnmode=2\n' > "$_hid_tmp"
_sudo install -Dm 0644 "$_hid_tmp" "$_modp/vinos-hid-apple.conf"
rm -f "$_hid_tmp"

# Unmount FUSE mounts before suspend/hibernate — well-known gvfsd fix. Fixes
# the "suspend silently fails" class of bug caused by gvfsd-fuse mounts
# blocking the kernel process-freeze on wake. Universal (harmless on
# systems that never mount FUSE).
_slp="$(_rootpath /usr/lib/systemd/system-sleep)"
_sudo install -d -m 0755 "$_slp"
_slp_tmp="$(mktemp)"
cat > "$_slp_tmp" <<'SLEEPHOOK'
#!/bin/bash
# vinOS system-sleep hook: lazy-unmount gvfsd-fuse mounts before
# suspend/hibernate so the freeze doesn't time out. Restores gvfs on
# wake so Nautilus's SMB/MTP/etc mounts come back.
if [[ $1 == pre ]]; then
  while IFS=' ' read -r _ mountpoint fstype _; do
    if [[ $fstype == fuse.gvfsd-fuse ]]; then
      mountpoint=$(printf '%b' "$mountpoint")
      fusermount3 -uz "$mountpoint" 2>/dev/null || \
        fusermount -uz "$mountpoint" 2>/dev/null || true
    fi
  done < /proc/mounts
fi
if [[ $1 == post ]]; then
  (
    sleep 5
    for uid_dir in /run/user/*; do
      uid=$(basename "$uid_dir")
      [[ -S $uid_dir/bus ]] && sudo -u "#$uid" env \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$uid_dir/bus" \
        XDG_RUNTIME_DIR="$uid_dir" \
        systemctl --user restart gvfs-daemon.service 2>/dev/null || true
    done
  ) &
fi
SLEEPHOOK
_sudo install -Dm 0755 "$_slp_tmp" "$_slp/vinos-unmount-fuse"
rm -f "$_slp_tmp"

log "04-services: installing vinos-firstboot.service"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_sysd="$(_rootpath /etc/systemd/system)"
_sudo install -d -m 0755 "$_sysd"
_sudo install -Dm 0644 "$REPO/install/systemd/vinos-firstboot.service" \
                       "$_sysd/vinos-firstboot.service"
if [[ -z "$VINOS_ROOT" ]]; then
  systemctl_enable vinos-firstboot
else
  log "04-services: vinos-firstboot staged (not enabled on live ISO)"
fi

# --- Plymouth shutdown + reboot splash -----------------------------
# plymouth-poweroff.service + plymouth-reboot.service extend the boot
# splash into the shutdown/reboot sequence — without them, the screen
# clears to black the instant systemd starts tearing down and no logo
# is visible until the firmware regains control. Both units ship with
# the `plymouth` package; they only need to be enabled.
# plymouth-quit-wait.service keeps the daemon alive until the display
# manager is ready so we don't flash-black on the boot→login handoff.
log "04-services: enabling plymouth splash on shutdown + reboot"
# plymouth-poweroff/reboot land in their own targets so the splash
# takes over at the moment systemd starts tearing down.
VINOS_SYSTEMCTL_TARGET=poweroff.target systemctl_enable plymouth-poweroff
VINOS_SYSTEMCTL_TARGET=reboot.target   systemctl_enable plymouth-reboot
# plymouth-quit-wait is a boot-time bridge that keeps the daemon
# alive through the boot→login handoff so the screen doesn't flash
# black. WantedBy=multi-user.target is correct for this one.
systemctl_enable plymouth-quit-wait

# Sudoers scoped to tzupdate + timedatectl so vinos-tz-select and the
# Hyprland exec-once fallback can update TZ without a password prompt.
# Mirrors Omarchy's install/config/timezones.sh. Idempotent — install
# rewrites the file each time. Perms 0440 (0644 would make sudo refuse).
log "04-services: writing /etc/sudoers.d/20-vinos-tzupdate"
_sudoers_d="$(_rootpath /etc/sudoers.d)"
_sudo install -d -m 0755 "$_sudoers_d"
_tzsudo_tmp="$(mktemp)"
cat > "$_tzsudo_tmp" <<'TZSUDO'
%wheel ALL=(root) NOPASSWD: /usr/bin/tzupdate, /usr/bin/timedatectl
TZSUDO
_sudo install -Dm 0440 "$_tzsudo_tmp" "$_sudoers_d/20-vinos-tzupdate"
rm -f "$_tzsudo_tmp"

log "04-services: done"
