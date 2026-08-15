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

### v1.3.0 — Enterprise polish (4-6 weeks)

**vinos-vm hardening + compliance**
- CIS Benchmark v2.0.0 automated audit (`vinos doctor --cis`)
- FIPS 140-3 kernel option (Ubuntu Pro attach)
- SBOM generation per image (SPDX 3.0)
- SLSA level 3 build attestation
- Sunset/EOL calendar published

**vinos-dev polish**
- **LiteLLM proxy service** — runs on `vinos-dev` as `litellm.service`, listens on `localhost:4000/v1`, routes named model roles (`vinos-planner`/`vinos-reviewer`/`vinos-architect` → Claude, `vinos-executor`/`vinos-checker`/`vinos-autoexec` → local Ollama). Apps target one endpoint; the proxy handles routing + retry + cost tracking. Shipped as `litellm.service` systemd unit + `configs/vinos/litellm/proxy.yaml`.
- Theme system with 4 vinOS-native themes (aurora + nebula + ember + frost — all authored by us, zero reuse of ecosystem theme names; see ADR-012)
- Waybar AI status pill (model + session + burn)
- `vinos vm-testbed` CLI for local Ubuntu VM testing
- All hypr toggles wired to `vinos-menu` submenus

**Cross-product**
- `vinos update --self` — updates the vinos runtime layer without touching base OS
- Fleet mgmt CLI (`vinos fleet list/status/broadcast` on the dev workstation for a group of vms)

### v1.4.0 — Ecosystem (6-8 weeks)

- Marketplace listings: AWS Marketplace + GCP Marketplace + Azure Marketplace
- MCP server catalog: user-contributed servers, review process, `vinos mcp search <term>`
- Community skills: `vinos skill add <name>` — shared automation snippets
- AgenticFlow orchestrator adapter (if AgenticFlow ships v1)
- vinos-dev tour mode: onboarding walkthrough for new users

### v1.5.0+ — TBD

Deferred until we have real-world usage data from v1.2-v1.4.

---

## Non-goals

- **No Omarchy code, configs, or overlays.** Ever. See [`RULES.md`](RULES.md).
- **No mobile/tablet story.** vinOS targets desktops + servers only.
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
