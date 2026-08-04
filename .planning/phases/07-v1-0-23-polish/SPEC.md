# Phase 07 — v1.0.23: Developer edition polish

**Type:** release · **Depends on:** 06 · **Ships as:** `vinos-1.0.23-x86_64.iso`
**Duration:** 7 days (extended for kernel work) · **Requirements:** R2, R-KERNEL

## Goal
Beat Omarchy visibly on the agentic axis. Per memory: elite UI/UX + perfect boot experience are THE differentiators. This phase is the highest-leverage of the release queue.

## Scope (in)
- **Boot experience:** Plymouth splash with vinOS logo (not Omarchy), Limine theme with vinOS palette, greetd theme branded, first-boot flow walks user through routine execution
- **Desktop polish:** Hyprland `.conf` → `.lua` migration (per Hyprland 0.57 deprecation), nwg-drawer as ⌥+Space default (full-screen icon grid — not walker text bar), waybar AI pill + routine ticker + budget indicator
- **Sandbox:** Firejail profiles for browser + AI shell + walker
- **Update discipline:** `vinos-update` command with snapshot-pinned upgrades between blessed Arch snapshots
- **Keybindings:** Super+A (AI shell), Super+Shift+A (Claude Code), Super+R (routine list), Super+B (brief)
- **Kernel control (`linux-vinos` package — first cut):** ships alongside `linux-cachyos`, opt-in via Limine boot entry. Source of truth: `configs/vinos/kernel/PKGBUILD` + `.config` + `patches/` + `RATIONALE.md`. Docs: `docs/v2/KERNEL.md` §5. Self-signed for dev (SecureBoot signing lands in Phase 12 if key acquired).

## Scope (out)
- Rewriting Hyprland modules that Omarchy already handles well
- Adding new themes beyond the 10 shipped
- Any Cloud-edition work (Phase 10 owns)

## Human checkpoints
1. Plymouth splash design (public-facing brand)
2. Greetd theme design (public-facing brand)
3. Every waybar layout change (public-facing UX)
4. `vinos-update` semantics for snapshot rollback (architecture-affecting)
5. Every `configs/vinos/kernel/config` flag flip (each is security-affecting — RATIONALE.md documents why)
6. Kernel signing key setup + storage (security-affecting, one-way)

## Ship gate
QA-1–7 + **QA-8 (local agent latency < 5s p50 at 16GB RAM baseline)**.

## Deliverables
- New `configs/vinos/default/etc/plymouth/themes/vinos/` (Plymouth theme)
- New `configs/vinos/default/etc/greetd/vinos-tuigreet-theme.toml`
- Modified `configs/vinos/default/etc/hypr/vinos-bindings.conf` → `.lua`
- New `configs/vinos/default/etc/nwg-drawer/` (drawer as ⌥+Space)
- New `configs/vinos/default/etc/firejail/vinos-browser.profile`
- New `configs/vinos/default/etc/firejail/vinos-ai.profile`
- New `bin/vinos-update` — snapshot-pinned upgrade wrapper
- Modified `configs/vinos/default/etc/xdg/waybar/config` (AI pill + routine ticker)
- New `configs/vinos/kernel/PKGBUILD` — linux-vinos package definition
- New `configs/vinos/kernel/config` — the .config file (all CONFIG_* flags)
- New `configs/vinos/kernel/patches/` — vinOS patches on top of upstream
- New `configs/vinos/kernel/RATIONALE.md` — per-flag justification
- New `configs/vinos/kernel/sign.sh` — signing helper
- New CI job `.github/workflows/kernel-build.yml` — rebuilds linux-vinos on any change to `configs/vinos/kernel/`
