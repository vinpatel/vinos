# vinOS themes — attribution & license

10 themes, each built around a **NASA Public Domain image**. Every wallpaper
sources from NASA's image gallery (`images.nasa.gov`), which is Public Domain
under US federal law (17 USC §105). No third-party licensing constraints.

vinOS overlay (colors, schema, watermark composition) is licensed under MIT.

| Theme | Wallpaper source | NASA ID |
|---|---|---|
| **Void** | Hubble Deep Field — galaxies from the beginning of time | `PIA12110` (upgraded from `GSFC_20171208_Archive_e001651` XDF) |
| **Console** | Apollo 7 Mission Control Center, first day of mission | `S68-49301` |
| **Aurora** | Earth Observation from ISS — atmospheric limb | `iss040e080833` |
| **Mare** | Apollo 8 oblique lunar surface view | `as08-17-2821` |
| **Origin** | Blue Marble 2007, West hemisphere | `GSFC_20171208_Archive_e002131` |
| **Ochre** | Perseverance and Mars 2020 Spacecraft Components on the Surface | `PIA24333` |
| **Canopy** | Rainforest satellite imagery (Amazon basin) | `PIA24378` (upgraded from `PIA11420` Mato Grosso) |
| **Flare** | Solar prominences (SDO archive) | `GSFC_20171208_Archive_e001466` |
| **Glacier** | Spawning of Massive Antarctic Iceberg (Larsen C) | `PIA21785` |
| **Nebula** | Four Famous Nebulae composite | `PIA24577` |

Each theme includes:

- `colors.toml` — hand-designed palette; vinOS teal `#4EC1B8` as through-line
  accent across all 10, individual primary hues per theme
- `shell.lock.toml` — lockscreen text/border tints
- `icons.theme` — Papirus-Dark as icon set base
- `keyboard.rgb` — theme-specific keyboard RGB color
- `neovim.lua` — pins tokyonight base (proper vinOS Neovim theme is v2.1 track)
- `vscode.json` — VSCode theme pin
- `wallpaper.png` — theme-root convention wallpaper (from branded jpg)
- `backgrounds/<Name>.jpg` — original 4K crop, unwatermarked
- `backgrounds/<Name>-branded.jpg` — watermarked variant with vinOS mono logo
  (5% width, bottom-right corner, luminance-adaptive light/dark logo pick)
- `unlock.png` — solid dark bg + centered vinOS color logo for greeter
- `preview.png` / `preview-unlock.png` — 600×338 for theme picker

## Regenerating

Palettes: `bash configs/vinos/brand/themes/build-themes.sh`  
Wallpapers: re-download source jpgs from `nasa-final.tsv`, run watermark pipeline in the same script.
