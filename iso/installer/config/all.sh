# config/all.sh — everything the pacstrap left un-personalised.
#   - fstab (genfstab)
#   - locale, keyboard, timezone, hostname
#   - user account + password + sudoers
#   - service enablement (NetworkManager, sshd off by default)
#   - vinOS overlay layered via install.sh in the chroot
#
# Every long-running chroot operation is wrapped by chroot_run so its
# stdout+stderr flows to the log and any non-zero exit dies loudly.

phase_start 60 config || return 0

answers_load
: "${USERNAME:?config phase reached without USERNAME}"
: "${PASSWORD:?config phase reached without PASSWORD}"
: "${HOSTNAME_:=vinos}"
: "${TIMEZONE:=UTC}"
: "${KB_LAYOUT:=us}"
: "${PROFILE:=generic}"

VINOS_REPO_URL="${VINOS_REPO_URL:-https://github.com/vinpatel/vinos.git}"
VINOS_BRANCH="${VINOS_BRANCH:-main}"

# ── fstab ─────────────────────────────────────────────────────────
log "generating fstab"
run bash -c "genfstab -U '$TARGET_ROOT' > '$TARGET_ROOT/etc/fstab'"
[[ -s "$TARGET_ROOT/etc/fstab" ]] || die "genfstab produced empty fstab"

# ── locale ────────────────────────────────────────────────────────
log "configuring locale (en_US.UTF-8 baseline)"
# Ensure the target has the en_US line uncommented; add if missing.
if [[ -f "$TARGET_ROOT/etc/locale.gen" ]]; then
  run sed -i 's/^#\(en_US\.UTF-8 UTF-8\)/\1/' "$TARGET_ROOT/etc/locale.gen"
  grep -q '^en_US.UTF-8 UTF-8' "$TARGET_ROOT/etc/locale.gen" \
    || printf 'en_US.UTF-8 UTF-8\n' >> "$TARGET_ROOT/etc/locale.gen"
fi
chroot_run 'locale-gen'
printf 'LANG=en_US.UTF-8\n' > "$TARGET_ROOT/etc/locale.conf"

# Console keymap for the installed system. FONT= intentionally omitted;
# mkinitcpio's sd-vconsole hook falls back to the compiled-in default,
# which is always present. Naming a specific font (e.g. eurlatgs16) is
# fragile — kbd occasionally drops fonts between releases.
printf 'KEYMAP=%s\n' "$KB_LAYOUT" > "$TARGET_ROOT/etc/vconsole.conf"

# ── timezone ──────────────────────────────────────────────────────
log "setting timezone: $TIMEZONE"
if [[ -f "$TARGET_ROOT/usr/share/zoneinfo/$TIMEZONE" ]]; then
  chroot_run "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime; hwclock --systohc"
else
  warn "target has no /usr/share/zoneinfo/$TIMEZONE — leaving UTC"
  chroot_run 'ln -sf /usr/share/zoneinfo/UTC /etc/localtime; hwclock --systohc'
fi

# ── hostname ──────────────────────────────────────────────────────
log "setting hostname: $HOSTNAME_"
printf '%s\n' "$HOSTNAME_" > "$TARGET_ROOT/etc/hostname"
cat > "$TARGET_ROOT/etc/hosts" <<HOSTS
127.0.0.1  localhost
::1        localhost
127.0.1.1  ${HOSTNAME_}.localdomain  ${HOSTNAME_}
HOSTS

# ── mkinitcpio (regenerate now that fstab exists) ─────────────────
# pacstrap already ran this once, but on some hardware the initial
# generation misses a hook (usb-storage on Apple T2 etc.). Re-run to
# be safe — cheap on stock kernel, catches missing hooks.
chroot_run 'mkinitcpio -P'

# ── user account ──────────────────────────────────────────────────
log "creating user $USERNAME (wheel + hardware groups)"
# Some hardware groups (network, storage) are only created by post-install
# hooks of specific packages (iwd, util-linux). Add each one only if it
# actually exists on the target, otherwise create it. Belt-and-suspenders
# so useradd -G doesn't fail on an otherwise-fine install.
chroot_run "
  useradd -m -s /bin/bash '$USERNAME'
  for g in wheel video audio input storage network; do
    getent group \"\$g\" >/dev/null 2>&1 || groupadd \"\$g\"
    usermod -aG \"\$g\" '$USERNAME'
  done
"
# Password via chpasswd stdin — never lands in ps.
# NOTE: arch-chroot mounts a fresh tmpfs on /tmp inside the chroot,
# which hides anything we drop into $TARGET_ROOT/tmp/ from the host.
# Use /root/ (not mounted-over) so the chroot session can read the file.
_PW_FILE="$TARGET_ROOT/root/.vinos-pw.tmp"
printf '%s:%s\n' "$USERNAME" "$PASSWORD" > "$_PW_FILE"
chmod 0600 "$_PW_FILE"
chroot_run 'chpasswd < /root/.vinos-pw.tmp; shred -u /root/.vinos-pw.tmp'

# Sudoers — wheel with password.
install -Dm 0440 /dev/stdin "$TARGET_ROOT/etc/sudoers.d/10-vinos-wheel" <<'SUDO'
# vinOS installed-system sudoers policy.
%wheel ALL=(ALL:ALL) ALL
SUDO
chroot_run 'visudo -cf /etc/sudoers.d/10-vinos-wheel'

# ── services ──────────────────────────────────────────────────────
log "enabling NetworkManager; leaving sshd disabled"
chroot_run '
  systemctl enable NetworkManager.service
  systemctl disable sshd.service 2>/dev/null || true
'

# ── vinOS overlay ─────────────────────────────────────────────────
# Clone the repo into the user's home and run install.sh. The overlay
# scripts call `sudo pacman -S ...` and expect an interactive tty for a
# password prompt — which we don't have inside the chroot. Drop a
# temporary NOPASSWD sudoers file for the install user, run install.sh,
# then remove the file. (Same pattern Omarchy uses for its bootstrap.)
log "cloning vinOS repo + running install.sh in chroot"
chroot_run "
  install -d -m 0755 -o '$USERNAME' -g '$USERNAME' '/home/$USERNAME/.local/share'

  # Temporary passwordless sudo for the install phase only. Removed
  # below regardless of install.sh's exit status. USERNAME is validated
  # in prompts/all.sh to ^[a-z_][a-z0-9_-]*$ so unquoting it here is
  # safe; sudoers does NOT strip single-quotes from the user token, so
  # writing '$USERNAME' would produce a rule that matches only the
  # literal name \"'qatest'\" — not the user we just created.
  install -Dm 0440 /dev/stdin /etc/sudoers.d/99-vinos-installer <<SUDO
$USERNAME ALL=(ALL:ALL) NOPASSWD: ALL
SUDO
  visudo -cf /etc/sudoers.d/99-vinos-installer >/dev/null

  sudo -u '$USERNAME' -H git clone --depth=1 --branch '$VINOS_BRANCH' \
    '$VINOS_REPO_URL' '/home/$USERNAME/.local/share/vinos'

  # T2 support and NVIDIA are post-boot upgrades — first-boot script prompts.
  # || true so we can always fall through to the sudoers cleanup below.
  set +e
  sudo -u '$USERNAME' -H env VINOS_INSTALL_ASSUME_YES=1 \
    /home/$USERNAME/.local/share/vinos/install.sh
  _install_rc=\$?
  set -e

  # Always remove the temporary NOPASSWD file, even if install.sh failed.
  rm -f /etc/sudoers.d/99-vinos-installer

  # Now propagate the install.sh failure so the phase dies loudly.
  exit \$_install_rc
"

# First-run service (writes T2 / NVIDIA detection prompt on first login).
chroot_run 'systemctl enable vinos-firstboot.service 2>/dev/null || true'

log "config phase complete"
phase_done 60 config
