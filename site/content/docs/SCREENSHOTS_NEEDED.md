---
title: "Screenshots needed"
description: "Master list of every desktop screenshot the docs pages reference. Take on booted v2.0.5 at 2560×1600, drop into site/static/img/screenshots/."
url: "/docs/screenshots-needed/"
sitemap:
  disable: true
---

# Screenshots needed for /docs/

Every placeholder in the docs section refers back to a numbered entry
here. Take each capture on a booted **v2.0.5 vinOS** at **2560×1600**
(or any 16:10) with the **cosmos** theme active unless a specific
theme is requested. Drop PNGs into
`site/static/img/screenshots/` with the exact filename the entry
suggests. A follow-up pass swaps the `.doc-shot-pending` placeholders
for real `<img>` tags.

## Boot / first-run

- [ ] **shot-01** · `boot-plymouth.png` — Plymouth splash mid-boot, brand caret visible.
- [ ] **shot-02** · `first-boot-tty.png` — First-login greeter, `vinos-welcome` box drawing rendered in foot.
- [ ] **shot-03** · `welcome-dmenu.png` — `vinos-welcome` walker-dmenu picker open, top item selected.

## Menu + theme picker

- [ ] **shot-10** · `menu-root.png` — `vinos-menu` open, Install submenu visible.
- [ ] **shot-11** · `theme-picker.png` — `vinos-theme --pick` walker overlay, ten themes listed with preview thumbnails.
- [ ] **shot-12** · `theme-cosmos.png` — Full desktop with the cosmos theme active (Milky Way wallpaper, waybar, walker peek).
- [ ] **shot-13** · `theme-summit.png` — Full desktop with the summit theme active (Ama Dablam at dawn, light mode).
- [ ] **shot-14** · `theme-circuit.png` — Full desktop with the circuit theme active (dark techy 3D blocks).

## Routines UI

- [ ] **shot-20** · `vinos-brief-panel.png` — `vinos-brief` walker panel showing today's day-brief output.
- [ ] **shot-21** · `waybar-routine-widget.png` — Waybar corner with the routine status widget expanded.
- [ ] **shot-22** · `routine-notification.png` — Mako toast on routine completion (bottom-right corner).

## Waybar + walker + keybindings

- [ ] **shot-30** · `waybar-full.png` — Top bar full width, all modules populated.
- [ ] **shot-31** · `walker-launcher.png` — Walker launcher open with a partial query typed.
- [ ] **shot-32** · `cheatsheet-overlay.png` — `Super+K` cheatsheet overlay showing keybindings grouped by section.

## Utilities in action

- [ ] **shot-40** · `vinos-focus-active.png` — Waybar showing focus countdown mid-session.
- [ ] **shot-41** · `vinos-commit-tui.png` — `vinos-commit` interactive prompt in a foot terminal, draft visible with Edit/Accept/Retry/Quit chooser below.
- [ ] **shot-42** · `vinos-standup-out.png` — Foot terminal after `vinos-standup` — the 4-bullet output visible.
- [ ] **shot-43** · `vinos-ai-chat.png` — `vinos-ai chat` interactive session in a foot terminal (2-3 turns visible).

## Hardware / T2

- [ ] **shot-50** · `t2-mbp-boot.png` — Physical shot: T2 MacBook Pro mid-boot with the vinOS Plymouth splash on screen. (Phone photo, 3:2 ok.)
- [ ] **shot-51** · `t2-wifi-connected.png` — Waybar network module showing a connected SSID, iwd routing active.

## Troubleshooting doc

- [ ] **shot-60** · `doctor-passing.png` — `vinos-doctor` output with all PASS on a real vinOS install.
- [ ] **shot-61** · `docker-lazydocker.png` — `lazydocker` TUI open, showing running containers.
