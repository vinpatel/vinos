# Building vinOS from source

How to reproduce the vinOS ISO from a clean checkout. Applies to v1.1.0 as the baseline; v1.2.0+ adds Track A (Arch ISO) + Track B (Ubuntu VM image) parallel builds.

## Prerequisites

- **A Linux host.** Any modern distro. Arch, Ubuntu, Fedora, Debian all fine. macOS + Windows work via a Linux VM.
- **Docker.** (Or Podman with the docker CLI shim.) The build runs inside `docker run --rm --privileged archlinux:latest` so the host stays clean.
- **`/dev/kvm` optional but 10× faster** for QEMU acceptance tests.
- **~15 GB scratch space** for the archiso work directory + package cache.
- **~800 MB bandwidth** on first build to fetch Arch packages. Subsequent builds hit the pacman cache.
- **Git.**

## Step-by-step: build the v1.1.0 ISO

### 1. Clone the repo

```bash
git clone git@github.com:vinpatel/vinos.git
cd vinos
git checkout v1.1.0    # or any newer tag / branch
```

### 2. Verify the tree

```bash
# what version this checkout will produce
cat VERSION
# → 1.1.0

# git anchor
git rev-parse HEAD
# → e5c44b9e61e1e5e0819600e4f833d47322ff17ed (for v1.1.0)
```

### 3. Run the build

```bash
bash iso/build.sh
```

That single command does all the work. Under the hood, it:

1. Reads `VERSION` → `VINOS_VERSION=1.1.0`
2. Launches `docker run --rm --privileged archlinux:latest`
3. Inside the container:
   - Copies the repo into `/vinos`
   - Runs `iso/gen-packages.sh` — unions `iso/packages.releng` + `iso/packages.live` + install-script deps into `iso/profile/packages.x86_64`
   - Runs `install/03-configs.sh` → copies `config/` into `iso/profile/airootfs/etc/skel/`
   - Runs `install/05-branding.sh` → writes `/etc/os-release`, wallpaper, `VERSION`, plymouth theme, 88 `vinos-*` bin scripts
   - Runs `install/02-desktop.sh` → adds the desktop-stack packages
   - Runs `install/04-services.sh` → enables systemd units
   - Rsyncs `iso/airootfs-overlay/` on top (live-only additions like `vinos-live-init.service`)
   - Builds the local `[vinos-aur]` repo via `iso/aur-build.sh` — compiles 12 AUR packages (walker, elephant, 1password, spotify, etc.)
   - Runs `mkarchiso -v -w WORK_DIR -o /out iso/profile`
   - Emits `iso/out/vinos-<VERSION>-x86_64.iso` + `sha256sums.txt`

Expected build time: **10-20 minutes** on a modern box with `/dev/kvm`. **30-60 minutes** without.

### 4. Verify the artifact

```bash
ls -lh iso/out/
# vinos-1.1.0-x86_64.iso      4.3G
# vinos-1.1.0-x86_64.iso.sha256
# sha256sums.txt

sha256sum -c iso/out/sha256sums.txt
# vinos-1.1.0-x86_64.iso: OK
```

For the *reference* v1.1.0 build, expected SHA256:
```
3bd3657ecbab018f1efe787c45caa83a28a6c19cbceaafa8ee009becd3873ef2
```

Note: your local build's SHA won't be bit-identical to the reference. Package mirror state drifts, timestamps embed, kernel versions bump. What matters is the **manifest** — the package list and configuration should match.

### 5. Test in QEMU (optional but recommended)

```bash
# Headless boot smoketest — asserts kernel loads, systemd reaches multi-user,
# ISO label + size are valid.
bash iso/test.sh --mode matrix

# Interactive QEMU window for manual poking.
bash iso/qemu-desktop.sh

# Headless screendump of the settled desktop after 90 seconds.
bash iso/test-desktop.sh
```

### 6. Flash to a USB stick

```bash
sudo bash iso/flash.sh
```

Interactive by default — lists candidate USB devices, refuses to write to non-USB targets, requires two typed confirmations (device path + model string) before invoking `dd`.

Non-interactive:
```bash
sudo bash iso/flash.sh --dev sdX --iso iso/out/vinos-1.1.0-x86_64.iso
```

See [USB.md](USB.md) for persistence, boot-menu tips, and troubleshooting.

## What the build produces (v1.1.0)

- **One ISO** (~4.3 GB) — dual-kernel (`linux` + `linux-t2`), dual-mode boot (BIOS syslinux + UEFI systemd-boot), 7 boot menu entries
- **~250 packages** installed
- **88 `vinos-*` helper scripts** in `/usr/share/vinos/bin/` (symlinked from `/usr/local/bin/`)
- **Live user `vinos`** created on first boot with passwordless wheel sudo
- **Greetd autologin → Hyprland session** via uwsm

Full architectural detail in [ARCHITECTURE-v1.1.0.md](ARCHITECTURE-v1.1.0.md).

## Building v1.2.0+ (multi-track)

Starting v1.2.0, the build splits into two tracks (see [ROADMAP.md](../.planning/ROADMAP.md)):

### Track A — `vinos-dev` (Arch ISO)

Same flow as v1.1.0 but with expanded package set + activated modular hypr configs + Ollama preinstalled + `vinos-mcp` CLI. Same `iso/build.sh` entry point.

### Track B — `vinos-vm` (Ubuntu cloud images)

New pipeline using [Packer](https://www.packer.io/) + Ansible instead of archiso:

```bash
# Build for QEMU/KVM (used by DigitalOcean, Hetzner, Linode, Vultr):
packer build -only=qemu.vinos-vm packer/vinos-vm.pkr.hcl

# Build for AWS AMI (both amd64 + arm64):
packer build -only=amazon-ebs.vinos-vm packer/vinos-vm.pkr.hcl

# Full matrix:
packer build packer/vinos-vm.pkr.hcl
```

Output: `packer-out/vinos-vm-<version>-{amd64,arm64}.qcow2` + AMI + VHD + GCE image.

Provisioner: `packer/provision/vinos-vm.yml` (Ansible) which:
1. Adds `deb https://apt.vinos.computer/ noble main` to apt sources
2. Installs `vinos-agent-worker`, `vinos-mcp`, `vinos-hardening`, `vinos-cloudinit`
3. Enables systemd units
4. Applies AppArmor profiles
5. `cloud-init clean --logs` to reset for image capture

### Publishing `.deb` packages

For the shared `vinos-runtime` layer (available as `.pkg.tar.zst` on Arch + `.deb` on Ubuntu):

```bash
# Build both packages from the same monorepo path:
make -C vinos-runtime pkg-arch      # → vinos-runtime-<version>.pkg.tar.zst
make -C vinos-runtime pkg-deb       # → vinos-runtime_<version>_all.deb

# Publish .deb to apt.vinos.computer:
make -C vinos-runtime publish-deb   # → uploads to apt repo, refreshes index
```

## Reproducibility

vinOS builds are **not** bit-reproducible today. Sources of drift:
- Arch mirror state (rolling)
- Package versions (`linux`, `hyprland`, etc. — no pins in v1.1.0)
- Timestamps embedded in squashfs metadata
- AUR package build recipes updated upstream

Bit-reproducibility is a nice-to-have but not a v1.2.0 goal. If a future milestone needs it, we'd:
- Pin every package to an exact version at build time
- Use `SOURCE_DATE_EPOCH` throughout
- Snapshot the mirror state per build
- Rebuild against the snapshot

For now, **manifest reproducibility** is what matters: the same source produces an ISO with the same package list, same config files, same behavior.

## Debugging failed builds

If `iso/build.sh` fails:

1. **Check the docker output** — the container's stderr streams to your terminal. Look for `error:` lines.
2. **Inspect `iso/out/build-<version>-<timestamp>.log`** — full build log if the container reached that stage.
3. **Common failures:**
   - **Package not found in Arch mirrors:** Arch removed a package. Update `iso/packages.releng` or `iso/packages.live`, regenerate `iso/profile/packages.x86_64` via `iso/gen-packages.sh`.
   - **AUR build failure:** the AUR recipe changed upstream. Check `iso/aur.list`, run `iso/aur-build.sh` manually inside the container to isolate.
   - **`/dev/kvm` permission denied:** add your user to the `kvm` group + relog, or run the build with `sudo`. Container passes it through automatically when available.
   - **Out of disk:** archiso work dir eats ~10 GB. `df -h` your `/tmp` or `--workdir` target.

4. **Nuclear option:** `docker system prune -a` (wipes all cached docker layers + images), then rebuild from scratch.

## QA / ship-gate

Before shipping any ISO to a user, run the ship gate:

```bash
bash iso/qa/oneshot.sh
```

Layers:
1. **Static** — script lint, VERSION check, config sanity
2. **Container** — build inside archiso Docker, inspect manifest
3. **Regression harness** (`iso/qa/verify-shipped-iso.sh`) — asserts every past fix is intact
4. **QEMU** — boot the ISO headless, take screendumps at 30s / 90s / 150s, assert desktop reached

**Never hand a user an ISO that hasn't passed all four layers.** This is a hard rule ([ADR-001](DECISIONS.md#adr-001)).

Note: `iso/qa/oneshot.sh` and `verify-shipped-iso.sh` shipped in a post-v1.1.0 milestone; the v1.1.0 tag does NOT contain them yet. They ship in v1.2.0.

## Getting help

- [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup
- [GitHub Discussions](https://github.com/vinpatel/vinos/discussions) for questions
- [GitHub Issues](https://github.com/vinpatel/vinos/issues) for bugs
