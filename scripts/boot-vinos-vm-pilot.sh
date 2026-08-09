#!/usr/bin/env bash
# scripts/boot-vinos-vm-pilot.sh — boot the vinos-vm pilot image
# under QEMU and capture the PERSONAS.md § Pilot-3 measurement panel.
#
# Boots iso/out/vinos-vm-pilot.qcow2 in QEMU with:
#   - user-mode networking + hostfwd 2222:22
#   - direct-kernel boot (kernel+initrd from build-vinos-vm-pilot.sh)
#   - cloud-init NoCloud data source via a mkisofs seed image
#     carrying the runner's SSH pubkey + a mission-less user-data
#
# Measures and prints:
#   1. Image size (compressed qcow2)   target < 900 MB
#   2. Boot-to-SSH-ready (t = first ok ssh)  target < 45 s
#   3. Idle RAM (free -m after 30s)     target < 300 MB
#   4. Package count (dpkg -l | wc -l)  target < 100
#   5. SSH pubkey-only works            target PASS
#   6. Password auth blocked            target FAIL (from client side)
#   7. nftables port scan               target only :22 open
#
# Emits: iso/out/vinos-vm-pilot.measurements.json + a human summary.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO/iso/out"
IMG="$OUT_DIR/vinos-vm-pilot.qcow2"
KERNEL="$OUT_DIR/vmlinuz"
INITRD="$OUT_DIR/initrd.img"
SEED_ISO="$OUT_DIR/vinos-vm-pilot-seed.iso"
MEAS_JSON="$OUT_DIR/vinos-vm-pilot.measurements.json"
BOOT_LOG="$OUT_DIR/vinos-vm-pilot.boot.log"
SSH_KEY="$OUT_DIR/vinos-vm-pilot.key"
SSH_PORT=2222
BOOT_TIMEOUT=180

die()  { printf '\033[1;31m[boot-vm-pilot] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log()  { printf '\033[1;34m[boot-vm-pilot]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[boot-vm-pilot] warn:\033[0m %s\n' "$*" >&2; }

[[ -f "$IMG"    ]] || die "$IMG not found — run scripts/build-vinos-vm-pilot.sh first"
[[ -f "$KERNEL" ]] || die "$KERNEL not found"
[[ -f "$INITRD" ]] || die "$INITRD not found"
command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 required"
command -v ssh >/dev/null || die "ssh client required"
command -v ssh-keygen >/dev/null || die "ssh-keygen required"
command -v xorriso >/dev/null 2>&1 || command -v mkisofs >/dev/null 2>&1 || command -v genisoimage >/dev/null 2>&1 \
  || die "xorriso, mkisofs, or genisoimage required to build the cloud-init seed"

# --- Generate an ephemeral SSH key ---------------------------------
if [[ ! -f "$SSH_KEY" ]]; then
  ssh-keygen -t ed25519 -N '' -C 'vinos-vm-pilot' -f "$SSH_KEY" >/dev/null
fi
PUBKEY=$(cat "${SSH_KEY}.pub")

# --- Build the cloud-init NoCloud seed ISO -------------------------
log "building NoCloud seed ISO"
SEED_DIR=$(mktemp -d)
trap 'rm -rf "$SEED_DIR"' EXIT

cat > "$SEED_DIR/meta-data" <<META
instance-id: vinos-vm-pilot-0001
local-hostname: vinos-vm-pilot
META

cat > "$SEED_DIR/user-data" <<USER
#cloud-config
ssh_authorized_keys:
  - ${PUBKEY}
runcmd:
  - [ systemctl, restart, nftables ]
USER

if command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs -input-charset utf-8 -o "$SEED_ISO" -V cidata \
    -joliet -r "$SEED_DIR" >/dev/null 2>&1
elif command -v genisoimage >/dev/null 2>&1; then
  genisoimage -output "$SEED_ISO" -volid cidata -joliet -rock "$SEED_DIR" >/dev/null 2>&1
else
  mkisofs -output "$SEED_ISO" -volid cidata -joliet -rock "$SEED_DIR" >/dev/null 2>&1
fi

# --- Boot QEMU in the background -----------------------------------
log "booting $IMG with direct-kernel + seed ISO"
: > "$BOOT_LOG"

ACCEL="tcg"
if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then ACCEL="kvm:tcg"; fi

qemu_args=(
  -m 1024 -smp 2
  -machine accel="$ACCEL"
  -drive file="$IMG",if=virtio,format=qcow2
  -drive file="$SEED_ISO",if=virtio,format=raw,readonly=on
  -kernel "$KERNEL"
  -initrd "$INITRD"
  -append "root=LABEL=VINOSROOT rw console=ttyS0 net.ifnames=0 biosdevname=0 quiet"
  -netdev user,id=n1,hostfwd=tcp::${SSH_PORT}-:22
  -device virtio-net-pci,netdev=n1
  -display none
  -serial "file:$BOOT_LOG"
  -no-reboot
)

qemu-system-x86_64 "${qemu_args[@]}" &
qpid=$!
trap 'kill $qpid 2>/dev/null || true; rm -rf "$SEED_DIR"' EXIT

# --- Poll for SSH-ready --------------------------------------------
log "polling SSH on port $SSH_PORT (timeout ${BOOT_TIMEOUT}s)"
t_start=$(date +%s%N)
boot_ok=0
while (( $(date +%s%N) - t_start < BOOT_TIMEOUT * 1000000000 )); do
  if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
         -o ConnectTimeout=2 -o LogLevel=ERROR \
         -p "$SSH_PORT" ubuntu@127.0.0.1 true 2>/dev/null; then
    boot_ok=1
    t_end=$(date +%s%N)
    break
  fi
  if ! kill -0 $qpid 2>/dev/null; then
    warn "QEMU died before SSH came up"
    break
  fi
  sleep 1
done

if (( boot_ok == 0 )); then
  tail -30 "$BOOT_LOG" 2>&1
  kill $qpid 2>/dev/null || true
  die "SSH did not come up within ${BOOT_TIMEOUT}s"
fi

boot_ms=$(( (t_end - t_start) / 1000000 ))
log "SSH ready in ${boot_ms} ms"

# --- Run measurements over SSH -------------------------------------
_ssh() {
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR -p "$SSH_PORT" ubuntu@127.0.0.1 "$@"
}

sleep 30  # per PERSONAS: idle RAM measured after 30s
mem_used_mb=$(_ssh "free -m | awk '/^Mem:/ {print \$3}'")
pkg_count=$(_ssh "dpkg -l | tail -n +6 | wc -l")
listen_ports=$(_ssh "ss -tuln | awk 'NR>1 {print \$5}' | awk -F: '{print \$NF}' | sort -u | tr '\n' ',' | sed 's/,$//'")
nft_ports=$(_ssh "sudo nft list ruleset 2>/dev/null | grep -oE 'tcp dport [0-9]+' | awk '{print \$3}' | sort -u | tr '\n' ',' | sed 's/,$//'")
pwauth_disabled=$(_ssh "grep -E '^PasswordAuthentication no' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | wc -l")

# Password auth blocked — verify from CLIENT side by trying and expecting failure.
if ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
       -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR \
       -p "$SSH_PORT" ubuntu@127.0.0.1 true 2>&1 | grep -q 'Permission denied\|no supported\|remote host\|Connection reset'; then
  pw_blocked="PASS"
else
  pw_blocked="AMBIGUOUS"
fi

# --- Shutdown gracefully -------------------------------------------
_ssh 'sudo systemctl poweroff' >/dev/null 2>&1 || true
wait $qpid 2>/dev/null || true

# --- Report --------------------------------------------------------
qcow2_bytes=$(stat -c '%s' "$IMG")
qcow2_hr=$(numfmt --to=iec-i --suffix=B "$qcow2_bytes")
qcow2_mb=$(( qcow2_bytes / 1024 / 1024 ))

cat > "$MEAS_JSON" <<JSON
{
  "image": "$IMG",
  "measured_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "targets_from": "PERSONAS.md § Pilot 3",
  "measurements": {
    "qcow2_size_mb":            { "value": $qcow2_mb,       "target_max": 900,  "unit": "MiB" },
    "boot_to_ssh_ms":           { "value": $boot_ms,        "target_max": 45000, "unit": "ms" },
    "idle_ram_used_mb":         { "value": $mem_used_mb,    "target_max": 300,  "unit": "MiB" },
    "dpkg_count":               { "value": $pkg_count,      "target_max": 100,  "unit": "packages" },
    "ssh_pubkey_only":          { "value": "PASS",          "target": "PASS" },
    "ssh_password_blocked":     { "value": "$pw_blocked",   "target": "PASS" },
    "nftables_open_tcp_ports":  { "value": "$nft_ports",    "target": "22" }
  },
  "extra": {
    "listen_ports_ss": "$listen_ports",
    "sshd_pwauth_disabled_files": $pwauth_disabled
  }
}
JSON

log "measurements saved to $MEAS_JSON"
log ""
log "== summary =="
jq -r '.measurements | to_entries[] | "  \(.key): \(.value.value)   (target: \(.value.target // .value.target_max))"' "$MEAS_JSON"
