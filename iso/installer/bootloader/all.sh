# bootloader/all.sh — install limine into the target ESP.
#
# vinOS boots limine, not systemd-boot. config/limine/limine.conf is the
# authored vinOS boot menu — nebula wallpaper, vinOS branding, tuned
# palette — and it ships to /usr/share/vinos/limine/ by 05-branding. That
# file is the THEME HEADER only; this phase appends the generated entries
# beneath it, so the look lives in one place and entry generation lives
# in one place.
#
# Two copies of the EFI binary go onto the ESP, deliberately:
#
#   EFI/BOOT/BOOTX64.EFI   the removable-media fallback path. Firmware
#                          boots this with no NVRAM cooperation at all.
#                          It is what makes the install come up in QEMU
#                          with fresh OVMF vars, and what saves an Apple
#                          machine whose NVRAM we could not write.
#   EFI/limine/BOOTX64.EFI the target of the named efibootmgr entry, so
#                          the firmware menu shows "vinOS" rather than a
#                          generic disk.
#
# The efibootmgr call is best-effort on purpose: on hardware that refuses
# the write, the removable path still boots. A hard failure here would
# fail an install that is actually fine.
#
# Verification does not trust any tool's exit code — it reads back the
# files and greps the generated config, which is the class of check the
# archinstall wrapper was missing.
#
# Entry generation is hardware-aware, which it did not used to be. The
# live medium gives Apple T2 Macs their own entries (see
# config/limine/entries-live.conf) booting vmlinuz-linux-t2 with the T2
# quirks, which is why the USB works on that hardware; this phase wrote
# one stock `vmlinuz-linux` entry with `quiet splash` for every machine,
# which is why the installed disk did not. preflight detects PROFILE and
# pacstrap now installs linux-t2 accordingly — this phase is the third
# leg: it boots what was installed, and when the T2 kernel is NOT there
# it drops the splash so the operator lands on a readable console instead
# of a black screen with no way to run vinos-t2-enable.

phase_start 50 bootloader || return 0

answers_load
: "${DISK:?bootloader phase reached without DISK (disk phase failed?)}"
: "${EFI_PART:?bootloader phase reached without EFI_PART (disk phase failed?)}"
: "${ROOT_UUID:?bootloader phase reached without ROOT_UUID (disk phase failed?)}"
: "${PROFILE:=generic}"
# Written by the pacstrap phase: 1 if the linux-t2 stack went in.
: "${T2_KERNEL:=0}"

ESP="$TARGET_ROOT/boot"
mountpoint -q "$ESP" || die "$ESP not mounted before limine install"

# ── EFI binary ─────────────────────────────────────────────────────
# Taken from the TARGET, not the live ISO: pacstrap put limine there, so
# the bootloader on the ESP and the limine userspace on the installed
# system are the same version. A mismatch between the two is exactly how
# a config key silently stops being understood after an update.
LIMINE_EFI="$TARGET_ROOT/usr/share/limine/BOOTX64.EFI"
[[ -f "$LIMINE_EFI" ]] || \
  die "limine is not installed in the target ($LIMINE_EFI missing) — is 'limine' in the pacstrap set?"

run install -Dm 0644 "$LIMINE_EFI" "$ESP/EFI/BOOT/BOOTX64.EFI"
run install -Dm 0644 "$LIMINE_EFI" "$ESP/EFI/limine/BOOTX64.EFI"
must_have_file \
  "$ESP/EFI/BOOT/BOOTX64.EFI" \
  "$ESP/EFI/limine/BOOTX64.EFI"

# ── theme header ───────────────────────────────────────────────────
LIMINE_SHARE="${VINOS_LIMINE_DIR:-/usr/share/vinos/limine}"
LIMINE_CONF="$ESP/limine.conf"

if [[ -f "$LIMINE_SHARE/limine.conf" ]]; then
  run cp "$LIMINE_SHARE/limine.conf" "$LIMINE_CONF"
else
  # Never leave the machine unbootable because the branding assets are
  # missing — write a plain header and carry on. The menu is ugly; the
  # system boots.
  warn "$LIMINE_SHARE/limine.conf not found — writing a minimal unthemed header"
  cat > "$LIMINE_CONF" <<'MINIMAL'
timeout: 5
default_entry: 1
interface_branding: vinOS
MINIMAL
fi

# Wallpaper referenced by the theme header as boot():/vinos-wallpaper.jpg.
# Its absence is cosmetic — limine falls back to the backdrop colour.
if [[ -f "$LIMINE_SHARE/wallpaper.jpg" ]]; then
  run install -Dm 0644 "$LIMINE_SHARE/wallpaper.jpg" "$ESP/vinos-wallpaper.jpg"
else
  warn "no boot wallpaper at $LIMINE_SHARE/wallpaper.jpg — menu falls back to the backdrop colour"
fi

# ── entries ────────────────────────────────────────────────────────
# Syntax is limine 12.x (see /usr/share/doc/limine/CONFIG.md): an entry
# opens with '/Title', options are indented 'key: value', and paths take
# the resource(argument):/path form. boot():/ is the partition holding
# this config file — the ESP — which is also where the kernel and
# initramfs live, because /boot IS the ESP in our layout.

# Trust the filesystem over the answers file. T2_KERNEL says what the
# pacstrap phase believes it installed; these two files are whether the
# machine can actually boot it. A menu entry pointing at a kernel that
# isn't there is worse than no entry — the machine dies after the menu
# has already disappeared.
T2_ON_ESP=0
if [[ -f "$ESP/vmlinuz-linux-t2" && -f "$ESP/initramfs-linux-t2.img" ]]; then
  T2_ON_ESP=1
fi
if (( T2_KERNEL == 1 )) && (( T2_ON_ESP == 0 )); then
  warn "pacstrap reported T2_KERNEL=1 but $ESP/vmlinuz-linux-t2 is not on the ESP — writing stock entries instead"
fi

# The T2 command line, token for token from the live medium's T2 entries
# in config/limine/entries-live.conf. That is the line verified to bring
# up a 2019 T2 MacBook Pro, so it is copied rather than re-derived;
# iso/qa/config-lint.sh compares the two so they cannot drift apart.
T2_QUIRKS='intel_iommu=on iommu=pt pcie_ports=compat cfg80211.ieee80211_regdom=US modprobe.blacklist=floppy'

ROOTOPTS="root=UUID=${ROOT_UUID} rw rootfstype=ext4"

# What the first, default entry should be called and boot.
DEFAULT_TITLE='vinOS'

if (( T2_ON_ESP )); then
  # ── Apple T2 Mac, T2 kernel installed ───────────────────────────
  # Splash is kept here: this is the same kernel and the same command
  # line the live USB boots on this hardware, and that path is proven.
  # The verbose twin sits directly beneath it for when it is not.
  DEFAULT_TITLE='vinOS (Apple T2 Mac)'
  cat >> "$LIMINE_CONF" <<T2ENTRIES

# ── entries (generated by the installer's bootloader phase) ────────
# Apple T2 hardware: linux-t2 is the default. Keyboard, trackpad,
# Broadcom Wi-Fi, audio, Touch Bar and fan control all live in this
# kernel — the stock entries below it are a rescue path, not a
# substitute.

/vinOS (Apple T2 Mac)
    comment: T2 kernel — keyboard, trackpad, Wi-Fi, audio, Touch Bar, fans.
    protocol: linux
    path: boot():/vmlinuz-linux-t2
    cmdline: ${ROOTOPTS} quiet splash loglevel=3 ${T2_QUIRKS}
    module_path: boot():/initramfs-linux-t2.img

/vinOS (Apple T2 Mac, verbose console)
    comment: Same T2 kernel, no splash — shows the boot log if the graphical boot stalls.
    protocol: linux
    path: boot():/vmlinuz-linux-t2
    cmdline: ${ROOTOPTS} ${T2_QUIRKS} systemd.log_level=info
    module_path: boot():/initramfs-linux-t2.img
T2ENTRIES

  # The fallback image is a mkinitcpio preset default, but presets can be
  # edited. Only advertise the entry if the image is actually on the ESP —
  # a menu entry that dead-ends at a panic is worse than no entry.
  if [[ -f "$ESP/initramfs-linux-t2-fallback.img" ]]; then
    cat >> "$LIMINE_CONF" <<T2FALLBACK

/vinOS (Apple T2 Mac, fallback initramfs)
    comment: Use if a microcode or module change left the main T2 initramfs broken.
    protocol: linux
    path: boot():/vmlinuz-linux-t2
    cmdline: ${ROOTOPTS} ${T2_QUIRKS}
    module_path: boot():/initramfs-linux-t2-fallback.img
T2FALLBACK
  fi

  # Stock entries still follow, as a rescue path if a linux-t2 update
  # ever lands broken.
  STOCK_CMDLINE="${ROOTOPTS} quiet splash loglevel=3"
  STOCK_COMMENT='Stock Arch kernel — rescue path. Most Apple hardware will not work under it.'
  STOCK_HEADER=''

elif [[ "$PROFILE" == "t2mac" ]]; then
  # ── Apple T2 Mac, T2 kernel NOT installed ───────────────────────
  # The arch-mact2 mirror was unreachable during pacstrap. The stock
  # kernel is all there is, and on this hardware it comes up with no
  # internal keyboard and no Wi-Fi. Booting THAT under `quiet splash`
  # is the black screen: nothing on the display, nothing on the
  # console, no way in. So the splash comes off and the T2 quirks stay
  # on, which is the difference between a dead laptop and a login
  # prompt you can plug a USB keyboard into and run vinos-t2-enable.
  warn "Apple hardware without the linux-t2 kernel — writing NO-SPLASH stock entries"
  warn "Run 'vinos-t2-enable' once the installed system is up and networked."
  STOCK_CMDLINE="${ROOTOPTS} ${T2_QUIRKS} loglevel=4"
  STOCK_COMMENT='Stock kernel on Apple hardware — run vinos-t2-enable to install the T2 kernel.'
  STOCK_HEADER='# Apple T2 hardware WITHOUT the T2 kernel (arch-mact2 was unreachable
# during install). Deliberately unsplashed so the console is readable:
# the internal keyboard and Wi-Fi will not work until vinos-t2-enable
# has run. Attach a USB keyboard, log in, connect, and run it.'

else
  # ── everything else ─────────────────────────────────────────────
  STOCK_CMDLINE="${ROOTOPTS} quiet splash loglevel=3"
  STOCK_COMMENT='Boot vinOS.'
  STOCK_HEADER='# ── entries (generated by the installer'"'"'s bootloader phase) ────────'
fi

# Written as an explicit `if` rather than `[[ -n ... ]] && printf`. The
# T2 branch leaves STOCK_HEADER empty, so that one-liner returns non-zero
# on exactly the path that matters most, and whether `set -e` kills the
# installer there depends on a subtle bash exemption for &&-lists. Not
# worth resting a T2 install on.
{
  printf '\n'
  if [[ -n "$STOCK_HEADER" ]]; then
    printf '%s\n\n' "$STOCK_HEADER"
  fi
  cat <<ENTRIES
/vinOS
    comment: ${STOCK_COMMENT}
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: ${STOCK_CMDLINE}
    module_path: boot():/initramfs-linux.img

/vinOS (verbose console)
    comment: Same kernel, no splash — shows the boot log.
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: ${ROOTOPTS} systemd.log_level=info
    module_path: boot():/initramfs-linux.img
ENTRIES
} >> "$LIMINE_CONF"

if [[ -f "$ESP/initramfs-linux-fallback.img" ]]; then
  cat >> "$LIMINE_CONF" <<FALLBACK

/vinOS (fallback initramfs)
    comment: Use if a microcode or module change left the main initramfs broken.
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: ${ROOTOPTS}
    module_path: boot():/initramfs-linux-fallback.img
FALLBACK
else
  warn "no initramfs-linux-fallback.img on the ESP — skipping the fallback entry"
fi

# ── default_entry ──────────────────────────────────────────────────
# limine's default_entry is a 1-based index over top-level entries in
# file order, not a title. The theme header ships `default_entry: 1`,
# which happens to be right today because the intended default is always
# written first — but "happens to be right" is how a T2 Mac ends up
# booting the rescue kernel after someone reorders this block. Compute
# it. Same arithmetic as bin/vinos-boot-entry.
_default_idx="$(awk -v title="/$DEFAULT_TITLE" '
  /^\// && substr($0,2,1) != "/" { n++; if ($0 == title) { print n; exit } }
' "$LIMINE_CONF")"
if [[ -n "$_default_idx" ]]; then
  if grep -q '^[[:space:]]*default_entry:' "$LIMINE_CONF"; then
    run sed -i "s|^[[:space:]]*default_entry:.*|default_entry: ${_default_idx}|" "$LIMINE_CONF"
  else
    run sed -i "1i default_entry: ${_default_idx}" "$LIMINE_CONF"
  fi
  log "default_entry -> ${_default_idx} (${DEFAULT_TITLE})"
else
  die "could not locate '/${DEFAULT_TITLE}' among the entries just written — entry generation is broken"
fi

must_have_file "$LIMINE_CONF"

# ── firmware boot entry (best-effort) ──────────────────────────────
# Partition number is 1 by construction — disk/all.sh always lays the ESP
# down as partition 1 — but derive it from EFI_PART rather than assuming,
# so a future layout change surfaces here instead of silently pointing
# efibootmgr at the wrong slot.
_efi_partnum="${EFI_PART##*[!0-9]}"
if [[ -n "$_efi_partnum" ]]; then
  # Drop any stale vinOS entries first so repeat installs don't stack up.
  while read -r _num; do
    [[ -n "$_num" ]] && try_run efibootmgr --delete-bootnum --bootnum "$_num"
  done < <(efibootmgr 2>/dev/null | awk '/^Boot[0-9A-Fa-f]{4}\*? +vinOS$/ {print substr($1,5,4)}')

  try_run efibootmgr --create \
      --disk "$DISK" --part "$_efi_partnum" \
      --loader '\EFI\limine\BOOTX64.EFI' \
      --label 'vinOS' \
    || warn "efibootmgr could not register the vinOS entry — the removable path EFI/BOOT/BOOTX64.EFI still boots"
else
  warn "could not derive the ESP partition number from '$EFI_PART' — skipping efibootmgr, removable path still boots"
fi

# ── verify ─────────────────────────────────────────────────────────
# Read back what we wrote. The kernel and initramfs must actually be on
# the ESP, or the menu will list entries that dead-end at a panic.
must_have_file \
  "$ESP/vmlinuz-linux" \
  "$ESP/initramfs-linux.img"

grep -q '^/vinOS$' "$LIMINE_CONF" || \
  die "limine.conf does not contain the vinOS entry — entry generation did not take"
grep -q "root=UUID=${ROOT_UUID}" "$LIMINE_CONF" || \
  die "limine.conf does not reference the root UUID ${ROOT_UUID} — wrong disk would be booted"

# ── Apple T2 assertions ────────────────────────────────────────────
# These are the checks that would have caught the black screen before it
# reached hardware, so they are hard failures, not warnings.
if (( T2_ON_ESP )); then
  must_have_file "$ESP/vmlinuz-linux-t2" "$ESP/initramfs-linux-t2.img"
  grep -q '^/vinOS (Apple T2 Mac)$' "$LIMINE_CONF" || \
    die "the T2 kernel is on the ESP but no T2 entry was written — the Mac would boot the stock kernel"
  grep -q 'vmlinuz-linux-t2' "$LIMINE_CONF" || \
    die "no entry references vmlinuz-linux-t2 — the T2 kernel is installed but unbootable"
  for _knob in intel_iommu=on iommu=pt pcie_ports=compat; do
    grep -q -- "$_knob" "$LIMINE_CONF" || \
      die "T2 entry is missing the '$_knob' quirk the live medium boots with"
  done
elif [[ "$PROFILE" == "t2mac" ]]; then
  # No T2 kernel on Apple hardware: the one thing that must be true is
  # that the operator can SEE the machine boot.
  if grep -E '^[[:space:]]*cmdline:' "$LIMINE_CONF" | head -1 | grep -q 'splash'; then
    die "Apple hardware fell back to the stock kernel but the default entry still carries 'splash' — that is the black screen this phase exists to prevent"
  fi
fi

log "limine installed; entries in $LIMINE_CONF:"
grep -E '^/' "$LIMINE_CONF" | sed 's/^/    /'

phase_done 50 bootloader
