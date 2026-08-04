# Phase 10 — v1.0.26: Headless edition

**Type:** release (multi-artifact) · **Depends on:** 09
**Ships as:** Docker image + systemd-nspawn tarball + Helm chart + hardened Arch profile
**Duration:** 10 days · **Requirements:** R2, R4, R-HARDEN

## Goal

vinOS Headless — the "unhackable" agentic OS for production fleets. **Same Arch base as Developer edition** (per user decision 2026-08-03: uniformity over declarative purity). Achieved via a hardened Arch profile that recovers ~80% of a declarative-immutable OS's security posture with 100% tooling uniformity.

Positioning: "vinOS runs on your dev laptop (Developer edition with Omarchy) and your production fleet (Headless with hardening stack). Same tree, same runtime, different install profiles."

## Scope (in)

### The hardened Arch profile
- **`linux-hardened` as default kernel** on headless installs (not `linux-cachyos`). `linux-vinos` custom kernel (from Phase 07) also available as opt-in.
- **Read-only rootfs** with overlayfs for writable state (`/var`, `/tmp`, `/home/*/`) — configured via `configs/vinos/headless/etc/vinos-immutable.conf` and applied at install time.
- **BTRFS + Snapper** for per-boot snapshots + auto-snapshot on any package install.
- **AppArmor enforcing** on every shipped service (already planned; enforced from install).
- **`hardened_malloc` as system-wide `LD_PRELOAD`** via `/etc/ld.so.preload`.
- **Firejail** profiles for every agent execution (adapted from Developer edition Phase 07 profiles).
- **Signed Arch snapshot pinning** — every ship reproducible from a specific mirror snapshot URL (see R11).
- **SSH hardening baked in** — no password auth, ed25519 keys only, no root SSH, port 22 fine but rate-limited via nftables.
- **`nftables` deny-in default** with explicit allow rules for the agent runtime's outbound (Anthropic/OpenRouter/Ollama).
- **Kernel cmdline hardening** — `slab_nomerge`, `page_alloc.shuffle=1`, `init_on_alloc=1`, `init_on_free=1`, `lockdown=integrity`, `mitigations=auto`.

### Deployment artifacts
- **`install.sh --profile headless`** — same installer, headless profile skips desktop + applies hardening stack. Documented in `docs/v2/HEADLESS.md`.
- **`ghcr.io/vinpatel/vinos-cloud:1.0.26`** — Docker image, ~200 MB compressed
  - Base: minimal Arch (`archlinux:base` official image + our hardening layer)
  - Includes: `vinos-routine` + `libexec/` + Ollama HTTP client + sqlite + LiteLLM proxy
  - Mounts `.vinos/routines.yaml` as config
- **`vinos-cloud-1.0.26.tar.zst`** — systemd-nspawn image for bare-metal ops shops
- **`vinos-cloud-1.0.26.qcow2`** — pre-built cloud image for Hetzner / KVM / OpenStack, published to `dl.vinos.computer/cloud/`
- **`charts/vinos-agents/`** — Helm chart with CronJobs per routine + PVC for state/ledger + Secret for API keys
- **Cloud-init templates** in `deploy/cloud-init/` — one-line install on Hetzner / DO / AWS / Fly.io / GCP
- **Webhook sinks** — `bin/vinos-notify-webhook` supports Slack, Discord, generic HTTP POST as first-class output destinations
- **K8s CronJob-based scheduling** as alternative to systemd timers

## Scope (out)

- Any desktop-specific code (Hyprland, Waybar, walker, Plymouth — all excluded from headless)
- macOS/Windows support (still Linux only)
- A hosted SaaS control plane (users bring their own cloud)
- NixOS variant (deferred to future M2 enterprise SKU if a specific customer needs declarative-config compliance)
- SELinux (staying with AppArmor — one MAC, well-supported)
- rootless containers as DEFAULT (Phase 12 or later — currently Docker daemon owns the socket)

## Human checkpoints

1. Container image publication to `ghcr.io` (public distribution surface)
2. Helm chart maintainer key setup (security-affecting)
3. Cloud-init template review — each is a distribution surface
4. Snapshot pinning URL policy (reproducibility-affecting)
5. `install.sh --profile headless` UX copy (public-facing)
6. Every hardening flag in `configs/vinos/headless/` — each is security-affecting

## Ship gate

- **QA-9** — image size < 300 MB compressed
- **QA-10** — idle power < 5 W on Hetzner CX22 (single vCPU, 4 GB RAM baseline)
- **QA-11** — Helm install → CronJob → webhook in 60 s on a fresh K3s cluster
- **QA-1 through QA-6** — foundation gates (reproducible build, harness clean, boots on target VMs, first-run to agent < 5 min, no unattributed strings, oneshot verifier)
- **QA-H1** (new) — hardened-profile assertion: `/etc/ld.so.preload` contains `hardened_malloc`, apparmor enforcing on all services, nftables rules present, rootfs mounted read-only
- **QA-H2** (new) — adversarial hardening test: attempt to write to `/etc/`, escalate to root via known CVE class, spawn unsigned binary — all denied

## Deliverables

New:
- `configs/vinos/headless/etc/` — the whole hardened overlay:
  - `vinos-immutable.conf` — overlayfs mount points
  - `apparmor.d/vinos-*` — profiles for every shipped service
  - `ld.so.preload` — hardened_malloc entry
  - `nftables/vinos-default.nft` — deny-in rules with agent egress allowlist
  - `ssh/sshd_config.d/vinos-hardened.conf` — key-only, no-root
  - `systemd/system/vinos-*.service.d/vinos-hardening.conf` — service-level ProtectSystem, PrivateDevices, etc.
- `configs/vinos/headless/etc/default/limine-cmdline-hardening.txt` — kernel cmdline additions
- `install/07-hardening.sh` — applies the hardening overlay when `--profile headless` is set
- `Dockerfile` + `deploy/docker/` build context
- `deploy/nspawn/` build scripts
- `deploy/qcow2/build.sh` — builds the cloud image via archiso
- `charts/vinos-agents/` complete Helm chart (values.yaml, templates/*, README)
- `deploy/cloud-init/hetzner.yaml`, `digitalocean.yaml`, `aws.yaml`, `fly.io.toml`, `gcp.yaml`
- `bin/vinos-notify-webhook`
- `docs/v2/HEADLESS.md` — deployment guide + hardening rationale
- `iso/qa/adversarial-tests/harden.sh` — QA-H2 test suite
- CI publishes image + qcow2 to `dl.vinos.computer` on tag

Modified:
- `install/install.sh` — supports `--profile headless`
- `iso/qa/verify-shipped-iso.sh` — adds QA-H1 and QA-H2 assertions
