#!/usr/bin/env bash
# iso/capture-shots.sh — automated capture of every UI state listed in
# site/content/docs/SCREENSHOTS_NEEDED.md.
#
# Boots the vinOS live ISO under QEMU, injects the in-guest runner via
# serial console (root has an empty password on the live image → login
# via ttyS0 is free), lets the runner drive Hyprland via hyprctl IPC and
# write PNGs to a QEMU virtfs share, then shuts down cleanly.
#
# Usage:
#   iso/capture-shots.sh                         # newest iso/out/vinos-2*.iso
#   iso/capture-shots.sh --iso PATH
#   iso/capture-shots.sh --out site/static/img/screenshots
#   iso/capture-shots.sh --timeout 900           # seconds (default 900)
#   iso/capture-shots.sh --keep-tmp              # don't wipe /tmp/vinos-caps
#
# Requirements on host:
#   - qemu-system-x86_64 (uses KVM if /dev/kvm present)
#   - socat (talks to QEMU's -serial unix socket)
#   - imagemagick (post-processing sanity)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_DIR="$ROOT/iso"
ISO=""
OUT="$ROOT/site/static/img/screenshots"
CAPS="/tmp/vinos-caps"
RUNNER_SRC="$ISO_DIR/capture/vinos-shot-runner.sh"
TIMEOUT=900
KEEP_TMP=0

die() { printf '\033[1;31m[capture-shots] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[capture-shots]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)     ISO="$2"; shift 2 ;;
    --out)     OUT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --keep-tmp) KEEP_TMP=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "qemu-system-x86_64 missing"
command -v socat            >/dev/null 2>&1 || die "socat missing (pacman -S socat)"
[[ -f "$RUNNER_SRC" ]] || die "runner missing: $RUNNER_SRC"

if [[ -z "$ISO" ]]; then
  ISO="$(find "$ISO_DIR/out" -maxdepth 1 -name 'vinos-2*.iso' -printf '%T@ %p\n' 2>/dev/null \
         | sort -nr | head -1 | cut -d' ' -f2- || true)"
fi
[[ -n "$ISO" && -f "$ISO" ]] || die "no vinos-2*.iso in $ISO_DIR/out"

log "ISO: $(basename "$ISO")"
log "out: $OUT"

# --- fresh shared dir --------------------------------------------------
if [[ "$KEEP_TMP" -eq 0 ]]; then
  rm -rf "$CAPS"
fi
mkdir -p "$CAPS" "$OUT"
# virtfs needs the share dir world-writable so the "vinos" user inside
# (uid 1000, unmapped) can write into it via 9p2000.L.
chmod 0777 "$CAPS"

# Stage the runner into a fixed name inside the share so the injector
# can copy it to /usr/local/bin/ in one line.
install -m 0755 "$RUNNER_SRC" "$CAPS/vinos-shot-runner"

# --- QEMU sockets ------------------------------------------------------
WORK="$(mktemp -d /tmp/vinos-capture.XXXXXX)"
trap 'rm -rf "$WORK"; [[ "$KEEP_TMP" -eq 0 ]] || true' EXIT
QMP_SOCK="$WORK/qmp.sock"
QLOG="$WORK/qemu.log"

KVM_ARGS=()
[[ -c /dev/kvm && -w /dev/kvm ]] && KVM_ARGS+=(-enable-kvm)

log "starting QEMU (headless, virtfs share $CAPS -> /mnt/caps)"
# Use plain std VGA — it consistently boots the T2 kernel in KVM. The
# virtio-vga path with xres/yres= sometimes stalls on kernel init in
# this box, so we skip it. Hyprland's monitor gets whatever mode std
# picks (usually 1024x768 or 1280x800). The runner nudges it up to a
# reasonable size via `hyprctl keyword monitor` once IPC is available.
QEMU_VGA=(-vga std)

# -serial: unix socket → socat pushes login + commands, receives prompt
# -qmp: unix socket → host issues system_powerdown at shutdown
# -virtfs: 9p share tagged "caps" → mounted in-guest at /mnt/caps
SER_LOG="$WORK/serial-out.log"
SER_SOCK="$WORK/serial.sock"
IN_FIFO="$WORK/to-guest.fifo"
: >"$SER_LOG"
mkfifo "$IN_FIFO"

# Use a Unix socket chardev — reliable across bootloader→kernel handoff.
# QEMU listens as server; a single socat client bridges the socket to
# (1) SER_LOG for reading and (2) IN_FIFO for writing.
setsid qemu-system-x86_64 \
  -m 4G -smp 2 \
  "${KVM_ARGS[@]}" \
  -cdrom "$ISO" -boot order=d,menu=off \
  -display none \
  "${QEMU_VGA[@]}" \
  -chardev "socket,id=ser0,path=$SER_SOCK,server=on,wait=off" \
  -serial chardev:ser0 \
  -qmp "unix:$QMP_SOCK,server,nowait" \
  -virtfs "local,path=$CAPS,mount_tag=caps,security_model=none,id=caps" \
  -net nic -net user \
  -no-reboot \
  </dev/null >"$QLOG" 2>&1 &
QPID=$!
log "QEMU pid=$QPID"

# Wait for the serial socket to appear.
for _ in $(seq 1 30); do
  [[ -S "$SER_SOCK" ]] && break
  sleep 1
done
[[ -S "$SER_SOCK" ]] || die "serial socket never appeared"

# Bidirectional socat on the QEMU serial socket. Its stdin is the input
# FIFO (bytes we push into the guest); its stdout appends to SER_LOG
# (guest → host). "ignoreeof" on the socket side keeps socat alive if
# the writer closes momentarily during bootloader → kernel handoff.
#
# Ordering trap: opening a fifo for writing blocks until a reader shows
# up, and opening for reading blocks until a writer does. We solve this
# by starting socat first (its "<$IN_FIFO" will block on open), then
# opening the write-side which unblocks it. But bash's "&" backgrounds
# the whole pipeline, so socat's stdin is opened in a subshell — we
# must ensure THAT subshell doesn't win a race with us opening fd 9.
# Solution: use exec to open fd 9 for both read+write in the same
# process; the read-side satisfies socat's open() immediately.
# Open the fifo for reading (fd 8) AND writing (fd 9) up-front so the
# following opens don't deadlock. socat inherits fd 8 as its stdin;
# bash writes to fd 9.
exec 8<>"$IN_FIFO"    # r+w: satisfies open() as reader
exec 9>"$IN_FIFO"     # w-only: our send() writes here
socat "UNIX-CONNECT:$SER_SOCK,ignoreeof" - \
  <&8 >>"$SER_LOG" 2>"$WORK/socat.err" &
RPID=$!
# Close bash's fd 8 (only socat should read from the fifo).
exec 8>&-

cleanup() {
  local rc=$?
  if kill -0 "$QPID" 2>/dev/null; then
    log "shutting down QEMU (system_powerdown)"
    printf '{"execute":"qmp_capabilities"}\n{"execute":"system_powerdown"}\n' \
      | socat - "UNIX-CONNECT:$QMP_SOCK" >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do
      kill -0 "$QPID" 2>/dev/null || break
      sleep 1
    done
    kill -TERM "$QPID" 2>/dev/null || true
    sleep 2
    kill -KILL "$QPID" 2>/dev/null || true
  fi
  wait "$QPID" 2>/dev/null || true
  return "$rc"
}
trap cleanup EXIT

# --- wait for QMP socket (proof QEMU came up) -----------------------
for _ in $(seq 1 30); do
  [[ -S "$QMP_SOCK" ]] && break
  sleep 1
done
[[ -S "$QMP_SOCK" ]] || die "QMP socket never appeared: $QMP_SOCK"

# --- talk to serial: login as root, install runner, kick it off -------
# The setup script runs as root over serial. It waits for greetd/Hyprland
# to be up, then executes the runner as the vinos user under that user's
# Wayland environment (import their WAYLAND_DISPLAY + XDG_RUNTIME_DIR).
INJECT="$WORK/inject.sh"
cat >"$INJECT" <<'INJECT_EOF'
set +e
umask 022
# Log to /tmp too (survives a failed 9p mount) — helps diagnose.
LOG=/tmp/vinos-inject.log
exec >>"$LOG" 2>&1
echo "== $(date -Iseconds) injector start =="

# Ensure 9p modules are loaded. archiso initramfs may or may not carry
# them; force-load in userspace either way (no-op if already loaded).
modprobe 9p         2>&1
modprobe 9pnet      2>&1
modprobe 9pnet_virtio 2>&1
lsmod | grep -E '^9p' 2>&1

# Mount the QEMU virtfs share tagged "caps" into /mnt/caps. Retry on
# transient failures (rare, but 9p module can be slow to register).
mkdir -p /mnt/caps
for i in 1 2 3 4 5; do
  mountpoint -q /mnt/caps && break
  mount -t 9p -o trans=virtio,version=9p2000.L,rw,msize=104857600 caps /mnt/caps
  rc=$?
  echo "mount attempt $i rc=$rc"
  [[ $rc -eq 0 ]] && break
  sleep 1
done
if ! mountpoint -q /mnt/caps; then
  echo "FATAL: could not mount 9p share; bailing"
  # Push the log back over serial so the host driver can see it.
  echo "===INJECTOR_FAIL===" >/dev/ttyS0 2>/dev/null
  cat "$LOG" >/dev/ttyS0 2>/dev/null
  echo "===INJECTOR_FAIL_END===" >/dev/ttyS0 2>/dev/null
  exit 1
fi
echo "mount OK; contents:"
ls -la /mnt/caps

# From here on log to the SHARED log so the host sees it.
cp -f "$LOG" /mnt/caps/serial-inject.log 2>/dev/null
exec >>/mnt/caps/serial-inject.log 2>&1

# Copy runner in place, make executable.
install -m 0755 /mnt/caps/vinos-shot-runner /usr/local/bin/vinos-shot-runner
echo "runner installed: $(ls -la /usr/local/bin/vinos-shot-runner)"

# Give the runner's output world-writable perms so uid 1000 can write.
chmod 0777 /mnt/caps

# Wait for greetd to start Hyprland as the "vinos" user (uid 1000).
for i in $(seq 1 120); do
  if pgrep -u vinos -x Hyprland >/dev/null 2>&1; then break; fi
  sleep 1
done

# Discover the running Hyprland's WAYLAND_DISPLAY + runtime dir, so we
# can setsid the runner in the correct session even though we're root.
HYPR_PID=$(pgrep -u vinos -x Hyprland | head -1)
if [ -z "$HYPR_PID" ]; then
  echo "no Hyprland pid — bailing" >>/mnt/caps/serial-inject.log
  touch /mnt/caps/DONE
  exit 0
fi

XDG_RUNTIME_DIR=/run/user/1000
# Hyprland's /proc/PID/environ doesn't contain WAYLAND_DISPLAY /
# HYPRLAND_INSTANCE_SIGNATURE (uwsm/xdg activation sets them in the
# session dbus but not in the parent env). Discover from filesystem:
# HIS = directory under /run/user/1000/hypr/, WD = wayland-N socket
# in that runtime dir.
HYPRLAND_INSTANCE=$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
WAYLAND_DISPLAY=$(ls -1 "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E "^wayland-[0-9]+$" | head -1)
DBUS="unix:path=$XDG_RUNTIME_DIR/bus"

echo "vinos Hyprland pid=$HYPR_PID HIS=$HYPRLAND_INSTANCE WD=$WAYLAND_DISPLAY RD=$XDG_RUNTIME_DIR" >>/mnt/caps/serial-inject.log

# runuser preserves the target user's shell + doesn't scrub env like
# sudo does. Detach with setsid so the serial line isn't held.
setsid runuser -u vinos -- env \
  HOME=/home/vinos \
  USER=vinos \
  XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE" \
  DBUS_SESSION_BUS_ADDRESS="$DBUS" \
  XDG_CURRENT_DESKTOP=Hyprland \
  XDG_SESSION_TYPE=wayland \
  OMARCHY_PATH=/usr/share/omarchy \
  PATH=/usr/local/bin:/usr/bin:/bin \
  /usr/local/bin/vinos-shot-runner </dev/null >>/mnt/caps/serial-inject.log 2>&1 &

echo "runner launched, pid=$!" >>/mnt/caps/serial-inject.log
INJECT_EOF

# base64-encode the injector so we can push it in one line over serial
# without escaping/CR/LF headaches. Guest decodes + runs.
B64=$(base64 -w0 <"$INJECT")

# The injector talks to the serial socket. It:
#  1. Waits for a "login:" prompt (up to N sec)
#  2. Sends "root\n"
#  3. Sleeps briefly, then pastes the injector as a single decoded line.
log "logging in via serial and injecting runner"
# Send a line to guest ttyS0. Linux getty in canonical mode terminates
# a line on LF (\n). Some raw-mode readers want CR too; sending both
# covers both. Without \n the getty never sees the login username →
# every subsequent line is treated as another login attempt.
send() { printf '%s\r\n' "$1" >&9; }
wait_for() {
  local pat="$1" timeout="${2:-60}" start; start=$(date +%s)
  while [[ $(( $(date +%s) - start )) -lt $timeout ]]; do
    if grep -a -q -F "$pat" "$SER_LOG" 2>/dev/null; then return 0; fi
    sleep 1
  done
  return 1
}
wait_for_re() {
  local re="$1" timeout="${2:-60}" start; start=$(date +%s)
  while [[ $(( $(date +%s) - start )) -lt $timeout ]]; do
    if grep -a -E -q "$re" "$SER_LOG" 2>/dev/null; then return 0; fi
    sleep 1
  done
  return 1
}

# 1. Wait for the serial login prompt. The vinOS live image reaches
#    "vinos-live login:" ~60-90s after boot start (isolinux countdown +
#    kernel init).
if ! wait_for "vinos-live login" 240; then
  log "  WARN: never saw a login prompt — kicking anyway"
fi
sleep 2
send ""            # nudge getty in case it lost sync
sleep 1
send "root"
# 2. Wait for the root shell prompt.
sleep 3
# 3. Push the injector script. The Linux TTY has a 255-byte canonical
# input-line buffer (MAX_CANON), so pasting the 4-5KB base64 blob on a
# single line silently truncates. Chunk it into ~200-char pieces and
# append each to a file, then decode + execute in one go.
send "rm -f /tmp/inj.b64"
sleep 0.4
# Keep each command line <= ~200 bytes wire (MAX_CANON is 255 but the
# echo-back doubles the visible line length in canonical mode). 100
# b64 chars + wrapper (~40 chars) fits comfortably.
step=100
for ((i=0; i<${#B64}; i+=step)); do
  send "printf %s ${B64:i:step} >>/tmp/inj.b64"
  # 0.08s gives the guest time to echo and consume each line without
  # backpressure on the tty buffer.
  sleep 0.08
done
sleep 0.5
send "base64 -d </tmp/inj.b64 >/tmp/inj.sh && bash /tmp/inj.sh"
sleep 1
send "echo INJECTOR_DONE_$$"
# 4. Wait for the sentinel to confirm injector at least started.
if wait_for "INJECTOR_DONE_$$" 60; then
  log "  injector fired successfully"
else
  log "  WARN: injector sentinel never seen — runner may not have started"
fi

# --- wait for DONE sentinel (or timeout) ------------------------------
log "waiting for /mnt/caps/DONE (up to ${TIMEOUT}s)…"
DEADLINE=$(( $(date +%s) + TIMEOUT ))
while [[ $(date +%s) -lt $DEADLINE ]]; do
  if [[ -f "$CAPS/DONE" ]]; then
    log "DONE sentinel appeared."
    break
  fi
  # Report a heartbeat every 30s with the current PNG count.
  count=$(find "$CAPS" -maxdepth 1 -name '*.png' 2>/dev/null | wc -l)
  now=$(date +%s); left=$(( DEADLINE - now ))
  printf '\033[1;34m[capture-shots]\033[0m  %ds left · %d PNGs so far\n' "$left" "$count"
  sleep 30
done

exec 9>&- 2>/dev/null || true
kill "$RPID" 2>/dev/null || true
wait "$RPID" 2>/dev/null || true

# --- post-process: sync everything to $OUT with the docs-mandated names
log "post-processing PNGs → $OUT"
declare -A MAP=(
  [waybar-full.png]=waybar-full.png
  [theme-cosmos.png]=theme-cosmos.png
  [theme-summit.png]=theme-summit.png
  [theme-circuit.png]=theme-circuit.png
  [vinos-focus-active.png]=vinos-focus-active.png
  [welcome-dmenu.png]=welcome-dmenu.png
  [first-boot-tty.png]=first-boot-tty.png
  [menu-root.png]=menu-root.png
  [theme-picker.png]=theme-picker.png
  [walker-launcher.png]=walker-launcher.png
  [cheatsheet-overlay.png]=cheatsheet-overlay.png
  [vinos-brief-panel.png]=vinos-brief-panel.png
  [vinos-commit-tui.png]=vinos-commit-tui.png
  [vinos-standup-out.png]=vinos-standup-out.png
  [vinos-ai-chat.png]=vinos-ai-chat.png
  [doctor-passing.png]=doctor-passing.png
  [docker-lazydocker.png]=docker-lazydocker.png
  [t2-wifi-connected.png]=t2-wifi-connected.png
)

# Boot-plymouth: captured host-side via HMP screendump earlier.
# We do it here as a best-effort second pass on a short throwaway boot.
# (Skip if it'd blow the whole session; add later if truly needed.)

CAPTURED=0
MISSED=()
for src in "${!MAP[@]}"; do
  dst="${MAP[$src]}"
  if [[ -f "$CAPS/$src" ]]; then
    cp -f "$CAPS/$src" "$OUT/$dst"
    sz=$(stat -c%s "$OUT/$dst" 2>/dev/null || echo "?")
    dim=$(identify -format '%wx%h' "$OUT/$dst" 2>/dev/null || echo "?")
    printf '  \033[1;32mOK\033[0m  %-32s %8s bytes  %s\n' "$dst" "$sz" "$dim"
    CAPTURED=$((CAPTURED+1))
  else
    MISSED+=("$dst")
  fi
done

# --- summary ----------------------------------------------------------
log "captured: $CAPTURED PNGs"
if (( ${#MISSED[@]} )); then
  log "missed:  ${#MISSED[@]}  ${MISSED[*]}"
fi
log "explicitly skipped (documented):"
log "  shot-01 boot-plymouth.png            — host-side screendump not yet implemented"
log "  shot-21 waybar-routine-widget.png    — widget not shipped until v2.0.6"
log "  shot-22 routine-notification.png     — needs API key + real routine run"
log "  shot-50 t2-mbp-boot.png              — physical phone photo required"
log ""
log "runner logs: $CAPS/runner.log · serial log: $CAPS/serial-inject.log · qemu: $QLOG"
[[ -f "$CAPS/capture.log" ]] && log "shot manifest: $CAPS/capture.log"

exit 0
