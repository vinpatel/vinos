# vinOS — vision

**Written 2026-08-08 · Author: Vin Patel**

## Why vinOS exists

I built vinOS because no Linux distribution — not Arch, not Ubuntu, not Fedora, not NixOS, and not Omarchy — treats **agentic AI as a first-class citizen** of the operating system.

Every existing distro was designed for a world where an OS runs apps and humans drive those apps. But that's not the world we live in anymore. Increasingly, we live in a world where:

- The primary user of a developer's laptop is a *fleet* of AI agents that the developer supervises.
- The primary user of a cloud VM is an autonomous agent workflow spawned by an orchestrator to complete a mission unattended.

Both cases share the same underlying need: **the OS itself has to be a first-class collaborator with agents**, not a passive platform hosting them as apps.

That's what vinOS is. A Linux OS designed from the ground up around the assumption that AI agents are how work gets done, and the OS should make that as frictionless as breathing.

## The two products

vinOS ships as two distinct products with a shared identity, runtime API, and CLI:

### Product 1 — `vinos-dev` · **agentic OS for developers**

The best Linux for developers who ship with agents. Built from pure Arch (rolling release, archiso build), tuned so a developer who drives Claude Code + local Ollama models all day feels at home from minute one.

- **Base:** Arch Linux (rolling)
- **Kernel:** stock `linux` + community `linux-t2` for Apple T2 Macs
- **Desktop:** Hyprland compositor, 88 `vinos-*` helper scripts, three-tier menu system (Super+Space fuzzy launcher · Super+Ctrl+Space visual app grid · Super+Alt+Space vinOS command palette)
- **AI stack:** Claude Code CLI + Ollama local models + LiteLLM proxy routing between them
- **Distribution:** signed live ISO + install-to-disk
- **Audience:** solo devs, hackers, "Hyprland power users"

Comparable to Omarchy (but with baked-in AI story), Pop!_OS (but Hyprland instead of GNOME), macOS (but hackable). Distinctive on **every keybinding self-documents, `vinos-menu` swiss-army in one chord, Claude + Ollama + MCP ready in under 5 min from first login**.

### Product 2 — `vinos-vm` · **enterprise-grade hardened agentic Linux VM**

The Linux VM for running agentic workflows in production. Built from Ubuntu 24.04 LTS minimal, hardened to CIS/STIG-adjacent standards by default, designed to be spawned by cloud orchestrators and complete missions unattended.

- **Base:** Ubuntu 24.04 LTS minimal (packer build, apt-native)
- **Kernel:** `linux-image-generic-hwe-24.04`
- **Security:** AppArmor enforcing · nftables locked to :22 · auditd rules · unattended-upgrades · SSH pubkey-only
- **Runtime:** `vinos-agent-worker.service` polls orchestrator, spawns agent runner in a systemd sandbox
- **Boot to first mission:** < 45 s from `terraform apply`
- **Distribution:** qcow2 (KVM/DO/Hetzner) + AMI (AWS) + VHD (Azure) + GCE image + `.deb` via `apt.vinos.computer`
- **Audience:** cloud fleets, AgenticFlow workers, enterprise ops

Comparable to Ubuntu Server (but agent-native), Amazon Linux (but distro-agnostic across every cloud), Fly.io machines (but self-hosted).

## The shared vinOS runtime layer

Both products share a **distro-agnostic bash runtime** installed identically:

- A single `vinos` CLI — 14 subcommands, learnable in 5 minutes
- `vinos-agent-worker.service` (systemd unit)
- `vinos-mcp` MCP server registry CLI
- `vinos-doctor` 25-check diagnostic
- Shared configs in `/etc/vinos/`

Built from one monorepo (`vinos-runtime/`) with a Makefile that emits both `.pkg.tar.zst` (for Arch) and `.deb` (for Ubuntu) from the same source. **Users see one brand, one CLI, one experience — even though the OS underneath is different.**

The full CLI surface, runner adapter interface, and lifecycle diagrams are in [`../.planning/research/PERSONAS.md`](../.planning/research/PERSONAS.md).

## The two-tier model policy

vinOS operates on a **frontier-decides / local-grinds** split, not a single-model story:

| Tier | Runtime | Cost | Role |
|---|---|---|---|
| **Frontier** — Claude Code | Anthropic API | pay per token | Plans, reviews, decides, orchestrates. Small call volume, high per-call value. |
| **Workhorse** — Ollama local | Your machine's GPU/CPU | free after hardware | Bulk mechanical work — apply N similar fixes, refactor M files, generate boilerplate. High call volume, low per-call value. |

Claude Code is the driver seat. Local Ollama models are the workhorse for repetitive volume. This split is codified in the LiteLLM proxy config that ships on `vinos-dev` and in the `VINOS_RUNNER` env var that governs `vinos-vm`.

## The runner abstraction

We ship Claude Code as the default because it's the best headless agentic CLI in 2026. But we're **not locked to it.** The `vinos-agent-worker` uses a runner abstraction — swap runners with one env var:

```
VINOS_RUNNER=claude   # default; Claude Code
VINOS_RUNNER=aider    # aider CLI, supports local Ollama directly
VINOS_RUNNER=codex    # OpenAI Codex CLI
VINOS_RUNNER=custom   # user-written adapter
```

Each adapter is ~150 lines of bash implementing 4 verbs. MCP servers work across all runners (MCP is cross-vendor now). Air-gapped mode is a config choice, not a rewrite. See [DESIGN-DECISIONS.md](DESIGN-DECISIONS.md) § "Why Claude Code as default, not lock-in" for the full argument.

## Why two distros — one brand, one CLI

The obvious question: why not ship both products on the same base?

- **Arch on cloud VMs:** < 1 % adoption ceiling. Zero cloud marketplaces list it by default. Enterprise procurement can't ratify it. The rolling model is a hard no for compliance.
- **Ubuntu on developer desktops:** loses the Hyprland/tinkerer aesthetic that defines `vinos-dev`. Users who reach for Ubuntu want GNOME defaults; users who reach for Arch want to compose their own stack.

The right answer is different bases for different customers. **The vinOS *layer* (bash scripts + systemd units + configs) is portable across both distros**, which preserves brand + CLI unity. Two products, one brand, one experience — even though the OS underneath differs.

Bonus: `vinos-dev` (Arch) can natively deploy Ubuntu containers via `podman` or `distrobox`. Developers can iterate against the *real* `vinos-vm` behavior locally without leaving Hyprland — the "unified developer experience" without technical unification underneath.

## Ground rules

Every design decision in this project follows a small set of durable rules. They live in [`../.planning/RULES.md`](../.planning/RULES.md):

- **Model policy:** 100 % Claude Opus 4.7 (1M context) as the driver until vinOS ships a stable ISO release. Local models are the workhorse tier, not the driver.
- **Baseline:** all new work branches from `v1.1.0`. The `v1.1.0` ISO is the permanent gold copy, verified end-to-end on T2 Mac hardware — never overwritten, rebuilt, or deleted.
- **No Omarchy:** vinOS ships zero Omarchy code, configs, forks, or overlays. We author every config ourselves. Commit messages don't reference the name either.
- **ISO storage & retention:** all ISOs live in `iso/out/`. Retention policy = last 3 successful builds + `v1.1.0` permanent.
- **Ship-gate discipline:** never hand a user an ISO without running `iso/qa/oneshot.sh` first (static + container + QEMU + regression harness).

## The frozen baseline

`v1.1.0` (tag `v1.1.0`, commit `e5c44b9e`, ISO SHA256 `3bd3657e…873ef2`) is the frozen starting point for everything that follows. Its exact architecture is captured in [`ARCHITECTURE-v1.1.0.md`](ARCHITECTURE-v1.1.0.md) — you can `git checkout v1.1.0 && bash iso/build.sh` and reproduce a byte-close ISO from source.

Every subsequent milestone (v1.2.0 "Persona activation", v1.3.0 "Enterprise polish", v1.4.0 "Ecosystem") is a layer on top of that baseline. The roadmap lives in [`../.planning/ROADMAP.md`](../.planning/ROADMAP.md).

## What vinOS is *not*

- Not a fork of Arch or Ubuntu — a composition on top of both
- Not a UI theme or a config bundle — a full OS build with its own release pipeline
- Not a hosted service — the code is MIT-licensed, self-buildable, self-hostable
- Not Omarchy — explicit hard rule, see above
- Not tied to any single AI vendor — the runner abstraction ensures portability
- Not for mobile / tablet / ChromeOS-adjacent form factors — desktops + servers only
- Not phone-home telemetry — zero telemetry by default; opt-in only, always local-first

## Where this is going

The near-term goal is **v1.2.0 — Persona activation**: split the single v1.1.0 base into `vinos-dev` (Arch) and `vinos-vm` (Ubuntu) as two distinct shippable products, with the shared `vinos` CLI + `vinos-agent-worker` runtime working identically on both.

The medium-term goal is **v1.3.0 — Enterprise polish**: CIS Benchmark automation, FIPS 140-3 kernel option, SBOM per image, SLSA level 3 build attestation. The bar to ratify vinOS-vm inside an enterprise procurement process.

The long-term goal is **v1.4.0 — Ecosystem**: marketplace listings on AWS/GCP/Azure, user-contributed MCP server catalog, AgenticFlow orchestrator adapter, community skills.

Beyond v1.4.0, direction depends on what real-world usage teaches us. See [ROADMAP.md](../.planning/ROADMAP.md).

---

*If you're reviewing vinOS, read [ARCHITECTURE-v1.1.0.md](ARCHITECTURE-v1.1.0.md) next for the concrete baseline, then [DESIGN-DECISIONS.md](DESIGN-DECISIONS.md) for how we got here.*
