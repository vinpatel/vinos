#!/usr/bin/env bash
# iso/qa/desktop-smoke.sh — prove vinos-install-desktop on an installed image.
#
# install-smoke.sh proves the *base* install: a disk that boots, has a user,
# a bootloader and sshd. It deliberately stops there — the base-only pivot
# moved the 300-package desktop overlay out of arch-chroot and into
# bin/vinos-install-desktop, run from a real session after the first reboot.
#
# Nothing proved that second half. This does.
#
# What it proves:
#   1. vinos-install-desktop is on PATH of a freshly installed system.
#   2. Its preflight passes there (network, disk, sudo, repo).
#   3. install.sh runs to completion through it, no argument or AUR fault.
#   4. The system comes back up with greetd on graphical.target.
#   5. The installed desktop actually has the surface the ISO has —
#      every binary a shipped keybinding or autostart line invokes.
#
# Input is the qcow2 install-smoke.sh leaves behind with --keep. This
# harness never installs a base itself; keeping the two halves separate
# means a desktop-layer bug costs one 40-min run, not two.
#
# Usage:
#   iso/qa/desktop-smoke.sh [--qcow2 PATH] [--nvram PATH] [--from-dir DIR]
#                           [--local-repo|--no-local-repo] [--keep] [--timeout SECS]
#
#     --from-dir DIR    install-smoke --out-dir to read target.qcow2 +
#                       OVMF_VARS.fd from. Default /data/vinos-qa/desktop-test
#     --qcow2 PATH      Override the disk image path.
#     --nvram PATH      Override the OVMF vars path.
#     --local-repo      rsync THIS checkout into the guest and install from it
#                       (default). Tests the working tree, not origin/main.
#     --no-local-repo   Leave the guest's own clone alone; test what shipped.
#     --keep            Leave the VM running on exit for hands-on poking.
#     --timeout SECS    Cap on the install.sh stretch. Default 3600.
#
# Env: DESKTOP_VNC_PORT (5906)  DESKTOP_SSH_PORT (2226)
#
# Assumes the install-smoke profile: user=qatest pass=qatest123.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$ISO_DIR/.." && pwd)"

FROM_DIR="/data/vinos-qa/desktop-test"
QCOW2=""
NVRAM=""
LOCAL_REPO=1
KEEP=0
TIMEOUT=3600

VNC_PORT="${DESKTOP_VNC_PORT:-5906}"
SSH_PORT="${DESKTOP_SSH_PORT:-2226}"
QA_USER="qatest"
QA_PASS="qatest123"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-dir)      FROM_DIR="$2"; shift 2 ;;
    --qcow2)         QCOW2="$2";    shift 2 ;;
    --nvram)         NVRAM="$2";    shift 2 ;;
    --local-repo)    LOCAL_REPO=1;  shift ;;
    --no-local-repo) LOCAL_REPO=0;  shift ;;
    --keep)          KEEP=1;        shift ;;
    --timeout)       TIMEOUT="$2";  shift 2 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'desktop-smoke: unknown arg: %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
done

: "${QCOW2:=$FROM_DIR/target.qcow2}"
: "${NVRAM:=$FROM_DIR/OVMF_VARS.fd}"

OUT_DIR="$FROM_DIR/desktop"
install -d -m 0755 "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.txt"
QEMU_LOG="$OUT_DIR/qemu.log"
# Guest serial console. Every observation this harness makes otherwise
# goes through sshd, so when sshd stops answering the harness has no idea
# whether the install is grinding, finished, or dead. The serial log
# keeps working regardless.
SERIAL_LOG="$OUT_DIR/serial.log"
DESKTOP_LOG="$OUT_DIR/install-desktop.log"
VERIFY_LOG="$OUT_DIR/verify.log"
HMP_SOCK="$OUT_DIR/hmp.sock"
VNCPW="$OUT_DIR/vncpw.secret"

: > "$SUMMARY"
die()  { printf '\033[1;31m[desk] FAIL:\033[0m %s\n' "$*" | tee -a "$SUMMARY" >&2; KEEP=1; _cleanup; exit 1; }
log()  { printf '\033[1;34m[desk]\033[0m %s\n' "$*" | tee -a "$SUMMARY"; }
step() { printf '\033[1;36m[desk] === %s ===\033[0m\n' "$*" | tee -a "$SUMMARY"; }

[[ -f "$QCOW2" ]] || die "no installed image at $QCOW2 — run iso/qa/install-smoke.sh --keep --out-dir $FROM_DIR first"
[[ -f "$NVRAM" ]] || die "no OVMF vars at $NVRAM (the install-smoke run keeps them beside the qcow2)"

for bin in qemu-system-x86_64 socat ssh rsync; do
  command -v "$bin" >/dev/null || die "missing prerequisite: $bin"
done

OVMF_CODE=""
for c in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2/x64/OVMF_CODE.fd \
         /usr/share/edk2-ovmf/x64/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd; do
  [[ -f "$c" ]] && { OVMF_CODE="$c"; break; }
done
[[ -n "$OVMF_CODE" ]] || die "OVMF firmware not found (install edk2-ovmf)"

QEMU_PID=""
_CLEANED=0
_cleanup() {
  local rc=$?
  (( _CLEANED )) && return 0
  _CLEANED=1
  (( rc != 0 )) && KEEP=1
  if (( KEEP )); then
    log "leaving VM up: ssh -p $SSH_PORT $QA_USER@127.0.0.1   (VNC :$VNC_PORT)"
    log "artifacts: $OUT_DIR"
  elif [[ -n "$QEMU_PID" ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
    printf 'quit\n' | timeout 4 socat - UNIX-CONNECT:"$HMP_SOCK" >/dev/null 2>&1 || true
    sleep 1; kill -KILL "$QEMU_PID" 2>/dev/null || true
  fi
  return $rc
}
trap _cleanup EXIT INT TERM

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR)
_ssh() { ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "$QA_USER@127.0.0.1" "$@"; }

_boot() {
  printf 'smoke' > "$VNCPW"; chmod 0600 "$VNCPW"
  # 8G was not enough: the AUR build storm (walker/elephant are Rust,
  # claude-code pulls npm) pinned the guest at its full allocation and
  # sshd stopped answering for 20 minutes, which blinded the harness
  # completely — the run had to be killed with no verdict.
  qemu-system-x86_64 \
    -m 12G -smp 4 \
    -serial "file:$SERIAL_LOG" \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$NVRAM" \
    -drive file="$QCOW2",format=qcow2,if=virtio \
    -boot order=c \
    -vga virtio \
    -display vnc="0.0.0.0:$((VNC_PORT - 5900)),password-secret=vncpw" \
    -k en-us -usb -device usb-kbd -device usb-tablet \
    -enable-kvm -cpu host \
    -object secret,id=vncpw,file="$VNCPW",format=raw \
    -monitor unix:"$HMP_SOCK",server,nowait \
    -nic user,hostfwd=tcp::"$SSH_PORT"-:22 \
    >> "$QEMU_LOG" 2>&1 &
  QEMU_PID=$!
}

_wait_ssh() {
  local deadline=$(( $(date +%s) + $1 ))
  while (( $(date +%s) < deadline )); do
    _ssh 'true' >/dev/null 2>&1 && return 0
    kill -0 "$QEMU_PID" 2>/dev/null || return 1
    sleep 5
  done
  return 1
}

START_TS=$(date +%s)
log "installed image: $QCOW2"

# ── STEP 1: boot the installed system ──────────────────────────────
step "1/6 boot installed system"
_boot
log "QEMU PID $QEMU_PID  VNC :$VNC_PORT  SSH $SSH_PORT"
_wait_ssh 300 || die "installed system never reached sshd — QEMU log: $QEMU_LOG"
log "up: $(_ssh 'cat /etc/os-release | grep ^PRETTY_NAME=' 2>/dev/null)"

# ── STEP 2: the command must exist ─────────────────────────────────
step "2/6 vinos-install-desktop is present and self-describing"
_ssh 'command -v vinos-install-desktop' >/dev/null \
  || die "vinos-install-desktop is NOT on PATH of the installed system.
       05-branding symlinks /usr/share/vinos/bin/vinos-* into /usr/local/bin —
       check that config/all.sh's branding step actually ran in the chroot."
log "found at: $(_ssh 'command -v vinos-install-desktop')"
_ssh 'vinos-install-desktop --help' >/dev/null \
  || die "vinos-install-desktop --help exits non-zero — the script is broken before it does anything"

# ── STEP 3: harness-side setup ─────────────────────────────────────
# Two deviations from the real user path, both deliberate:
#   NOPASSWD  — the real path prompts once on a real tty; this runs
#               unattended over SSH, where the prompt has nowhere to go.
#               `sudo -n true` (the script's own keepalive) needs it too.
#   local repo— install from THIS working tree rather than origin/main,
#               so a fix under test is what actually gets exercised.
step "3/6 harness setup (NOPASSWD sudo${LOCAL_REPO:+, local repo sync})"
# Build the rule host-side and ship it as a file: quoting a sudoers line
# through ssh -> sh -> sudo -> bash -c is three levels of escaping and one
# typo away from writing a broken /etc/sudoers.d that locks sudo out.
# NOPASSWD alone is not enough. vinos-install-desktop's preflight calls
# `sudo -v`, and sudo requires a password for -v whenever ANY entry
# matching the user needs one — the installed system's own
# /etc/sudoers.d/10-vinos-wheel (%wheel ALL=(ALL:ALL) ALL) is such an
# entry, and it is correct that it exists. On a real tty the user simply
# types their password there, which is the intended behaviour and not a
# bug; an unattended run has nowhere to put the prompt. `!authenticate`
# is the sudoers way to say "skip the auth step for this user".
{ printf 'Defaults:%s !authenticate\n' "$QA_USER"
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$QA_USER"
} > "$OUT_DIR/90-qa-nopasswd"
scp "${SSH_OPTS[@]}" -P "$SSH_PORT" -q \
    "$OUT_DIR/90-qa-nopasswd" "$QA_USER@127.0.0.1:90-qa-nopasswd" \
  || die "could not copy the NOPASSWD rule into the guest"
# sudo -S takes the password off stdin; the payload travels as argv, so
# the two never contend for the same file descriptor.
printf '%s\n' "$QA_PASS" \
  | _ssh 'sudo -S install -Dm0440 -o root -g root ~/90-qa-nopasswd /etc/sudoers.d/90-qa-nopasswd' \
    >/dev/null 2>&1 || die "could not seed NOPASSWD sudoers for $QA_USER"
_ssh 'sudo -n visudo -c >/dev/null' || die "sudoers is invalid after seeding — do not reboot this guest"
_ssh 'sudo -n true' || die "NOPASSWD sudo did not take effect"
# Prove the exact call the script's preflight makes, before spending 40
# minutes finding out it does not work.
_ssh 'sudo -v' || die "sudo -v still wants a password — the !authenticate default did not take"

if (( LOCAL_REPO )); then
  # .git is excluded on purpose and it is not an optimisation: this repo's
  # history is 14 G, which does not fit beside a desktop install on a 20 G
  # target and filled the guest disk the first time this ran. The install
  # phase already left a shallow clone at ~/.local/share/vinos; rsync
  # overwrites its working tree and leaves its .git alone, which is all
  # vinos-install-desktop needs (with --no-update it only checks that
  # $REPO/.git exists, then installs whatever is on disk).
  # --delete does not touch excluded paths, so the clone survives it.
  log "syncing $REPO working tree into guest ~/.local/share/vinos (.git excluded)"
  _ssh 'test -d ~/.local/share/vinos/.git' \
    || die "guest has no clone at ~/.local/share/vinos/.git to sync onto.
       config/all.sh's clone step must have failed during the base install."
  rsync -a --delete \
        --exclude '.git' \
        --exclude 'iso/out' --exclude 'iso/work' --exclude 'iso/aurrepo' \
        --exclude 'iso/.aur-cache' --exclude 'node_modules' --exclude 'site' \
        -e "ssh ${SSH_OPTS[*]} -p $SSH_PORT" \
        "$REPO/" "$QA_USER@127.0.0.1:.local/share/vinos/" \
    || die "rsync of the working tree into the guest failed"
  # The commit below is the guest clone's, not the synced tree's — the
  # working tree on top of it is what actually gets installed.
  log "guest tree synced (clone HEAD was $(_ssh 'git -C ~/.local/share/vinos rev-parse --short HEAD 2>/dev/null || echo no-git'))"
  log "guest free space: $(_ssh "df -h / | awk 'NR==2{print \$4}'" 2>/dev/null)"

  # Syncing the checkout is not enough. The command on PATH is
  # /usr/local/bin/vinos-install-desktop -> /usr/share/vinos/bin/..., a
  # copy frozen at install time by 05-branding; a newer checkout under
  # ~/.local/share does not change it, so without this the run silently
  # exercises whatever shipped on the ISO rather than the tree under
  # test. 05-branding is exactly the in-repo mechanism for refreshing
  # the installed vinos-* commands (~5 s, no network, idempotent), so
  # use it rather than hand-copying files around.
  log "refreshing /usr/share/vinos/bin from the synced tree (install/05-branding.sh)"
  _ssh 'cd ~/.local/share/vinos && bash install/05-branding.sh' >/dev/null 2>&1 \
    || die "05-branding.sh failed while refreshing the installed vinos-* commands"
  _ssh 'cmp -s /usr/share/vinos/bin/vinos-install-desktop ~/.local/share/vinos/bin/vinos-install-desktop' \
    || die "/usr/share/vinos/bin/vinos-install-desktop still differs from the tree under test"
  log "on-PATH vinos-install-desktop now matches the tree under test"
fi

# Record the pre-install package count so the diff is provable.
_ssh 'pacman -Qq | wc -l' > "$OUT_DIR/pkgcount.before" 2>/dev/null || true

# ── STEP 4: run it ─────────────────────────────────────────────────
# VINOS_ENABLE_SSH=1 is not cosmetic. install/04-services.sh runs
# `ufw --force default deny incoming` + `ufw --force enable`, and only
# adds an ssh rule when this is set. Without it the firewall closes the
# harness's only observation channel partway through its own run — which
# is what made two runs look like memory exhaustion when the guest was
# in fact perfectly healthy at a login prompt. Real installs keep ssh
# closed; this is a harness deviation, and the ufw-is-active assertion
# in step 6 makes sure we did not weaken the firewall itself.
step "4/6 run vinos-install-desktop (up to $((TIMEOUT/60)) min)"
UPDATE_FLAG=$( (( LOCAL_REPO )) && printf -- '--no-update' || printf '' )
# Poll on an exit-code file, not on pgrep. `pgrep -f vinos-install-desktop`
# run over ssh matches the shell running the pgrep itself, so the process
# always looks alive and the loop only ever ends at the timeout.
_ssh "rm -f ~/desktop-run.rc; \
      nohup setsid bash -c 'TERM=dumb VINOS_ENABLE_SSH=1 vinos-install-desktop $UPDATE_FLAG --yes --no-reboot \
        > ~/desktop-run.log 2>&1; echo \$? > ~/desktop-run.rc' \
        < /dev/null > /dev/null 2>&1 & echo started" >/dev/null \
  || die "could not launch vinos-install-desktop"

DEADLINE=$(( $(date +%s) + TIMEOUT ))
LAST=0
RC=""
while (( $(date +%s) < DEADLINE )); do
  if RC="$(_ssh 'cat ~/desktop-run.rc 2>/dev/null' 2>/dev/null)" && [[ -n "$RC" ]]; then
    break
  fi
  now=$(date +%s)
  if (( now - LAST >= 60 )); then
    # `|| true` is load-bearing. A bare assignment from a command
    # substitution takes that command's exit status, so under `set -e` a
    # failed ssh kills the harness outright — which is exactly what
    # happened: the branch below, written to REPORT that ssh is
    # unreachable, never ran because ssh being unreachable aborted the
    # script one line earlier, at +614s, with no verdict and the install
    # still running in the guest.
    _line="$(_ssh 'tail -1 ~/desktop-run.log 2>/dev/null | tr -d "\r" | cut -c1-140' 2>/dev/null || true)"
    if [[ -z "$_line" ]]; then
      # Distinguish "sshd is not answering" from "the log line was blank".
      # Reporting an empty string for both is what made a 20-minute stall
      # look identical to normal progress.
      if _ssh 'true' >/dev/null 2>&1; then
        _line="(no new output)"
      else
        _line="ssh unreachable — guest load? last serial: $(tail -1 "$SERIAL_LOG" 2>/dev/null | tr -d '\r' | cut -c1-100)"
      fi
    fi
    log "  [+$(( now - START_TS ))s] $_line"
    LAST=$now
  fi
  sleep 10
done
_ssh 'cat ~/desktop-run.log' > "$DESKTOP_LOG" 2>&1 || true
[[ -n "$RC" ]] || die "vinos-install-desktop did not finish within $((TIMEOUT/60)) min — hang.
       Last line: $(tail -1 "$DESKTOP_LOG" 2>/dev/null)
       Log: $DESKTOP_LOG"
(( RC == 0 )) || die "vinos-install-desktop exited $RC.
$(grep -n -B6 '\[vinOS FAIL\]' "$DESKTOP_LOG" 2>/dev/null | tail -25 || tail -25 "$DESKTOP_LOG")
       Full log: $DESKTOP_LOG"

if grep -q '\[vinOS FAIL\]' "$DESKTOP_LOG"; then
  die "vinos-install-desktop reported FAIL:
$(grep -n -B4 '\[vinOS FAIL\]' "$DESKTOP_LOG" | tail -25)
       Full log: $DESKTOP_LOG"
fi
grep -q 'vinOS desktop installed' "$DESKTOP_LOG" \
  || die "vinos-install-desktop exited without printing its success banner. Log: $DESKTOP_LOG"
log "vinos-install-desktop completed"
_ssh 'pacman -Qq | wc -l' > "$OUT_DIR/pkgcount.after" 2>/dev/null || true
log "packages: $(cat "$OUT_DIR/pkgcount.before" 2>/dev/null) -> $(cat "$OUT_DIR/pkgcount.after" 2>/dev/null)"

# ── STEP 5: reboot into it ─────────────────────────────────────────
step "5/6 reboot into the installed desktop"
_ssh 'sudo -n systemctl reboot' >/dev/null 2>&1 || true
sleep 20
_wait_ssh 300 || die "installed system did not come back after the desktop layer — QEMU log: $QEMU_LOG"
log "back up after reboot"

# ── STEP 6: does it actually have a desktop? ───────────────────────
step "6/6 verify the desktop surface"
: > "$VERIFY_LOG"
fails=0
_check() {
  local label="$1" cmd="$2" want="$3" actual
  actual="$(_ssh "$cmd" 2>&1)" || {
    printf 'FAIL: %-28s | cmd failed: %s\n' "$label" "$cmd" >> "$VERIFY_LOG"; return 1; }
  if [[ "$actual" =~ $want ]]; then
    printf 'PASS: %-28s | %s\n' "$label" "${actual:0:70}" >> "$VERIFY_LOG"; return 0
  fi
  printf 'FAIL: %-28s | got: %s (want /%s/)\n' "$label" "${actual:0:70}" "$want" >> "$VERIFY_LOG"; return 1
}

_check "default target"  "systemctl get-default"                       '^graphical\.target$' || (( fails+=1 ))
_check "greetd enabled"  "systemctl is-enabled greetd"                 '^enabled$'           || (( fails+=1 ))
_check "greetd config"   "test -f /etc/greetd/config.toml && echo yes" '^yes$'               || (( fails+=1 ))
_check "hypr config"     "test -f ~/.config/hypr/hyprland.conf && echo yes" '^yes$'          || (( fails+=1 ))
_check "sentinel"        "test -f ~/.local/state/vinos/desktop.done && echo yes" '^yes$'     || (( fails+=1 ))
# The firewall must still be up — we opened ssh for observability, we did
# not turn the firewall off.
_check "ufw active"      "sudo -n ufw status | head -1"                 'Status: active'    || (( fails+=1 ))
# 04-services repoints /etc/resolv.conf at systemd-resolved's stub. When
# that stub does not exist the symlink dangles and DNS dies silently for
# everything downstream; 07-ai.sh failed on every mirror that way.
_check "resolv.conf resolves" "readlink -e /etc/resolv.conf >/dev/null && echo ok" '^ok$'   || (( fails+=1 ))
_check "DNS works"       "getent hosts archlinux.org >/dev/null && echo ok"        '^ok$'   || (( fails+=1 ))

# Every binary below is invoked by a shipped keybinding, an autostart line,
# or a vinos-* helper. A missing one is a keystroke that silently does
# nothing on the installed system while working fine off the USB — which
# is exactly the gap the base-only pivot could open without anyone noticing.
BINS=(
  Hyprland waybar mako foot alacritty          # compositor + shell + terms
  walker elephant nwg-drawer                   # Super+Space launcher chain
  uwsm                                         # every `uwsm-app --` autostart line
  swaybg grim slurp wl-copy                    # wallpaper + screenshots
  jq socat imagemagick                         # vinos-* helper plumbing
  xkbcli                                       # Super+K cheatsheet
  brightnessctl playerctl                      # media/brightness keys
  chromium                                     # Super+B
)
missing=()
for b in "${BINS[@]}"; do
  _ssh "command -v $b >/dev/null 2>&1 || pacman -Qq $b >/dev/null 2>&1" \
    || missing+=("$b")
done
if (( ${#missing[@]} )); then
  printf 'FAIL: %-28s | missing: %s\n' "desktop binaries" "${missing[*]}" >> "$VERIFY_LOG"
  (( fails+=1 ))
else
  printf 'PASS: %-28s | all %d present\n' "desktop binaries" "${#BINS[@]}" >> "$VERIFY_LOG"
fi

# Hyprland parses its own config better than any grep can.
if _ssh 'command -v Hyprland >/dev/null'; then
  _check "hyprland config parses" \
    "Hyprland --verify-config 2>&1 | grep -ciE '^ *(err|error)' || true" '^0$' || (( fails+=1 ))
fi

# Informational, not a gate: what the live ISO carries that the installed
# desktop does not. Most of the delta is legitimately live-only (archiso,
# memtest, alternate kernels). What matters is anything a keybinding or
# autostart line reaches for — the BINS gate above covers those by name,
# and this file is where you go to find the next one.
if [[ -f "$REPO/iso/profile/packages.x86_64" ]]; then
  _ssh 'pacman -Qq' | LC_ALL=C sort > "$OUT_DIR/pkgs.installed" 2>/dev/null || true
  grep -Ev '^\s*(#|$)' "$REPO/iso/profile/packages.x86_64" | LC_ALL=C sort -u > "$OUT_DIR/pkgs.iso"
  LC_ALL=C comm -23 "$OUT_DIR/pkgs.iso" "$OUT_DIR/pkgs.installed" > "$OUT_DIR/pkgs.iso-only" || true
  log "ISO ships $(wc -l < "$OUT_DIR/pkgs.iso") named pkgs; $(wc -l < "$OUT_DIR/pkgs.iso-only") of them are absent here"
  log "  full list: $OUT_DIR/pkgs.iso-only"
fi

log "verification results:"
cat "$VERIFY_LOG" | tee -a "$SUMMARY"
log "elapsed: $(( $(date +%s) - START_TS ))s"

(( fails == 0 )) || die "$fails desktop check(s) failed. $VERIFY_LOG · install log $DESKTOP_LOG"

log "GREEN — desktop-smoke passed."
KEEP=1
exit 0
