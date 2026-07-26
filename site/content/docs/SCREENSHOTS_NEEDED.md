---
title: "Screenshots needed"
description: "Master list of every desktop screenshot the docs pages reference. Take on booted v2.0.5 at 2560×1600 (or 1280×800 fallback), drop into site/static/img/screenshots/."
url: "/docs/screenshots-needed/"
sitemap:
  disable: true
---

# Screenshots needed for /docs/

Every placeholder in the docs section refers back to a numbered entry
here. Take each capture on a booted **v2.0.5 vinOS** at **2560×1600**
(or 1280×800 fallback — the QEMU pipeline picks whichever the guest
framebuffer supports) with the **cosmos** theme active unless a
specific theme is requested. Drop PNGs into
`site/static/img/screenshots/` with the exact filename the entry
suggests. A follow-up pass swaps the `.doc-shot-pending` placeholders
for real `<img>` tags.

## Boot / first-run

- [ ] **shot-01** · `boot-plymouth.png` — Plymouth splash mid-boot, brand caret visible.
- [x] **shot-02** · `first-boot-tty.png` — First-login greeter, `vinos-welcome` box drawing rendered in foot.
- [x] **shot-03** · `welcome-dmenu.png` — `vinos-welcome` walker-dmenu picker open, top item selected.
- [ ] **shot-04** · `boot-syslinux-menu.png` — syslinux boot menu with "vinOS live" highlighted (pre-Hyprland; captured via QEMU HMP screendump ~4s into boot).
- [ ] **shot-05** · `login-greeter.png` — greetd/tuigreet on the TTY before autologin fires.
- [ ] **shot-06** · `first-desktop.png` — clean cosmos desktop after autologin, no menu, no toast.
- [ ] **shot-07** · `welcome-checklist.png` — vinos-welcome checklist walker view.

## Menu + theme picker

- [x] **shot-10** · `menu-root.png` — `vinos-menu` open, Install submenu visible.
- [x] **shot-11** · `theme-picker.png` — `vinos-theme --pick` walker overlay, ten themes listed with preview thumbnails.
- [x] **shot-12** · `theme-cosmos.png` — Full desktop with the cosmos theme active (Milky Way wallpaper, waybar, walker peek). Captured 2026-07-26 via QEMU pipeline.
- [x] **shot-13** · `theme-summit.png` — Full desktop with the summit theme active (Ama Dablam at dawn, light mode).
- [x] **shot-14** · `theme-circuit.png` — Full desktop with the circuit theme active (dark techy 3D blocks).
- [ ] **shot-15** · `menu-style.png` — vinos-menu open at Style submenu.
- [ ] **shot-16** · `menu-install.png` — vinos-menu at Install bundles submenu (ai, dev, comms, browser).
- [ ] **shot-17** · `menu-trigger.png` — vinos-menu at Trigger submenu.

### Clean overlay-free theme swap (v2 of shot-12/13/14, dismisses cheatsheet properly)

- [ ] **shot-12b** · `theme-cosmos-clean.png` — cosmos desktop, no overlays.
- [ ] **shot-13b** · `theme-summit-clean.png` — summit desktop, no overlays (light mode showcase).
- [ ] **shot-14b** · `theme-circuit-clean.png` — circuit desktop, no overlays (dark showcase).

## Routines UI

- [x] **shot-20** · `vinos-brief-panel.png` — `vinos-brief` walker panel showing today's day-brief output.
- [ ] **shot-21** · `waybar-routine-widget.png` — Waybar corner with the routine status widget expanded. (v2.0.6+)
- [ ] **shot-22** · `routine-notification.png` — Mako toast on routine completion (bottom-right corner). (needs API key + real routine run)
- [ ] **shot-23** · `routine-list.png` — foot terminal after `vinos-routine list` — two shipped starters + status.
- [ ] **shot-24** · `routine-run.png` — foot terminal during `vinos-routine run day-brief` (or clear failure path if no API key).
- [ ] **shot-25** · `routine-cost.png` — foot terminal after `vinos-routine cost` — sqlite ledger dump.
- [ ] **shot-26** · `brief-panel.png` — `vinos-brief` output shown in foot (markdown rendered).

## Waybar + walker + keybindings

- [x] **shot-30** · `waybar-full.png` — Top bar full width, all modules populated.
- [x] **shot-31** · `walker-launcher.png` — Walker launcher open with a partial query typed.
- [x] **shot-32** · `cheatsheet-overlay.png` — `Super+K` cheatsheet overlay showing keybindings grouped by section.
- [ ] **shot-33** · `waybar-close-up.png` — top-right of waybar zoomed showing routine-status widget slot (may be empty in v2.0.5; that's OK, doc the placeholder area).
- [ ] **shot-34** · `terminal-vinos-fix.png` — foot terminal showing `false 2>&1 | vinos-fix` output (or similar failed-command pipe).
- [ ] **shot-35** · `terminal-vinos-standup.png` — foot terminal after `vinos-standup --yesterday` (may fail with "no code dir" — that's OK, doc the error path).

## Utilities in action

- [x] **shot-40** · `vinos-focus-active.png` — Waybar showing focus countdown mid-session.
- [x] **shot-41** · `vinos-commit-tui.png` — `vinos-commit` interactive prompt in a foot terminal, draft visible with Edit/Accept/Retry/Quit chooser below.
- [x] **shot-42** · `vinos-standup-out.png` — Foot terminal after `vinos-standup` — the 4-bullet output visible.
- [x] **shot-43** · `vinos-ai-chat.png` — `vinos-ai chat` interactive session in a foot terminal (2-3 turns visible).

## Hardware / T2

- [ ] **shot-50** · `t2-mbp-boot.png` — Physical shot: T2 MacBook Pro mid-boot with the vinOS Plymouth splash on screen. (Phone photo, 3:2 ok.)
- [x] **shot-51** · `t2-wifi-connected.png` — Waybar network module showing a connected SSID, iwd routing active.

## Troubleshooting doc

- [x] **shot-60** · `doctor-passing.png` — `vinos-doctor` output with all PASS on a real vinOS install.
- [x] **shot-61** · `docker-lazydocker.png` — `lazydocker` TUI open, showing running containers.

## CLI --help renders

Rendered host-side via ImageMagick from the actual `bin/vinos-*
--help` output (JetBrains Mono / near-black bg / fg-1). No QEMU boot
needed for these.

- [ ] **shot-70** · `vinos-routine-help.png`
- [ ] **shot-71** · `vinos-brief-help.png`
- [ ] **shot-72** · `vinos-standup-help.png`
- [ ] **shot-73** · `vinos-commit-help.png`
- [ ] **shot-74** · `vinos-focus-help.png`
- [ ] **shot-75** · `vinos-fix-help.png`
- [ ] **shot-76** · `vinos-explain-help.png`
- [ ] **shot-77** · `vinos-ai-help.png`
- [ ] **shot-78** · `vinos-doctor-help.png`
- [ ] **shot-79** · `vinos-theme-set-help.png` — v2.0.6 wrapper — passthrough to `Usage: omarchy-theme-set <theme>`.
