#!/usr/bin/env bash
# iso/qa/config-lint.sh — static config lint for the Hyprland
# autostart + bindings the ISO ships. Catches the exact bug classes
# that broke v1.2.1:
#
#   1. exec-once = <cmd> -i <PATH> where PATH is a per-user path that
#      isn't seeded on a fresh live user home. swaybg was pointed at
#      ~/.config/vinos/theme/background which is NEVER created, so the
#      compositor showed default black on every boot.
#
#   2. bindd = ..., exec, xdg-terminal-exec ...
#      xdg-terminal-exec resolves the user's preferred terminal via
#      ~/.config/xdg-terminals.list or a system-wide .desktop with the
#      TerminalEmulator category. Neither is seeded on the ISO, so the
#      bind is a silent no-op.
#
#   3. exec, <binary> for any binary that isn't in the built ISO's
#      package list (missing package → nothing happens).
#
# Runs against config/hypr/ + iso/profile/packages.x86_64 + iso/aur.list.
# Zero external deps: pure bash + awk + grep. Exit 0 on green.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF="$REPO/config/hypr"
PKG_LIST="$REPO/iso/profile/packages.x86_64"
AUR_LIST="$REPO/iso/aur.list"

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
FAIL=0
WARN=0
PASS=0
fail() { printf "${RED}FAIL${RESET} %s\n" "$*"; FAIL=$((FAIL+1)); }
warn() { printf "${YELLOW}WARN${RESET} %s\n" "$*"; WARN=$((WARN+1)); }
pass() { printf "${GREEN}PASS${RESET} %s\n" "$*"; PASS=$((PASS+1)); }

# --- 1. autostart.conf: exec-once paths --------------------------------

_check_autostart_paths() {
  local file="$CONF/autostart.conf"
  [[ -f "$file" ]] || { fail "autostart.conf missing at $file"; return; }
  # Extract the -i <path> arg to swaybg and similar path-consuming daemons.
  # We conservatively match `-i <path>` and `--image <path>`.
  local line path
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    for kw in '-i' '--image'; do
      if [[ "$line" == *" $kw "* ]]; then
        path=$(printf '%s' "$line" | awk -v kw="$kw" '
          { for (i=1;i<=NF;i++) if ($i==kw && i<NF) { print $(i+1); exit } }')
        # Strip surrounding quotes.
        path="${path%\"}"; path="${path#\"}"
        path="${path%\'}"; path="${path#\'}"
        # Home-relative? Verify it's a system-seeded path.
        case "$path" in
          '~/'*|'$HOME/'*)
            fail "autostart.conf uses per-user path '$path' — NOT seeded on fresh live user. This is the v1.2.1 blank-screen bug. Use a /usr/share/vinos/… path instead."
            ;;
          /usr/*|/etc/*|/opt/*)
            # System path — verify it exists in the built airootfs.
            # 05-branding installs /usr/share/vinos/wallpaper.png.
            case "$path" in
              /usr/share/vinos/wallpaper.png)
                pass "autostart: swaybg → $path (populated by 05-branding.sh)"
                ;;
              *)
                warn "autostart uses system path '$path' — verify it's guaranteed to exist in the airootfs"
                ;;
            esac
            ;;
          *)
            warn "autostart uses non-absolute path '$path' — verify resolution"
            ;;
        esac
      fi
    done
  done < "$file"
}

# --- 2. bindings/*.conf: no xdg-terminal-exec --------------------------

_check_no_xdg_terminal_exec() {
  # Skip commented lines — the fix for the v1.2.1 bug is documented in
  # a comment header and we don't want the lint to trip on its own
  # explanation.
  local hits
  hits=$(grep -rHn 'xdg-terminal-exec' "$CONF/bindings/" 2>/dev/null \
    | awk -F: '{ line=$0; rest=""; for (i=3;i<=NF;i++) rest=rest ":" $i;
                  # rest starts with the file content after "path:lineno:"
                  sub(/^:/, "", rest);
                  gsub(/^[[:space:]]+/, "", rest);
                  if (rest !~ /^#/) print line }' || true)
  if [[ -n "$hits" ]]; then
    while IFS= read -r line; do
      fail "xdg-terminal-exec is a silent no-op on the live ISO (no registered terminals): $line"
    done <<<"$hits"
  else
    pass "no active xdg-terminal-exec in bindings/ (would silently no-op)"
  fi
}

# --- 3. bindings/*.conf: exec targets are shipped ----------------------

_check_exec_targets_present() {
  # Collect known-shipped binaries: package list + AUR list names +
  # every vinos-* helper in bin/ + a hardcoded set of guaranteed system
  # binaries. We stay conservative — false negatives (unshipped bin
  # slipping through) are far worse than a warn we can eyeball.
  local known
  known=$(cat "$PKG_LIST" "$AUR_LIST" 2>/dev/null | grep -vE '^\s*(#|$)' | LC_ALL=C sort -u)
  local vinos_bins
  vinos_bins=$(ls "$REPO/bin"/ 2>/dev/null | LC_ALL=C sort)
  # Whitelist system utilities Arch always ships.
  local sysbins="bash sh systemctl systemd-cat sleep hyprctl swaybg mako waybar walker foot alacritty nautilus dbus-update-activation-environment env logger notify-send makoctl fcitx5 hypridle uwsm-app elephant sudo hyprpicker gpu-screen-recorder pkill pgrep xdg-open wl-copy hyprlock hyprsunset jq gum swayosd-client swayosd-server nwg-drawer gnome-calculator voxtype"

  local file line target basename
  for file in "$CONF/bindings/"*.conf; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" == *", exec, "* ]] || continue
      # Pattern: bindd = KEY, DESC, exec, CMD ARGS...
      target=$(printf '%s' "$line" | awk -F', exec, ' '{print $2}' | awk '{print $1}')
      # If the exec command starts with a chord like `pkill hyprpicker ||
      # hyprpicker -a` or `hyprctl keyword ...`, use the first token.
      # If it starts with `uwsm-app -- <real>`, use <real>.
      if [[ "$target" == "uwsm-app" ]]; then
        target=$(printf '%s' "$line" | awk -F', exec, ' '{print $2}' | awk '{print $3}')
      fi
      basename="${target##*/}"
      # Empty / conditional / pipe leftovers — skip.
      case "$basename" in
        ''|'||'|'!'|'2>/dev/null'|'>/dev/null') continue ;;
      esac
      # Whitelisted system bins?
      if [[ " $sysbins " == *" $basename "* ]]; then
        continue
      fi
      # vinos-* helper we ship?
      if [[ "$basename" == vinos-* ]] && printf '%s\n' "$vinos_bins" | grep -qxF "$basename"; then
        continue
      fi
      # In the package list?
      if printf '%s\n' "$known" | grep -qxF "$basename"; then
        continue
      fi
      # Unknown — flag.
      warn "bindings: '$basename' is not in packages.x86_64 / aur.list / bin/ / whitelist — may be a silent no-op (file: $(basename "$file"))"
    done < "$file"
  done
  pass "bindings scan complete ($PASS pass · $WARN warn · $FAIL fail so far)"
}

# --- 4. wallpaper symlink exists in themes ------------------------------

_check_wallpaper_present() {
  local wp="$REPO/themes/aurora/wallpaper.png"
  if [[ -f "$wp" ]]; then
    pass "themes/aurora/wallpaper.png present"
  else
    # Also allow assets/wallpapers/aurora
    local aw="$REPO/assets/wallpapers/aurora/wallpaper.png"
    if [[ -f "$aw" ]]; then
      pass "assets/wallpapers/aurora/wallpaper.png present (staged by 05-branding)"
    else
      fail "no aurora wallpaper at themes/aurora/wallpaper.png or assets/wallpapers/aurora/wallpaper.png — swaybg will point at a missing symlink"
    fi
  fi
}

# --- 5. limine live menu mirrors the archiso boot entries ---------------
#
# The live ISO is re-mastered onto limine by iso/mklimine-iso.sh, which
# reads config/limine/entries-live.conf. mkarchiso still builds the
# systemd-boot ESP from iso/profile/efiboot/loader/entries/*.conf first,
# and that ESP is then thrown away — so an edit made only there changes
# nothing on the shipped medium, silently. Compare the two.

_check_limine_live_parity() {
  local live="$REPO/config/limine/entries-live.conf"
  local sd_dir="$REPO/iso/profile/efiboot/loader/entries"
  [[ -f "$live" ]]   || { fail "config/limine/entries-live.conf missing — iso/mklimine-iso.sh has nothing to write"; return; }
  [[ -d "$sd_dir" ]] || { fail "$sd_dir missing"; return; }

  local sd_cmdlines limine_cmdlines
  sd_cmdlines="$(cat "$sd_dir"/*.conf | sed -n 's/^options[[:space:]]*//p' | tr -s ' ' | sort)"
  limine_cmdlines="$(sed -n 's/^[[:space:]]*kernel_cmdline:[[:space:]]*//p' "$live" | tr -s ' ' | sort)"

  local sd_n limine_n
  sd_n="$(printf '%s\n' "$sd_cmdlines" | grep -c .)"
  limine_n="$(printf '%s\n' "$limine_cmdlines" | grep -c .)"

  if [[ "$sd_n" -ne "$limine_n" ]]; then
    fail "limine live menu has $limine_n entries but archiso ships $sd_n — config/limine/entries-live.conf is out of sync with $sd_dir"
    return
  fi

  if [[ "$sd_cmdlines" != "$limine_cmdlines" ]]; then
    fail "limine live menu kernel command lines differ from the archiso entries:"
    diff <(printf '%s\n' "$sd_cmdlines") <(printf '%s\n' "$limine_cmdlines") | sed 's/^/     /'
    return
  fi

  # Every entry needs both halves; a missing module_path boots a kernel
  # with no initramfs, which panics after the menu has already gone.
  local k m
  k="$(grep -c '^[[:space:]]*kernel_path:' "$live")"
  m="$(grep -c '^[[:space:]]*module_path:' "$live")"
  if [[ "$k" -ne "$limine_n" || "$m" -ne "$limine_n" ]]; then
    fail "limine live menu: $limine_n entries but $k kernel_path / $m module_path lines"
    return
  fi

  # Limine draws the menu in its built-in console font. Anything outside
  # ASCII in a title came out as a tofu box in QEMU.
  local nonascii
  nonascii="$(grep -n '^/' "$live" | LC_ALL=C grep -P '[^\x00-\x7F]' | grep -v '—' || true)"
  if [[ -n "$nonascii" ]]; then
    warn "limine entry titles carry non-ASCII limine's font may not have: $(printf '%s' "$nonascii" | head -2 | tr '\n' ' ')"
  fi

  pass "limine live menu mirrors all $limine_n archiso boot entries"
}

# --- 6. installer boots what the installer installed --------------------
#
# The live medium and the installed disk are built by two different pieces
# of code — config/limine/entries-live.conf for the USB, and
# iso/installer/bootloader/all.sh for the disk. They drifted: the USB gave
# Apple T2 Macs a linux-t2 entry with the T2 quirks, the installer wrote
# one stock `vmlinuz-linux` entry with `quiet splash` for every machine,
# and a T2 Mac that installed to disk rebooted into a black screen with no
# console to recover from. Nothing in the tree compared them. This does.

_check_installer_t2_parity() {
  local live="$REPO/config/limine/entries-live.conf"
  local boot="$REPO/iso/installer/bootloader/all.sh"
  local pacs="$REPO/iso/installer/pacstrap/all.sh"
  local t2en="$REPO/bin/vinos-t2-enable"

  for f in "$live" "$boot" "$pacs" "$t2en"; do
    [[ -f "$f" ]] || { fail "installer T2 parity: $f missing"; return; }
  done

  # (a) The installer must actually install the T2 kernel on Apple hardware.
  if grep -q 'linux-t2' "$pacs"; then
    pass "installer pacstrap phase installs linux-t2 on the t2mac profile"
  else
    fail "iso/installer/pacstrap/all.sh never mentions linux-t2 — an installed T2 Mac gets a stock kernel it cannot use"
  fi

  # (b) The T2 quirks the installer writes must be the ones the live medium
  #     boots with. That live command line is the verified-on-hardware one;
  #     anything the installer invents instead is untested.
  local quirks
  quirks="$(sed -n "s/^T2_QUIRKS='\(.*\)'.*/\1/p" "$boot" | head -1)"
  if [[ -z "$quirks" ]]; then
    fail "iso/installer/bootloader/all.sh has no T2_QUIRKS assignment — the installed T2 entry carries no T2 flags"
  else
    local live_t2_cmdlines missing=""
    live_t2_cmdlines="$(sed -n 's/^[[:space:]]*kernel_cmdline:[[:space:]]*//p' "$live" | grep 'intel_iommu' || true)"
    local knob
    for knob in $quirks; do
      printf '%s\n' "$live_t2_cmdlines" | grep -qF -- "$knob" || missing="$missing $knob"
    done
    if [[ -n "$missing" ]]; then
      fail "installer T2 quirks not present on the live medium's T2 entries:$missing (config/limine/entries-live.conf is the verified command line)"
    else
      pass "installer T2 kernel flags match the live medium's verified T2 command line"
    fi
  fi

  # (c) A T2 entry must exist and point at the T2 kernel.
  if grep -q 'boot():/vmlinuz-linux-t2' "$boot"; then
    pass "installer writes a limine entry for vmlinuz-linux-t2"
  else
    fail "iso/installer/bootloader/all.sh writes no vmlinuz-linux-t2 entry — the T2 kernel would be installed but unbootable"
  fi

  # (d) The stock-kernel-on-Apple-hardware fallback must not be splashed.
  #     `quiet splash` over a kernel with no working display, keyboard or
  #     Wi-Fi is indistinguishable from a dead machine.
  if grep -q "that is the black screen this phase exists to prevent" "$boot"; then
    pass "installer asserts the Apple-hardware stock fallback boots unsplashed"
  else
    fail "iso/installer/bootloader/all.sh has no guard against a splashed stock entry on Apple hardware — that is the v1.4.0 black screen"
  fi

  # (e) The brcmfmac recipe the installer seeds must match the one
  #     vinos-t2-enable writes post-boot, or the same Mac gets different
  #     Wi-Fi behaviour depending on which path configured it.
  local a b
  a="$(grep -o 'feature_disable=0x[0-9a-fA-F]*' "$pacs" | head -1)"
  b="$(grep -o 'feature_disable=0x[0-9a-fA-F]*' "$t2en" | head -1)"
  if [[ -n "$a" && "$a" == "$b" ]]; then
    pass "brcmfmac recipe identical in the installer and vinos-t2-enable ($a)"
  else
    fail "brcmfmac feature_disable differs: installer='$a' vinos-t2-enable='$b' — the same Mac would get different Wi-Fi behaviour by install path"
  fi
}

# --- Run --------------------------------------------------------------

printf '\n\033[1;36m== iso/qa/config-lint.sh ==\033[0m\n'
_check_autostart_paths
_check_no_xdg_terminal_exec
_check_wallpaper_present
_check_exec_targets_present
_check_limine_live_parity
_check_installer_t2_parity

printf '\n\033[1;36msummary\033[0m: %d pass · %d warn · %d fail\n' "$PASS" "$WARN" "$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
