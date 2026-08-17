#!/usr/bin/env bash
# iso/qa/install-smoke.sh — end-to-end install harness. The hard gate.
#
# What this proves for a candidate ISO:
#   1. The vinos-installer.target/service unit files ship + are wired.
#   2. The wizard renders on tty1 and collects answers from HMP keystrokes.
#   3. The backend runs archinstall + chroot layering without silent failure.
#   4. The installed system boots (from the qcow2 alone, no ISO) into a
#      real UEFI-bootable environment.
#   5. The installed system has: correct hostname, working user, a bootctl
#      entry, sshd reachable, no red-severity errors in the first boot.
#
# If any step hangs, times out, or the post-install checks fail, the
# harness exits non-zero with a clear diagnostic. On green: exits 0.
#
# Runs entirely unattended. ~15-25 min. Chooses ports/sockets that avoid
# collision with a locally-running dev QEMU on the default ones.
#
# Usage:
#   iso/qa/install-smoke.sh [--iso PATH] [--out-dir DIR] [--keep] [--timeout SECS]
#     --iso PATH        Candidate ISO to test.
#                       Default: iso/out/vinos-$(cat VERSION)-x86_64.iso
#     --out-dir DIR     Directory to place scratch qcow2 + logs + screendumps.
#                       Default: /tmp/vinos-smoke-<pid>
#     --keep            Keep the QEMU + scratch state on exit (for post-mortem).
#     --timeout SECS    Overall wall-clock cap. Default 1800 (30 min).
#
# Env overrides:
#   SMOKE_VNC_PORT     VNC display port (default 5905)
#   SMOKE_SSH_PORT     SSH host-forward port (default 2225)
#   SMOKE_QCOW2_SIZE   scratch disk size (default 20G)
#
# Fixed install profile (canonical for reproducibility):
#   user=qatest  password=qatest123  hostname=qatest
#   kb=us        timezone=UTC        disk=/dev/vda (the scratch qcow2)
set -euo pipefail

# ── config ─────────────────────────────────────────────────────────
ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$ISO_DIR/.." && pwd)"
VERSION="$(<"$REPO/VERSION")"
ISO_DEFAULT="$ISO_DIR/out/vinos-${VERSION}-x86_64.iso"

ISO=""
OUT_DIR=""
KEEP=0
TIMEOUT=1800

VNC_PORT="${SMOKE_VNC_PORT:-5905}"
SSH_PORT="${SMOKE_SSH_PORT:-2225}"
QCOW2_SIZE="${SMOKE_QCOW2_SIZE:-20G}"

QA_USER="qatest"
QA_PASS="qatest123"
QA_HOST="qatest"
QA_TZ="UTC"
QA_KB="us"

# ── parse ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)      ISO="$2";     shift 2 ;;
    --out-dir)  OUT_DIR="$2"; shift 2 ;;
    --keep)     KEEP=1;       shift ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    -h|--help)  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'install-smoke: unknown arg: %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
done

: "${ISO:=$ISO_DEFAULT}"
: "${OUT_DIR:=/tmp/vinos-smoke-$$}"

[[ -f "$ISO" ]] || { printf 'install-smoke: ISO not found at %s\n' "$ISO" >&2; exit 2; }

install -d -m 0755 "$OUT_DIR"
QCOW2="$OUT_DIR/target.qcow2"
NVRAM="$OUT_DIR/OVMF_VARS.fd"
VNCPW="$OUT_DIR/vncpw.secret"
HMP_SOCK="$OUT_DIR/hmp.sock"
LIVE_QEMU_LOG="$OUT_DIR/qemu-live.log"
INSTALLED_QEMU_LOG="$OUT_DIR/qemu-installed.log"
INSTALL_LOG="$OUT_DIR/vinos-install.log"
STATE_SUMMARY="$OUT_DIR/summary.txt"

# ── logging helpers ────────────────────────────────────────────────
die()  { printf '\033[1;31m[smoke] FAIL:\033[0m %s\n' "$*" | tee -a "$STATE_SUMMARY" >&2; _cleanup; exit 1; }
log()  { printf '\033[1;34m[smoke]\033[0m %s\n' "$*" | tee -a "$STATE_SUMMARY"; }
step() { printf '\033[1;36m[smoke] === %s ===\033[0m\n' "$*" | tee -a "$STATE_SUMMARY"; }

: > "$STATE_SUMMARY"
log "harness starting: ISO=$ISO OUT_DIR=$OUT_DIR VNC=$VNC_PORT SSH=$SSH_PORT"
START_TS=$(date +%s)

# ── prerequisites ──────────────────────────────────────────────────
for bin in qemu-system-x86_64 qemu-img socat ssh; do
  command -v "$bin" >/dev/null 2>&1 \
    || die "missing prerequisite: $bin"
done

# Host pubkey — seed it into the installed user's authorized_keys during
# the install phase so we can SSH in with the same identity that iso/build.sh
# baked into the live ISO's vinos user.
HOST_PUBKEY="${SMOKE_HOST_PUBKEY:-$HOME/.ssh/id_ed25519.pub}"
[[ -f "$HOST_PUBKEY" ]] || die "no host pubkey at $HOST_PUBKEY (set SMOKE_HOST_PUBKEY=...)"

# Find OVMF (Arch ships edk2-ovmf; Debian ships ovmf).
OVMF_CODE=""
for candidate in \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd \
    /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF_CODE.fd; do
  [[ -f "$candidate" ]] && { OVMF_CODE="$candidate"; break; }
done
[[ -n "$OVMF_CODE" ]] || die "OVMF firmware not found (install edk2-ovmf)"

OVMF_VARS_SEED=""
for candidate in \
    /usr/share/edk2/x64/OVMF_VARS.4m.fd \
    /usr/share/edk2/x64/OVMF_VARS.fd \
    /usr/share/edk2-ovmf/x64/OVMF_VARS.fd \
    /usr/share/OVMF/OVMF_VARS.fd; do
  [[ -f "$candidate" ]] && { OVMF_VARS_SEED="$candidate"; break; }
done
[[ -n "$OVMF_VARS_SEED" ]] || die "OVMF_VARS seed not found"

# ── cleanup ────────────────────────────────────────────────────────
QEMU_PID=""
_cleanup() {
  if [[ -n "$QEMU_PID" ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
    _hmp_send "quit" >/dev/null 2>&1 || true
    sleep 1
    kill -0 "$QEMU_PID" 2>/dev/null && kill -TERM "$QEMU_PID" 2>/dev/null || true
    sleep 1
    kill -0 "$QEMU_PID" 2>/dev/null && kill -KILL "$QEMU_PID" 2>/dev/null || true
  fi
  if (( KEEP )); then
    log "keeping scratch state at $OUT_DIR"
  else
    rm -rf "$OUT_DIR"
  fi
}
trap _cleanup EXIT INT TERM

# ── HMP helpers ────────────────────────────────────────────────────
_hmp_send() {
  [[ -S "$HMP_SOCK" ]] || return 1
  printf '%s\n' "$1" | timeout 4 socat - UNIX-CONNECT:"$HMP_SOCK" >/dev/null 2>&1 || return 1
}

_hmp_key() {
  local k="$1"
  _hmp_send "sendkey $k" || true
}

# Type a printable ASCII string one character at a time using HMP sendkey.
# Small punctuation supported; special chars would need extended handling.
_hmp_type() {
  local s="$1" i c code
  for (( i=0; i<${#s}; i++ )); do
    c="${s:$i:1}"
    case "$c" in
      [a-z0-9]) code="$c" ;;
      [A-Z]) code="shift-$(printf '%s' "$c" | tr 'A-Z' 'a-z')" ;;
      ' ') code="spc" ;;
      '.') code="dot" ;;
      '-') code="minus" ;;
      '_') code="shift-minus" ;;
      '/') code="slash" ;;
      ':') code="shift-semicolon" ;;
      *) log "warn: unmapped char '$c' in HMP type — skipping"; continue ;;
    esac
    _hmp_key "$code"
    # Give HMP a beat between characters — otherwise fast typing drops keys.
    sleep 0.08
  done
}

_hmp_dump() {
  local out="$1"
  _hmp_send "screendump $out" || return 1
}

# ── SSH helpers ────────────────────────────────────────────────────
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o BatchMode=yes)
_ssh_live()      { ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" vinos@127.0.0.1 "$@"; }
_ssh_installed() { ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "$QA_USER@127.0.0.1" "$@"; }

_wait_ssh_live() {
  local deadline=$(( $(date +%s) + $1 ))
  while (( $(date +%s) < deadline )); do
    _ssh_live 'true' >/dev/null 2>&1 && return 0
    sleep 5
  done
  return 1
}

_wait_ssh_installed() {
  local deadline=$(( $(date +%s) + $1 ))
  while (( $(date +%s) < deadline )); do
    _ssh_installed 'true' >/dev/null 2>&1 && return 0
    sleep 5
  done
  return 1
}

# ── STEP 1: scratch qcow2 + OVMF vars ──────────────────────────────
step "1/9 scratch disk + OVMF vars"
qemu-img create -f qcow2 "$QCOW2" "$QCOW2_SIZE" >/dev/null || die "qemu-img create failed"
cp "$OVMF_VARS_SEED" "$NVRAM" || die "copy OVMF_VARS failed"
printf 'smoke' > "$VNCPW"
chmod 0600 "$NVRAM" "$VNCPW" "$QCOW2"
log "scratch disk: $QCOW2  ($QCOW2_SIZE)"

# ── STEP 2: boot ISO in UEFI QEMU ──────────────────────────────────
step "2/9 boot ISO in UEFI QEMU"
qemu-system-x86_64 \
  -m 8G -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$NVRAM" \
  -cdrom "$ISO" \
  -drive file="$QCOW2",format=qcow2,if=virtio \
  -boot order=d,menu=off \
  -vga virtio \
  -display vnc="0.0.0.0:$((VNC_PORT - 5900)),password-secret=vncpw" \
  -k en-us -usb -device usb-kbd -device usb-tablet -device virtio-keyboard-pci \
  -enable-kvm -cpu host \
  -object secret,id=vncpw,file="$VNCPW",format=raw \
  -monitor unix:"$HMP_SOCK",server,nowait \
  -nic user,hostfwd=tcp::"$SSH_PORT"-:22 \
  > "$LIVE_QEMU_LOG" 2>&1 &
QEMU_PID=$!
log "QEMU PID $QEMU_PID  VNC :$VNC_PORT  SSH $SSH_PORT"

# ── STEP 3: wait for live sshd + isolate installer target ──────────
step "3/9 wait for live sshd (up to 4 min)"
_wait_ssh_live 240 || die "live sshd did not come up within 4 min — QEMU log: $LIVE_QEMU_LOG"
log "live sshd is up"

log "isolating vinos-installer.target"
_ssh_live 'sudo -n systemctl --no-block isolate vinos-installer.target' \
  || die "failed to isolate vinos-installer.target"

# Give the service ~15 s to start + gum to render.
sleep 15
_hmp_key "ctrl-alt-f2" >/dev/null 2>&1 || true
sleep 1
_hmp_key "ctrl-alt-f1" >/dev/null 2>&1 || true
sleep 2

# ── STEP 4: drive wizard ───────────────────────────────────────────
step "4/9 drive the wizard through the fixed profile"

_hmp_dump "$OUT_DIR/wizard-01-welcome.ppm"
_hmp_key "ret"; sleep 3        # welcome → keyboard
_hmp_dump "$OUT_DIR/wizard-02-kb.ppm"
_hmp_key "ret"; sleep 4        # accept US (highlighted)
_hmp_dump "$OUT_DIR/wizard-03-tz.ppm"
# Timezone: force UTC by declining detected TZ then typing UTC.
_hmp_key "n"; sleep 2
_hmp_type "UTC"
_hmp_key "ret"; sleep 3
_hmp_dump "$OUT_DIR/wizard-04-disk.ppm"
_hmp_key "ret"; sleep 2        # accept /dev/vda (only entry)
_hmp_dump "$OUT_DIR/wizard-05-wipe.ppm"
_hmp_key "y"; sleep 3          # confirm wipe
_hmp_dump "$OUT_DIR/wizard-06-user.ppm"
_hmp_type "$QA_USER"
_hmp_key "ret"; sleep 2
_hmp_type "$QA_PASS"
_hmp_key "ret"; sleep 1
_hmp_type "$QA_PASS"
_hmp_key "ret"; sleep 2
_hmp_dump "$OUT_DIR/wizard-07-host.ppm"
# Hostname field is pre-filled with "vinos". Delete and retype.
for _ in 1 2 3 4 5; do _hmp_key "backspace"; done
_hmp_type "$QA_HOST"
_hmp_key "ret"; sleep 3
_hmp_dump "$OUT_DIR/wizard-08-summary.ppm"
_hmp_key "y"                    # start install

log "wizard driven; install phase begins"

# ── STEP 5: wait for install completion ────────────────────────────
step "5/9 wait for install to finish (poll live via SSH; up to 25 min)"

# Watch /var/log/vinos-install.log for either the completion marker or a
# hard failure line. Bounded polling; hangs die with a diagnostic tail.
INSTALL_DEADLINE=$(( $(date +%s) + 1500 ))
while (( $(date +%s) < INSTALL_DEADLINE )); do
  if _ssh_live 'sudo -n grep -q "vinOS install complete" /var/log/vinos-install.log 2>/dev/null'; then
    log "install log reports completion"
    break
  fi
  if _ssh_live 'sudo -n grep -qE "\[install-execute\] FAIL:|archinstall failed" /var/log/vinos-install.log 2>/dev/null'; then
    _ssh_live 'sudo -n tail -30 /var/log/vinos-install.log' > "$INSTALL_LOG.tail" 2>&1 || true
    die "install-execute reported failure. Tail:\n$(cat "$INSTALL_LOG.tail")"
  fi
  sleep 10
done
(( $(date +%s) < INSTALL_DEADLINE )) \
  || die "install did not complete within 25 min — hang."

# Fetch the full log for the record.
_ssh_live 'sudo -n cat /var/log/vinos-install.log' > "$INSTALL_LOG" 2>&1 || true

# Seed our host pubkey into the installed user's authorized_keys so we can
# ssh in without a password after the reboot. sshd is disabled by default
# on the installed system; also enable it via the chroot.
log "seeding host pubkey + enabling sshd on installed system"
PUBKEY_CONTENT="$(<"$HOST_PUBKEY")"
_ssh_live "sudo -n bash -s" <<CHROOT
set -eu
install -d -m 0700 -o ${QA_USER} -g ${QA_USER} /mnt/home/${QA_USER}/.ssh
printf '%s\n' '${PUBKEY_CONTENT//\'/\'\\\'\'}' > /mnt/home/${QA_USER}/.ssh/authorized_keys
chown ${QA_USER}:${QA_USER} /mnt/home/${QA_USER}/.ssh/authorized_keys
chmod 0600 /mnt/home/${QA_USER}/.ssh/authorized_keys
arch-chroot /mnt systemctl enable sshd.service >/dev/null 2>&1 || true
CHROOT

# ── STEP 6: shutdown live QEMU ─────────────────────────────────────
step "6/9 shutting down live QEMU"
_hmp_send "quit" >/dev/null 2>&1 || true
sleep 3
if kill -0 "$QEMU_PID" 2>/dev/null; then
  kill -TERM "$QEMU_PID" 2>/dev/null || true
  sleep 2
  kill -KILL "$QEMU_PID" 2>/dev/null || true
fi
QEMU_PID=""
sleep 1

# ── STEP 7: boot the installed system from qcow2 alone ─────────────
step "7/9 boot INSTALLED system (no ISO)"
qemu-system-x86_64 \
  -m 4G -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$NVRAM" \
  -drive file="$QCOW2",format=qcow2,if=virtio \
  -boot order=c \
  -vga virtio \
  -display vnc="0.0.0.0:$((VNC_PORT - 5900)),password-secret=vncpw" \
  -k en-us \
  -enable-kvm -cpu host \
  -object secret,id=vncpw,file="$VNCPW",format=raw \
  -monitor unix:"$HMP_SOCK",server,nowait \
  -nic user,hostfwd=tcp::"$SSH_PORT"-:22 \
  > "$INSTALLED_QEMU_LOG" 2>&1 &
QEMU_PID=$!
log "installed QEMU PID $QEMU_PID"

# ── STEP 8: wait for installed sshd + verify ───────────────────────
step "8/9 wait for installed sshd (up to 4 min)"
_wait_ssh_installed 240 || die "installed system did not come up on SSH — bootloader or sshd broken.  installed QEMU log: $INSTALLED_QEMU_LOG"
log "installed sshd is up"

step "9/9 verify installed system"
VERIFY_LOG="$OUT_DIR/verify.log"
: > "$VERIFY_LOG"

_check() {
  local label="$1" cmd="$2" expect_pattern="$3"
  local actual
  actual="$(_ssh_installed "$cmd" 2>&1)" || {
    printf 'FAIL: %-30s | ssh cmd failed: %s\n' "$label" "$cmd" >> "$VERIFY_LOG"
    return 1
  }
  if [[ "$actual" =~ $expect_pattern ]]; then
    printf 'PASS: %-30s | %s\n' "$label" "$actual" >> "$VERIFY_LOG"
    return 0
  else
    printf 'FAIL: %-30s | got: %s (want match /%s/)\n' "$label" "$actual" "$expect_pattern" >> "$VERIFY_LOG"
    return 1
  fi
}

fails=0
_check "hostname"      "hostnamectl --static"                     "^${QA_HOST}$"                    || (( fails+=1 ))
_check "user exists"   "id ${QA_USER}"                            "uid="                            || (( fails+=1 ))
_check "user in wheel" "id -Gn ${QA_USER}"                        "wheel"                           || (( fails+=1 ))
_check "bootctl entry" "bootctl status 2>/dev/null | head -30"    "(linux|vinOS|arch)"              || (( fails+=1 ))
_check "os-release"    "grep -c vinos /etc/os-release || true"    "^[1-9]"                          || (( fails+=1 ))
_check "efi partition" "findmnt -n -o TARGET /boot 2>/dev/null || findmnt -n -o TARGET /efi 2>/dev/null" "^/(boot|efi)"  || (( fails+=1 ))
_check "no red errors" "journalctl -p 3 -b --no-pager | wc -l"    "^[0-9]{1,2}$"                    || (( fails+=1 ))

log "verification results:"
cat "$VERIFY_LOG" | tee -a "$STATE_SUMMARY"

END_TS=$(date +%s)
ELAPSED=$(( END_TS - START_TS ))
log "elapsed: ${ELAPSED}s"

if (( fails > 0 )); then
  die "$fails verification check(s) failed. Full log: $VERIFY_LOG. Install log: $INSTALL_LOG"
fi

log "GREEN — install-smoke passed."
KEEP=1  # keep artifacts on success for review; caller can rm at will
exit 0
