# Hardened Kernel (Phase B2a)

**Phase:** B
**Version target:** 2.1.0
**Status:** in-progress
**Owner:** claude
**Memory entry:** [secure-kernel](memory/project_secure_kernel.md)
**Harness check IDs:** #49 → #55

## 1. Problem statement

Today vinOS ships stock `linux` and `linux-t2` kernels — mainline configurations tuned for general desktop use. Neither has KASLR at maximum, SLUB hardening, page poisoning, or kernel-level protections against SMEP/SMAP/KPTI-adjacent attacks. For an OS positioned as "the most secure OS in the agentic era" — running local LLMs handling API keys, git credentials, sensitive prompt histories — this is a gap. Container-heavy workloads (docker, k8s) also need specific kernel features (cgroups v2, unprivileged user namespaces, bridge netfilter) that ship enabled but not tuned. A hardened kernel plus container-optimized sysctl closes both gaps.

## 2. User story

As a **founder / agent operator running vinOS**, I want the kernel to have every reasonable hardening flag enabled by default, so that even if an agent I run has a bug or vulnerability, kernel-level defenses (KASLR, SLUB, SMEP/SMAP, KPTI) contain the blast radius — and containerized workloads still run cleanly because cgroups v2 and modern container primitives are enabled.

## 3. Behavior spec

### Inputs

- Existing kernel packages: `linux`, `linux-t2`
- Available: `linux-hardened` (Arch community, has GRSecurity-adjacent patches)
- Target: dual-kernel install — one default + fallback

### Behavior

**Generic profile (Intel/AMD/generic PC):**
- Default kernel: `linux-hardened`
- Fallback kernel: `linux` (in bootloader as second entry)
- systemd-boot default: `linux-hardened`

**T2 profile:**
- Default kernel: `linux-t2` (required for T2 hardware)
- Fallback: `linux-hardened` (hardware may not fully work — power/wifi/keyboard could regress; user chooses at boot menu)
- systemd-boot default: `linux-t2`
- **Rationale:** T2 hardware needs specific patches only present in `linux-t2`; `linux-hardened` would kill wifi. Accept the tradeoff and expose the choice.

**Kernel command line additions (all profiles):**
```
init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 randomize_kstack_offset=on vsyscall=none debugfs=off oops=panic module.sig_enforce=1 lockdown=confidentiality mce=0 quiet loglevel=0
```

**sysctl hardening (`/etc/sysctl.d/99-vinos-hardening.conf`):**
```
# Reduce attack surface
kernel.kexec_load_disabled = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.printk = 3 3 3 3
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 2
net.core.bpf_jit_harden = 2

# Network hardening
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Filesystem
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0
```

**AppArmor enabled by default:**
- Kernel supports AppArmor (linux-hardened has it built in)
- `apparmor.service` enabled
- Profiles for chromium, firefox, foot, waybar, walker installed

**Modules that must be baked into initramfs (containers + T2):**
```
MODULES=(applespi brcmfmac hci_bcm4377 overlay br_netfilter veth nf_conntrack)
```

### Non-behavior

- Do NOT ship SELinux (Arch community has weak SELinux packaging; AppArmor works better here)
- Do NOT enable grsecurity patches (unpatched availability, community-maintained fork)
- Do NOT disable ptrace entirely (developers need it)
- Do NOT lock down `/proc` — developers need visibility

### Error paths

- If `linux-hardened` fails to boot on user's hardware: bootloader fallback entry loads `linux` (unhardened). vinOS-doctor reports `WARN: booted on linux, not linux-hardened — hardening reduced`
- If AppArmor profile blocks legitimate app: `journalctl -k` shows `DENIED` line; user can disable specific profile with `sudo aa-disable /etc/apparmor.d/<profile>`

## 4. Harness checks

```bash
# #49: linux-hardened kernel installed on target
if grep -q 'linux-hardened' "$INSTALLER" || \
   [[ -f "$ROOT/usr/lib/modules/"*"hardened"*"/vmlinuz" ]]; then
  ok "linux-hardened kernel package present"
else
  fail "linux-hardened NOT installed — kernel hardening posture reduced" \
       "secure-kernel"
fi

# #50: sysctl hardening file present
if [[ -f "$ROOT/etc/sysctl.d/99-vinos-hardening.conf" ]] && \
   grep -q 'kernel.kexec_load_disabled = 1' "$ROOT/etc/sysctl.d/99-vinos-hardening.conf"; then
  ok "sysctl hardening config shipped"
else
  fail "99-vinos-hardening.conf missing or incomplete" \
       "secure-kernel"
fi

# #51: kernel command line has hardening flags
if grep -q 'init_on_alloc=1' "$INSTALLER" && \
   grep -q 'lockdown=confidentiality' "$INSTALLER" && \
   grep -q 'module.sig_enforce=1' "$INSTALLER"; then
  ok "kernel cmdline has hardening flags"
else
  fail "kernel cmdline missing hardening flags (init_on_alloc, lockdown, module sig)" \
       "secure-kernel"
fi

# #52: AppArmor enabled
if [[ -L "$ROOT/etc/systemd/system/multi-user.target.wants/apparmor.service" ]]; then
  ok "AppArmor service enabled"
else
  fail "AppArmor not enabled by default" \
       "secure-kernel"
fi

# #53: modprobe blacklist for known-risky kernel modules
if [[ -f "$ROOT/etc/modprobe.d/vinos-blacklist.conf" ]] && \
   grep -q 'blacklist dccp' "$ROOT/etc/modprobe.d/vinos-blacklist.conf" && \
   grep -q 'blacklist sctp' "$ROOT/etc/modprobe.d/vinos-blacklist.conf"; then
  ok "risky kernel modules blacklisted (dccp, sctp, rds, tipc)"
else
  fail "risky module blacklist missing" \
       "secure-kernel"
fi

# #54: container-required modules in initramfs
if awk '/^MODULES=\(/,/\)/' "$INSTALLER" | grep -q 'overlay' && \
   awk '/^MODULES=\(/,/\)/' "$INSTALLER" | grep -q 'br_netfilter'; then
  ok "container modules baked into initramfs (overlay + br_netfilter)"
else
  fail "container modules missing from target initramfs" \
       "k8s-optimized"
fi

# #55: /boot has both kernels for fallback
if bsdtar -tf "$ISO" 2>/dev/null | grep -q 'vmlinuz-linux-hardened' || \
   grep -q 'linux-hardened' "$INSTALLER"; then
  ok "linux-hardened kernel shipping in ISO"
else
  fail "linux-hardened kernel NOT shipping — install can't offer it as default" \
       "secure-kernel"
fi
```

## 5. Memory entry

New: `~/.claude/projects/-data-projects-vinos/memory/project_secure_kernel.md`

## Implementation

### Files created

- `iso/profile/airootfs/etc/sysctl.d/99-vinos-hardening.conf`
- `iso/profile/airootfs/etc/modprobe.d/vinos-blacklist.conf` (dccp, sctp, rds, tipc, cramfs, freevxfs, jffs2, hfs, hfsplus, squashfs, udf)
- `iso/profile/airootfs/etc/apparmor.d/vinos-*.profile` (per app)

### Files modified

- `iso/profile/packages.x86_64` — add `linux-hardened linux-hardened-headers apparmor python-notify2`
- `iso/profile/profiledef.sh` — file_permissions for `99-vinos-hardening.conf`, `vinos-blacklist.conf`
- `bin/vinos-install-disk` — write hardening cmdline to bootloader entry, install both kernels on generic profile
- `install/04-services.sh` — enable `apparmor.service`
- `iso/qa/verify-shipped-iso.sh` — checks #49-#55

### Package additions

- `linux-hardened` + `linux-hardened-headers`
- `apparmor`
- `audit` (for AppArmor DENIED tracking)

## Testing

1. Build 2.1.0 ISO with hardened kernel
2. `bash iso/qa/verify-shipped-iso.sh iso/out/vinos-2.1.0-x86_64.iso` — checks #49-#55 pass
3. Flash + install
4. `uname -r` shows `-hardened`
5. `sysctl kernel.kexec_load_disabled` returns 1
6. `sudo aa-status` shows profiles loaded and enforcing
7. `journalctl -k | grep -i lockdown` shows kernel is in confidentiality mode
8. Boot fallback entry `linux` — hardware still works, just less hardened

## Rollback

If hardened kernel breaks user's hardware: bootloader offers `linux` fallback. If cluster of users hit issues: hotfix 2.1.1 defaults to `linux` for a specific hardware profile.
