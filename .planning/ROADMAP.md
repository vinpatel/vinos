# vinOS roadmap

**Baseline:** v1.1.0 (permanent, 2026-07-18 · `iso/out/vinos-1.1.0-x86_64.iso`)
**Direction locked:** 2026-08-08 — Option C (dev = Arch, vm = Ubuntu, shared bash runtime)
**Governing rules:** `.planning/RULES.md`

---

## Vision — two products, one brand, agentic-first

vinOS ships as two distinct products with a shared identity, runtime API, and CLI:

### Product 1 — `vinos-dev` · **agentic OS for developers**

A tinkerer-friendly Linux desktop built from Arch, tuned so developers who drive AI agents all day feel at home from minute one.

- **Positioning:** "The best Linux for developers who ship with agents."
- **Comparable to:** Omarchy (but with baked-in AI story), Pop!_OS (but Hyprland instead of GNOME), macOS (but hackable).
- **Distinctive:** Every keybinding self-documents. `vinos-menu` swiss-army in Super+Alt+Space. Claude Code + Ollama + MCP ready in ≤ 5 min from first login. 88 `vinos-*` bash helpers form a coherent developer UX layer.
- **Base:** Arch (rolling), archiso build, `linux` + `linux-t2` kernels.
- **Distribution:** Signed live ISO + install-to-disk on `vinos.computer/download`.

### Product 2 — `vinos-vm` · **enterprise-grade hardened agentic Linux VM**

A minimal Ubuntu 24.04 LTS image with the vinOS runtime layered on top — designed to be spawned by cloud orchestrators, run agentic missions fully unattended, and satisfy enterprise security bars out-of-box.

- **Positioning:** "The Linux VM for running agentic workflows in production."
- **Comparable to:** Ubuntu Server (but agent-native), Amazon Linux (but distro-agnostic), Fly.io machines (but self-hosted).
- **Distinctive:** Boot-to-first-mission < 45 s from `terraform apply`. CIS/STIG-adjacent hardening enforced by default. AppArmor + nftables + auditd + unattended-upgrades preconfigured. Ships across every major cloud marketplace with the same behavior.
- **Base:** Ubuntu 24.04 LTS minimal, packer build, `linux-image-generic-hwe`.
- **Distribution:** qcow2 (KVM/DO/Hetzner) + AMI (AWS) + VHD (Azure) + GCE image, plus `.deb` packages at `apt.vinos.computer`.

### Cross-product runtime — the vinOS layer

Both products share a **distro-agnostic bash runtime** installed identically as `.pkg.tar.zst` on dev and `.deb` on vm:

- Single `vinos` CLI (14 subcommands, learnable in 5 min)
- `vinos-agent-worker.service` (systemd unit, defaults on/off by product)
- **Runner-agnostic worker** — Claude Code is the shipped default, but `VINOS_RUNNER=claude|codex|aider|custom` swaps runners in one env var. Each runner is ~150 lines of bash in `/usr/lib/vinos/runners/*.sh` implementing 4 verbs (`runner_check`, `runner_run`, `runner_cancel`, `runner_capabilities`)
- `vinos-mcp` MCP server registry CLI (MCP is now cross-vendor, so servers are portable across runners)
- `vinos-doctor` 25-check diagnostic
- Shared configs in `/etc/vinos/`

**Two-tier model policy (both products):** frontier reasoning via Claude Code (Anthropic API), workhorse volume via local Ollama models. On `vinos-dev`, a **LiteLLM proxy** at `localhost:4000/v1` fronts both with named roles (`vinos-planner` → Claude, `vinos-executor` → local Qwen3-Coder, etc.). On `vinos-vm`, local models are opt-in via `vinos install ai-local` — off by default because most cloud VMs lack GPUs.

**Users see one brand, one CLI, one experience — even though the OS underneath is different.**

### Bridge — Arch can deploy Ubuntu containers

`vinos-dev` (Arch) can natively deploy Ubuntu workloads for testing without spinning up a cloud VM:

- `podman run -it --rm ubuntu:24.04 bash` — instant Ubuntu shell
- `distrobox create -i ubuntu:24.04 -n vm-testbed && distrobox enter vm-testbed` — full Ubuntu userland integrated into the Hyprland session
- `vinos vm-testbed launch` (planned CLI) — spawns a headless `vinos-vm` VM locally in QEMU, ssh-forwarded, for iterating on agent workflows before pushing to the cloud

**Developers get both worlds. No context switching. No leaving Hyprland.**

---

## Milestones

### v1.2.0 — Persona activation (3-5 weeks, this milestone)

Split the single v1.1.0 base into two distinct products. Publish first v1.2.0 releases of each.

**Track A — vinos-dev**
- A1 · Activate modular hypr sourcing + `bindd =` migration
- A2 · `vinos-menu` binding activation (Super+Alt+Space)
- A3 · First-run wizard v2 (`gum`-driven, 6 screens)
- A4 · Preinstall Claude Code + Ollama + `vinos-mcp` + curated MCP registry
- A5 · Ship `vinos-dev-1.2.0-x86_64.iso`

**Track B — vinos-vm**
- B1 · Shared vinOS runtime monorepo (`vinos-runtime/`) + Makefile → both `.pkg.tar.zst` and `.deb`
- B2 · Publish signed apt repo at `apt.vinos.computer` (GPG-signed, Cloudflare-hosted)
- B3 · Packer template + Ansible provisioner for Ubuntu 24.04 minimal + vinOS layer
- B4 · Multi-arch image build (amd64 + arm64 qcow2)
- B5 · `vinos-agent-worker` polling loop + orchestrator protocol v1 + **runner abstraction** (Claude default; Codex + Aider adapters ship in the same milestone)
- B6 · Full `vinos` CLI (14 subcommands, all tested)
- B7 · Multi-cloud image publish: DigitalOcean + Hetzner first, AWS + Azure + GCE second
- B8 · Ship `vinos-vm-1.2.0-{amd64,arm64}.qcow2` + apt repo v1

**Track Q — QA & test harness** (added 2026-08-14 after v1.2.1/v1.2.2 SUPER+Return regression escaped every existing gate)
- Q1 · `iso/qa/config-lint.sh` — static Hyprland/autostart gate at build time (shipped 2026-08-11, catches v1.2.1-class bugs)
- Q2 · `iso/qemu-desktop.sh --lan/--keepalive/--monitor/--hostfwd` — one-command Mac→QEMU test path with hypridle defeat + HMP socket + SSH forward
- Q3 · `iso/qa/hmp.sh` + `iso/qa/keepalive.sh` — HMP client wrapper + anti-lock keepalive (composable primitives for every future test tool)
- Q4 · `iso/test-super-return.sh` — headless sendkey regression: injects SUPER+Return, pixel-diffs before/after, blocks ship on FAIL
- Q5 · `iso/qa/loop.sh` — Tier 3 hot-patch iteration (inotifywait on config/hypr → scp → hyprctl reload). Requires sshd enabled in live overlay
- Q6 · Enable sshd in `iso/airootfs-overlay/etc/systemd/system/multi-user.target.wants/` so Q5 + guest introspection work without VINOS_ENABLE_SSH=1
- Q7 · Wire Q4 into `iso/test.sh matrix` — no ISO ships without SUPER+Return proven live in QEMU
- Q8 · `iso/qa/checkpoint.sh` + `.planning/SHIP-MANIFEST.md` — single pre-ship gate that runs every declared config through its own parser (waybar/hyprctl/mako/swaybg/fcitx5/walker). Added 2026-08-15 after v1.2.5 shipped a `font-feature-settings` + `@keyframes inset` CSS bug that config-lint couldn't see. Reference: `.planning/research/QA-CHECKPOINT-REFERENCE.md`

Full runbook: `.planning/TESTING.md`. The four tiers of iteration + which bug class each catches are documented there.

**Success criteria:**
1. `vinos-dev` boots to working agentic dev env in ≤ 5 min post-login
2. `vinos-vm` on any cloud accepts an agent config via cloud-init and completes a test mission within 60 s of first boot
3. Both images pass `iso/qa/oneshot.sh` + regression harness
4. `apt.vinos.computer` serves signed `.deb` that installs cleanly on stock Ubuntu 24.04
5. Retention rule holds: `iso/out/` = last 3 dev + last 3 vm + `vinos-1.1.0` permanent
6. Zero "omarchy" mentions in commits or file contents

### v1.3.0 — Refined desktop (5-day sprint, blocks all other v1.3+)

**Motivation (2026-08-15):** vinOS looks bare next to JaKooLit / HyDE /
end-4/dots-hyprland. Zero Hyprland plugins loaded, no GTK / icon / cursor
themes, no reactive widget layer. Config-only work is done — the visual
layer is the gap. Beat HyDE without importing HyDE.

**Track R — Refinement**

| ID | Item | Notes |
|----|------|-------|
| R1 | Bundle 5 MIT/BSD Hyprland plugins pre-installed | hyprexpo, borders-plus-plus, hyprwinwrap, hypergrass, csgo-vulkan-fix (per PILOT-4-RESULTS.md). No `hyprpm` dance for user. |
| R2 | `vinos-gtk` theme package | Own GTK3 + GTK4 CSS. Tokyo-night-derived palette per BRANDING.md. No Adwaita default look. |
| R3 | `vinos-icons` theme package | Papirus base (MIT), color-shifted to vinOS teal accents, action/status icons redrawn on-brand. |
| R4 | `vinos-cursor` theme package | Bibata base (GPL-3 — **evaluate license fit**; if blocked, fall back to XCursor from scratch). |
| R5 | Astal widget layer | MIT, minimal deps. Ships `vinos-dashboard` (system stats + AI state), `vinos-notify` (fancy notification center replacing bare mako), agent-state module. |
| R6 | Refined waybar animations | SIGRTMIN+N real signal-driven state transitions (not the fake @keyframes we ripped out). Battery pulse, AI-active glow, connection-drop shake. |
| R7 | Live wallpapers via hyprwinwrap | Ship 1 default animated aurora scene + `vinos-theme apply aurora --live` CLI toggle. |
| R8 | `hyprshade` color-temperature integration + `vinos-menu → Display` toggle | Warm/cool profiles per time of day. |
| R9 | Refined swaybg pipeline — parallax on workspace switch, dim on window focus | Same wallpaper file, subtle motion — makes single-image feel alive. |
| R10 | Screenshot side-by-side vs JaKooLit / HyDE / end-4 in `.planning/research/UI-COMPARISON.md` before shipping | We commit to at-least-parity or better on ~10 concrete axes: focus rings, module density, animation cadence, palette consistency, tray sensibility, launcher aesthetic, wallpaper polish, notification stack, workspace overview, cursor smoothness. |

**License gate:** every plugin/theme evaluated per `BRANDING.md` + PILOT-4 gates.
No GPL bundling — Bibata's license needs verifying before R4 ships.

**Deliverable:** vinos-dev-1.3.0-x86_64.iso that a fresh viewer would rate
visually equal to or better than the top 3 curated Hyprland dotfile
repos. Screenshot showdown documented in UI-COMPARISON.md.

### v1.3.1 — Boot menu + installer UX (1-2 weeks) — next after v1.3.0 stable

**Motivation (2026-08-15):** v1.3.0 ships live-boot to Hyprland cleanly, but
installing to disk still requires the user to open a terminal and run
`sudo vinos-install-disk`. Distros like Ubuntu/Fedora/Manjaro ship a
**boot-menu Install entry** so the flash-USB-then-boot flow ends with a
guided install, not a treasure hunt. That is the last major UX gap before
handing vinOS to non-Vin developers.

**Track I — Install UX**

| ID | Item | Notes |
|----|------|-------|
| I1 | Add "Install vinOS (T2 Mac)" + "Install vinOS (Intel/AMD PC)" UEFI boot entries | New `.conf` files under `iso/profile/efiboot/loader/entries/` with kernel cmdline flag `vinos.install=1` |
| I2 | Same for BIOS/syslinux (`iso/profile/syslinux/`) | Match feature parity for non-UEFI legacy boot |
| I3 | Reorder loader.conf `default` so "Install" appears first on the menu, live "Try" second | Common distro convention. Reduces friction for the common case. |
| I4 | `vinos-live-init.service` reads `/proc/cmdline` for `vinos.install=1` | Sets `~/.local/state/vinos/auto-install` flag on the ephemeral vinos user |
| I5 | `config/hypr/autostart.conf` auto-launches `vinos-install-disk --gum-wizard` when the flag is present | User boots into a full-screen gum-driven installer, not a bare desktop |
| I6 | `bin/vinos-install-disk --gum-wizard` — interactive gum-styled wizard | Screens: welcome, disk pick (with `lsblk` preview), user/pass/hostname, confirm, run. Matches vinos-first-run visual style. |
| I7 | Post-install: reboot prompt with 10-s countdown | Cancellable with any key. Matches archinstall UX. |
| I8 | Progress bar during pacstrap + copy | Currently silent for 5-10 min. Feels broken. |
| I9 | Screenshot of every install screen filed to `.planning/research/screenshots/1.3.1-install-*.png` | For docs/INSTALL.md refresh |

**Deliverable:** flash `vinos-1.3.1-x86_64.iso` to USB, boot on any target,
pick "Install vinOS", answer 4 prompts, walk away. Reboot into installed
system. Zero terminal.

### v1.4.0 — Enterprise polish (4-6 weeks) — was v1.3.0

**vinos-vm hardening + compliance**
- CIS Benchmark v2.0.0 automated audit (`vinos doctor --cis`)
- FIPS 140-3 kernel option (Ubuntu Pro attach)
- SBOM generation per image (SPDX 3.0)
- SLSA level 3 build attestation
- Sunset/EOL calendar published

**vinos-dev polish**
- **LiteLLM proxy service** — runs on `vinos-dev` as `litellm.service`, listens on `localhost:4000/v1`, routes named model roles (`vinos-planner`/`vinos-reviewer`/`vinos-architect` → Claude, `vinos-executor`/`vinos-checker`/`vinos-autoexec` → local Ollama). Apps target one endpoint; the proxy handles routing + retry + cost tracking. Shipped as `litellm.service` systemd unit + `configs/vinos/litellm/proxy.yaml`.
- Waybar AI status pill (model + session + burn) — bumped from Track R6 if not covered
- `vinos vm-testbed` CLI for local Ubuntu VM testing
- All hypr toggles wired to `vinos-menu` submenus

**Cross-product**
- `vinos update --self` — updates the vinos runtime layer without touching base OS
- Fleet mgmt CLI (`vinos fleet list/status/broadcast` on the dev workstation for a group of vms)

### v1.5.0 — Ecosystem (6-8 weeks) — was v1.6.0

- Marketplace listings: AWS Marketplace + GCP Marketplace + Azure Marketplace
- MCP server catalog: user-contributed servers, review process, `vinos mcp search <term>`
- Community skills: `vinos skill add <name>` — shared automation snippets
- AgenticFlow orchestrator adapter (if AgenticFlow ships v1)
- vinos-dev tour mode: onboarding walkthrough for new users

### v1.6.0 — Apple Silicon (Track M) — 3-4 weeks — DEFERRED from v1.5.0

**Motivation:** vinOS currently targets x86_64 with T2-Mac as the primary
hardware. M-series Macs (M1/M2/M3/M4) are the modern Apple laptop line —
covering them multiplies the addressable install base. Asahi Linux
(asahilinux.org) has done the hard work: kernel patches, m1n1 bootloader,
Apple GPU (mesa) driver, macsmc-hid audio. We integrate their libraries
under a vinOS-branded install path — no wheel reinvention, GPL-2 accepted
for the kernel (already the case).

**Deferred 2026-08-15** at user's direction — the x86_64 install UX
(v1.3.1) + enterprise (v1.4) + ecosystem (v1.5) must land first before we
fork the codebase for aarch64.

| ID | Item | Notes |
|----|------|-------|
| M1 | `iso/build.sh --arch aarch64` — parallel archiso build path for ARM | Docker container gets a --platform linux/arm64 flag, mkarchiso stays the same |
| M2 | Bundle `asahi-linux` kernel + `asahi-installer` + `m1n1` bootloader | From asahilinux.org repos; GPL-2 kernel patches compatible with our stance |
| M3 | Bundle Apple GPU mesa driver + macsmc-hid audio + brcmfmac wifi | Asahi's driver stack, no custom work |
| M4 | `bin/vinos-asahi-enable` — first-boot hardware detect + driver activation, mirrors bin/vinos-t2-enable pattern | |
| M5 | Install-disk path for M-series | No BIOS grub, uses m1n1 → uboot → EFI. Different partition scheme; may need archinstall extension |
| M6 | Ship `vinos-dev-<version>-aarch64.iso` alongside x86_64 in release | Two ISOs per release; retention policy applies to both |
| M7 | QEMU aarch64 tests in Track Q harness | qemu-system-aarch64 + virt machine; keyboard/network/GPU passthrough tests |

**License gate:** Asahi's kernel patches are GPL-2 (upstream Linux). Compatible.
Apple GPU driver is in mesa (MIT). No proprietary blobs added.

**Deliverable:** vinOS runs on M1/M2/M3/M4 Macs from a single boot USB with
the same install-disk UX as x86_64 T2s.

### v1.7.0+ — TBD

Deferred until we have real-world usage data from v1.3-v1.6.

---

## Non-goals

- **No Omarchy code, configs, or overlays.** Ever. See [`RULES.md`](RULES.md).
- **No mobile/tablet story.** vinOS targets desktops + servers only. (M-chip Macs count as desktops per Track M.)
- **No i18n beyond en-US.** Post-1.5 maybe.
- **No custom package manager.** apt for vm, pacman for dev — inheriting each distro's ecosystem.
- **No forked kernel.** We use stock `linux`, `linux-t2`, `linux-image-generic`. Kernel work belongs upstream.
- **No proprietary telemetry.** Zero phone-home from either product. Opt-in metrics only, always local-first.

---

## Model policy (until stable ISO ships)

100% Claude Opus 4.7 (1M context) for all planning, execution, review, debug — see `.planning/RULES.md` § Model policy.

---

## References

- `.planning/RULES.md` — durable project rules
- `.planning/research/PERSONAS.md` — detailed design spec for both personas
- `docs/ARCHITECTURE-v1.1.0.md` — frozen architecture of the baseline
- `iso/qa/oneshot.sh` — ship gate (Layer 1 static + Layer 2 container + Layer 3 QEMU + regression harness)
- `iso/flash.sh` — safe USB burn helper
