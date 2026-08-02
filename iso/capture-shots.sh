#!/usr/bin/env bash
# iso/capture-shots.sh — automated capture of every UI state listed in
# site/content/docs/SCREENSHOTS_NEEDED.md.
#
# Boots the vinOS live ISO under QEMU, injects the in-guest runner via
# serial console (root has an empty password on the live image → login
# via ttyS0 is free), lets the runner drive Hyprland via hyprctl IPC and
# write PNGs to a QEMU virtfs share, then shuts down cleanly.
#
# Also renders host-side CLI --help screenshots (shot-70..79) via
# ImageMagick from the bin/vinos-* scripts in this checkout — no QEMU
# boot needed for those, so they're cheap to iterate on.
#
# Also grabs pre-Hyprland boot frames (shot-04 syslinux menu,
# shot-05 greetd greeter) via QMP screendump at fixed timestamps.
#
# Usage:
#   iso/capture-shots.sh                         # newest iso/out/vinos-2*.iso
#   iso/capture-shots.sh --iso PATH
#   iso/capture-shots.sh --out site/static/img/screenshots
#   iso/capture-shots.sh --timeout 900           # seconds (default 900)
#   iso/capture-shots.sh --keep-tmp              # don't wipe /tmp/vinos-caps
#   iso/capture-shots.sh --skip-boot             # skip QEMU boot; only host-side --help renders
#
# Requirements on host:
#   - qemu-system-x86_64 (uses KVM if /dev/kvm present)
#   - socat (talks to QEMU's -serial unix socket)
#   - imagemagick (post-processing sanity + --help renders)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_DIR="$ROOT/iso"
ISO=""
OUT="$ROOT/site/static/img/screenshots"
CAPS="/tmp/vinos-caps"
RUNNER_SRC="$ISO_DIR/capture/vinos-shot-runner.sh"
TIMEOUT=900
KEEP_TMP=0
SKIP_BOOT=0

die() { printf '\033[1;31m[capture-shots] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[capture-shots]\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)     ISO="$2"; shift 2 ;;
    --out)     OUT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --keep-tmp) KEEP_TMP=1; shift ;;
    --skip-boot) SKIP_BOOT=1; shift ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "qemu-system-x86_64 missing"
command -v socat            >/dev/null 2>&1 || die "socat missing (pacman -S socat)"
command -v magick           >/dev/null 2>&1 || die "imagemagick (magick) missing"
[[ -f "$RUNNER_SRC" ]] || die "runner missing: $RUNNER_SRC"

if [[ -z "$ISO" ]]; then
  ISO="$(find "$ISO_DIR/out" -maxdepth 1 -name 'vinos-2*.iso' -printf '%T@ %p\n' 2>/dev/null \
         | sort -nr | head -1 | cut -d' ' -f2- || true)"
fi
if [[ "$SKIP_BOOT" -eq 0 ]]; then
  [[ -n "$ISO" && -f "$ISO" ]] || die "no vinos-2*.iso in $ISO_DIR/out"
  log "ISO: $(basename "$ISO")"
fi
log "out: $OUT"

mkdir -p "$OUT"

# =========================================================================
# HOST-SIDE PHASE A: render CLI --help outputs (shot-70..79)
# =========================================================================
# These come from bin/vinos-* --help in the checkout. Cheap: no boot.
# Font: JetBrains Mono if present, else DejaVu Sans Mono. Style: near-
# black bg (#0f1218), fg-1 (#e0e2e7), 900px wide, height auto-sized to
# content.

find_mono_font() {
  local candidate
  for candidate in \
    "$ROOT/site/static/fonts/JetBrainsMono-Regular.ttf" \
    /usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf \
    /usr/share/fonts/TTF/JetBrainsMono-Regular.ttf \
    /usr/share/fonts/jetbrains-mono/JetBrainsMono-Regular.ttf \
    /usr/share/fonts/TTF/DejaVuSansMono.ttf \
    /usr/share/fonts/dejavu/DejaVuSansMono.ttf \
    /usr/share/fonts/liberation-mono/LiberationMono-Regular.ttf; do
    [[ -f "$candidate" ]] && { echo "$candidate"; return 0; }
  done
  find /usr/share/fonts -type f \( -iname '*JetBrainsMono*.ttf' -o -iname '*DejaVuSansMono*.ttf' -o -iname '*mono*.ttf' \) 2>/dev/null | head -1
}
HOST_FONT=$(find_mono_font)
[[ -n "$HOST_FONT" && -f "$HOST_FONT" ]] || die "no monospace font found for --help renders"
log "host font: $HOST_FONT"

# render_help(script_path, out_png, title, [override_text])
# If override_text is provided, use it instead of running --help. This
# is how we handle scripts that don't accept --help (vinos-doctor just
# runs; vinos-theme-set is a positional-only passthrough).
render_help() {
  local script="$1" out="$2" title="$3" override="${4:-}"
  if [[ ! -f "$script" ]]; then
    log "  SKIP $out: $script missing"
    return 1
  fi
  local tmp text
  tmp=$(mktemp)
  if [[ -n "$override" ]]; then
    text="$override"
  else
    # Invoke the script's --help. Fall back to bash for non-exec scripts.
    if [[ -x "$script" ]]; then
      text=$("$script" --help 2>&1 || true)
    else
      text=$(bash "$script" --help 2>&1 || true)
    fi
    if [[ -z "$text" ]]; then
      text="(no --help output; run '$title' directly to see live output)"
    fi
  fi
  # Prepend a shell prompt so it reads like a real terminal.
  {
    printf '$ %s --help\n' "$(basename "$script")"
    printf '%s\n' "$text"
  } >"$tmp"

  # Line-count → height. 20px per line at pointsize 15, plus padding
  # and a 40px title bar. Cap at 1600px so absurd outputs don't blow up.
  local lines h w=900
  lines=$(wc -l <"$tmp")
  (( lines < 12 )) && lines=12
  h=$(( 40 + 24 + lines * 20 + 24 ))
  (( h > 1600 )) && h=1600

  local pad=24
  magick \
    -size "${w}x${h}" xc:'#0f1218' \
    -fill '#1a1e26' -draw "rectangle 0,0 ${w},40" \
    -fill '#ff5f57' -draw "circle 20,20 20,26" \
    -fill '#febc2e' -draw "circle 40,20 40,26" \
    -fill '#28c840' -draw "circle 60,20 60,26" \
    -fill '#e0e2e7' -font "$HOST_FONT" -pointsize 12 \
      -annotate +90+26 "vinos ~ $title" \
    \( -background '#0f1218' -fill '#c9d1d9' \
       -font "$HOST_FONT" -pointsize 14 \
       -size "$((w - 2*pad))x$((h - 80))" \
       "caption:@$tmp" \) \
    -geometry "+${pad}+56" -composite \
    "$OUT/$out" \
    && log "  rendered $out (${w}x${h}, ${lines} lines)" \
    || log "  FAILED $out"
  rm -f "$tmp"
}

log "rendering CLI --help shots (host-side, no QEMU)…"
render_help "$ROOT/bin/vinos-routine"   vinos-routine-help.png  "vinos-routine"
render_help "$ROOT/bin/vinos-brief"     vinos-brief-help.png    "vinos-brief"
render_help "$ROOT/bin/vinos-standup"   vinos-standup-help.png  "vinos-standup"
render_help "$ROOT/bin/vinos-commit"    vinos-commit-help.png   "vinos-commit"
render_help "$ROOT/bin/vinos-focus"     vinos-focus-help.png    "vinos-focus"
render_help "$ROOT/bin/vinos-fix"       vinos-fix-help.png      "vinos-fix"
render_help "$ROOT/bin/vinos-explain"   vinos-explain-help.png  "vinos-explain"
render_help "$ROOT/bin/vinos-ai"        vinos-ai-help.png       "vinos-ai"
# vinos-doctor doesn't accept --help — it just runs. Show a synthesized
# "what it checks" summary rather than the FAIL-riddled live output we
# get on the dev host (which is misleading for docs readers).
render_help "$ROOT/bin/vinos-doctor" vinos-doctor-help.png "vinos-doctor" "\
vinos-doctor — health check for a vinOS install.

No arguments. Runs every check, prints [PASS] / [FAIL] / [SKIP]
grouped by section, then a one-line summary. Exits non-zero if any
FAIL. Runs in ~1s on a warm install.

Sections checked:
  os-release identity        NAME/ID/ID_LIKE
  base packages              base-devel git curl wget rsync openssh …
  user configs               ~/.config/fastfetch/config.jsonc …
  branding assets            /usr/share/vinos/VERSION, wallpaper, logo
  services                   ufw, iwd, greetd, docker (if installed)
  wifi (T2 Mac + generic)    regdb, brcmfmac feature_disable, cfg80211 …
  repo                       is the vinOS source available for vinos-update

Live output shown as a rendered shot at SCREENSHOTS_NEEDED.md #shot-60."

# vinos-theme-set is a positional-only passthrough to omarchy-theme-set.
# Its --help path is 'Theme "--help" does not exist' (an error path
# from omarchy-theme-set). Render a synthesized usage that reflects the
# actual v2.0.6 wrapper contract.
render_help "$ROOT/bin/vinos-theme-set" vinos-theme-set-help.png "vinos-theme-set" "\
vinos-theme-set — apply a shipped vinOS theme by name (v2.0.6 wrapper
around omarchy-theme-set).

Usage:
  vinos-theme-set <theme>

Available themes:
  bloom  circuit  cosmos  crater  dusk
  egret  prism    reef    ridge   summit

Behavior:
  * Rewrites the theme symlink at ~/.config/omarchy/current/theme.
  * Broadcasts a hyprland event; the shipped config reloads waybar,
    walker, mako, and terminal palettes in one shot.
  * Idempotent — running it twice with the same name is a no-op.

Related:
  vinos-theme                    # show current + list
  vinos-theme --pick             # walker picker (Super+Ctrl+Shift+Space)"

if [[ "$SKIP_BOOT" -eq 1 ]]; then
  log "--skip-boot set; done after host-side renders."
  exit 0
fi

# =========================================================================
# HOST-SIDE PHASE B: QEMU boot + in-guest runner
# =========================================================================

# --- fresh shared dir --------------------------------------------------
if [[ "$KEEP_TMP" -eq 0 ]]; then
  rm -rf "$CAPS"
fi
mkdir -p "$CAPS"
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
# VGA path: try virtio-gpu with a large mode; fall back to std VGA on
# failure. Note: virtio-gpu-pci without DRM host acceleration renders
# the same modes as std but supports xres/yres hinting. If the T2 kernel
# module chain doesn't cooperate we'd notice via a stalled boot log; we
# don't currently probe for that here — trust the try, fall back if the
# runner sees a tiny monitor.
QEMU_VGA=(-vga virtio -device virtio-gpu-pci,xres=2560,yres=1600)

# -serial: unix socket → socat pushes login + commands, receives prompt
# -qmp: unix socket → host issues system_powerdown at shutdown +
#                    screendump for pre-Hyprland captures
# -virtfs: 9p share tagged "caps" → mounted in-guest at /mnt/caps
SER_LOG="$WORK/serial-out.log"
SER_SOCK="$WORK/serial.sock"
IN_FIFO="$WORK/to-guest.fifo"
: >"$SER_LOG"
mkfifo "$IN_FIFO"

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
log "QEMU pid=$QPID (VGA: virtio-gpu 2560x1600 hint; falls back to std if unsupported)"

# Wait for the serial socket to appear.
for _ in $(seq 1 30); do
  [[ -S "$SER_SOCK" ]] && break
  sleep 1
done
[[ -S "$SER_SOCK" ]] || die "serial socket never appeared"

exec 8<>"$IN_FIFO"    # r+w: satisfies open() as reader
exec 9>"$IN_FIFO"     # w-only: our send() writes here
socat "UNIX-CONNECT:$SER_SOCK,ignoreeof" - \
  <&8 >>"$SER_LOG" 2>"$WORK/socat.err" &
RPID=$!
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

# --- QMP screendump helper (for shot-04 syslinux + shot-05 greetd) -
# QMP screendump writes a PPM to the given path. We shell out to
# magick to convert to PNG in $CAPS/. Silent on failure — these are
# best-effort captures.
qmp_screendump() {
  local dest="$1"
  local ppm="$WORK/dump.ppm"
  printf '{"execute":"qmp_capabilities"}\n{"execute":"screendump","arguments":{"filename":"%s"}}\n' "$ppm" \
    | socat - "UNIX-CONNECT:$QMP_SOCK" >/dev/null 2>&1 || return 1
  # QEMU writes the file async; wait briefly for it to appear.
  local t=0
  while [[ $t -lt 20 ]]; do
    [[ -s "$ppm" ]] && break
    sleep 0.2; t=$((t+1))
  done
  [[ -s "$ppm" ]] || return 1
  magick "$ppm" "$CAPS/$dest" 2>/dev/null || return 1
  rm -f "$ppm"
  local sz; sz=$(stat -c%s "$CAPS/$dest" 2>/dev/null || echo "?")
  log "  screendump → $dest (${sz} bytes)"
  return 0
}

# Kick off a background "boot phase" screendump chain. Fires at
# well-known timestamps into the boot to catch:
#   - t=4s   → syslinux menu still on-screen (shot-04)
#   - t=8s   → syslinux countdown finishing / kernel loading (backup)
#   - t=90s  → greetd/tuigreet or console login prompt (shot-05)
#   - t=120s → post-autologin, pre-desktop
(
  sleep 4  && qmp_screendump boot-syslinux-menu.png || true
  sleep 4  && qmp_screendump boot-syslinux-late.png || true
  sleep 82 && qmp_screendump login-greeter.png || true
  sleep 30 && qmp_screendump login-post.png || true
) &

# --- talk to serial: login as root, install runner, kick it off -------
INJECT="$WORK/inject.sh"
cat >"$INJECT" <<'INJECT_EOF'
set +e
umask 022
LOG=/tmp/vinos-inject.log
exec >>"$LOG" 2>&1
echo "== $(date -Iseconds) injector start =="

modprobe 9p         2>&1
modprobe 9pnet      2>&1
modprobe 9pnet_virtio 2>&1
lsmod | grep -E '^9p' 2>&1

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
  echo "===INJECTOR_MOUNT_FAIL===" >/dev/ttyS0 2>/dev/null
  cat "$LOG" >/dev/ttyS0 2>/dev/null
  echo "===INJECTOR_MOUNT_FAIL_END===" >/dev/ttyS0 2>/dev/null
  exit 1
fi
echo "===INJECTOR_MOUNT_OK===" >/dev/ttyS0 2>/dev/null
echo "mount OK; contents:"
ls -la /mnt/caps

cp -f "$LOG" /mnt/caps/serial-inject.log 2>/dev/null
exec >>/mnt/caps/serial-inject.log 2>&1

install -m 0755 /mnt/caps/vinos-shot-runner /usr/local/bin/vinos-shot-runner
echo "runner installed: $(ls -la /usr/local/bin/vinos-shot-runner)"

chmod 0777 /mnt/caps

# Diagnostic: does the vinos user even exist on this live image?
VINOS_UID=$(id -u vinos 2>/dev/null || echo MISSING)
echo "===INJECTOR_VINOS_UID=$VINOS_UID===" >/dev/ttyS0 2>/dev/null

# Wait up to 3min for greetd to autologin the vinos user and Hyprland
# to be running under uid 1000. Cold boots on this box regularly stall
# ~90-120s on ldconfig — pass 1's 120s window was too tight.
for i in $(seq 1 180); do
  if pgrep -u vinos -x Hyprland >/dev/null 2>&1; then break; fi
  sleep 1
done

HYPR_PID=$(pgrep -u vinos -x Hyprland | head -1)
if [ -z "$HYPR_PID" ]; then
  echo "===INJECTOR_HYPR_TIMEOUT===" >/dev/ttyS0 2>/dev/null
  ps -eo user,pid,cmd --no-headers 2>/dev/null | head -40 >/dev/ttyS0 2>/dev/null
  echo "===INJECTOR_HYPR_TIMEOUT_END===" >/dev/ttyS0 2>/dev/null
  echo "no Hyprland pid after 180s — bailing" >>/mnt/caps/serial-inject.log
  touch /mnt/caps/DONE
  exit 0
fi
echo "===INJECTOR_HYPR_UP_pid=$HYPR_PID===" >/dev/ttyS0 2>/dev/null

XDG_RUNTIME_DIR=/run/user/1000
HYPRLAND_INSTANCE=$(ls -1 "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
WAYLAND_DISPLAY=$(ls -1 "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E "^wayland-[0-9]+$" | head -1)
DBUS="unix:path=$XDG_RUNTIME_DIR/bus"

echo "vinos Hyprland pid=$HYPR_PID HIS=$HYPRLAND_INSTANCE WD=$WAYLAND_DISPLAY RD=$XDG_RUNTIME_DIR" >>/mnt/caps/serial-inject.log

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

RUNNER_PID=$!
echo "runner launched, pid=$RUNNER_PID" >>/mnt/caps/serial-inject.log
echo "===INJECTOR_RUNNER_LAUNCHED_pid=$RUNNER_PID===" >/dev/ttyS0 2>/dev/null
INJECT_EOF

B64=$(base64 -w0 <"$INJECT")

send() { printf '%s\r\n' "$1" >&9; }
wait_for() {
  local pat="$1" timeout="${2:-60}" start; start=$(date +%s)
  while [[ $(( $(date +%s) - start )) -lt $timeout ]]; do
    if grep -a -q -F "$pat" "$SER_LOG" 2>/dev/null; then return 0; fi
    sleep 1
  done
  return 1
}

log "logging in via serial and injecting runner"
# Fragile-bit #4: cold boots stall 60-120s on ldconfig. Pass 1 used
# 240s here; occasional boots just barely fit. Bump to 360s.
if ! wait_for "vinos-live login" 360; then
  log "  WARN: never saw a login prompt in 360s — kicking anyway"
fi
# Login flow. On the vinOS live ISO, root has NO password — but the
# agetty (`--login-program /usr/bin/login`) may or may not prompt for
# one. Send username, wait briefly, then send an empty password just
# in case. Pass-2 fragile-bit: pass-1's script skipped the password
# send and got "Password:" → treated our subsequent b64 chunk as the
# password → Login incorrect → 60s getty timeout kicked us out mid-run.
sleep 2
send ""            # nudge getty in case it lost sync
sleep 1
send "root"
sleep 2
send ""            # blank password (root has none on live)
# Wait for the root shell prompt. Root's PS1 on archiso ends in "# ".
# If we don't see it in 20s, fall through anyway.
prompt_ready=0
for _ in $(seq 1 20); do
  # Check for either a bash prompt char (# at end of line) OR the
  # motd banner "Welcome to vinOS" that only appears post-login.
  if grep -a -q -E '(vinos-live|root@vinos)[^:]*#|Welcome to vinOS' "$SER_LOG" 2>/dev/null; then
    prompt_ready=1
    break
  fi
  sleep 1
done
if [[ "$prompt_ready" -eq 1 ]]; then
  log "  root shell ready — injecting"
else
  log "  WARN: no shell prompt detected — injecting anyway"
fi
# Silence job-control chatter + speed up subsequent commands.
send "stty -echo; set +m"
sleep 0.3
send "rm -f /tmp/inj.b64"
sleep 0.4
# Chunk the base64 blob. Each chunk is 200 chars of payload wrapped
# in a printf. Pass-1 used 100 chars/line and 0.08s sleep — total
# runtime was ~5s for a 5KB blob, which is safely under agetty's
# 60s timeout. Keep those numbers.
step=100
for ((i=0; i<${#B64}; i+=step)); do
  send "printf %s ${B64:i:step} >>/tmp/inj.b64"
  sleep 0.08
done
sleep 0.5
send "base64 -d </tmp/inj.b64 >/tmp/inj.sh && bash /tmp/inj.sh"
sleep 1
send "echo INJECTOR_DONE_$$"
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
  count=$(find "$CAPS" -maxdepth 1 -name '*.png' -not -name '*.dup.png' 2>/dev/null | wc -l)
  dups=$(find "$CAPS" -maxdepth 1 -name '*.dup.png' 2>/dev/null | wc -l)
  now=$(date +%s); left=$(( DEADLINE - now ))
  printf '\033[1;34m[capture-shots]\033[0m  %ds left · %d PNGs so far · %d duplicates rejected\n' "$left" "$count" "$dups"
  sleep 30
done

exec 9>&- 2>/dev/null || true
kill "$RPID" 2>/dev/null || true
wait "$RPID" 2>/dev/null || true

# --- post-process: sync everything to $OUT with the docs-mandated names
log "post-processing PNGs → $OUT"
# Every filename the guest runner + boot-phase screendumps produce.
# Key = filename in CAPS, value = filename to ship in OUT.
declare -A MAP=(
  # existing pass-1 shots
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
  # boot-phase screendumps (host, via QMP)
  [boot-syslinux-menu.png]=boot-syslinux-menu.png
  [login-greeter.png]=login-greeter.png
  # new pass-2 shots
  [first-desktop.png]=first-desktop.png
  [welcome-checklist.png]=welcome-checklist.png
  [menu-style.png]=menu-style.png
  [menu-install.png]=menu-install.png
  [menu-trigger.png]=menu-trigger.png
  [routine-list.png]=routine-list.png
  [routine-run.png]=routine-run.png
  [routine-cost.png]=routine-cost.png
  [brief-panel.png]=brief-panel.png
  [waybar-close-up.png]=waybar-close-up.png
  [terminal-vinos-fix.png]=terminal-vinos-fix.png
  [terminal-vinos-standup.png]=terminal-vinos-standup.png
  [theme-cosmos-clean.png]=theme-cosmos-clean.png
  [theme-summit-clean.png]=theme-summit-clean.png
  [theme-circuit-clean.png]=theme-circuit-clean.png
)

CAPTURED=0
MISSED=()
DUPS=()
for src in "${!MAP[@]}"; do
  dst="${MAP[$src]}"
  if [[ -f "$CAPS/$src" ]]; then
    cp -f "$CAPS/$src" "$OUT/$dst"
    sz=$(stat -c%s "$OUT/$dst" 2>/dev/null || echo "?")
    dim=$(identify -format '%wx%h' "$OUT/$dst" 2>/dev/null || echo "?")
    printf '  \033[1;32mOK\033[0m  %-32s %8s bytes  %s\n' "$dst" "$sz" "$dim"
    CAPTURED=$((CAPTURED+1))
  elif [[ -f "$CAPS/${src%.png}.dup.png" ]]; then
    printf '  \033[1;33mDUP\033[0m %-32s (matched a recent frame; not shipped)\n' "$dst"
    DUPS+=("$dst")
  else
    MISSED+=("$dst")
  fi
done

# --- summary ----------------------------------------------------------
log "captured: $CAPTURED PNGs"
if (( ${#DUPS[@]} )); then
  log "duplicates rejected: ${#DUPS[@]}  ${DUPS[*]}"
fi
if (( ${#MISSED[@]} )); then
  log "missed:  ${#MISSED[@]}  ${MISSED[*]}"
fi
log "explicitly skipped (documented):"
log "  shot-01 boot-plymouth.png            — host-side screendump not implemented"
log "  shot-21 waybar-routine-widget.png    — widget not shipped until v2.0.6"
log "  shot-22 routine-notification.png     — needs API key + real routine run"
log "  shot-50 t2-mbp-boot.png              — physical phone photo required"
log ""
log "runner logs: $CAPS/runner.log · serial log: $CAPS/serial-inject.log · qemu: $QLOG"
[[ -f "$CAPS/capture.log" ]] && log "shot manifest: $CAPS/capture.log"

exit 0
