# finalize/all.sh — the last mile. Scrub secrets, unmount, prompt to
# reboot into the new system.

phase_start 70 finalize || return 0

answers_load

# ── scrub PASSWORD from $ANSWERS ──────────────────────────────────
# It served its purpose in the config phase. Rewrite the file without it.
log "scrubbing PASSWORD from $ANSWERS"
if [[ -f "$ANSWERS" ]]; then
  _tmp="$(mktemp)"
  chmod 0600 "$_tmp"
  grep -v '^PASSWORD=' "$ANSWERS" > "$_tmp" || true
  install -m 0600 "$_tmp" "$ANSWERS"
  rm -f "$_tmp"
fi

# ── unmount /mnt (and everything below it) ────────────────────────
log "unmounting $TARGET_ROOT"
run sync
try_run umount -R "$TARGET_ROOT" || {
  warn "umount -R $TARGET_ROOT failed. Retrying with -l (lazy)..."
  try_run umount -l "$TARGET_ROOT" || warn "lazy umount also failed — reboot will detach"
}

phase_done 70 finalize

# ── prompt for reboot ────────────────────────────────────────────
# gum prompt with a 5-second countdown gives the operator a chance to
# Ctrl-C into the shell for post-install debugging.
clear
gum style --border double --border-foreground "#7BA7BC" --padding "1 3" --margin "1 4" \
  "Install complete." \
  "" \
  "Press Enter to reboot into your new vinOS install," \
  "or Ctrl-C to drop to a shell (the install is already on disk)."

read -r _ || {
  clear
  cat <<EOF
Install is complete. You are on a root shell on this TTY.
  • run  reboot     to boot the new vinOS install
  • run  poweroff   to power off
Install log: $LOG
EOF
  exec /bin/bash --login
}

systemctl reboot
