# vinOS Kernel Control

**Goal:** Full-tier control over the kernel without building a custom kernel package.

Custom kernel builds are expensive (~1 hour per build, huge maintenance burden). Tiers 1–4 below cover 95% of what people actually need. Tier 5 (custom kernel) is available but deferred until we have a proven need.

## Tier 1 · Kernel command line (highest impact, lowest cost)

Kernel command-line params live in the bootloader entries. vinOS uses Limine (with systemd-boot fallback on some boards).

### Where they live

- **Live ISO:** `iso/profile/efiboot/loader/entries/00-archiso-*.conf` (systemd-boot) + `iso/profile/boot/limine.conf` (Limine)
- **Installed system:** `/boot/limine.conf` (created by `install/vinos-install-disk`)

### Common vinOS defaults (already set)

```
# Security-related
apparmor=1 security=apparmor lsm=landlock,lockdown,yama,integrity,apparmor,bpf
mitigations=auto
random.trust_cpu=on
lockdown=confidentiality

# Hardware (T2 Mac specific — only appears in T2 boot entries)
mbp_devices=8 module_blacklist=thunderbolt
efi=noruntime

# Performance
threadirqs
mitigations=auto

# LUKS (added in Phase 04 / v1.0.20)
rd.luks.name=<uuid>=vinos-root rd.luks.options=discard,no-read-workqueue,no-write-workqueue
```

### How to add a param

**One-off testing (existing install):** edit `/boot/limine.conf`, reboot.

**Ship it in the ISO:** edit the entry files in `iso/profile/efiboot/loader/entries/` (for systemd-boot) or the Limine template used by `install/vinos-install-disk`. Add the assertion to `iso/qa/verify-shipped-iso.sh`.

### Frequently useful params to know

| Param | What it does | When to use |
|---|---|---|
| `quiet` | Suppress kernel boot messages | Default; drop for debugging |
| `debug` | Enable kernel debug output | Debugging boot failures |
| `nomodeset` | Skip KMS drivers | Emergency boot on broken GPU |
| `single` | Boot to single-user recovery shell | Recovery only |
| `ip=dhcp` | DHCP in initramfs | Netboot / iPXE flows |
| `mem=8G` | Limit RAM (test low-memory paths) | QEMU testing |
| `nokaslr` | Disable KASLR | Kernel debugging with symbols |
| `console=ttyS0,115200` | Redirect console to serial | Headless install; VPS |

---

## Tier 2 · Modules loaded at boot / initramfs

### Load modules at boot

`configs/vinos/default/etc/modules-load.d/vinos.conf` — one module name per line, loaded by systemd at boot.

Current vinOS defaults live in `configs/vinos/t2/airootfs/etc/modules-load.d/vinos-t2.conf` for T2 Macs (brcmfmac, apple-bce, etc.).

### Blacklist modules

`configs/vinos/default/etc/modprobe.d/vinos-blacklist.conf`:

```
blacklist pcspkr
blacklist snd_pcsp
# Add here as needed
```

### Include modules in initramfs (mkinitcpio hooks)

For hardware needed BEFORE root pivot (LUKS, T2 wifi, exotic filesystems):

`configs/vinos/default/etc/mkinitcpio.conf.d/vinos.conf`:

```
# Force these modules into the initramfs
MODULES=(crc32c-intel usbhid xhci_hcd)

# For LUKS
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block sd-encrypt filesystems fsck)
```

Also see `configs/vinos/t2/airootfs/etc/mkinitcpio.conf.d/vinos-t2.conf` — the T2 wifi recipe (per memory: `brcmfmac feature_disable` + T2 initramfs modules).

### Regenerate initramfs after changes

```bash
sudo mkinitcpio -P   # regenerates initramfs for ALL kernels installed
```

---

## Tier 3 · Module parameters (modprobe options)

Fine-tune loaded modules without recompiling. Files under `/etc/modprobe.d/`.

**T2 wifi (already shipped per memory):**
```
# configs/vinos/t2/airootfs/etc/modprobe.d/brcmfmac.conf
options brcmfmac feature_disable=0x82000 
```

**Powersave off for CPU-heavy work:**
```
# configs/vinos/security/etc/modprobe.d/powersave.conf
options snd_hda_intel power_save=0
options iwlwifi power_save=0 uapsd_disable=1
```

**Ship as vinOS overlay:** put files under `configs/vinos/<scope>/etc/modprobe.d/*.conf`. `install/03-configs.sh` rsyncs them into `/etc/`.

---

## Tier 4 · Runtime kernel behavior (sysctl.d)

Persistent runtime tuning. Files under `/etc/sysctl.d/`.

**vinOS security defaults** (`configs/vinos/security/etc/sysctl.d/99-vinos.conf`):

```
# Kernel hardening
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 2

# Network hardening
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Memory
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16
```

Apply at runtime without reboot: `sudo sysctl --system`.

---

## Tier 5 · Custom kernel package (`linux-vinos`) — ACTIVE deliverable

**Line-by-line control over the kernel is a real vinOS deliverable, not a nice-to-have.**

### What ships

- `configs/vinos/kernel/PKGBUILD` — source of truth for the `linux-vinos` package
- `configs/vinos/kernel/config` — the .config file (every CONFIG_* flag versioned in git)
- `configs/vinos/kernel/patches/` — vinOS-specific patches on top of upstream
- `configs/vinos/kernel/keys/` — signing keys (private key encrypted; public in NOTICES)
- Built as an AUR-style package, installed alongside `linux-cachyos` (fallback) and `linux-hardened` (opt-in)

### Base

`linux-cachyos` PKGBUILD is the starting point (perf-tuned, BTRFS+Snapper defaults, already default in vinOS). We fork it into `linux-vinos` with:
- Merged linux-hardened patches (attack surface reduction)
- Merged linux-t2 patches when the target is T2 Mac
- vinOS `.config` overriding defaults for: LSM ordering, syscall restrictions, module compression, LTO settings, timer frequency, io_uring, BPF hardening

### Build discipline

- Per kernel release (~weekly upstream): review the diff, update `.config` if new CONFIG_* flags appeared, rebuild
- All builds reproducible — same `configs/vinos/kernel/*` inputs → same package sha256
- Build takes ~1 hour on the current server; can be offloaded to GitHub Actions with cache
- Multi-kernel Limine ALWAYS keeps `linux-cachyos` as a fallback boot entry — a bad `linux-vinos` never bricks the machine

### Signing

- Self-signed for dev; SecureBoot-signed for v1.0.28 GA (contingent on Foundation cert or paid key)
- Signing infra: `configs/vinos/kernel/sign.sh` — takes an unsigned .ko/vmlinuz and produces signed
- Public key ships in ISO at `/usr/share/vinos/keys/kernel.pub`
- Key rotation policy: annual

### Delivery timeline

- **Phase 07 (v1.0.23):** `linux-vinos` PKGBUILD merged, first signed dev build ships in ISO, but `linux-cachyos` remains default
- **Phase 12 (v1.0.28):** `linux-vinos` becomes the DEFAULT kernel if SecureBoot signing key acquired
- **Every ship after 07:** kernel diff review in `docs/v2/kernel-changelog-<ver>.md`

### Config strategy

vinOS `.config` starts as `linux-cachyos-defaults` + these targeted flips:

```
# Attack surface reduction
CONFIG_MODULES_TREE_LOOKUP=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_FORCE=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_SHA512=y

# Hardening
CONFIG_INIT_STACK_ALL_ZERO=y
CONFIG_STACKPROTECTOR_STRONG=y
CONFIG_STRICT_KERNEL_RWX=y
CONFIG_STRICT_MODULE_RWX=y
CONFIG_RANDOMIZE_BASE=y
CONFIG_RANDOMIZE_MEMORY=y
CONFIG_SLAB_HARDENED=y
CONFIG_SLAB_FREELIST_RANDOM=y
CONFIG_SLAB_FREELIST_HARDENED=y

# LSMs — apparmor + lockdown + landlock all built-in
CONFIG_LSM="landlock,lockdown,yama,integrity,apparmor,bpf"
CONFIG_SECURITY_LOCKDOWN_LSM=y
CONFIG_SECURITY_LOCKDOWN_LSM_EARLY=y
CONFIG_SECURITY_APPARMOR_DEFAULT_HAT=""

# Disable legacy attack surfaces
CONFIG_KEXEC=n
CONFIG_KEXEC_FILE=n
CONFIG_HIBERNATION=n              # can override if needed
CONFIG_USER_NS=y                  # keep for bwrap sandbox
CONFIG_LEGACY_PTYS=n
CONFIG_LEGACY_TIOCSTI=n

# Perf + agent-friendly
CONFIG_PREEMPT=y                  # low-latency for agent responsiveness
CONFIG_IO_URING=y                 # required by modern async agent runtimes
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_UNPRIV_DEFAULT_OFF=y
```

Every flag flip is a commit with reasoning in the message. `configs/vinos/kernel/RATIONALE.md` documents each choice.

### When to override at ship time

- **Testing:** boot with `linux-cachyos` first via Limine menu, then upgrade to `linux-vinos` after canary routines pass
- **Rollback:** if a `linux-vinos` release regresses hardware, users reboot into `linux-cachyos` (one-command via `vinos-update kernel-rollback`)
- **Compliance:** enterprise builds with FIPS/STIG requirements ship additional patches on top

### Related

- `configs/vinos/kernel/` — the whole subtree
- `configs/vinos/kernel/RATIONALE.md` — per-CONFIG_* justification
- Memory: `[[kernel-line-by-line-control]]` — Vin's ask (2026-08-03)

---

## Which tier for which need?

| Need | Tier |
|---|---|
| Change how much RAM is used at boot | 1 (cmdline `mem=`) |
| Disable CPU mitigations for benchmarking | 1 (`mitigations=off`) |
| Enable/disable a driver | 2 (modules-load or blacklist) |
| Get LUKS working | 1 + 2 (cmdline + mkinitcpio hooks) |
| T2 wifi tuning | 3 (modprobe options) |
| Harden network stack | 4 (sysctl) |
| Enable a `CONFIG_*` flag not compiled in | 5 (custom kernel — pause and reconsider first) |

---

## Verifying kernel config on a running system

```bash
# Current cmdline
cat /proc/cmdline

# Loaded modules
lsmod

# Module parameters in use
cat /sys/module/brcmfmac/parameters/feature_disable

# sysctl effective values
sysctl -a | grep kernel.kptr_restrict

# Enabled CONFIG flags (if kernel exposes /proc/config.gz)
zcat /proc/config.gz | grep CONFIG_APPARMOR
```

Every vinOS ship adds one assertion per shipped kernel tweak to `iso/qa/verify-shipped-iso.sh`. That's how we prevent regression.
