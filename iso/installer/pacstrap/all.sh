# pacstrap/all.sh — pacstrap base Arch + kernel + minimum viable set
# into $TARGET_ROOT. No archinstall. No --silent black box. Just the
# canonical arch tooling we can wrap in run() and inspect after.
#
# Package rationale (kept intentionally small; the vinOS overlay via
# install.sh in config/ pulls the full desktop later):
#   base            — base group; drops in glibc, systemd, coreutils, ...
#   base-devel      — group; needed for AUR/build-time hooks in the
#                     overlay phase later
#   linux           — stock kernel (T2 kernel is a post-boot upgrade path
#                     driven by vinos-t2-enable; base install uses stock)
#   linux-firmware  — needed even on generic hardware for wifi radios
#   mkinitcpio      — build the initramfs for the installed kernel
#   sudo            — required by the vinOS overlay
#   networkmanager  — post-install networking (users expect a GUI)
#   efibootmgr      — needed by bootctl install + for entry management
#   git             — vinOS overlay clones itself in the config phase
#   iwd             — wifi backend NetworkManager can use on all hardware
#   vim             — recovery editor if bootstrapping the desktop fails
#
# Profile-specific kernels (linux-t2, nvidia-open) DO NOT ship here.
# They pacstrap fine only if the target chroot has the arch-mact2 (or
# NVIDIA) repo registered first — which we do NOT do at install time.
# vinos-first-run on the installed system handles the T2 upgrade path.

phase_start 40 pacstrap || return 0

answers_load
: "${DISK:?pacstrap phase reached without a DISK}"
: "${PROFILE:=generic}"

# Sanity: disk phase's mounts must be present.
mountpoint -q "$TARGET_ROOT"      || die "$TARGET_ROOT is not mounted (disk phase failed?)"
mountpoint -q "$TARGET_ROOT/boot" || die "$TARGET_ROOT/boot is not mounted (disk phase failed?)"

# Pick the fastest mirrors on the live ISO before pacstrap inherits them.
# Fine-grained country list is intentionally omitted — reflector's own
# "sort by rate" is enough on the timescales we care about.
if command -v reflector >/dev/null 2>&1; then
  log "refreshing pacman mirrorlist via reflector"
  try_run reflector --latest 20 --protocol https --sort rate \
                    --save /etc/pacman.d/mirrorlist \
    || warn "reflector failed — keeping existing mirrorlist"
fi

PKGS=(
  base base-devel
  linux linux-firmware mkinitcpio
  sudo networkmanager iwd efibootmgr git vim
  # rsync: 05-branding.sh copies assets with it. Before the base-only
  # pivot this arrived via install/01-base.sh during the full overlay
  # run; that run is gone, so the base set must carry it.
  rsync
  # openssh: the install-smoke gate proves the installed system by SSHing
  # into it after booting the disk with no ISO attached, and cycle 11 died
  # there — config/all.sh runs `systemctl enable sshd` under `|| true`, so
  # a missing unit failed silently and the gate waited on a daemon that was
  # never installed. It also belongs in a base vinOS regardless: the vm
  # persona is administered over SSH. Installed but NOT enabled — enabling
  # it stays a deliberate act, which config/all.sh already handles.
  openssh
)

log "pacstrap package set: ${PKGS[*]}"
run pacstrap -K "$TARGET_ROOT" "${PKGS[@]}"

# Verify — the exact class of check my archinstall wrapper was missing.
must_have_file \
  "$TARGET_ROOT/etc/os-release" \
  "$TARGET_ROOT/usr/lib/systemd/systemd" \
  "$TARGET_ROOT/usr/bin/pacman"

# Kernel image must be on the EFI partition (which we mounted at
# $TARGET_ROOT/boot) so the bootloader entry can find it later. mkinitcpio
# runs from pacstrap's post-install hook and drops both vmlinuz + initramfs
# there.
must_have_file \
  "$TARGET_ROOT/boot/vmlinuz-linux" \
  "$TARGET_ROOT/boot/initramfs-linux.img"

# ── swap fakeroot → fakeroot-tcp inside the target ────────────────
# base-devel drags fakeroot in. Regular fakeroot uses SysV semaphores
# (semop), which fail inside an arch-chroot environment ("semop(1):
# Invalid argument"), taking down every AUR makepkg call. fakeroot-tcp
# provides the same interface over TCP-based IPC and works inside the
# chroot. Swap it in before install.sh runs any yay/makepkg calls.
log "swapping fakeroot → fakeroot-tcp (arch-chroot fakeroot-SysV workaround)"
try_run arch-chroot "$TARGET_ROOT" pacman -S --needed --noconfirm --ask=4 fakeroot-tcp \
  || warn "fakeroot-tcp swap failed — AUR builds may fail; installer will surface it later"

log "pacstrap complete — kernel + initramfs at $TARGET_ROOT/boot"
phase_done 40 pacstrap
