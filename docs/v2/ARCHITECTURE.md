# vinOS Architecture

**Version:** v1.0.x line · **Base:** Arch Linux (rolling, snapshot-pinned) · **Desktop:** Omarchy 3.8.4 (vendored)

_Developer-facing. For end-user product description, see the vinos.computer site._

## Four-layer stack

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 4 — vinOS ISO                                            │
│  archiso profile at iso/profile/                                │
│  packages.x86_64 + airootfs overlays + bootloader entries       │
│  Produces: vinos-<VERSION>-x86_64.iso (~4.4 GB)                 │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3 — vinOS overlay                                        │
│  configs/vinos/  — vinOS-specific configs (themes, T2, sec)     │
│  overlays/       — persona variants (education, health, ex.)    │
│  bin/vinos-*     — 130 wrapper commands (AI, routines, waybar)  │
│  install/*.sh    — 6-script install pipeline                    │
│  libexec/        — routine executor + ledger + budget           │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2 — Omarchy 3.8.4 (vendored)                             │
│  omarchy/  — git subtree merged at 29502e29                     │
│  Provides: Hyprland + Waybar + walker + terminals + themes      │
│  © David Heinemeier Hansson / Basecamp · MIT                    │
│  HARD RULE: never inline-edit; deltas go in configs/vinos/      │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1 — Arch Linux (base)                                    │
│  Snapshot-pinned per ISO — URL written to /etc/vinos-release    │
│  Kernels: linux-cachyos (default), linux-hardened, linux-t2     │
│  Package manager: pacman + AUR (via yay wrappers)               │
│  © Arch Linux community · GPL                                   │
└─────────────────────────────────────────────────────────────────┘
```

Every layer is independently upgradable with its own discipline (§Fork Policies below).

## Layer 1 — Arch Linux base

**What we get:** rolling-release, systemd, pacman, glibc, AUR access, T2 kernel via linux-t2 package.

**Discipline:**
- **Snapshot pinning** — every ISO records the exact Arch mirror snapshot URL used at build in `/etc/vinos-release`. Retained on R2 for 12 months.
- **No custom repos** — one upstream. Nothing from CachyOS repos, nothing from private mirrors. Bleeding-edge packages come via AUR only.
- **Kernel choice** — multi-kernel Limine boot menu ships three: `linux-cachyos` (default), `linux-hardened` (opt-in), `linux-t2` (required on Mac). From Phase 07 forward, `linux-vinos` custom kernel package also ships (see `KERNEL.md` §5).
- **Updates** — users on installed systems upgrade only between vinOS-blessed Arch snapshots via `vinos-update` (Phase 07 deliverable), not `pacman -Syu`.

## Layer 2 — Omarchy 3.8.4 (vendored)

**What we get:** polished Hyprland desktop with sane defaults — window rules, animations, keybindings, terminal themes, waybar/walker/mako configs, 10 themes, first-boot flow.

**Discipline:**
- **Vendored via git subtree** at `omarchy/`, merged at commit `29502e29` (squashed from Omarchy upstream `ef32ac97`).
- **Pinned per ISO** — every vinOS release ships with a specific Omarchy version. Never a moving target.
- **Quarterly bump discipline** — upgrade Omarchy on Feb / May / Aug / Nov schedule, not on every upstream release.
- **Diff-before-merge** — every bump requires a diff review + full regression harness pass. If any vinOS overlay would need rewriting, we file a hold and defer.
- **LKG tag** — `omarchy-lkg-<date>` is a permanent tag on the last-known-good pin. Rollback = `git subtree pull --squash omarchy <lkg-tag>`.
- **HARD RULE:** no inline edits to `omarchy/`. Every vinOS delta lives in `configs/vinos/` or `overlays/` and layers at install time. Enforced by CI grep (Phase 05 deliverable).

**Attribution:** © David Heinemeier Hansson / Basecamp · MIT · full text preserved in `NOTICES.md`. See `docs/v2/PLAN-2026-08-03.md` §10 for the fork rationale.

## Layer 3 — vinOS overlay

The vinOS overlay is where every vinOS-specific design decision lives. Broken down:

### `configs/vinos/`
- `default/` — always-applied configs (systemd tweaks, sudoers, mkinitcpio, sysctl)
- `brand/` — 10 themes (circuit, ridge, dusk, cosmos, egret, prism, summit, crater, bloom, reef) with wallpapers + palettes
- `t2/` — T2 Mac ISO-only support (brcmfmac, mkinitcpio hooks, iwd, modprobe.d)
- `security/` — hardening layer (firewall, SSH, faillock, sysctl, hardened_malloc from Phase 07)
- `headless/` — Phase 10 addition: hardened Arch profile for the Headless edition (overlayfs, apparmor enforcing, nftables deny-in)
- `kernel/` — Phase 07 addition: `linux-vinos` PKGBUILD + `.config` + patches + RATIONALE.md
- `mac/` — Cmd remap, natural scroll, screenshot keybindings
- `routines/dev/` — 10 dev-flow routine TOMLs (Phase 02 deliverable)
- `litellm/` — proxy config (Phase 01 deliverable; runtime deferred pending Python 3.14 compat)
- `systemd/` — user services (vinos-litellm, vinos-dev-qa-nightly, vinos-dev-triage)

### `overlays/`
Persona variants that layer on top of `configs/vinos/`. Base owns install scripts 01–09; overlays own 10–99. Config files shadow base (same basename wins).
- `education/` — office + media + dev tools
- `health/` — privacy-safe, no AI
- `example/` — reference template

### `bin/vinos-*`
130 wrapper commands. Categories:
- **AI agents:** `vinos-ai`, `vinos-routine`, `vinos-brief`, `vinos-standup`, `vinos-commit`, `vinos-focus`, `vinos-fix`, `vinos-explain`
- **Waybar pills:** `vinos-waybar-ai`, `vinos-waybar-routines`
- **Install/first-run:** `vinos-install-disk`, `vinos-first-run`, `vinos-installer-autolaunch-gui`
- **Menu + launch:** `vinos-menu`, `vinos-launch-*`
- **Hardware wrappers:** brightness, audio, battery, wifi, bluetooth

### `install/`
Six install scripts run by `install.sh` in order:
1. `01-base.sh` — base packages + pacman.conf + AUR mirror
2. `02-desktop.sh` — Omarchy core + Hyprland + Waybar + walker + fonts (ONLY graphical script; skip for headless)
3. `03-configs.sh` — rsync vinOS overlays + configs into `/etc/skel` + system paths
4. `04-services.sh` — systemd services (apparmor enabled, vinos-live-init, hardware watchers)
5. `05-branding.sh` — wallpapers, themes, menu labels, Plymouth splash
6. `06-hardware.sh` — T2 audio fixups, NVIDIA drivers, thermal management

Phase 04 adds `07-luks.sh`. Phase 10 adds `07-hardening.sh` (for headless profile).

### `libexec/`
- `vinos-routine-load.py` — parses `~/.vinos/routines.yaml`, emits TOML
- `vinos-routine-run.py` — executes routine TOML, manages tool calls, writes ledger (SQLite: tokens, dollars, duration)
- `vinos_routine_cron.py` — cron-string → systemd OnCalendar translator

## Layer 4 — vinOS ISO

**Build:** `iso/build.sh` runs `mkarchiso` in a Docker `archlinux:latest` container. Avoids host contamination.

**Profile:** `iso/profile/` (archiso spec)
- `packages.x86_64` — 298 packages, autogenerated by `iso/scripts/gen-packages.sh`
- `airootfs/` — base archiso airootfs plus vinOS T2 support
- `efiboot/loader/entries/` — systemd-boot entries
- `boot/limine.conf` — Limine bootloader config
- `profiledef.sh` — image name, format, bootmodes

**Overlays (build-time):** `iso/airootfs-overlay/` — additional live-ISO customizations (NetworkManager, systemd-networkd, greetd, sudoers, branding).

**QA harness:**
- `iso/qa/oneshot.sh` — 3-layer verifier (static lint + container QA + QEMU screendumps). Runs before every ship.
- `iso/qa/verify-shipped-iso.sh` — 11+ regression assertions. Immune system. Every ship adds one assertion per new gate.
- `iso/qa/verify-baseline.sh` — Phase 03 deliverable: backup discipline checks.
- `iso/qa/tier1-lint.sh` — Phase 03 deliverable: fast static lint from DEV-LOOP.md Tier 1.
- `iso/qa/tier2-container.sh` — Phase 03 deliverable: container-based install-script test from Tier 2.

**Output:** `iso/out/vinos-<VERSION>-x86_64.iso` + `sha256sums.txt`. Published to `dl.vinos.computer/releases/<VERSION>/` on ship. Artifacts archived to `~/vinos-iso-archive/isos/` + R2 for retention.

## Fork policies (summary)

Detailed policy in `docs/v2/PLAN-2026-08-03.md` §10.

| Component | Policy | Rollback |
|---|---|---|
| Arch base | Snapshot-pinned per ISO, blessed snapshots on R2 12 months | `vinos-update` between blessed snapshots |
| Omarchy 3.8.4 | Git subtree, quarterly bump, LKG tag | `git subtree pull --squash omarchy <lkg>` |
| Kernels | Multi-kernel Limine (cachyos + hardened + t2 + vinos from Phase 07) | Reboot to alternative |
| BTRFS | Auto-snapshot per boot via Snapper | `snapper rollback` |
| Kernel config | `configs/vinos/kernel/` in git from Phase 07 (custom `linux-vinos`) | Reboot to `linux-cachyos` fallback |

## Kernel strategy

See `docs/v2/KERNEL.md` for the 5-tier control model:
1. Kernel command line (Limine params + systemd-boot entries)
2. Modules — loaded at boot, blacklisted, or forced into initramfs
3. Modprobe options — per-module tuning (brcmfmac, iwlwifi, snd_hda_intel)
4. Runtime sysctl (`/etc/sysctl.d/`)
5. **Custom `linux-vinos` package** — line-by-line CONFIG_* control from Phase 07, signed for SecureBoot at Phase 12.

## Related

- `docs/v2/PLAN-2026-08-03.md` — master roadmap
- `docs/v2/DEV-LOOP.md` — 5-tier iteration pyramid (kills ISO burns)
- `docs/v2/KERNEL.md` — 5-tier kernel control
- `docs/v2/BACKUP.md` — backup + rollback strategy
- `docs/v2/TESTING.md` — QA gate framework
- `SECURITY.md` — public security posture + disclosure
- `NOTICES.md` — attribution registry
- `.planning/ROADMAP.md` — 12-phase ship queue
