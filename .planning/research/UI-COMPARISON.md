# UI Comparison — vinOS v1.3.0 vs top curated Hyprland setups

**Filed:** 2026-08-15 as R10 of Track R.
**Purpose:** Track R shipping gate. We do not ship v1.3.0 unless a fresh viewer
would rate vinOS visually equal to or better than the top 3 curated Hyprland
dotfile repos on the 10 axes below.

## Rivals

| Repo | Stars | What they ship |
|---|---:|---|
| **HyDE** (`prasanthrangan/hyprdots`) | ~7k | GTK theme installer + waybar + rofi + wallpapers + refined animations |
| **JaKooLit** (`JaKooLit/Arch-Hyprland`) | ~4k | Curated dotfiles, several theme flavours (Catppuccin/Nord/Rose-Pine), scripts |
| **end-4** (`end-4/dots-hyprland`) | ~10k | Ags/quickshell widget layer + heavy sidebar + fancy animations + material-you flavour |

## Axes (10)

Each rated on **0–3**: 0 = missing / bare, 1 = present but crude, 2 = solid, 3 = distinctive/refined.
Ship gate: **≥ 2** on every axis AND **≥ 22 / 30 total**.

| # | Axis | vinOS 1.3.0 | HyDE | JaKooLit | end-4 |
|---|---|---:|---:|---:|---:|
| 1 | **Focus rings / window borders** — visible on the currently focused window; multi-layer or animated on state change | 2 | 3 | 2 | 3 |
| 2 | **Module density** (waybar / top bar) — right ratio of info to whitespace, no dead space, no overflow | 2 | 2 | 2 | 3 |
| 3 | **Animation cadence** — window open/close, workspace switch, focus feels natural (not sluggish, not jittery) | 2 | 3 | 2 | 3 |
| 4 | **Palette consistency** — waybar / walker / GTK apps / wallpaper share the same colors, feels one product | 2 | 3 | 2 | 3 |
| 5 | **Tray sensibility** — icons don't clash with palette, right size, proper alignment | 2 | 2 | 2 | 2 |
| 6 | **Launcher aesthetic** — search chip, result rows, iconography, glass/blur, keyboard hints | 1 | 3 | 2 | 3 |
| 7 | **Wallpaper polish** — image quality, subject fits the palette, brand mark present but not intrusive | 3 | 3 | 2 | 2 |
| 8 | **Notification stack** — style matches the desktop, not default `mako` gray boxes | 1 | 3 | 2 | 3 |
| 9 | **Workspace overview** — visual switch (mission-control-style), quick tab-to-workspace preview | 1 | 3 | 1 | 3 |
| 10 | **Cursor smoothness** — modern cursor set, right size at HiDPI, animated where the theme provides it | 3 | 2 | 2 | 2 |
| — | **TOTAL** | **19** / 30 | 27 / 30 | 19 / 30 | 27 / 30 |

## Scoring notes (honest)

- **Axis 1 (2/3):** borders-plus-plus loads and shows the double gradient outline, hyprfocus animates focus. Missing: multi-layer per-state (urgent / warning) borders. Behind HyDE, level with JaKooLit.
- **Axis 2 (2/3):** waybar pill layout is clean, palette-consistent, no overflow at 1280 wide. Not distinctive though — same tokyo-night-esque bar you see everywhere.
- **Axis 3 (2/3):** hyprfocus + Hyprland's default bezier feel natural. Missing per-workspace transitions, no fancy floating-window-fly-in.
- **Axis 4 (2/3):** waybar + walker + drawer + hyprbars all use the same palette. GTK apps mostly follow. `libadwaita` apps (nautilus 50, gnome-calculator) don't fully respect `~/.config/gtk-4.0/gtk.css` — bg goes dark but accent colors default to Adwaita. This is the honest gap.
- **Axis 5 (2/3):** tray icons render via papirus, fine.
- **Axis 6 (1/3):** walker + drawer CSS is on-brand and clean — but **elephant provider system returns "No Results" for every query** (task #7). A launcher that can't search is a 1 no matter how the box looks.
- **Axis 7 (3/3):** aurora / nebula / frost photos are on-brand, watermark reads clean (drop-shadow bug fixed), 4K native, awww wave transitions cycle every 90 s. This is our distinctive win.
- **Axis 8 (1/3):** mako with default styling. No `swaync` or fancy notification centre. Notifications appear but visually stock. Backlog item.
- **Axis 9 (1/3):** `hyprexpo` not in official plugins repo, workspace overview not shipped. Config exists but plugin absent. Backlog.
- **Axis 10 (3/3):** Bibata-Modern-Ice is present, sized right (24 px), consistent everywhere. Distinct win.

## Verdict

**Total 19 / 30. Ship gate = 22 / 30 with ≥ 2 on every axis.**

- Fails the ≥ 2 axis floor on **6 (launcher search)**, **8 (notifications)**, **9 (workspace overview)**.
- Total 19 = tied with JaKooLit, 8 behind HyDE, 8 behind end-4.

**Do not tag v1.3.0 yet.** Ship as **v1.3.0-rc1** for user testing on real T2 hardware while three follow-ups are addressed:
- Task #7 — elephant provider system
- Task #8 — R1 first-boot plugin setup (hyprpm crash)
- New task — swaync notification centre + hyprexpo workspace overview

R7 (live wallpapers) and R10 (Bibata cursor) are the distinctive wins that already put us ahead of the field. R1/R6 hold their own. R2/R3/R4/R5 are table stakes and we ship them cleanly. The three failing axes are all "plugin ecosystem" items that are one hyprpm fix + one AUR bundle away from ≥ 2.

**Recommendation:** flash `iso/out/vinos-1.3.0-x86_64.iso` to USB, boot on the T2, verify install-to-disk still works, verify the transparent Plymouth splash + Bibata cursor + waybar polish + hyprbars (post first-boot hyprpm) render as expected on real hardware. Iterate to v1.3.0-rc2 with the three fixes, then tag v1.3.0.

## vinOS 1.3.0 evidence

Screenshots (fresh from a boot of `vinos-dev-1.3.0-x86_64.iso` on QEMU, no post-boot patching):

*Filled in after ISO rebuild + fresh-boot verification (R10 step 2).*

- `screenshots/1.3.0-desktop-focus.png` — focused foot window with hyprbars + borders-plus-plus
- `screenshots/1.3.0-desktop-two.png` — two tiled windows, hyprfocus shrink visible
- `screenshots/1.3.0-waybar-detail.png` — bar close-up: pills, palette, spacing
- `screenshots/1.3.0-walker.png` — walker open (search chip + first 3 results)
- `screenshots/1.3.0-drawer.png` — nwg-drawer full-screen app grid
- `screenshots/1.3.0-menu-display.png` — vinos-menu Display submenu
- `screenshots/1.3.0-wallpaper-cycle.png` — mid-transition (wave)
- `screenshots/1.3.0-notifications.png` — mako with vinos-menu triggered notify-send
- `screenshots/1.3.0-cursor.png` — Bibata cursor over a light UI element (contrast test)
- `screenshots/1.3.0-splash.png` — plymouth splash from cold boot (transparent V confirmed)

## Rival reference

Not shipped in-repo (public repos, screenshots on their READMEs / preview galleries).
Compared visually only — do not rehost their images.

- HyDE: <https://github.com/prasanthrangan/hyprdots#showcase>
- JaKooLit: <https://github.com/JaKooLit/Arch-Hyprland#preview>
- end-4: <https://github.com/end-4/dots-hyprland#screenshots>

## Scoring protocol

1. Boot the freshly-built `vinos-dev-1.3.0-x86_64.iso` on QEMU with the Track Q harness.
2. Capture the 10 screenshots above via `iso/qa/hmp.sh dump` — no live-patching, no manual post-boot fixup.
3. Compare side-by-side with the three rivals' showcases at similar UI moments (bar detail, launcher open, tiled windows, etc.).
4. Fill in vinOS column with 0–3 scores + honest note.
5. If any axis is **< 2** OR total is **< 22 / 30**, do not ship — file follow-up items into the Track R backlog (or a new v1.3.1) and re-run.
6. If gate passes, tag `v1.3.0` and archive the screenshots as ship evidence.

## Non-goals

- We do **not** copy any rival's palette, keybinding scheme, waybar module layout, or CSS. Score parity, don't imitate.
- We do **not** score subjective preferences (dark vs light, dense vs airy) — the axes are outcome-based (does the focus ring exist? does the launcher have proper iconography? etc.)
- We do **not** treat 30/30 as the goal. 22 is enough to ship; anything above is nice-to-have.

## Related

- `docs/BRANDING.md` — the palette and typography rules being enforced
- `docs/CONFIGURATION.md` — the config surface map (what each rival ships that we do too)
- `.planning/ROADMAP.md` v1.3.0 Track R — the source of R1–R10
