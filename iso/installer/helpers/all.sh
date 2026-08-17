# helpers/all.sh — sourced first by vinos-install. Provides logging,
# marker helpers, chroot helpers, run-or-die.
#
# All installer state lives under $STATE_DIR (/var/log/vinos-install/).
# Marker files gate phase re-entry: if the marker exists, the phase is
# skipped. Delete the marker to force re-run of a phase.
#
# Design rule: every command that can mutate disk or system state must
# be wrapped by `run` so its exit code is checked and its stdout+stderr
# lands in the install log verbatim. Silent failure is the enemy.

STATE_DIR="${VINOS_STATE_DIR:-/var/log/vinos-install}"
MARKER_DIR="$STATE_DIR/markers"
LOG="${VINOS_INSTALL_LOG:-$STATE_DIR/install.log}"
ANSWERS="${VINOS_ANSWERS:-$STATE_DIR/answers.env}"
TARGET_ROOT="${VINOS_TARGET_ROOT:-/mnt}"

install -d -m 0755 "$STATE_DIR" "$MARKER_DIR"
touch "$LOG"; chmod 0600 "$LOG"

# ── logging ────────────────────────────────────────────────────────
_log_ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

log() {
  local msg="[$(_log_ts)] $*"
  printf '\033[1;34m%s\033[0m\n' "$msg"
  printf '%s\n' "$msg" >> "$LOG"
}

warn() {
  local msg="[$(_log_ts)] WARN: $*"
  printf '\033[1;33m%s\033[0m\n' "$msg" >&2
  printf '%s\n' "$msg" >> "$LOG"
}

die() {
  local msg="[$(_log_ts)] FAIL: $*"
  printf '\033[1;31m%s\033[0m\n' "$msg" >&2
  printf '%s\n' "$msg" >> "$LOG"
  exit 1
}

step() {
  local msg="[$(_log_ts)] === $* ==="
  printf '\033[1;36m%s\033[0m\n' "$msg"
  printf '%s\n' "$msg" >> "$LOG"
}

# ── run: wrapper for every mutating command ────────────────────────
# Echoes the command, executes, streams stdout+stderr to the log AND
# the current TTY. On non-zero exit: die with the captured tail so the
# operator sees WHY it failed, not just that it did.
run() {
  local rc tail_bytes
  log "run: $*"
  # Line-buffered pipe so log tails are useful; script(1) would be nicer
  # but adds a dep. Use unbuffer only if available.
  if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL "$@" 2>&1 | tee -a "$LOG"
  else
    "$@" 2>&1 | tee -a "$LOG"
  fi
  rc=${PIPESTATUS[0]}
  if (( rc != 0 )); then
    tail_bytes="$(tail -20 "$LOG" 2>/dev/null || true)"
    die "command exited $rc: $*
Last 20 log lines:
$tail_bytes"
  fi
  return 0
}

# Same as run but the failure is not fatal — caller checks rc.
try_run() {
  local rc
  log "try_run: $*"
  "$@" 2>&1 | tee -a "$LOG"
  rc=${PIPESTATUS[0]}
  return "$rc"
}

# ── phase markers ──────────────────────────────────────────────────
# phase_start N SHORT_NAME  — call at top of a phase. If already done,
# skips the phase body. Returns 1 to signal skip; caller MUST return 0
# on skip (i.e. `phase_start 30 disk || return 0`).
phase_start() {
  local num="$1" name="$2"
  local marker="$MARKER_DIR/${num}-${name}.done"
  if [[ -f "$marker" ]]; then
    log "phase $num-$name: SKIP (marker exists)"
    return 1
  fi
  step "phase $num-$name: START"
  return 0
}

phase_done() {
  local num="$1" name="$2"
  local marker="$MARKER_DIR/${num}-${name}.done"
  install -m 0644 /dev/null "$marker"
  log "phase $num-$name: DONE"
}

# ── answers.env io ─────────────────────────────────────────────────
# answers.env is a shell-sourceable KEY=VALUE file. Written by prompts/,
# read by every phase after that. Keep values simple — no spaces in
# hostnames, no shell metacharacters. Password is stored TEMPORARILY
# here for the pacstrap phase, then scrubbed by finalize/.
answers_write() {
  # Args: KEY VALUE (repeated). Idempotent — replaces existing KEY.
  local key val
  local tmp
  tmp="$(mktemp)"
  [[ -f "$ANSWERS" ]] && cp "$ANSWERS" "$tmp"
  chmod 0600 "$tmp"
  while (( $# > 0 )); do
    key="$1"; val="$2"; shift 2
    # Escape single quotes in val for safe shell-sourcing.
    val="${val//\'/\'\\\'\'}"
    # Drop any prior line for this key.
    sed -i "/^${key}=/d" "$tmp"
    printf "%s='%s'\n" "$key" "$val" >> "$tmp"
  done
  install -m 0600 "$tmp" "$ANSWERS"
  rm -f "$tmp"
}

answers_load() {
  if [[ -f "$ANSWERS" ]]; then
    # shellcheck disable=SC1090
    source "$ANSWERS"
  fi
}

answers_get() {
  # Print the value of the given key (empty if unset). Non-destructive.
  local key="$1"
  [[ -f "$ANSWERS" ]] || { printf ''; return; }
  awk -F= -v k="$key" '
    $1 == k { sub(/^[^=]+=/,""); gsub(/^\047|\047$/,""); print; exit }
  ' "$ANSWERS"
}

# ── chroot helpers ─────────────────────────────────────────────────
# Prefer systemd-nspawn for bootloader ops (sidesteps systemd #36174).
# For everything else, arch-chroot's bind-mount + chroot is enough and
# doesn't require a full container init. Both are checked at preflight.
chroot_run() {
  # Args: bash script (multi-line via heredoc-friendly). Runs in
  # arch-chroot on $TARGET_ROOT. Non-zero exit → die.
  local script="$1"
  log "chroot_run (arch-chroot on $TARGET_ROOT):"
  printf '  %s\n' "$script" | sed 's/^/  /' | tee -a "$LOG" >/dev/null
  if arch-chroot "$TARGET_ROOT" bash -euo pipefail -c "$script" 2>&1 | tee -a "$LOG"; then
    return 0
  else
    die "chroot_run failed. Script was:
$script"
  fi
}

nspawn_run() {
  # Args: bash script. Runs in systemd-nspawn on $TARGET_ROOT. Use this
  # for bootctl install / systemd operations that need a proper PID 1.
  local script="$1"
  log "nspawn_run on $TARGET_ROOT:"
  printf '  %s\n' "$script" | sed 's/^/  /' | tee -a "$LOG" >/dev/null
  if systemd-nspawn -q -D "$TARGET_ROOT" --console=pipe bash -euo pipefail -c "$script" 2>&1 | tee -a "$LOG"; then
    return 0
  else
    die "nspawn_run failed. Script was:
$script"
  fi
}

# ── assertion helpers ──────────────────────────────────────────────
must_have_cmd() {
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command missing on live ISO: $c"
  done
}

must_have_file() {
  for f in "$@"; do
    [[ -e "$f" ]] || die "required file missing: $f"
  done
}

must_be_root() {
  (( EUID == 0 )) || die "must run as root"
}

must_be_uefi() {
  [[ -d /sys/firmware/efi/efivars ]] || die "vinOS installer requires UEFI. Legacy BIOS is not supported (as of v1.4.0)."
}
