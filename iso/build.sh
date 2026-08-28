#!/usr/bin/env bash
# iso/build.sh — build a vinOS live ISO from the current repo state.
#
# Usage: iso/build.sh [--overlay <path>]... [--out <dir>] [--skip-aur]
#                     [--no-drift-check]
#
# Runs mkarchiso inside `docker run --privileged archlinux:latest` so the
# host stays untouched (mkarchiso needs loop devices + chroot). Emits
# out/vinos-<VERSION>-x86_64.iso and out/sha256sums.txt.
#
# I1 scope: base profile boots to multi-user.target. Overlay/build-time
# assembly of airootfs branding lands in I2. --skip-aur is accepted now
# and becomes meaningful once AUR packages appear in iso/aur.list.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ISO_DIR/.." && pwd)"
OUT_DIR="$ISO_DIR/out"
OVERLAYS=()
SKIP_AUR=0
DRIFT_CHECK=1

die() { printf '\033[1;31m[iso-build] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[iso-build]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --overlay) [[ $# -ge 2 ]] || die "--overlay needs a path"; OVERLAYS+=("$2"); shift 2 ;;
    --out)     [[ $# -ge 2 ]] || die "--out needs a path";     OUT_DIR="$2"; shift 2 ;;
    --skip-aur) SKIP_AUR=1; shift ;;
    --no-drift-check) DRIFT_CHECK=0; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

command -v docker >/dev/null || die "docker not found — install docker or run inside an archiso-capable environment"
[[ -f "$REPO/VERSION" ]] || die "$REPO/VERSION missing"
VINOS_VERSION="$(<"$REPO/VERSION")"

# Q6b — seed authorized_keys for the vinos live user from the developer's
# public key so iso/qa/loop.sh can ssh in without password prompts. Empty
# password stays enabled in sshd_config.d/10-vinos-live.conf as a fallback
# for interactive testing. This is DEV convenience only; ship-time gate
# (Q10) removes both the pubkey and the sshd unit.
DEV_KEY="${VINOS_DEV_SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}"
AUTHKEYS_DIR="$ISO_DIR/airootfs-overlay/home/vinos/.ssh"
if [[ -f "$DEV_KEY" ]]; then
  install -d -m 0700 "$AUTHKEYS_DIR"
  install -m 0600 "$DEV_KEY" "$AUTHKEYS_DIR/authorized_keys"
  log "seeded dev authorized_keys from $DEV_KEY"
else
  log "no dev pubkey at $DEV_KEY — loop.sh will need password auth"
fi

# Ship gate 0 — static Hyprland config lint (catches the v1.2.1 class
# of silent no-op bugs: xdg-terminal-exec, ~/.config paths in swaybg,
# exec targets that aren'\''t in the shipped package list).
if [[ -x "$ISO_DIR/qa/config-lint.sh" ]]; then
  log "running iso/qa/config-lint.sh (static gate)"
  "$ISO_DIR/qa/config-lint.sh" || die "config-lint FAILED — refusing to build"
fi

# Ship gate 0a — render the installer's bootloader phase for each hardware
# profile and assert it boots what pacstrap installed. Catches the v1.4.0
# black screen: a T2 Mac installed to disk was given a stock-kernel entry
# with 'quiet splash', so it rebooted with no keyboard, no Wi-Fi, and no
# console to run vinos-t2-enable from.
if [[ -x "$ISO_DIR/qa/installer-boot-render.sh" ]]; then
  log "running iso/qa/installer-boot-render.sh (installer boot-menu gate)"
  "$ISO_DIR/qa/installer-boot-render.sh" || die "installer-boot-render FAILED — refusing to build"
fi

# Ship gate 0b — branding-check enforces docs/BRANDING.md (logo alpha,
# wallpaper dims, GTK-CSS-safe waybar, product name spelling).
if [[ -x "$ISO_DIR/qa/branding-check.sh" ]]; then
  log "running iso/qa/branding-check.sh (branding gate)"
  "$ISO_DIR/qa/branding-check.sh" || die "branding-check FAILED — refusing to build"
fi
mkdir -p "$OUT_DIR"

log "regenerating packages.x86_64 (drift check)"
tmp_old="$(mktemp)"; cp "$ISO_DIR/profile/packages.x86_64" "$tmp_old" 2>/dev/null || : > "$tmp_old"
"$ISO_DIR/gen-packages.sh"
if (( DRIFT_CHECK )); then
  if ! diff -q "$tmp_old" "$ISO_DIR/profile/packages.x86_64" >/dev/null 2>&1; then
    log "packages.x86_64 changed — commit the regenerated file before building for release"
    diff -u "$tmp_old" "$ISO_DIR/profile/packages.x86_64" | head -40 || true
    # Not fatal for local dev; use --no-drift-check to silence.
  fi
fi
rm -f "$tmp_old"

if (( SKIP_AUR )); then log "skip-aur requested"; fi
if [[ ${#OVERLAYS[@]} -gt 0 ]]; then
  log "overlays requested (deferred to I2 airootfs assembly): ${OVERLAYS[*]}"
fi

log "building vinOS $VINOS_VERSION via docker (privileged, KVM optional)"
WORK_DIR="/tmp/vinos-iso-work.$$"

# Use a version-suffixed image tag so successive builds share the archiso
# install layer instead of re-downloading it every run.
IMG="vinos-archiso-builder:latest"
# Rebuild the image when this stamp changes so runtime deps stay in sync.
IMG_STAMP="archiso rsync"
if ! docker image inspect "$IMG" >/dev/null 2>&1 \
   || ! docker inspect --format '{{ index .Config.Labels "vinos.stamp" }}' "$IMG" 2>/dev/null | grep -qxF "$IMG_STAMP"; then
  log "building archiso builder image ($IMG_STAMP)"
  docker build -t "$IMG" -f - "$REPO" <<DOCKERFILE
FROM archlinux:latest
LABEL vinos.stamp="$IMG_STAMP"
RUN pacman -Sy --needed --noconfirm $IMG_STAMP && pacman -Scc --noconfirm
DOCKERFILE
fi

# Persist AUR build outputs across runs. Without this the container is
# ephemeral and every rebuild re-does the ~5 min of makepkg work.
AUR_CACHE="$ISO_DIR/.aur-cache"
mkdir -p "$AUR_CACHE"

docker run --rm --privileged \
  -v "$REPO":/vinos-src:ro \
  -v "$OUT_DIR":/out \
  -v "$AUR_CACHE":/vinos-aur-cache \
  -e VINOS_VERSION="$VINOS_VERSION" \
  "$IMG" \
  bash -euo pipefail -c "
    # Copy the source tree in, minus everything that is an OUTPUT rather
    # than an input. This used to be a flat 'cp -a /vinos-src /vinos',
    # which also copied iso/out — 72 GB of previously-built ISOs, qcow2
    # images and QEMU screendumps — into the container on every single
    # build. It cost ~10 minutes and 70 GB of writes before mkarchiso had
    # even started, and it was pure waste twice over: iso/out is already
    # bind-mounted at /out, so the build could always reach it directly.
    #
    # Excludes are outputs and caches only. If you add a directory here,
    # be certain mkarchiso does not read from it.
    mkdir -p /vinos
    rsync -a \
      --exclude 'iso/out/' \
      --exclude 'iso/work/' \
      --exclude 'iso/.aur-cache/' \
      --exclude '.git/' \
      --exclude 'site/public/' \
      --exclude 'site/resources/' \
      --exclude '*.iso' \
      --exclude '*.qcow2' \
      /vinos-src/ /vinos/
    cd /vinos
    export VINOS_VERSION='$VINOS_VERSION'

    echo '== regenerating packages.x86_64 =='
    bash iso/gen-packages.sh

    echo '== assembling airootfs (VINOS_ROOT mode: 03/05/02/04) =='
    AIROOT=/vinos/iso/profile/airootfs
    export VINOS_ROOT=\$AIROOT
    bash install/03-configs.sh
    bash install/05-branding.sh
    bash install/02-desktop.sh
    bash install/04-services.sh
    unset VINOS_ROOT

    echo '== applying live-only airootfs overlay =='
    rsync -a /vinos/iso/airootfs-overlay/ \$AIROOT/

    # Build local [vinos-aur] repo when aur.list is non-empty and we
    # weren't asked to skip. Empty aur.list -> no-op (I3 default).
    # Seed aurrepo from host cache mount so already-built pkgs skip.
    if [[ -d /vinos-aur-cache ]]; then
      mkdir -p /vinos/iso/aurrepo
      cp -a /vinos-aur-cache/. /vinos/iso/aurrepo/ 2>/dev/null || true
    fi
    if [[ '$SKIP_AUR' -ne 1 ]] && grep -qEv '^\s*(#|$)' /vinos/iso/aur.list 2>/dev/null; then
      echo '== building [vinos-aur] via iso/aur-build.sh =='
      bash /vinos/iso/aur-build.sh
      # Push freshly built pkgs back to host cache for next run.
      cp -a /vinos/iso/aurrepo/. /vinos-aur-cache/ 2>/dev/null || true
      cat >> /vinos/iso/profile/pacman.conf <<PACCONF

[vinos-aur]
SigLevel = Optional TrustAll
Server = file:///vinos/iso/aurrepo
PACCONF
      # If aur-build.sh gave up on any packages, strip them from
      # packages.x86_64 so mkarchiso doesn't hard-fail chasing them.
      if [[ -s /vinos/iso/aur.failed ]]; then
        while read -r fp; do
          [[ -n \"\$fp\" ]] || continue
          echo \"== dropping failed AUR pkg from packages.x86_64: \$fp\"
          sed -i \"/^\${fp}\$/d\" /vinos/iso/profile/packages.x86_64
        done < /vinos/iso/aur.failed
      fi
    fi

    # Ensure staged config/branding files are root-owned before squashfs.
    chown -R root:root \$AIROOT/etc \$AIROOT/usr/share/vinos \$AIROOT/usr/local/bin 2>/dev/null || true

    mkdir -p '$WORK_DIR'
    mkarchiso -v -w '$WORK_DIR' -o /out iso/profile
    # Pick the ISO we just built by exact filename (previous heuristic
    # picked the alphabetically-first vinos-*.iso, which returned
    # v1.1.0 when the preserved gold copy was sitting alongside the
    # newly-built ISO).
    ISO_FILE=\"/out/vinos-\$VINOS_VERSION-x86_64.iso\"
    if [[ ! -f \"\$ISO_FILE\" ]]; then
      echo \"mkarchiso produced no \$ISO_FILE\" >&2
      ls /out || true
      exit 1
    fi
    ( cd /out && sha256sum \"\$(basename \"\$ISO_FILE\")\" > sha256sums.txt )
    echo \"ISO: \$ISO_FILE\"
    ls -lh \"\$ISO_FILE\"
  "

log "done → $OUT_DIR"

# Re-master onto limine. archiso can only emit bios.syslinux +
# uefi.systemd-boot, which means a freshly built ISO shows one of two
# stock menus depending on firmware, while the installed system shows the
# authored vinOS one. This rewrites both boot paths to the same limine
# menu, so what a user sees off the USB is what they see off the disk.
#
# Runs before the install-smoke gate on purpose: the gate must exercise
# the bootloader we actually ship, not the one mkarchiso happened to make.
FRESH_ISO="$OUT_DIR/vinos-${VINOS_VERSION}-x86_64.iso"
if [[ -f "$FRESH_ISO" ]]; then
  log "re-mastering the live medium onto limine"
  "$ISO_DIR/mklimine-iso.sh" --iso "$FRESH_ISO" \
    || die "limine re-master failed — the ISO still carries systemd-boot/syslinux"
fi

ls -1sh "$OUT_DIR"/*.iso "$OUT_DIR"/sha256sums.txt 2>/dev/null || true

# Ship gate 0c — boot the image as a USB stick, both firmwares.
#
# This runs BEFORE install-smoke because install-smoke attaches the ISO with
# -cdrom, and a CD has no partition table. On 2026-08-22 an ISO passed
# install-smoke 10/10 and then looped in the initramfs emergency shell on
# real hardware, because the re-master had dropped -partition_offset 16 and
# no partition carried an ISO9660 superblock. Only a USB-shaped boot sees
# that class of bug.
if [[ -f "$FRESH_ISO" && -x "$ISO_DIR/qa/usb-boot-smoke.sh" ]]; then
  log "usb-boot-smoke: booting the image as a USB stick"
  "$ISO_DIR/qa/usb-boot-smoke.sh" --iso "$FRESH_ISO" \
    || die "usb-boot-smoke FAILED — this image would not boot off a USB stick"
  log "usb-boot-smoke: GREEN"
fi

# Ship gate 1 — install-smoke. Boots the newly-built ISO in UEFI QEMU with
# a scratch disk, drives the wizard through a fixed profile, waits for the
# install to finish, then reboots into the installed system and verifies
# hostname / user / bootctl entry. If the install can't complete end-to-end
# in a controlled VM, the ISO does not leave this script. Set
# VINOS_SKIP_INSTALL_SMOKE=1 to bypass ONLY for iteration on ISO-side
# changes that don't touch the install path (branding, wallpaper, etc.).
if [[ -f "$FRESH_ISO" ]]; then
  if [[ "${VINOS_SKIP_INSTALL_SMOKE:-0}" == "1" ]]; then
    log "install-smoke SKIPPED (VINOS_SKIP_INSTALL_SMOKE=1) — do not ship this ISO"
  else
    log "install-smoke: running end-to-end install harness against $FRESH_ISO"
    log "install-smoke: this takes ~15-25 min. Set VINOS_SKIP_INSTALL_SMOKE=1 to bypass."
    if "$ISO_DIR/qa/install-smoke.sh" --iso "$FRESH_ISO" --out-dir "$OUT_DIR/smoke-latest"; then
      log "install-smoke: GREEN"
    else
      _rc=$?
      log "install-smoke: FAILED (rc=$_rc). Post-mortem in $OUT_DIR/smoke-latest/"
      # Do NOT delete it. A failed ISO is the only way to re-run the gate
      # without paying another ~30 min rebuild, and diagnosing an install
      # failure usually takes several runs against the same image.
      #
      # Rename it out of the flash path instead. iso/flash.sh defaults to
      # `ls -1t out/vinos-*.iso | head -1` — newest match wins — so a
      # suffix like .FAILED-GATE.iso would still match AND sort first,
      # making the broken ISO the default flash target. The marker has to
      # go on the FRONT so the name no longer starts with "vinos-".
      _failed_iso="$(dirname "$FRESH_ISO")/FAILED-GATE-$(basename "$FRESH_ISO")"
      mv -f "$FRESH_ISO" "$_failed_iso"
      rm -f "$OUT_DIR/sha256sums.txt"
      log "install-smoke: ISO kept at $_failed_iso (renamed so it cannot be flashed)."
      log "install-smoke: re-run the gate against it without rebuilding:"
      log "  iso/qa/install-smoke.sh --iso $_failed_iso --out-dir iso/out/smoke-latest --keep"
      die "ship gate 1 failed — install did not complete end-to-end in UEFI QEMU"
    fi
  fi
fi

# Ship-gate reminder — every build ends with a nudge to walk the T2
# checkpoint on real hardware before tagging. v1.3.0 shipped 4 hardware
# regressions because QEMU-green was mistaken for ship-ready.
printf '\n\033[1;33mREMINDER\033[0m: before tagging, walk iso/qa/t2-hardware-checkpoint.md\n'
printf '  on a real Apple T2 MacBook. QEMU-green is not enough — v1.3.0 shipped\n'
printf '  4 hardware regressions (tiny-dfr / t2fanrd / tzdetect / slowness) the\n'
printf '  QEMU harness could not catch.\n'
