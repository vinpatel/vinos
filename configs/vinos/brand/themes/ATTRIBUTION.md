# vinOS themes — attribution & license

10 themes, each built around a wallpaper from a working photographer on
[Unsplash](https://unsplash.com/). All source images are used under the
[Unsplash License](https://unsplash.com/license), which grants a
worldwide, irrevocable, non-exclusive, royalty-free license to use,
copy, modify, distribute, and use for commercial purposes — attribution
appreciated but not legally required. We attribute anyway because the
photographers earned it.

## Photographers

| Photographer | Profile |
|---|---|
| A Chosen Soul (Bulut Selek) | https://unsplash.com/@a_chosensoul |
| David Clode | https://unsplash.com/@davidclode |
| Pascal Debrunner | https://unsplash.com/@debrupas |
| Eugene Ga | https://unsplash.com/@eugene_ga |
| Marek Piwnicki | https://unsplash.com/@marekpiwnicki |
| Natalie Kinnear | https://unsplash.com/@nataliekinnear |
| NASA (Unsplash) | https://unsplash.com/@nasa |

## Theme → wallpaper mapping

| Theme | Mode | Wallpaper subject | Source | Photographer |
|---|---|---|---|---|
| **circuit** | dark | Dark techy 3D blocks, cyan + orange edge lighting | `a-chosen-soul-D_ivYIn4jWw` | A Chosen Soul |
| **egret** | dark | Cattle egret portrait on black, dramatic side light | `david-clode-pWDUJYt0faU` | David Clode |
| **reef** | dark | Vivid green brain coral on black | `david-clode-xISv9EMQ1BY` | David Clode |
| **crater** | dark | Fresh Martian impact crater, orange + steel-blue | `nasa-E7q00J_8N7A` | NASA |
| **cosmos** | dark | Milky Way over an alpine lake reflection | `pascal-debrunner-HUYPJupBvwE` | Pascal Debrunner |
| **dusk** | dark | Distant snow range under sunset alpenglow | `pascal-debrunner-V7EgUtCnvLY` | Pascal Debrunner |
| **prism** | light | Isometric pastel 3D blocks — rainbow architecture | `a-chosen-soul-Aj18oWR97sE` | A Chosen Soul |
| **bloom** | light | Orange lilies on lime-green background | `natalie-kinnear-a39dZ_gddHA` | Natalie Kinnear |
| **summit** | light | Ama Dablam at dawn, pastel Himalayan sky | `eugene-ga-infssQ2tjeM` | Eugene Ga |
| **ridge** | light | Snowy range under pastel-pink sunset sky | `marek-piwnicki-dlEUrYSnOOc` | Marek Piwnicki |

Default first-boot theme: **cosmos**.

## What ships per theme

Each `configs/vinos/brand/themes/<name>/` directory contains a full
Omarchy-schema theme:

- `colors.toml` — 16-color palette + accent/selection/muted; each theme
  layers a battle-tested community scheme (tokyonight, gruvbox, nord,
  catppuccin-latte, everforest) with vinOS teal **#4EC1B8** as the
  family-signature accent override
- `shell.lock.toml` — lockscreen text + border tints
- `icons.theme` — Papirus-Dark (uniform across the family)
- `keyboard.rgb` — theme-specific single-hex keyboard RGB color
- `neovim.lua` — tokyonight colorscheme pin (works with LazyVim's
  default install; users can swap)
- `vscode.json` — pins the built-in VS Code Dark/Light Modern theme
- `backgrounds/<name>.jpg` — 4K master (unwatermarked, 3840×2160 JPEG q=92)
- `backgrounds/<name>-branded.jpg` — same at 4K with vinOS mono logo
  composited at 5% width, bottom-right, 55% opacity
- `unlock.png` — 1920×1080 solid theme-bg + centered color logo
- `preview.png` / `preview-unlock.png` — 600×338 picker thumbnails
- `wallpaper.png` — symlink → `backgrounds/<name>-branded.jpg`

## Regenerating

```bash
bash configs/vinos/brand/themes/build-themes.sh
```

Reads the palette table + source wallpapers under
`assets/wallpapers-hd/`, rewrites every theme dir. Requires ImageMagick 7
(`magick`) and `rsvg-convert` (librsvg).

## Adding a new theme

1. Drop a new source wallpaper into `assets/wallpapers-hd/`
2. Append a row to the `palettes()` heredoc in `build-themes.sh`, in the
   documented format
3. Re-run `build-themes.sh` — the new theme dir gets scaffolded end-to-end

## vinOS overlay licensing

Everything under `configs/vinos/brand/themes/` (palettes, watermark
compositions, generated schema files) is licensed under MIT.
