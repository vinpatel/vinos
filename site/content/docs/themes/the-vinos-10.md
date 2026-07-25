---
title: "The vinOS 10"
description: "Six dark themes, four light. Every one anchored to a real photograph by a working photographer and a battle-tested community palette."
weight: 20
---

Ten themes, chosen for range and coherence rather than novelty. Every
photograph is used under the [Unsplash License](https://unsplash.com/license);
credits below because the photographers earned it. Full attribution
table also lives in the repo at
[`configs/vinos/brand/themes/ATTRIBUTION.md`](https://github.com/vinpatel/vinos/blob/main/configs/vinos/brand/themes/ATTRIBUTION.md).

Default first-boot theme: **cosmos**.

## Dark

| Theme | Wallpaper subject | Base palette | Photographer |
|---|---|---|---|
| **circuit** | Dark techy 3D blocks with cyan + orange edge lighting | tokyonight | A Chosen Soul |
| **egret** | Cattle egret portrait on black, dramatic side light | gruvbox-dark | David Clode |
| **reef** | Vivid green brain coral on black | nord | David Clode |
| **crater** | Fresh Martian impact crater, orange + steel-blue | everforest | NASA |
| **cosmos** | Milky Way over an alpine lake reflection | tokyonight | Pascal Debrunner |
| **dusk** | Distant snow range under sunset alpenglow | gruvbox-dark | Pascal Debrunner |

<figure class="doc-shot doc-shot-pending" id="shot-12">
  <div class="doc-shot-slot">Screenshot pending: full desktop with cosmos active</div>
  <figcaption>cosmos — see SCREENSHOTS_NEEDED.md #shot-12.</figcaption>
</figure>

<figure class="doc-shot doc-shot-pending" id="shot-14">
  <div class="doc-shot-slot">Screenshot pending: full desktop with circuit active</div>
  <figcaption>circuit — see SCREENSHOTS_NEEDED.md #shot-14.</figcaption>
</figure>

## Light

| Theme | Wallpaper subject | Base palette | Photographer |
|---|---|---|---|
| **prism** | Isometric pastel 3D blocks — rainbow architecture | catppuccin-latte | A Chosen Soul |
| **bloom** | Orange lilies on lime-green background | catppuccin-latte | Natalie Kinnear |
| **summit** | Ama Dablam at dawn, pastel Himalayan sky | everforest-light | Eugene Ga |
| **ridge** | Snowy range under pastel-pink sunset sky | catppuccin-latte | Marek Piwnicki |

<figure class="doc-shot doc-shot-pending" id="shot-13">
  <div class="doc-shot-slot">Screenshot pending: full desktop with summit active</div>
  <figcaption>summit — see SCREENSHOTS_NEEDED.md #shot-13.</figcaption>
</figure>

## What's the vinOS override?

Every one of the ten palettes has its accent overridden with
**#4EC1B8** — the same teal as the vinOS wordmark. This is the
family-signature bit: no matter which theme you're on, the "hey,
that's vinOS" recognition dot is the same.

## What ships in each theme dir

`configs/vinos/brand/themes/<name>/` contains:

- `colors.toml` — 16-color palette + accent/selection/muted overrides.
- `shell.lock.toml` — lockscreen text + border tints.
- `icons.theme` — Papirus-Dark (uniform across the family).
- `keyboard.rgb` — theme-specific single-hex keyboard RGB color.
- `neovim.lua` — tokyonight (or family-appropriate) colorscheme pin.
- `vscode.json` — pins the built-in VS Code Dark/Light Modern theme.
- `backgrounds/<name>.jpg` — 4K master (3840×2160 JPEG q=92).
- `backgrounds/<name>-branded.jpg` — same at 4K with vinOS mono logo
  composited at 5% width, bottom-right, 55% opacity.
- `unlock.png` — 1920×1080 solid theme-bg + centered color logo.
- `preview.png` / `preview-unlock.png` — 600×338 picker thumbnails.
- `wallpaper.png` — symlink → `backgrounds/<name>-branded.jpg`.

## Photographer profiles

| Photographer | Profile |
|---|---|
| A Chosen Soul (Bulut Selek) | [unsplash.com/@a_chosensoul](https://unsplash.com/@a_chosensoul) |
| David Clode | [unsplash.com/@davidclode](https://unsplash.com/@davidclode) |
| Pascal Debrunner | [unsplash.com/@debrupas](https://unsplash.com/@debrupas) |
| Eugene Ga | [unsplash.com/@eugene_ga](https://unsplash.com/@eugene_ga) |
| Marek Piwnicki | [unsplash.com/@marekpiwnicki](https://unsplash.com/@marekpiwnicki) |
| Natalie Kinnear | [unsplash.com/@nataliekinnear](https://unsplash.com/@nataliekinnear) |
| NASA (Unsplash) | [unsplash.com/@nasa](https://unsplash.com/@nasa) |

Next: [build your own theme](/docs/themes/building-your-own/).
