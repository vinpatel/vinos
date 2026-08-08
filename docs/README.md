# vinOS documentation

Everything you need to understand, build, use, and contribute to vinOS.

## For users (installing + using)

Start here if you want to run vinOS on hardware or a VM.

- **[QUICKSTART.md](QUICKSTART.md)** — fastest path from download to a working desktop
- **[INSTALL.md](INSTALL.md)** — full install methods (live-USB, install-on-Arch)
- **[USB.md](USB.md)** — flashing the ISO to a USB stick + persistence
- **[HARDWARE.md](HARDWARE.md)** — supported hardware, T2 Mac specifics, GPU/wifi notes
- **[KEYBINDINGS.txt](KEYBINDINGS.txt)** — every Hyprland shortcut vinOS ships
- **[BUNDLES.md](BUNDLES.md)** — the optional software bundles (`vinos-install-*`)
- **[PREFLIGHT.md](PREFLIGHT.md)** — hardware readiness checklist before install

## For reviewers (understanding how vinOS is built)

Read in this order if you're evaluating vinOS or trying to understand the design:

1. **[VISION.md](VISION.md)** — why vinOS exists, the two-product framing, and the north star
2. **[ARCHITECTURE-v1.1.0.md](ARCHITECTURE-v1.1.0.md)** — the frozen baseline: exact packages, kernels, boot flow, UX layer, everything reproducible
3. **[DESIGN-DECISIONS.md](DESIGN-DECISIONS.md)** — the design decisions log — every big choice with date, context, and rationale (why Ubuntu for the VM, why no Omarchy, why runner-agnostic, etc.)
4. **[../.planning/RULES.md](../.planning/RULES.md)** — the durable rules that govern all future work
5. **[../.planning/ROADMAP.md](../.planning/ROADMAP.md)** — where we're going (milestones v1.2.0 → v1.4.0)
6. **[../.planning/research/PERSONAS.md](../.planning/research/PERSONAS.md)** — the full dual-persona design spec (packages, security, CLI, agentic runtime)

## For contributors (building + shipping code)

- **[CONTRIBUTING.md](CONTRIBUTING.md)** — repo layout, dev setup, commit style, review flow
- **[BUILDING.md](BUILDING.md)** — reproduce the ISO from source, step-by-step
- **[../iso/README.md](../iso/README.md)** — the ISO build subsystem specifically

## Repo map — top level

```
vinos/
├── README.md                              # marketing landing + quick nav
├── VERSION                                # single source of truth for release number
├── LICENSE                                # MIT
│
├── docs/                                  # you are here
│   ├── README.md                          # this file
│   ├── VISION.md                          # why vinOS
│   ├── ARCHITECTURE-v1.1.0.md             # frozen baseline reference
│   ├── DESIGN-DECISIONS.md                       # design decisions log (ADR-style)
│   ├── BUILDING.md                        # build the ISO from source
│   ├── CONTRIBUTING.md                    # for new contributors
│   ├── INSTALL.md                         # install methods
│   ├── QUICKSTART.md                      # fastest path
│   ├── USB.md                             # flash to USB
│   ├── HARDWARE.md                        # supported hardware
│   ├── KEYBINDINGS.txt                    # every shortcut
│   ├── BUNDLES.md                         # optional bundles
│   └── PREFLIGHT.md                       # readiness checklist
│
├── .planning/                             # active planning + rules
│   ├── RULES.md                           # durable rules (read this)
│   ├── ROADMAP.md                         # milestones
│   ├── config.json                        # GSD workflow config
│   └── research/PERSONAS.md               # dual-persona spec
│
├── iso/                                   # ISO build system
│   ├── build.sh                           # container-based mkarchiso wrapper
│   ├── flash.sh                           # USB burn helper
│   ├── profile/                           # archiso profile (bootmodes, packages, initramfs, boot entries)
│   ├── airootfs-overlay/                  # live-only overlay merged after installer runs
│   ├── packages.releng                    # base archiso packages
│   ├── packages.live                      # vinOS live-only additions
│   ├── aur.list                           # AUR packages built by aur-build.sh
│   ├── aur.live                           # subset of aur.list needed on live ISO
│   ├── gen-packages.sh                    # unions all sources → profile/packages.x86_64
│   ├── test.sh / qemu-desktop.sh          # QEMU acceptance harnesses
│   └── out/                               # build artifacts (ISOs + sha256)
│
├── config/                                # end-user config (installed to /etc/skel)
│   ├── hypr/                              # Hyprland configs (see menu system design)
│   ├── waybar/, walker/, mako/, foot/, ...
│
├── install/                               # installer scripts (Path B: install on top of Arch)
│   ├── 01-base.sh through 05-branding.sh
│   └── first-run/                         # post-install one-shot setup
│
├── bin/                                   # the vinos-* helper library (88 scripts)
│   └── vinos-*                            # menu, doctor, cheatsheet, hyprland-*, hw-*, etc.
│
├── configs/vinos/                         # system config artifacts installed to /etc/vinos/
│   ├── litellm/                           # LiteLLM proxy config (v1.3.0)
│   └── routines/                          # scheduled routines (dev/*)
│
└── site/                                  # marketing website source
```

## The 60-second overview

vinOS is **two products from one brand**:

1. **`vinos-dev`** — an Arch-based Linux desktop tuned for developers who drive AI agents all day. Hyprland compositor, 88 `vinos-*` helper scripts, Claude Code + Ollama preinstalled, best-in-class agentic UX.

2. **`vinos-vm`** — an Ubuntu 24.04 LTS minimal image built for cloud fleets. Enterprise-grade hardening (AppArmor + nftables + auditd + unattended-upgrades), boots to first agentic mission in under 45 seconds from `terraform apply`.

Both share a distro-agnostic bash runtime — the same `vinos` CLI, the same `vinos-agent-worker` systemd unit, the same MCP server registry. Only the package format differs (`.pkg.tar.zst` vs `.deb`).

The full origin story is in [VISION.md](VISION.md).
