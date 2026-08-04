# vinOS Dev Loop — how to test without burning ISOs

**Goal:** For every change you make, use the fastest tier that can validate it. Only burn a USB when you're testing hardware-specific behavior that no VM can reproduce.

## The iteration pyramid

```
                    ┌───────────────────────────┐
                    │  Tier 5: USB burn + boot  │  ← ONLY for T2/hardware bugs
                    │        15+ min cycle      │      (wifi, trackpad, T2 audio)
                    └───────────────────────────┘
                  ┌──────────────────────────────────┐
                  │  Tier 4: QEMU persistent install │  ← full install testing
                  │        5-15 min cycle            │      (installer flow, LUKS)
                  └──────────────────────────────────┘
                ┌────────────────────────────────────────┐
                │  Tier 3: QEMU live ISO boot            │  ← ISO smoke test
                │        2-5 min cycle                   │      (boot, greetd, live user)
                └────────────────────────────────────────┘
              ┌──────────────────────────────────────────────┐
              │  Tier 2: Container install-script test       │  ← config + install/*.sh
              │        30s-2 min cycle                       │      (no VM, no ISO)
              └──────────────────────────────────────────────┘
            ┌────────────────────────────────────────────────────┐
            │  Tier 1: Static lint / dry-run                     │  ← config syntax
            │        <10s cycle                                  │      (shellcheck, jq, yq)
            └────────────────────────────────────────────────────┘
```

**Rule:** promote to the next tier only when the current tier passes. Never skip tiers.

---

## Tier 1 · Static lint (10 seconds)

Use this tier for:
- Shell script syntax
- YAML/TOML/JSON validity
- Config schema checks
- Grep-based invariants (attribution, no forbidden strings)

```bash
# Bash scripts — shellcheck-clean
find install/ bin/ iso/qa/ -type f -name "*.sh" -exec shellcheck {} +

# JSON validity
find configs/ .planning/ -name "*.json" -exec jq . {} + >/dev/null

# YAML validity
find configs/ -name "*.yaml" -exec python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" {} \;

# TOML validity
find configs/ -name "*.toml" -exec python3 -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" {} \;

# Attribution grep — no rogue "Omarchy" outside NOTICES/About
grep -rIn --exclude-dir={omarchy,.git,site/public} "Omarchy" configs/ bin/ iso/ install/ docs/ site/content/ 2>/dev/null | grep -v -E "NOTICES\.md|about/_index\.md"
```

Bundled in `iso/qa/tier1-lint.sh` (Phase 03 deliverable). Runs in <10s.

---

## Tier 2 · Container install-script test (30s–2 min)

Use this tier for:
- Changes to `install/01-base.sh` through `install/06-hardware.sh`
- Changes to `configs/vinos/*` overlays
- Changes to `bin/vinos-*` wrappers
- Anything that DOESN'T need a real boot

**The trick:** run the install scripts in a fresh Arch container. They run as if they're installing to disk, but the "disk" is the container's rootfs. If the script succeeds, most bugs are caught.

```bash
# Interactive shell in a fresh Arch container with vinos repo mounted
docker run --rm -it \
  --privileged \
  -v "$PWD:/vinos" \
  -w /vinos \
  archlinux:latest \
  bash -c "pacman -Sy --noconfirm base-devel git && ./install/01-base.sh && ./install/03-configs.sh && bash"

# Automated smoke — exits 0 or fails
bash iso/qa/tier2-container.sh
```

**Limits of Tier 2:**
- No systemd services actually run (no PID 1 in a normal container)
- No initramfs, no bootloader, no kernel modules
- No LUKS, no cryptsetup (needs kernel devices)
- No pacman keyring initialization quirks

**Fixes for Tier 2 gaps:**
- Use `systemd/systemd` container as PID 1 if you need service testing:
  ```bash
  docker run --rm -it --privileged --tmpfs /tmp --tmpfs /run \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    quay.io/centos/centos:stream9 /sbin/init
  ```
- For LUKS testing, use Tier 3 (needs kernel + loop devices).

Bundled in `iso/qa/tier2-container.sh` (Phase 03 deliverable).

---

## Tier 3 · QEMU live-ISO boot (2–5 min)

Use this tier for:
- Testing the actual built ISO boots to the live desktop
- greetd login flow
- systemd unit ordering at boot
- Waybar / Hyprland startup

**Already exists** as Layer 3 of `iso/qa/oneshot.sh` (per memory: 3-layer verifier does static + container + QEMU screendumps). Captures screenshots at:
- Bootloader (Limine menu)
- Greetd login
- Post-login desktop
- Any error screens (red-banner detection)

Reports pass/fail based on screendumps matching expected fingerprints. **No manual boot required.**

```bash
bash iso/qa/oneshot.sh iso/out/vinos-1.0.19-x86_64.iso
```

---

## Tier 4 · QEMU persistent install (5–15 min)

Use this tier for:
- Installer flow (`vinos-install-disk`)
- LUKS enrollment
- First-boot logic
- Persistence between reboots

**The trick:** attach a virtual disk to QEMU, run the installer, reboot from that disk instead of the ISO. Repeat as needed.

```bash
# First-time: create the persistent disk
qemu-img create -f qcow2 ~/vinos-testbed.qcow2 60G

# Boot ISO, install to disk (interactive first time to verify flow)
qemu-system-x86_64 \
  -enable-kvm -m 8G -smp 4 \
  -cdrom iso/out/vinos-1.0.19-x86_64.iso \
  -drive file=~/vinos-testbed.qcow2,if=virtio \
  -netdev user,id=n0 -device virtio-net,netdev=n0 \
  -boot d

# Subsequent boots — no ISO, boot from the installed disk
qemu-system-x86_64 \
  -enable-kvm -m 8G -smp 4 \
  -drive file=~/vinos-testbed.qcow2,if=virtio \
  -netdev user,id=n0 -device virtio-net,netdev=n0 \
  -boot c

# Automated snapshot: take a snapshot after clean install, revert for repeat tests
qemu-img snapshot -c clean-install ~/vinos-testbed.qcow2   # after install
qemu-img snapshot -a clean-install ~/vinos-testbed.qcow2   # revert to it
```

**Snapshot workflow (this is the frustration-killer):**
1. Install once → snapshot as `clean-install`
2. Test change → revert to `clean-install`
3. Test another change → revert again
4. Never re-install unless the installer itself changed

Bundled in `iso/qa/tier4-qemu-persistent.sh` (Phase 04 deliverable — comes with the LUKS work).

---

## Tier 5 · USB burn (15+ min)

**Only** when Tier 4 passes and you need to verify hardware-specific behavior:
- T2 wifi (brcmfmac firmware timing)
- T2 keyboard / trackpad (Apple SPI driver)
- T2 audio (T2 audio bridge)
- NVIDIA proprietary driver on non-Mac hardware
- Real BIOS/UEFI quirks
- Suspend/resume against real hardware timers

**Do NOT burn a USB to test:**
- Config file changes → Tier 1 or 2
- Install script changes → Tier 2
- ISO boot behavior → Tier 3
- Installer flow → Tier 4
- Anything that ran green in Tiers 1–4

**When you do burn, use `dd` with progress:**
```bash
sudo dd if=iso/out/vinos-1.0.19-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

---

## Decision tree — "which tier?"

```
Am I changing…
├─ config syntax / schema?                  → Tier 1
├─ install/*.sh logic?                      → Tier 2 (container)
├─ configs/vinos/* overlay files?           → Tier 2, then Tier 3
├─ iso/profile/* or archiso profile?        → Tier 3
├─ bootloader (Limine) config?              → Tier 3, then Tier 4
├─ installer (vinos-install-disk) logic?    → Tier 4
├─ LUKS / partitioning?                     → Tier 4
├─ First-boot behavior?                     → Tier 4
├─ Hardware driver (brcmfmac, T2)?          → Tier 5 (real hw)
├─ Kernel command line / module load?       → Tier 4 for behavior, Tier 5 for hw effect
├─ Anything else?                           → Start at Tier 2
```

---

## Common gotchas

- **Ollama not reachable from container:** the container needs `--network host` OR you serve Ollama on a bridged IP.
- **QEMU no KVM:** without `-enable-kvm`, boot is 10× slower. Always check `ls /dev/kvm` first.
- **T2 wifi in QEMU:** brcmfmac firmware doesn't apply — QEMU can't test T2 wifi. This is why Tier 5 exists for that specific bug class.
- **`docker run --privileged`:** required for LUKS / loop devices / systemd. Don't skip.
- **Snapshot revert loses network state:** if your test involves the network, snapshot AFTER the network is up.

---

## Automation goal

By v1.0.20, every commit to `main` triggers CI that runs Tiers 1 + 2 automatically. QEMU (Tier 3) runs nightly on `main`. Tier 4/5 are manual (or triggered by `[test-boot]` in commit message).

Wall-clock target on a typical CI runner:
- Tier 1: <30s
- Tier 2: <5 min
- Tier 3: <10 min
- Tier 4: <20 min

Beyond that, we're pathologically slow and need to optimize.
