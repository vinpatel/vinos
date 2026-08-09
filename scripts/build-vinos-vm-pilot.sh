#!/usr/bin/env bash
# scripts/build-vinos-vm-pilot.sh — build the vinos-vm Pilot 3 image.
#
# Debootstraps Ubuntu 24.04 (noble) minimal inside a Docker container,
# installs the PERSONAS.md § 2.2 package set (minus the not-yet-shipped
# vinOS runtime .debs), applies § 2.3 hardening drop-ins, then produces
# a bootable qcow2 image at iso/out/vinos-vm-pilot.qcow2.
#
# Design goals from PERSONAS.md:
#   - qcow2 size       < 900 MB
#   - boot-to-SSH      < 45 s
#   - idle RAM         < 300 MB
#   - dpkg -l count    < 100     (ambitious; likely miss — record honestly)
#   - SSH pubkey-only  pass
#   - password auth    blocked
#   - nftables ports   only 22 open
#
# Usage:
#   scripts/build-vinos-vm-pilot.sh                 # full build
#   scripts/build-vinos-vm-pilot.sh --skip-build    # only reslice image
#   VINOS_VM_SIZE=4G scripts/build-vinos-vm-pilot.sh
#
# Output: iso/out/vinos-vm-pilot.qcow2 + iso/out/vinos-vm-pilot.info
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO/iso/out"
IMG_RAW="$OUT_DIR/vinos-vm-pilot.raw"
IMG_QCOW2="$OUT_DIR/vinos-vm-pilot.qcow2"
INFO="$OUT_DIR/vinos-vm-pilot.info"
SIZE="${VINOS_VM_SIZE:-3G}"

die()  { printf '\033[1;31m[build-vm-pilot] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log()  { printf '\033[1;34m[build-vm-pilot]\033[0m %s\n' "$*"; }

command -v docker >/dev/null || die "docker required"
command -v qemu-img >/dev/null || die "qemu-img required"
command -v mkfs.ext4 >/dev/null || die "mkfs.ext4 required"

mkdir -p "$OUT_DIR"

# --- Step 1: raw disk with ext4 root filesystem ---------------------
log "creating $SIZE raw image"
rm -f "$IMG_RAW"
truncate -s "$SIZE" "$IMG_RAW"
mkfs.ext4 -q -F -L VINOSROOT "$IMG_RAW"

# --- Step 2: debootstrap + package install inside Docker ------------
# Runs the whole build in an ubuntu:24.04 container so the debootstrap
# host has the right suite defs + gpg keys. Bind-mounts the raw image
# at /out/root.raw, mounts it, populates it, unmounts, we're done.
log "building rootfs inside ubuntu:24.04 container (~10-20 min)"

docker run -i --rm --privileged \
  -v "$OUT_DIR":/out:rw \
  -v "$REPO":/vinos:ro \
  -v /dev:/dev \
  -e SIZE="$SIZE" \
  -e RAW_NAME="$(basename "$IMG_RAW")" \
  ubuntu:24.04 \
  bash -euo pipefail <<'DOCKER_EOF'

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  debootstrap \
  systemd-container \
  cloud-image-utils \
  qemu-utils \
  parted \
  util-linux \
  udev >/dev/null

# Mount the raw image via an explicit loop device. Docker's --privileged
# doesn't grant `mount -o loop` on its own; we bind /dev in from the host
# and losetup an unused loop device ourselves.
mkdir -p /mnt
LOOP=$(losetup -f --show "/out/${RAW_NAME}")
echo "== loop device: $LOOP =="
mount "$LOOP" /mnt

# debootstrap minimal variant to hit the < 100 package target (still
# unlikely — record honest numbers post-build). --variant=minbase gives
# the smallest possible Ubuntu userland (~ 90 pkgs base). We layer on
# extras with apt after chroot is bootable.
echo "== debootstrap minbase noble =="
debootstrap \
  --variant=minbase \
  --components=main,universe \
  --include=systemd-sysv,init,dbus,udev,netbase,iproute2,iputils-ping,ca-certificates,gnupg \
  noble /mnt http://archive.ubuntu.com/ubuntu/

# Setup for chroot commands.
mount -t proc  proc  /mnt/proc
mount -t sysfs sys   /mnt/sys
mount --bind /dev    /mnt/dev
mount --bind /dev/pts /mnt/dev/pts

# --- Kernel + explicit vinos-vm packages inside chroot --------------
chroot /mnt bash -euo pipefail <<'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive

# Configure apt to prefer cached-friendly install (no docs, no locales).
cat > /etc/dpkg/dpkg.cfg.d/01_nodoc <<CFG
path-exclude=/usr/share/doc/*
path-exclude=/usr/share/man/*
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/en*
path-exclude=/usr/share/info/*
CFG

# Block snap — see PERSONAS.md § 2.1.
cat > /etc/apt/preferences.d/nosnap.pref <<PREF
Package: snapd
Pin: release a=*
Pin-Priority: -10
PREF

# Baseline sources.list (main + universe + security). No snap channels.
cat > /etc/apt/sources.list <<SRC
deb http://archive.ubuntu.com/ubuntu/ noble main universe
deb http://archive.ubuntu.com/ubuntu/ noble-updates main universe
deb http://security.ubuntu.com/ubuntu/ noble-security main universe
SRC

apt-get update -qq

# --- PERSONAS.md § 2.2 package set (minus not-yet-shipped vinOS runtime debs).
apt-get install -y -qq --no-install-recommends \
  linux-image-generic-hwe-24.04 \
  openssh-server sudo curl wget less htop jq vim \
  cloud-init cloud-guest-utils cloud-initramfs-growroot qemu-guest-agent \
  nftables fail2ban auditd apparmor apparmor-utils libpam-tmpdir haveged \
  python3 python3-pip python3-venv \
  git tmux \
  unattended-upgrades apt-listchanges \
  systemd-timesyncd \
  grub-pc-bin grub-efi-amd64-bin \
  >/dev/null

apt-get autoremove -y -qq
apt-get clean

# --- fstab: root on the labeled ext4 partition -----------------------
cat > /etc/fstab <<FSTAB
LABEL=VINOSROOT / ext4 defaults,noatime 0 1
FSTAB

# --- Hostname + machine-id (blank so first boot regenerates) ---------
echo vinos-vm > /etc/hostname
: > /etc/machine-id

# --- SSH hardening (PERSONAS.md § 2.3) -------------------------------
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-vinos.conf <<SSHD
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
X11Forwarding no
AllowAgentForwarding no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
SSHD
systemctl enable ssh

# --- sysctl hardening ------------------------------------------------
cat > /etc/sysctl.d/50-vinos.conf <<SYSCTL
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.log_martians=1
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
kernel.unprivileged_bpf_disabled=1
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.protected_fifos=2
fs.protected_regular=2
fs.suid_dumpable=0
SYSCTL

# --- nftables: drop input, only :22 open, ct-tracked accept ---------
cat > /etc/nftables.conf <<NFT
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif lo accept
    ip protocol icmp accept
    tcp dport 22 accept
  }
  chain forward { type filter hook forward priority 0; policy drop; }
  chain output  { type filter hook output  priority 0; policy accept; }
}
NFT
systemctl enable nftables

# --- Unattended-upgrades -------------------------------------------
cat > /etc/apt/apt.conf.d/50vinos-unattended <<APT
Unattended-Upgrade::Origins-Pattern {
    "origin=Ubuntu,archive=noble-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
APT
systemctl enable unattended-upgrades

# --- cloud-init config ---------------------------------------------
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/10-vinos.cfg <<CI
# vinOS defaults — hostname per instance-id, ssh keys via cloud-init,
# default user 'ubuntu' with sudo. Refined in vinos-cloudinit .deb.
system_info:
  default_user:
    name: ubuntu
    lock_passwd: true
    gecos: vinOS vm user
    groups: [adm, sudo]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
ssh_pwauth: false
disable_root: true
CI

# systemctl enable is needed for cloud-init on debootstrap-built images
systemctl enable cloud-init cloud-config cloud-final cloud-init-local

# Serial console for QEMU -serial + boot log capture
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf <<OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ubuntu --keep-baud 115200,38400,9600 %I \$TERM
OVERRIDE

# --- Grub install for BIOS + UEFI ----------------------------------
# For the debootstrap pilot we rely on QEMU direct-kernel-boot at the
# raw-image level; grub install inside a loop-mounted image needs a
# device it can find /dev/loopX for. Skip grub-install here — the boot
# harness uses -kernel + -initrd + -append with the built vmlinuz.

# List installed packages for the measurement log.
dpkg -l | tail -n +6 | wc -l > /vinos-pkg-count.txt

CHROOT_EOF

# --- Copy the built kernel + initramfs out for direct-kernel boot ---
KVER=$(ls /mnt/lib/modules/ | head -1)
cp /mnt/boot/vmlinuz-${KVER}         /out/vmlinuz
cp /mnt/boot/initrd.img-${KVER}      /out/initrd.img
cp /mnt/vinos-pkg-count.txt          /out/vinos-pkg-count.txt

# Unmount and finish.
umount /mnt/dev/pts /mnt/dev /mnt/sys /mnt/proc
umount /mnt
losetup -d "$LOOP" || true

DOCKER_EOF

# --- Step 3: convert raw → sparse qcow2 -----------------------------
log "converting raw → qcow2 (sparse)"
qemu-img convert -c -O qcow2 "$IMG_RAW" "$IMG_QCOW2"
rm -f "$IMG_RAW"

# --- Step 4: record image metadata ----------------------------------
qcow2_size=$(stat -c '%s' "$IMG_QCOW2")
pkg_count=$(cat "$OUT_DIR/vinos-pkg-count.txt" 2>/dev/null || echo "?")

cat > "$INFO" <<INFO
image      : $IMG_QCOW2
size_bytes : $qcow2_size
size_hr    : $(numfmt --to=iec-i --suffix=B "$qcow2_size")
built      : $(date -u +%Y-%m-%dT%H:%M:%SZ)
dpkg_count : $pkg_count
kernel     : $OUT_DIR/vmlinuz
initrd     : $OUT_DIR/initrd.img
INFO

log "PoC image ready: $IMG_QCOW2 ($(numfmt --to=iec-i --suffix=B "$qcow2_size"))"
log "dpkg -l count  : $pkg_count"
log "kernel + initrd: $OUT_DIR/vmlinuz, $OUT_DIR/initrd.img"
log ""
log "next: scripts/boot-vinos-vm-pilot.sh   # boot + measure"
