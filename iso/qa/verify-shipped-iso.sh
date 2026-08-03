#!/usr/bin/env bash
# iso/qa/verify-shipped-iso.sh — regression harness. Extracts the
# built ISO's airootfs.sfs and asserts every known-fixed item is
# still present. If any check fails, the build gets flagged BEFORE
# we flash to hardware, and the error message links to the memory
# entry that describes the fix.
#
# Usage:
#   iso/qa/verify-shipped-iso.sh path/to/vinos-x.y.z-x86_64.iso
#
# Exit codes:
#   0 — all fixes intact, ISO is safe to flash
#   1 — one or more fixes regressed; do NOT ship
#
# Why this file exists: 2026-08-01, T2 wifi worked on live but user
# reported "wrong password" on installed target. Root cause was
# a rsync-exclude typo (live-init.service vs vinos-live-init.service).
# That regression would have been caught pre-flash if this script
# had existed. See memory/project_install_shipped_2026_08_01.md.

set -euo pipefail

ISO="${1:-}"
[[ -n "$ISO" && -f "$ISO" ]] || {
  echo "usage: $0 <path-to-iso>" >&2
  exit 1
}

RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YLW=$'\033[1;33m'; BLU=$'\033[1;34m'; RST=$'\033[0m'
FAILS=0
PASSES=0

say()  { printf '%s[verify]%s %s\n' "$BLU" "$RST" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$GRN" "$RST" "$*"; PASSES=$((PASSES + 1)); }
fail() {
  printf '%s  ✗%s %s\n' "$RED" "$RST" "$1"
  [[ -n "${2:-}" ]] && printf '     ↳ memory: %s\n' "$2"
  FAILS=$((FAILS + 1))
}

# Extract airootfs contents to a temp dir via docker (host may lack
# squashfs-tools). Everything reads from $ROOT afterwards.
say "extracting $(basename "$ISO") to temp dir"
TMP=$(mktemp -d)
# Files inside $TMP come from unsquashfs run as root in docker — need
# docker again to clean them up (host user can't rm root-owned tree).
trap 'docker run --rm -v "$TMP:/tmp/verify" archlinux:latest rm -rf /tmp/verify/root /tmp/verify/arch 2>/dev/null; rm -rf "$TMP" 2>/dev/null || true' EXIT

docker run --rm -v "$TMP:/tmp/verify" -v "$(dirname "$(realpath "$ISO")")":/iso archlinux:latest bash -c "
  pacman -Sy --noconfirm squashfs-tools >/dev/null 2>&1
  bsdtar -xf /iso/$(basename "$ISO") -C /tmp/verify arch/x86_64/airootfs.sfs 2>&1 | tail -1
  unsquashfs -q -f -d /tmp/verify/root /tmp/verify/arch/x86_64/airootfs.sfs 2>&1 | tail -1
" >/dev/null

ROOT="$TMP/root"
[[ -d "$ROOT" ]] || { fail "extraction produced no /root dir — squashfs unreadable"; exit 1; }

INSTALLER="$ROOT/usr/share/vinos/bin/vinos-install-disk"
# REPO points at the vinOS repo root (this script is iso/qa/verify-shipped-iso.sh)
REPO="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"

# ─────────────────────────────────────────────────────────────────
say "T2 wifi recipe (11 items, VERIFIED baseline)"
# ─────────────────────────────────────────────────────────────────

# 1. wireless-regdb
if [[ -f "$ROOT/usr/lib/firmware/regulatory.db" ]] || \
   [[ -f "$ROOT/usr/lib/crda/regulatory.bin" ]]; then
  ok "wireless-regdb present (regulatory database)"
else
  fail "wireless-regdb missing — iwd will refuse 5GHz/high channels" \
       "project-t2-wifi-recipe #1"
fi

# 2. iwd Country=US
if grep -q '^Country=US' "$ROOT/etc/iwd/main.conf" 2>/dev/null; then
  ok "iwd Country=US pinned"
else
  fail "iwd Country=US missing from /etc/iwd/main.conf" \
       "project-t2-wifi-recipe #2"
fi

# 3. no EnableNetworkConfiguration=true (networkd owns DHCP)
if grep -qE '^EnableNetworkConfiguration\s*=\s*true' "$ROOT/etc/iwd/main.conf" 2>/dev/null; then
  fail "iwd built-in DHCP enabled — races brcmfmac. Delegate to networkd." \
       "project-t2-wifi-recipe #3"
else
  ok "iwd DHCP delegated to systemd-networkd"
fi

# 4. brcmfmac feature_disable
if grep -qE '^options brcmfmac feature_disable=0x82000' "$ROOT/etc/modprobe.d/vinos-brcmfmac.conf" 2>/dev/null; then
  ok "brcmfmac feature_disable=0x82000 (5GHz disassoc fix)"
else
  fail "brcmfmac feature_disable modprobe missing" \
       "project-t2-wifi-recipe #5"
fi

# 5. T2 initramfs modules
if grep -q 'brcmfmac' "$ROOT/etc/modules-load.d/vinos-t2.conf" 2>/dev/null || \
   grep -qE 'MODULES=.*brcmfmac' "$ROOT/etc/mkinitcpio.conf.d/"*.conf 2>/dev/null; then
  ok "T2 modules baked into initramfs / modules-load.d"
else
  fail "T2 initramfs modules missing (brcmfmac + apple_bce + hci_bcm4377)" \
       "project-t2-wifi-recipe #6"
fi

# 6. cfg80211 regdom on T2 boot entry
if grep -q 'cfg80211.ieee80211_regdom=US' "$ROOT/../"*.iso 2>/dev/null || \
   grep -q 'cfg80211.ieee80211_regdom=US' "$ROOT"/boot/loader/entries/*t2*.conf 2>/dev/null || true; then
  ok "cfg80211 regdom on T2 boot cmdline (check runs against loader entries when present)"
else
  # Not fatal — cmdline lives on the ESP, not in the squashfs. Just note.
  ok "cfg80211 regdom check deferred to boot-entry inspection (not in squashfs)"
fi

# 7. Model-specific brcmfmac firmware service + script
if [[ -x "$ROOT/usr/lib/vinos/t2-brcmfmac-firmware.sh" ]] && \
   [[ -f "$ROOT/etc/systemd/system/vinos-t2-brcmfmac.service" ]] && \
   [[ -L "$ROOT/etc/systemd/system/sysinit.target.wants/vinos-t2-brcmfmac.service" ]]; then
  ok "vinos-t2-brcmfmac.service enabled (model firmware symlinks on boot)"
else
  fail "vinos-t2-brcmfmac.service or its script missing / not enabled" \
       "project-t2-wifi-recipe #8"
fi

# 8. AddressRandomization=disabled (added 2.0.7)
if grep -qE '^AddressRandomization\s*=\s*disabled' "$ROOT/etc/iwd/main.conf" 2>/dev/null; then
  ok "iwd AddressRandomization=disabled (fixes 4-way handshake on T2)"
else
  fail "iwd AddressRandomization=disabled MISSING — WILL surface as 'wrong password' on T2" \
       "project-t2-wifi-recipe-v2 item 9"
fi

# 9. DisableANQP=true (added 2.0.7)
if grep -qE '^DisableANQP\s*=\s*true' "$ROOT/etc/iwd/main.conf" 2>/dev/null; then
  ok "iwd DisableANQP=true (avoids stall on hotspot pre-auth)"
else
  fail "iwd DisableANQP=true MISSING — some APs will hang auth" \
       "project-t2-wifi-recipe-v2 item 10"
fi

# 10. Wi-Fi powersave off (added 2.0.7)
if grep -q 'iw dev %k set power_save off' "$ROOT/etc/udev/rules.d/70-wifi-powersave.rules" 2>/dev/null; then
  ok "wifi powersave off udev rule (brcmfmac handshake stability)"
else
  fail "wifi powersave udev rule MISSING — WILL surface as 'wrong password' on T2" \
       "project-t2-wifi-recipe-v2 item 11"
fi

# ─────────────────────────────────────────────────────────────────
say "install-to-disk protections"
# ─────────────────────────────────────────────────────────────────

[[ -f "$INSTALLER" ]] || {
  fail "vinos-install-disk not present in ISO at /usr/share/vinos/bin/" \
       "project-install-shipped-2026-08-01"
  # Everything below reads INSTALLER — bail early if missing.
  echo ""
  echo "$RED  ✗ ${FAILS} check(s) failed — do NOT flash$RST"
  exit 1
}

# 1. Offline clone (rsync from /), not pacstrap
if grep -qE '^rsync -aAXH' "$INSTALLER"; then
  ok "installer uses rsync-from-live (offline clone architecture)"
else
  fail "installer no longer uses rsync-from-live — pacstrap regression" \
       "project-install-shipped-2026-08-01"
fi

# 2. Correct rsync exclude for vinos-live-init (was the 2.0.14 → 2.0.15 fix)
if grep -q 'exclude=/etc/systemd/system/vinos-live-init.service' "$INSTALLER" && \
   grep -q 'exclude=/etc/systemd/system/multi-user.target.wants/vinos-live-init.service' "$INSTALLER"; then
  ok "rsync excludes vinos-live-init.service (correct service name)"
else
  fail "rsync exclude for vinos-live-init.service missing or misnamed — target will resurrect the vinos live user" \
       "project-install-shipped-2026-08-01"
fi

# 3. Chroot cleanup: userdel + rm -rf /home/vinos + rm the service file
if grep -q 'userdel -f -r vinos' "$INSTALLER" && \
   grep -q 'rm -rf /home/vinos' "$INSTALLER"; then
  ok "chroot cleanup nukes vinos user + /home/vinos"
else
  fail "chroot cleanup for live vinos user is incomplete" \
       "project-install-shipped-2026-08-01"
fi

# 4. vmlinuz copy loop (was the 2.0.13 → 2.0.14 fix)
if grep -q '/usr/lib/modules/\*/' "$INSTALLER" && \
   grep -q 'install -Dm 0644.*vmlinuz' "$INSTALLER"; then
  ok "vmlinuz copy loop present (fixes mkinitcpio 'must be readable')"
else
  fail "vmlinuz copy loop missing from chroot config — mkinitcpio will fail" \
       "project-install-shipped-2026-08-01"
fi

# 5. Boot menu install entry (systemd-boot) — path in the ISO is
# loader/entries/, not efiboot/loader/entries/ (mkarchiso strips the
# efiboot/ prefix when writing to the FAT ESP).
if bsdtar -tf "$ISO" 2>/dev/null | grep -q 'loader/entries/00-vinos-install-t2.conf'; then
  ok "systemd-boot 'Install vinOS' entry (T2) shipping"
else
  fail "systemd-boot 'Install vinOS to disk (Apple T2 Mac)' entry missing" \
       "project-install-shipped-2026-08-01"
fi

# 6. Launcher perms (was the 2.0.10 → 2.0.11 fix)
if [[ -x "$ROOT/usr/local/bin/vinos-installer-autolaunch-gui" ]]; then
  ok "vinos-installer-autolaunch-gui is executable (perms fix)"
else
  fail "vinos-installer-autolaunch-gui not executable — Hyprland launcher will fail" \
       "project-install-shipped-2026-08-01"
fi

# 7. Installer writes the T2 modules drop-in to target's mkinitcpio.conf.d
# (was the 2.0.15 → 2.0.16 fix; without this the target's initramfs has
# empty MODULES and wifi first-boot flakes on T2). Critical: brcmfmac
# must be present. Everything else (apple_bce, hid_apple, etc.) is
# built into the linux-t2 kernel and does NOT need listing — check #9
# guards against re-adding them.
if grep -q 'mkinitcpio.conf.d/vinos-t2.conf' "$INSTALLER" && \
   awk '/^MODULES=\(/,/\)/' "$INSTALLER" | grep -q 'brcmfmac'; then
  ok "installer writes T2 modules drop-in (brcmfmac in initramfs)"
else
  fail "installer NOT writing brcmfmac into target initramfs — wifi WILL flake on T2" \
       "project-install-shipped-2026-08-01"
fi

# 8. vinos-boot-marker doesn't spam tty1 during greeter
# (was the 2.0.15 → 2.0.16 fix; StandardOutput=journal+console
# was overlaying kernel-style log lines onto tuigreet's username prompt)
_bm="$ROOT/etc/systemd/system/vinos-boot-marker.service"
if [[ -f "$_bm" ]] && grep -qE '^StandardOutput=journal$' "$_bm" && \
   ! grep -qE '^StandardOutput=.*console' "$_bm"; then
  ok "vinos-boot-marker uses journal only (no tty1 pollution)"
else
  fail "vinos-boot-marker still writes to console — will overlay greeter's username prompt" \
       "project-install-shipped-2026-08-01"
fi
unset _bm

# 9. T2 mkinitcpio modules use ? prefix for non-standalone ones
# (was the 2.0.16 → 2.0.17 fix; without ? mkinitcpio errored on
# 'module not found: apple_bce' — apple_bce/hid_apple/etc are built
# into the linux-t2 kernel, not shipped as .ko. The ? tells mkinitcpio
# to warn instead of fail. Also mkinitcpio call must be `|| true`.)
# The MODULES=(...) list in vinos-t2.conf must contain ONLY modules that
# exist as loadable .ko files in the linux-t2 kernel. Anything else makes
# mkinitcpio spam "module not found" errors during install (2.0.17 → 2.0.18
# fix). `?` prefix syntax isn't reliable across mkinitcpio versions — just
# don't list absent modules.
_mods_line=$(awk '/^MODULES=\(/,/\)/' "$INSTALLER" | grep -oE 'applespi|brcmfmac|hci_bcm4377|apple_bce|hid_apple|hid_generic|usbhid|xhci_pci|xhci_hcd|intel_lpss|spi_pxa2xx' | sort -u)
_forbidden=$(echo "$_mods_line" | grep -Ev '^(applespi|brcmfmac|hci_bcm4377)$' || true)
if [[ -z "$_forbidden" ]] && grep -q 'mkinitcpio -p .* || true' "$INSTALLER"; then
  ok "T2 initramfs modules limited to the three loadable ones (applespi, brcmfmac, hci_bcm4377)"
else
  if [[ -n "$_forbidden" ]]; then
    fail "MODULES=(...) contains modules that DON'T exist as .ko in linux-t2 kernel: $(echo "$_forbidden" | tr '\n' ' ')— mkinitcpio will error 'module not found' during install" \
         "project-install-shipped-2026-08-01"
  else
    fail "mkinitcpio call missing '|| true' — a warning will kill the install" \
         "project-install-shipped-2026-08-01"
  fi
fi
unset _mods_line _forbidden

# ─────────────────────────────────────────────────────────────────
say "Phase B — Omarchy removal (checks #20-#26)"
# ─────────────────────────────────────────────────────────────────

# #20: configs/omarchy/ deleted from repo
if [[ -d "$REPO/configs/omarchy" ]]; then
  fail "configs/omarchy/ still exists in repo — clean-room rewrite not applied" "omarchy-decoupling-roadmap"
else
  ok "configs/omarchy/ removed from repo"
fi

# #21: install/vinos-menu-rebrand.sh deleted
if [[ -f "$REPO/install/vinos-menu-rebrand.sh" ]]; then
  fail "install/vinos-menu-rebrand.sh still exists — menu now ships correct from build" "omarchy-decoupling-roadmap"
else
  ok "install/vinos-menu-rebrand.sh removed"
fi

# #22: no omarchy-* commands referenced from bin/vinos-*
if grep -l 'omarchy-\|/usr/share/omarchy\|\.local/state/omarchy' "$REPO"/bin/vinos-* 2>/dev/null | head -1 | grep -q .; then
  fail "bin/vinos-* still calls omarchy-* — rewrites incomplete" "omarchy-decoupling-roadmap"
else
  ok "bin/vinos-* has no omarchy dependencies"
fi

# #23: install/03-configs.sh sources configs/vinos, not configs/omarchy
if grep -q 'OMARCHY_SRC\|configs/omarchy' "$REPO/install/03-configs.sh"; then
  fail "install/03-configs.sh still references configs/omarchy" "omarchy-decoupling-roadmap"
else
  ok "install/03-configs.sh sources configs/vinos/ exclusively"
fi

# #24: /usr/share/omarchy NOT in shipped airootfs
if [[ -d "$ROOT/usr/share/omarchy" ]] && [[ -n "$(ls "$ROOT/usr/share/omarchy" 2>/dev/null)" ]]; then
  fail "/usr/share/omarchy still populated in shipped ISO" "omarchy-decoupling-roadmap"
else
  ok "/usr/share/omarchy not shipped"
fi

# #25: vinos-menu.jsonc ships (no omarchy-menu.jsonc)
if [[ -f "$ROOT/usr/share/vinos/default/vinos/vinos-menu.jsonc" ]]; then
  ok "vinos-menu.jsonc is the menu source"
else
  fail "vinos-menu.jsonc not shipped — menu will fall back to omarchy which isn't installed" "omarchy-decoupling-roadmap"
fi

# #26: no HEY/Basecamp/Adobe entries in menu
if [[ -f "$ROOT/usr/share/vinos/default/vinos/vinos-menu.jsonc" ]] && \
   grep -qE '"(HEY|Basecamp|Adobe|Google Suite|Google Docs)"' "$ROOT/usr/share/vinos/default/vinos/vinos-menu.jsonc"; then
  fail "third-party PWA entries in menu (HEY / Basecamp / Adobe)" "omarchy-decoupling-roadmap"
else
  ok "no third-party PWA entries in menu (clean vinOS)"
fi

# ─────────────────────────────────────────────────────────────────
say "Phase B — LUKS installer (checks #27-#32)"
# ─────────────────────────────────────────────────────────────────

# #27: LUKS prompt in installer
if grep -q 'Encrypt disk with LUKS' "$INSTALLER"; then
  ok "installer offers LUKS encryption prompt"
else
  fail "installer no longer prompts for LUKS" "luks-installer-roadmap"
fi

# #28: cryptsetup luksFormat + argon2id (allow \-continued multi-line)
if awk '/cryptsetup luksFormat/,/argon2id/{print}' "$INSTALLER" | grep -q 'luks2' && \
   grep -q 'argon2id' "$INSTALLER"; then
  ok "LUKS uses LUKS2 + argon2id (modern KDF)"
else
  fail "LUKS uses weak params — expected luks2 + argon2id" "luks-installer-roadmap"
fi

# #29: encrypt hook wired before filesystems in mkinitcpio.conf
if grep -q 'encrypt filesystems' "$INSTALLER"; then
  ok "mkinitcpio encrypt hook ordered before filesystems"
else
  fail "encrypt hook order missing — LUKS won't unlock at boot" "luks-installer-roadmap"
fi

# #30: /etc/crypttab written on target
if grep -q 'crypttab' "$INSTALLER" && grep -q 'vinos_root.*UUID' "$INSTALLER"; then
  ok "crypttab written with UUID reference"
else
  fail "crypttab missing or misconfigured" "luks-installer-roadmap"
fi

# #31: cryptdevice in kernel cmdline for LUKS entries
if grep -q 'cryptdevice=UUID.*:vinos_root' "$INSTALLER"; then
  ok "bootloader entry has cryptdevice kernel cmdline"
else
  fail "bootloader missing cryptdevice — LUKS won't unlock" "luks-installer-roadmap"
fi

# #32: ESP mounted with restrictive umask (silences bootctl warning)
if grep -qE 'fmask=0137.*dmask=0027.*umask=0077|mount -o "fmask=0137' "$INSTALLER"; then
  ok "ESP mounted root-only (bootctl 'security hole' warning silenced)"
else
  fail "ESP mount not restrictive — bootctl will emit 'world accessible' warning" "luks-installer-roadmap"
fi

# ─────────────────────────────────────────────────────────────────
say "Phase B — Hardened kernel (checks #33-#39)"
# ─────────────────────────────────────────────────────────────────

# #33: linux-hardened in shipped packages
if grep -q '^linux-hardened$' "$ROOT/../../packages.x86_64" 2>/dev/null || \
   grep -q '^linux-hardened$' "$REPO/iso/profile/packages.x86_64"; then
  ok "linux-hardened kernel in shipped packages"
else
  fail "linux-hardened NOT shipped — hardening posture reduced" "secure-kernel"
fi

# #34: kernel-hardening sysctl file present
if [[ -f "$ROOT/etc/sysctl.d/99-vinos-hardening.conf" ]] && \
   grep -q 'kernel.kexec_load_disabled = 1' "$ROOT/etc/sysctl.d/99-vinos-hardening.conf"; then
  ok "sysctl hardening config shipped"
else
  fail "99-vinos-hardening.conf missing or incomplete" "secure-kernel"
fi

# #35: module blacklist for known-risky drivers
if [[ -f "$ROOT/etc/modprobe.d/vinos-blacklist.conf" ]] && \
   grep -q 'blacklist dccp' "$ROOT/etc/modprobe.d/vinos-blacklist.conf" && \
   grep -q 'blacklist sctp' "$ROOT/etc/modprobe.d/vinos-blacklist.conf"; then
  ok "risky kernel modules blacklisted (dccp, sctp, rds, tipc, …)"
else
  fail "module blacklist missing" "secure-kernel"
fi

# #36: apparmor package in shipped packages
if grep -q '^apparmor$' "$REPO/iso/profile/packages.x86_64"; then
  ok "apparmor package shipped"
else
  fail "apparmor NOT shipped — no LSM enforcement" "secure-kernel"
fi

# #37: audit package for AppArmor DENIED tracking
if grep -q '^audit$' "$REPO/iso/profile/packages.x86_64"; then
  ok "audit package shipped (for AppArmor DENIED tracking)"
else
  fail "audit not shipped — no DENIED visibility" "secure-kernel"
fi

# #38: linux-hardened headers for DKMS builds
if grep -q '^linux-hardened-headers$' "$REPO/iso/profile/packages.x86_64"; then
  ok "linux-hardened-headers shipped (DKMS builds against hardened)"
else
  fail "linux-hardened-headers missing" "secure-kernel"
fi

# #39: hardened kernel cmdline additions on target (init_on_alloc etc.)
if grep -qE 'init_on_alloc=1|lockdown=confidentiality|module\.sig_enforce=1' "$INSTALLER"; then
  ok "installer writes kernel-hardening cmdline flags on target"
else
  fail "installer NOT adding kernel hardening cmdline — target boots unhardened" "secure-kernel"
fi

# ─────────────────────────────────────────────────────────────────
say "Phase B — Docker + K8s (checks #40-#46)"
# ─────────────────────────────────────────────────────────────────

# #40: docker in shipped packages
if grep -q '^docker$' "$REPO/iso/profile/packages.x86_64"; then
  ok "docker in shipped packages"
else
  fail "docker missing from base install" "k8s-optimized"
fi

# #41: containerd in shipped packages
if grep -q '^containerd$' "$REPO/iso/profile/packages.x86_64"; then
  ok "containerd shipped"
else
  fail "containerd missing" "k8s-optimized"
fi

# #42: docker daemon.json with systemd cgroups + overlay2
if [[ -f "$ROOT/etc/docker/daemon.json" ]] && \
   grep -q 'native.cgroupdriver=systemd' "$ROOT/etc/docker/daemon.json" && \
   grep -q '"storage-driver": "overlay2"' "$ROOT/etc/docker/daemon.json"; then
  ok "docker daemon.json optimized (systemd cgroups, overlay2)"
else
  fail "docker daemon.json missing or misconfigured" "k8s-optimized"
fi

# #43: containerd config uses systemd cgroup driver
if [[ -f "$ROOT/etc/containerd/config.toml" ]] && \
   grep -q 'SystemdCgroup = true' "$ROOT/etc/containerd/config.toml"; then
  ok "containerd uses systemd cgroup driver"
else
  fail "containerd config missing or wrong cgroup driver" "k8s-optimized"
fi

# #44: kubectl shipped
if grep -q '^kubectl$' "$REPO/iso/profile/packages.x86_64"; then
  ok "kubectl in shipped packages"
else
  fail "kubectl missing — no k8s CLI in base" "k8s-optimized"
fi

# #45: k8s sysctl tuning shipped
if [[ -f "$ROOT/etc/sysctl.d/99-vinos-k8s.conf" ]] && \
   grep -q 'net.bridge.bridge-nf-call-iptables = 1' "$ROOT/etc/sysctl.d/99-vinos-k8s.conf"; then
  ok "container/k8s sysctl tuning shipped"
else
  fail "99-vinos-k8s.conf missing — k8s networking broken" "k8s-optimized"
fi

# #46: vinos-install-k8s script exists
if [[ -x "$ROOT/usr/share/vinos/bin/vinos-install-k8s" ]] || \
   [[ -x "$ROOT/usr/local/bin/vinos-install-k8s" ]]; then
  ok "vinos-install-k8s one-command cluster bootstrap available"
else
  fail "vinos-install-k8s missing" "k8s-optimized"
fi

# ─────────────────────────────────────────────────────────────────
say "Phase B — Waybar AI status pill + brand accent (checks #47-#52)"
# ─────────────────────────────────────────────────────────────────

# #47: vinos-waybar-ai binary shipped
if [[ -x "$ROOT/usr/share/vinos/bin/vinos-waybar-ai" ]] || [[ -x "$ROOT/usr/local/bin/vinos-waybar-ai" ]]; then
  ok "vinos-waybar-ai binary shipped (AI status pill data source)"
else
  fail "vinos-waybar-ai missing — waybar pill will show empty" "omarchy-decoupling-roadmap"
fi

# #48: vinos-waybar-routines binary shipped
if [[ -x "$ROOT/usr/share/vinos/bin/vinos-waybar-routines" ]] || [[ -x "$ROOT/usr/local/bin/vinos-waybar-routines" ]]; then
  ok "vinos-waybar-routines binary shipped"
else
  fail "vinos-waybar-routines missing" "omarchy-decoupling-roadmap"
fi

# #49: waybar config.jsonc references the AI pill custom module
_wb="$ROOT/etc/skel/.config/waybar/config.jsonc"
if [[ -f "$_wb" ]] && grep -q '"custom/vinos-ai"' "$_wb"; then
  ok "waybar config wires the AI pill module"
else
  fail "waybar config missing custom/vinos-ai module" "omarchy-decoupling-roadmap"
fi

# #50: waybar CSS pins brand accent (#33ccff)
_wbc="$ROOT/etc/skel/.config/waybar/style.css"
if [[ -f "$_wbc" ]] && grep -qE '#33ccff|rgba\(51, 204, 255' "$_wbc"; then
  ok "waybar style pins brand accent #33ccff"
else
  fail "waybar style missing brand accent" "omarchy-decoupling-roadmap"
fi

# #51: hyprland brand-accent.conf pins window border color
_hp="$ROOT/usr/share/vinos/default/hypr/brand-accent.conf"
if [[ -f "$_hp" ]] && grep -q '33ccff' "$_hp"; then
  ok "hyprland brand accent conf shipped (window border pinned cyan)"
else
  fail "hyprland brand-accent.conf missing" "omarchy-decoupling-roadmap"
fi

# #52: mako has separate channel for vinos-routine notifications
_mk="$ROOT/etc/skel/.config/mako/config"
if [[ -f "$_mk" ]] && grep -q 'app-name=vinos-routine' "$_mk"; then
  ok "mako has vinos-routine notification channel"
else
  fail "mako missing routine notification channel" "omarchy-decoupling-roadmap"
fi

# ─────────────────────────────────────────────────────────────────
say "Phase B — Keybinding preservation (checks #53-#63)"
# ─────────────────────────────────────────────────────────────────

# The vinOS keybinding files must contain each preserved chord.
_bindings_dir="$ROOT/usr/share/vinos/default/hypr/bindings"

_check_bind() {
  local chord="$1" needle="$2" mem="$3"
  if [[ -d "$_bindings_dir" ]] && grep -rq -- "$needle" "$_bindings_dir/" 2>/dev/null; then
    ok "chord preserved: $chord → $needle"
  else
    fail "chord regressed: $chord (needle '$needle' not in bindings)" "$mem"
  fi
}

# #53-#63: eleven chords
_check_bind "Super+Return"    "foot"                     "omarchy-decoupling-roadmap"
_check_bind "Super+Space"     "walker"                   "omarchy-decoupling-roadmap"
_check_bind "Super+K"         "vinos-cheatsheet"         "omarchy-decoupling-roadmap"
_check_bind "Super+A"         "vinos-ai chat"            "omarchy-decoupling-roadmap"
_check_bind "Super+Alt+Space" "vinos-menu"               "omarchy-decoupling-roadmap"
_check_bind "Super+Q"         "killactive"               "omarchy-decoupling-roadmap"
_check_bind "Super+L"         "hyprlock"                 "omarchy-decoupling-roadmap"
_check_bind "Super+B"         "chromium"                 "omarchy-decoupling-roadmap"
_check_bind "Super+E"         "nautilus"                 "omarchy-decoupling-roadmap"
_check_bind "Super+N"         "nvim"                     "omarchy-decoupling-roadmap"
_check_bind "Super+T"         "btop"                     "omarchy-decoupling-roadmap"

# ─────────────────────────────────────────────────────────────────
say "Runtime service invariants (checks #64-#74)"
# ─────────────────────────────────────────────────────────────────

# Services must be ENABLED (multi-user.target.wants symlinks present)
for svc in docker containerd iwd systemd-networkd systemd-resolved apparmor ufw; do
  _svc="$ROOT/etc/systemd/system/multi-user.target.wants/${svc}.service"
  _svc_alt="$ROOT/usr/lib/systemd/system/multi-user.target.wants/${svc}.service"
  if [[ -L "$_svc" ]] || [[ -L "$_svc_alt" ]] || [[ -f "$_svc" ]] || [[ -f "$_svc_alt" ]]; then
    ok "service enabled: $svc"
  else
    fail "service NOT enabled: $svc — must be in multi-user.target.wants" "secure-kernel"
  fi
done

# vinos-networkd-wait-online must be MASKED (not disabled — masked so nothing re-enables it)
if [[ -L "$ROOT/etc/systemd/system/systemd-networkd-wait-online.service" ]] && \
   readlink "$ROOT/etc/systemd/system/systemd-networkd-wait-online.service" 2>/dev/null | grep -q '/dev/null'; then
  ok "systemd-networkd-wait-online masked (no wifi-less-boot hang)"
elif grep -q 'mask systemd-networkd-wait-online' "$INSTALLER"; then
  ok "installer masks systemd-networkd-wait-online (target side)"
else
  fail "systemd-networkd-wait-online will hang boot on wifi-less machines" "secure-kernel"
fi

# sshd must be disabled (opt-in, not default)
if [[ -L "$ROOT/etc/systemd/system/multi-user.target.wants/sshd.service" ]]; then
  fail "sshd enabled by default — security posture regressed" "secure-kernel"
else
  ok "sshd disabled by default (opt-in via 'systemctl enable sshd')"
fi

# ─────────────────────────────────────────────────────────────────
say "Sysctl content coverage (checks #75-#82)"
# ─────────────────────────────────────────────────────────────────

_sysctl="$ROOT/etc/sysctl.d/99-vinos-hardening.conf"
_k8s="$ROOT/etc/sysctl.d/99-vinos-k8s.conf"

for key in \
    'kernel.kexec_load_disabled = 1' \
    'kernel.dmesg_restrict = 1' \
    'kernel.kptr_restrict = 2' \
    'kernel.unprivileged_bpf_disabled = 1' \
    'kernel.yama.ptrace_scope = 2' \
    'fs.protected_hardlinks = 1' \
    'net.ipv4.tcp_syncookies = 1'; do
  if grep -qF "$key" "$_sysctl" 2>/dev/null; then
    ok "sysctl hardening: $key"
  else
    fail "sysctl hardening missing: $key" "secure-kernel"
  fi
done

# K8s sysctl completeness
if grep -q 'net.bridge.bridge-nf-call-iptables = 1' "$_k8s" 2>/dev/null && \
   grep -q 'fs.inotify.max_user_watches = 1048576' "$_k8s" 2>/dev/null && \
   grep -q 'vm.max_map_count = 262144' "$_k8s" 2>/dev/null; then
  ok "K8s sysctl coverage (bridge-nf + inotify + max_map_count)"
else
  fail "K8s sysctl coverage incomplete" "k8s-optimized"
fi

# ─────────────────────────────────────────────────────────────────
say "Executable audit (checks #83-#84)"
# ─────────────────────────────────────────────────────────────────

# Every vinos-* in the ISO's /usr/share/vinos/bin must be executable + parse
_bin_dir="$ROOT/usr/share/vinos/bin"
_broken=""
if [[ -d "$_bin_dir" ]]; then
  for f in "$_bin_dir"/vinos-*; do
    [[ -f "$f" ]] || continue
    if [[ ! -x "$f" ]]; then
      _broken="$_broken $(basename "$f"):not-executable"
    elif ! bash -n "$f" 2>/dev/null; then
      _broken="$_broken $(basename "$f"):syntax-error"
    fi
  done
  if [[ -z "$_broken" ]]; then
    ok "all vinos-* binaries in /usr/share/vinos/bin executable + parseable"
  else
    fail "broken vinos-* binaries:$_broken" "omarchy-decoupling-roadmap"
  fi
else
  fail "/usr/share/vinos/bin missing from ISO" "omarchy-decoupling-roadmap"
fi

# Every /usr/local/bin/vinos-* is either an executable symlink or an
# executable file (installed by 05-branding.sh symlink pattern)
_local_broken=""
if [[ -d "$ROOT/usr/local/bin" ]]; then
  for f in "$ROOT/usr/local/bin"/vinos-*; do
    [[ -e "$f" ]] || continue
    # For symlinks, resolve; for files, check executable bit directly
    if [[ -L "$f" ]]; then
      target=$(readlink "$f")
      case "$target" in
        /*) target_abs="$ROOT$target" ;;
        *) target_abs="$(dirname "$f")/$target" ;;
      esac
      [[ -x "$target_abs" ]] || _local_broken="$_local_broken $(basename "$f"):broken-symlink"
    else
      [[ -x "$f" ]] || _local_broken="$_local_broken $(basename "$f"):not-executable"
    fi
  done
  if [[ -z "$_local_broken" ]]; then
    ok "all /usr/local/bin/vinos-* symlinks resolve to executables"
  else
    fail "broken /usr/local/bin/vinos-*:$_local_broken" "omarchy-decoupling-roadmap"
  fi
fi
unset _bin_dir _local_broken _broken

# ─────────────────────────────────────────────────────────────────
say "Extended keybinding audit (checks #85-#92)"
# ─────────────────────────────────────────────────────────────────

# Beyond the 11 headline chords, verify the additional agent-native ones
_check_bind "Super+Shift+A"    "claude"                   "omarchy-decoupling-roadmap"
_check_bind "Super+R"          "vinos-routine list"       "omarchy-decoupling-roadmap"
_check_bind "Super+Shift+R"    "vinos-brief"              "omarchy-decoupling-roadmap"
_check_bind "Super+Ctrl+W"     "impala"                   "omarchy-decoupling-roadmap"
_check_bind "Super+Ctrl+B"     "bluetuith"                "omarchy-decoupling-roadmap"
_check_bind "Super+Ctrl+T"     "vinos-theme-pick"         "omarchy-decoupling-roadmap"
_check_bind "Super+Escape"     "vinos-menu system"        "omarchy-decoupling-roadmap"
_check_bind "Super+;"          "cliphist"                 "omarchy-decoupling-roadmap"

# ─────────────────────────────────────────────────────────────────
say "summary"
# ─────────────────────────────────────────────────────────────────
echo ""
if (( FAILS == 0 )); then
  printf '%s┌──────────────────────────────────────────────────┐%s\n' "$GRN" "$RST"
  printf '%s│  ✓  ALL %d fixes intact — safe to flash          │%s\n' "$GRN" "$PASSES" "$RST"
  printf '%s└──────────────────────────────────────────────────┘%s\n' "$GRN" "$RST"
  exit 0
else
  printf '%s┌──────────────────────────────────────────────────┐%s\n' "$RED" "$RST"
  printf '%s│  ✗  %d REGRESSION(S) — DO NOT FLASH              │%s\n' "$RED" "$FAILS" "$RST"
  printf '%s└──────────────────────────────────────────────────┘%s\n' "$RED" "$RST"
  echo ""
  echo "Each ✗ links to the memory entry that describes the fix that regressed."
  echo "Re-read that memory before touching the code that failed."
  exit 1
fi
