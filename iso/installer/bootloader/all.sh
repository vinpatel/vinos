# bootloader/all.sh — install systemd-boot into the target ESP.
#
# systemd-boot for Day 3-4. Limine migration lands Day 5 as a separate
# phase so we can bisect any regression.
#
# Key design choice: we run `bootctl install` from the LIVE ISO's
# systemd, NOT chrooted. Rationale is systemd issue #36174: `bootctl
# install` inside chroot silently no-ops on certain systemd version
# mismatches — precisely the class of silent failure that spoiled the
# archinstall wrapper. Running from the live ISO with --esp-path=/mnt/boot
# uses the systemd we boot from (which knows its own bootloader binary)
# and writes into the mounted target ESP.
#
# After install we verify by inspecting the actual files on disk. We do
# NOT trust `bootctl status` exit code alone.

phase_start 50 bootloader || return 0

answers_load
: "${ROOT_UUID:?bootloader phase reached without ROOT_UUID (disk phase failed?)}"
: "${PROFILE:=generic}"
: "${KB_LAYOUT:=us}"
: "${TIMEZONE:=UTC}"

# Confirm the ESP mount is still live.
mountpoint -q "$TARGET_ROOT/boot" || die "$TARGET_ROOT/boot not mounted before bootctl install"

# ── install systemd-boot binary + register EFI variable ────────────
# --no-variables is off — we WANT bootctl to write BootOrder/BootXXXX
# via efivars. Without that the firmware doesn't know to try this ESP.
# On QEMU with fresh OVMF vars this works; on some old firmwares it may
# soft-fail. try_run captures either way and we verify below.
try_run bootctl --esp-path="$TARGET_ROOT/boot" install || \
  warn "bootctl install exited non-zero — verifying files on disk anyway"

# The definitive success signals: EFI binary AND loader-schema files.
must_have_file \
  "$TARGET_ROOT/boot/EFI/systemd/systemd-bootx64.efi" \
  "$TARGET_ROOT/boot/EFI/BOOT/BOOTX64.EFI"
[[ -d "$TARGET_ROOT/boot/loader/entries" ]] || \
  run install -d -m 0755 "$TARGET_ROOT/boot/loader/entries"

# ── loader.conf ────────────────────────────────────────────────────
# Default is the vinOS entry. Timeout 3 s — long enough to hit space to
# pick alternatives, short enough that boot feels instant.
cat > "$TARGET_ROOT/boot/loader/loader.conf" <<LOADER
default vinos.conf
timeout 3
console-mode auto
editor no
LOADER
must_have_file "$TARGET_ROOT/boot/loader/loader.conf"

# ── vinos.conf (the boot entry) ────────────────────────────────────
# Cmdline stays minimal. rw + rootuuid + rootflags is the classic Arch
# recipe. quiet + splash keep the plymouth splash flow that the desktop
# phase later wires up. We do NOT put profile-specific hackery here —
# T2 kernel cmdline knobs live in a separate vinos-t2 entry that
# vinos-t2-enable writes on the installed system.
cat > "$TARGET_ROOT/boot/loader/entries/vinos.conf" <<VINOS_ENTRY
title    vinOS
sort-key 00
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  root=UUID=${ROOT_UUID} rw quiet splash loglevel=3 rootfstype=ext4
VINOS_ENTRY
must_have_file "$TARGET_ROOT/boot/loader/entries/vinos.conf"

# Fallback entry — same kernel but verbose console. Useful if plymouth
# fails and the user wants to see what's happening.
cat > "$TARGET_ROOT/boot/loader/entries/vinos-verbose.conf" <<VINOS_VERBOSE
title    vinOS (verbose console)
sort-key 09
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  root=UUID=${ROOT_UUID} rw rootfstype=ext4 systemd.log_level=info
VINOS_VERBOSE

# ── verify ────────────────────────────────────────────────────────
# Run bootctl status against the target ESP. This tells us both that
# systemd-boot recognises its own files and which entries it can see.
# Exit code is honest here (it's just reading files we just wrote).
log "bootctl status against $TARGET_ROOT/boot:"
run bootctl --esp-path="$TARGET_ROOT/boot" status

# Confirm the entries file lists the vinOS entry.
_bootctl_out=$(bootctl --esp-path="$TARGET_ROOT/boot" list 2>&1 || true)
if ! grep -qE 'title: *vinOS( |$)' <<<"$_bootctl_out"; then
  die "bootctl list does not see the vinOS entry — bootloader install did not take"
fi

log "bootloader installed and vinOS entry recognised"
phase_done 50 bootloader
