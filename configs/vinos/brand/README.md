# vinOS brand overlay

vinOS visual identity — 100% original work, no third-party aesthetic
borrowing. Fonts are open-licensed only (SIL OFL / Apache).

## Assets

- `wallpaper/vinos-default.svg` — original vinOS wallpaper (generated, not commissioned yet)
- `palette.toml` — vinOS palette (extends existing brand: teal + cool-charcoal)
- `fonts.list` — open-source fonts installed by default (SIL OFL / Apache only)
- `plymouth/vinos/` — boot splash theme
- `sddm/vinos/` — display manager theme (branded)

## Palette

Matches the site's post-2026-07-19 brand pass:
- Primary: `#2AA198` (teal, from vinOS logo)
- Ink: `#1E2A2E` (cool-charcoal)
- Accent: `#89B4C4` (softer teal)
- Background: `#FAFAF7` (warm off-white)
- Dark background: `#0F1518` (near-black)

## Fonts

All shipped fonts are SIL OFL 1.1 or Apache 2.0:
- **JetBrains Mono** (OFL) — monospace / terminal / code
- **Inter** (OFL) — UI sans-serif
- **IBM Plex Sans** (OFL) — alternative UI pairing
- **Fira Code** (OFL) — programmer's fallback

## Rule

No file in this overlay may reference a third-party project's aesthetic
by name in comments, filenames, or docstrings. Original vinOS only.
