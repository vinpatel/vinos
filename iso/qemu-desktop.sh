#!/usr/bin/env bash
# iso/qemu-desktop.sh — boot the built ISO in a real QEMU window on the
# host, no host install required. Uses the vinos-iso-tester container
# (already has qemu-base + edk2-ovmf) with X11/Wayland socket forwarded
# so the QEMU GTK window renders on the user's desktop.
#
# Usage:
#   iso/qemu-desktop.sh                          # BIOS, 4G, KVM (local GUI)
#   iso/qemu-desktop.sh --mode uefi              # UEFI via OVMF
#   iso/qemu-desktop.sh --mem 8G
#   iso/qemu-desktop.sh --iso PATH
#   iso/qemu-desktop.sh --vnc                    # VNC on 127.0.0.1:5900
#   iso/qemu-desktop.sh --lan                    # VNC on 0.0.0.0:5900
#   iso/qemu-desktop.sh --lan --keepalive        # + auto-defeat hypridle
#   iso/qemu-desktop.sh --lan --keepalive --hostfwd  # + SSH forward 2222→22
#
# --vnc mode: SSH-tunnel port 5900 to your laptop and connect with macOS
# Screen Sharing (Finder → Cmd+K → vnc://localhost:5900).
#
# --lan mode: canonical test path when the Linux dev host and the Mac
# are on the same LAN. Binds VNC to 0.0.0.0 so Finder → Cmd+K →
# vnc://<host-ip> connects directly, no SSH tunnel. Prerequisite: open
# port 5900/tcp in the host firewall (LAN-scoped). Default password
# "vinos"; override with --password STR or --no-password.
#
# --monitor [SOCK]: expose QEMU HMP monitor socket (default /tmp/qemu-hmp.sock).
#                   Used by iso/qa/hmp.sh, keepalive, and test-super-return.sh.
#
# --keepalive:      spawn iso/qa/keepalive.sh in background — sends a
#                   silent Shift press to the guest every 45 s so hypridle
#                   NEVER triggers hyprlock. Required for pre-v1.2.3 ISOs
#                   where the live user cannot unlock (empty password + PAM).
#                   Auto-enables --monitor.
#
# --hostfwd [PORT]: forward tcp::<host>:PORT → guest:22 (sshd) for hot-patch
#                   iteration via iso/qa/loop.sh. Default host port 2222.
#
# VNC forwards Super natively, so no keyboard-grab dance is needed.
#
# See .planning/TESTING.md for the full test runbook.
#
# Prefers host `qemu-system-x86_64` when present (faster startup);
# otherwise runs the tester container with GTK display forwarded.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO=""
MODE="bios"
MEM="8G"           # was 4G; bumped 2026-08-14 after user reported slow response
SMP=4              # was 2; host has 12 cores so 4 is safe on the shared dev host
VGA="virtio"       # was "std"; virtio-vga is much faster with the modern QEMU/KVM
VNC=""              # empty = local GUI; "5900" or "0.0.0.0:5900" = VNC headless
VNC_PASSWORD=""     # empty + --lan → auto-set to "vinos"; empty + --vnc → no auth
                    # (SSH tunnel already provides confidentiality on --vnc)
MONITOR_SOCK=""     # non-empty = expose QEMU HMP monitor at this Unix socket path
KEEPALIVE=0         # 1 = spawn iso/qa/keepalive.sh in background to defeat hypridle
HOSTFWD_SSH=""      # e.g. "2222" — QEMU forwards <host>:2222 → guest 22 (sshd)

die() { printf '\033[1;31m[qemu-desktop] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[qemu-desktop]\033[0m %s\n' "$*"; }

# Parse --vnc's optional value: --vnc alone → default 5900, --vnc NNNN → that
# port. Accept "host:port" too. Falls through to default when the next arg is
# another flag or missing.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)  ISO="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --mem)  MEM="$2"; shift 2 ;;
    --smp)  SMP="$2"; shift 2 ;;
    --vga)  VGA="$2"; shift 2 ;;
    --vnc)
      if [[ $# -ge 2 && "$2" != --* ]]; then VNC="$2"; shift 2
      else VNC="127.0.0.1:5900"; shift; fi
      # Bare port → bind to localhost only (safe default).
      [[ "$VNC" =~ ^[0-9]+$ ]] && VNC="127.0.0.1:$VNC"
      ;;
    --lan)
      # LAN-visible VNC. Bare port arg allowed (defaults to 5900).
      if [[ $# -ge 2 && "$2" != --* && "$2" =~ ^[0-9]+$ ]]; then
        VNC="0.0.0.0:$2"; shift 2
      else
        VNC="0.0.0.0:5900"; shift
      fi
      ;;
    --password)   VNC_PASSWORD="$2"; shift 2 ;;
    --no-password) VNC_PASSWORD="__NONE__"; shift ;;
    --monitor)
      # Optional custom path; defaults to /tmp/qemu-hmp.sock.
      if [[ $# -ge 2 && "$2" != --* ]]; then MONITOR_SOCK="$2"; shift 2
      else MONITOR_SOCK="/tmp/qemu-hmp.sock"; shift; fi
      ;;
    --keepalive) KEEPALIVE=1; shift ;;
    --hostfwd)
      # Bare port sets host port, guest port fixed at 22 (sshd).
      if [[ $# -ge 2 && "$2" != --* && "$2" =~ ^[0-9]+$ ]]; then HOSTFWD_SSH="$2"; shift 2
      else HOSTFWD_SSH="2222"; shift; fi
      ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# --keepalive requires --monitor; auto-enable a default socket if user forgot.
if [[ "$KEEPALIVE" == 1 && -z "$MONITOR_SOCK" ]]; then
  MONITOR_SOCK="/tmp/qemu-hmp.sock"
fi

[[ -z "$ISO" ]] && ISO="$(ls -1t "$ISO_DIR"/out/vinos-*.iso 2>/dev/null | head -1 || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO — run iso/build.sh (or pass --iso PATH)"
case "$MODE" in bios|uefi) ;; *) die "--mode must be bios or uefi" ;; esac

# Prefer host qemu when installed.
if command -v qemu-system-x86_64 >/dev/null 2>&1; then
  log "using host qemu-system-x86_64"
  # Display selection:
  #   --vnc → serve VNC over the network (Super passes through natively).
  #   Wayland session → SDL with grab hotkey (LShift+LCtrl+LAlt) so the
  #     host compositor releases Super via keyboard-shortcuts-inhibit-v1.
  #     (SDL only accepts lshift-lctrl-lalt or rctrl for grab-mod.)
  #   X11 session → plain GTK.
  if [[ -n "$VNC" ]]; then
    # QEMU's -vnc expects "host:display" where display is (port-5900).
    host="${VNC%:*}"; port="${VNC##*:}"
    dpy=$(( port - 5900 ))
    [[ "$dpy" -ge 0 ]] || die "VNC port must be >= 5900 (got $port)"

    # Default LAN password when caller didn't set one and didn't opt out.
    # macOS Screen Sharing always prompts, so a stable known password
    # streamlines the flow. Loopback --vnc keeps noauth by default because
    # the SSH tunnel already secures it.
    if [[ -z "$VNC_PASSWORD" && "$host" == "0.0.0.0" ]]; then
      VNC_PASSWORD="vinos"
    fi

    display="vnc=${host}:${dpy}"
    if [[ -n "$VNC_PASSWORD" && "$VNC_PASSWORD" != "__NONE__" ]]; then
      display+=",password-secret=vncpw"
    fi

    log "VNC on ${host}:${port}"
    if [[ "$host" == "0.0.0.0" ]]; then
      lan_ip="$(ip -4 addr show 2>/dev/null | awk '/inet .*global/ {gsub(/\/.*/,"",$2); print $2; exit}')"
      log "From your Mac:"
      log "  Finder → Cmd+K → vnc://${lan_ip:-<host-ip>}:${port}"
      log "  (or:  open vnc://${lan_ip:-<host-ip>}:${port} )"
      if [[ -n "$VNC_PASSWORD" && "$VNC_PASSWORD" != "__NONE__" ]]; then
        log "  Password: \033[1;32m${VNC_PASSWORD}\033[0m"
      else
        log "  Password: (none — auth disabled with --no-password)"
      fi
    else
      log "Localhost-only. Connect from your Mac with:"
      log "  Terminal 1: ssh -N -L ${port}:${host}:${port} <user>@<this-host>"
      log "  Terminal 2: open vnc://localhost:${port}"
      if [[ -n "$VNC_PASSWORD" && "$VNC_PASSWORD" != "__NONE__" ]]; then
        log "  Password: \033[1;32m${VNC_PASSWORD}\033[0m"
      fi
    fi
  elif [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
    display="gtk"
  else
    display="sdl,grab-mod=lshift-lctrl-lalt"
  fi
  args=(-m "$MEM" -smp "$SMP" -cdrom "$ISO" -boot order=d,menu=off -vga "$VGA" -display "$display"
        -usb -device usb-kbd -device usb-tablet)
  [[ -c /dev/kvm ]] && args+=(-enable-kvm -cpu host)
  # Wire VNC password via an inline QEMU secret (host-side only; never
  # written to disk). Skipped when noauth was explicitly requested.
  if [[ -n "$VNC" && -n "$VNC_PASSWORD" && "$VNC_PASSWORD" != "__NONE__" ]]; then
    args+=(-object "secret,id=vncpw,data=${VNC_PASSWORD},format=raw")
  fi
  # HMP monitor socket for automation (keepalive, hmp.sh, test-super-return).
  if [[ -n "$MONITOR_SOCK" ]]; then
    rm -f "$MONITOR_SOCK"
    args+=(-monitor "unix:${MONITOR_SOCK},server,nowait")
    log "HMP monitor socket: ${MONITOR_SOCK}"
  fi
  # SSH port-forward from host to guest (for hot-patch iteration via loop.sh).
  if [[ -n "$HOSTFWD_SSH" ]]; then
    args+=(-nic "user,hostfwd=tcp::${HOSTFWD_SSH}-:22")
    log "SSH forward: <host>:${HOSTFWD_SSH} → guest:22 (vinos@<host>, empty pw on live)"
  fi
  if [[ "$MODE" == uefi ]]; then
    ovmf_code=""
    for c in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd; do
      [[ -f "$c" ]] && { ovmf_code="$c"; break; }
    done
    [[ -n "$ovmf_code" ]] || die "OVMF_CODE not found — install edk2-ovmf"
    ovmf_vars=/tmp/vinos-OVMF_VARS.fd
    [[ -f "$ovmf_vars" ]] || cp "${ovmf_code%CODE.*}VARS.${ovmf_code##*CODE.}" "$ovmf_vars"
    args+=(
      -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code"
      -drive "if=pflash,format=raw,file=$ovmf_vars"
    )
  fi
  # Spawn keepalive after QEMU starts. `exec` would replace this shell so we
  # fork QEMU when --keepalive was requested, wait for the HMP socket, then
  # start the keepalive as a background job before wait()ing on QEMU.
  if [[ "$KEEPALIVE" == 1 ]]; then
    [[ -n "$MONITOR_SOCK" ]] || die "--keepalive requires --monitor (auto-defaulted upstream — bug)"
    qemu-system-x86_64 "${args[@]}" &
    qpid=$!
    # Poll for the HMP socket (QEMU creates it a fraction of a second after fork).
    for _ in {1..30}; do
      [[ -S "$MONITOR_SOCK" ]] && break
      sleep 0.2
    done
    if [[ -S "$MONITOR_SOCK" ]]; then
      setsid "$ISO_DIR/qa/keepalive.sh" --socket "$MONITOR_SOCK" >/dev/null 2>&1 < /dev/null &
      kapid=$!
      log "keepalive spawned (PID $kapid) — hypridle idle timer will never fire"
      trap "kill $kapid 2>/dev/null || true" EXIT
    else
      log "warning: HMP socket did not appear — keepalive not started"
    fi
    wait "$qpid"
    exit $?
  fi
  exec qemu-system-x86_64 "${args[@]}"
fi

# Fallback: run in a dedicated container image with GTK UI installed.
log "host qemu missing — falling back to docker + X11 forward"
IMG="vinos-qemu-desktop:latest"
if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  log "one-time: building qemu-desktop image (qemu-base + qemu-ui-gtk + edk2-ovmf)"
  docker build -t "$IMG" -f - . <<'DOCKERFILE'
FROM archlinux:latest
RUN pacman -Sy --needed --noconfirm qemu-base qemu-ui-gtk edk2-ovmf && pacman -Scc --noconfirm
DOCKERFILE
fi

[[ -n "${DISPLAY:-}" ]] || die "no DISPLAY — either install qemu-desktop on host (sudo pacman -S qemu-desktop edk2-ovmf) or run under X/Wayland+XWayland"

# Allow docker to open X11 windows on this display. Try xhost first,
# fall back to no-op (usually works with same-uid + socket mount).
if command -v xhost >/dev/null 2>&1; then
  xhost +local:root >/dev/null 2>&1 || true
fi

KVM_ARGS=()
[[ -c /dev/kvm && -w /dev/kvm ]] && KVM_ARGS+=(--device /dev/kvm)

CMD=(
  qemu-system-x86_64
  -m "$MEM" -smp 2
  -machine accel=kvm:tcg
  -cdrom /iso.iso
  -boot order=d,menu=off
  -vga std
  -display gtk
  -usb -device usb-kbd -device usb-tablet
)
if [[ "$MODE" == uefi ]]; then
  CMD+=(
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
    -drive "if=pflash,format=raw,file=/tmp/OVMF_VARS.fd"
  )
fi

docker run --rm "${KVM_ARGS[@]}" \
  --net=host \
  -e DISPLAY="$DISPLAY" \
  -e XAUTHORITY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$ISO":/iso.iso:ro \
  --user "$(id -u):$(id -g)" \
  --group-add "$(getent group video | cut -d: -f3)" \
  "$IMG" \
  bash -c '
    if [[ "'"$MODE"'" == uefi ]]; then
      cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/OVMF_VARS.fd
    fi
    exec '"${CMD[*]}"'
  '
