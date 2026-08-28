# pacstrap/all.sh — pacstrap base Arch + kernel + minimum viable set
# into $TARGET_ROOT. No archinstall. No --silent black box. Just the
# canonical arch tooling we can wrap in run() and inspect after.
#
# Package rationale (kept intentionally small; the vinOS overlay via
# install.sh in config/ pulls the full desktop later):
#   base            — base group; drops in glibc, systemd, coreutils, ...
#   base-devel      — group; needed for AUR/build-time hooks in the
#                     overlay phase later
#   linux           — stock kernel. Every machine gets it, including Apple
#                     ones, where it is the rescue path underneath linux-t2
#   linux-firmware  — needed even on generic hardware for wifi radios
#   mkinitcpio      — build the initramfs for the installed kernel
#   sudo            — required by the vinOS overlay
#   networkmanager  — post-install networking (users expect a GUI)
#   efibootmgr      — needed by bootctl install + for entry management
#   git             — vinOS overlay clones itself in the config phase
#   iwd             — wifi backend NetworkManager can use on all hardware
#   vim             — recovery editor if bootstrapping the desktop fails
#
# Profile-specific kernels: linux-t2 IS installed here on Apple hardware,
# in a second pass after the base set (see the T2 block at the bottom).
#
# The comment this replaces claimed the T2 kernel could not be installed
# because "the target chroot does not have the arch-mact2 repo registered"
# — which mis-stated the mechanism. pacstrap resolves packages using the
# HOST's /etc/pacman.conf (pacstrap(8): -C picks an alternate; -P is what
# copies it into the target), and the live ISO's pacman.conf already
# carries [arch-mact2] because the ISO itself boots linux-t2. What is true
# is that the repo is not registered in the TARGET afterwards, so the
# installed system would lose linux-t2 on its first `pacman -Syu`. The T2
# block below registers it there before installing anything.
#
# Consequence of the old behaviour: a T2 Mac installed to disk booted a
# stock kernel, with no apple-bce (keyboard/trackpad), no Broadcom
# firmware (Wi-Fi), under `quiet splash` — an unusable machine showing a
# black screen, with no console to run the vinos-t2-enable escape hatch
# from. That is what this phase and bootloader/all.sh now fix together.
#
# nvidia-open is still deferred to first boot: it is a driver, not a
# kernel, and a bad one leaves a bootable machine.

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
  # limine: the bootloader. bootloader/all.sh copies BOOTX64.EFI out of
  # the TARGET rather than the live ISO so the EFI binary on the ESP and
  # the limine userspace on the installed system are the same version —
  # a skew between the two is how a config key quietly stops being
  # understood after an update.
  limine
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

# ── Apple T2: linux-t2 kernel + firmware into the target ──────────
# Second pass on purpose. Folding these into the PKGS array above would
# mean a flaky arch-mact2 mirror takes down an install that is otherwise
# perfectly fine. Here a failure degrades to "stock kernel, T2 quirks on
# the cmdline, run vinos-t2-enable after first boot" — which the
# bootloader phase reads off T2_KERNEL and boots accordingly.
T2_KERNEL=0

if [[ "$PROFILE" == "t2mac" ]]; then
  step "Apple T2 hardware detected — installing the linux-t2 kernel stack"

  # 1. Register [arch-mact2] in the TARGET. pacstrap used the live ISO's
  #    copy to resolve packages; the installed system needs its own or
  #    the first `pacman -Syu` drops linux-t2 as an orphan from nowhere.
  #    Mirrors the stanza in iso/profile/pacman.conf verbatim.
  if ! grep -q '^\[arch-mact2\]' "$TARGET_ROOT/etc/pacman.conf" 2>/dev/null; then
    log "registering [arch-mact2] in the target's /etc/pacman.conf"
    cat >> "$TARGET_ROOT/etc/pacman.conf" <<'PACCONF'

# Apple T2 Mac kernel + firmware. Registered by the vinOS installer's
# pacstrap phase; vinos-t2-enable writes the same stanza post-boot.
[arch-mact2]
SigLevel = Never
Server = https://mirror.funami.tech/arch-mact2/os/$arch
PACCONF
  fi

  # 2. Seed the T2 module drop-ins BEFORE the kernel is installed, so the
  #    initramfs mkinitcpio builds from linux-t2's post-install hook is
  #    already correct. Without apple-bce in the image the internal
  #    keyboard and trackpad are dead from the very first boot — which is
  #    indistinguishable, to the person holding the laptop, from a hang.
  #    Content is kept identical to bin/vinos-t2-enable; if you change one,
  #    change both (iso/qa/config-lint.sh compares them).
  log "seeding T2 mkinitcpio / modules-load / modprobe drop-ins"
  install -Dm 0644 /dev/stdin "$TARGET_ROOT/etc/mkinitcpio.conf.d/apple-t2.conf" <<'T2MKI'
# Apple T2 early-boot modules. applespi + the Intel LPSS SPI stack drive
# the internal keyboard and trackpad; apple-bce is the T2 bridge itself.
MODULES+=(applespi spi_pxa2xx_platform intel_lpss intel_lpss_pci)
MODULES+=(apple-bce usbhid hid_apple hid_generic xhci_pci xhci_hcd)
T2MKI

  install -Dm 0644 /dev/stdin "$TARGET_ROOT/etc/modules-load.d/vinos-t2.conf" <<'T2ML'
apple-bce
hci_bcm4377
T2ML

  install -Dm 0644 /dev/stdin "$TARGET_ROOT/etc/modprobe.d/vinos-brcmfmac.conf" <<'BRCMCONF'
# T2 MacBook Wi-Fi connectivity recipe (linux-t2 project).
# Mask broken firmware features; disable MAC randomization + ANQP so
# brcmfmac's 4-way handshake doesn't get false "wrong password" hits.
options brcmfmac feature_disable=0x82000
BRCMCONF

  # 3. Install the stack. -Syu rather than -Sy: the target was pacstrapped
  #    from these same mirrors moments ago so the upgrade is a no-op in
  #    practice, and it keeps us off the partial-upgrade footgun if the
  #    arch-mact2 mirror happens to be ahead of the Arch one.
  T2_PKGS=(
    linux-t2 linux-t2-headers arch-mact2-mirrorlist
    apple-bcm-firmware apple-t2-audio-config
    tiny-dfr t2fanrd
  )
  log "target T2 package set: ${T2_PKGS[*]}"
  if try_run arch-chroot "$TARGET_ROOT" \
       pacman -Syu --needed --noconfirm --ask=4 "${T2_PKGS[@]}"; then

    # 4. Rebuild every preset now that the drop-ins and the kernel are both
    #    in place. linux-t2's own hook already ran, but a re-run is cheap
    #    insurance and also refreshes the stock image.
    try_run arch-chroot "$TARGET_ROOT" mkinitcpio -P \
      || warn "mkinitcpio -P returned non-zero after the T2 install — checking the images directly"

    # 5. Trust the filesystem, not the exit codes. The bootloader phase
    #    will only write a T2 entry if both halves are actually on the ESP.
    if [[ -f "$TARGET_ROOT/boot/vmlinuz-linux-t2" \
       && -f "$TARGET_ROOT/boot/initramfs-linux-t2.img" ]]; then
      T2_KERNEL=1
      log "linux-t2 installed: $(du -h "$TARGET_ROOT/boot/vmlinuz-linux-t2" | cut -f1) kernel, $(du -h "$TARGET_ROOT/boot/initramfs-linux-t2.img" | cut -f1) initramfs"
    else
      warn "linux-t2 packages installed but /boot/vmlinuz-linux-t2 or its initramfs is missing — falling back to the stock kernel"
    fi
  else
    warn "could not install the linux-t2 stack (arch-mact2 mirror down, or no network)."
    warn "The install continues on the stock kernel. The bootloader phase will boot it"
    warn "with T2-safe flags and NO splash, so you get a readable console to run"
    warn "'vinos-t2-enable' from once the machine is up."
  fi

  # 6. Switch the direct Server= for the curated mirrorlist, now that
  #    arch-mact2-mirrorlist has shipped one. Same edit vinos-t2-enable
  #    makes, and equally optional — a direct Server= keeps working.
  if [[ -f "$TARGET_ROOT/etc/pacman.d/arch-mact2-mirrorlist" ]] \
     && ! grep -q '^Include = /etc/pacman.d/arch-mact2-mirrorlist' "$TARGET_ROOT/etc/pacman.conf"; then
    log "switching [arch-mact2] Server= → Include = /etc/pacman.d/arch-mact2-mirrorlist"
    try_run sed -i '/^\[arch-mact2\]/,/^Server/ { /^Server/c\Include = /etc/pacman.d/arch-mact2-mirrorlist
    }' "$TARGET_ROOT/etc/pacman.conf" \
      || warn "could not switch to the mirrorlist; the direct Server= line remains and still works"
  fi
fi

# Read by bootloader/all.sh (which entries to write, and which is default)
# and by config/all.sh (whether to enable t2fanrd / tiny-dfr).
answers_write T2_KERNEL "$T2_KERNEL"

log "pacstrap complete — kernel + initramfs at $TARGET_ROOT/boot (T2_KERNEL=$T2_KERNEL)"
phase_done 40 pacstrap
