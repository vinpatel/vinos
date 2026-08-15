# vinOS Branding

The rules that keep every vinOS surface — ISO splash, desktop wallpaper, waybar,
walker theme, site, README — looking like the same product. Anything shipped
by a vinOS release must satisfy this doc. `iso/qa/branding-check.sh` enforces
the mechanical parts at build time; the rest is on you.

## Logo

**Source of truth:** `assets/logo/vinos.svg` — the V mark.
**Variants shipped:**

| File | Purpose |
|---|---|
| `assets/logo/vinos.svg` | primary — teal V on transparent |
| `assets/logo/vinos-light.svg` | light-mode variant (dark V) |
| `assets/logo/vinos-mono-white.svg` | single-color white, use on dark photos |
| `assets/logo/vinos-mono-dark.svg` | single-color dark, use on light photos |
| `assets/logo/vinos-animated.svg` | for site hero + landing pages, not OS surfaces |
| `assets/logo/png/vinos-{16,32,64,128,256,512}.png` | rasterized from `vinos.svg` |

### Alpha requirements

**All logo PNGs must be `PNG color-type=6 (RGBA)` with no `bKGD` chunk.** If
you regenerate them, the incantation is:

```bash
magick -background none -size 512x512 assets/logo/vinos.svg \
  -define png:exclude-chunk=bKGD -define png:color-type=6 \
  assets/logo/png/vinos-512.png
```

The `bKGD` chunk causes some renderers (Plymouth, some GTK widgets, iTerm2
image preview) to composite the logo over a solid rectangle — that's the
"white box behind the V" or "black box on splash" bug we hit in v1.2.5.
`iso/qa/branding-check.sh` will fail the build if `bKGD` is present.

### Sizing on OS surfaces

| Surface | Logo edge | Position | Notes |
|---|---|---|---|
| Desktop wallpaper watermark | 10 % of frame min edge (216 px on 4K) | bottom-right, 64 px inset | 55 % opacity + soft drop-shadow via `watermark.sh` |
| Waybar `V Menu` module | 13 px (text-scale) | far left | plain text glyph, not the PNG |
| Plymouth boot splash | 256 px on 800×600 | centered | frame-00 (caret on) / frame-01 (caret off) toggle |
| Syslinux boot splash | 400 px on 800×600 | centered | fallback for BIOS boot menu |
| walker launcher icon | 32 px | header | drawn via CSS mask |
| App menu / nwg-drawer entry | 128 px | tile icon | referenced by `.desktop` file |

## Colors

vinOS runs on a tokyo-night-derived palette. **Do not import upstream
palettes verbatim** — we authored these values, they are vinOS's colors.

| Role | Hex | Where used |
|---|---|---|
| Background base | `#1A1B26` | window bg, mako bg, walker bg |
| Background raised | `#24283B` | popups, tooltips, waybar module bg (with alpha) |
| Foreground primary | `#C0CAF5` | body text, waybar labels |
| Foreground muted | `#565F89` | secondary text, disabled states |
| Accent teal | `#7AA2F7` | V logo, links, focus rings, active workspace, plymouth caret |
| Accent purple | `#BB9AF7` | vinos-menu highlights, `#custom-ai` waybar module |
| Accent green | `#9ECE6A` | network up, battery ok |
| Accent yellow | `#E0AF68` | cpu warning, battery warning |
| Accent red | `#F7768E` | battery critical, disconnected |

Named references live in `themes/<theme>/theme.conf` under `[palette]`.
`iso/qa/branding-check.sh` diffs each theme's palette against this table
and warns on drift.

## Wallpapers

Everything under `assets/wallpapers/<theme>/wallpaper.png` must be:

1. **3840 × 2160**, PNG, RGBA (no bKGD)
2. **Watermarked** via `assets/wallpapers/watermark.sh` — never hand-composited
3. **Sourced** from Unsplash under the Unsplash License (attribution optional
   but tracked in `NOTICES.md`) OR original photography with a signed release

Raw source photos live under `assets/wallpapers/incoming/` (gitignored) so
future re-watermarking is one command:

```bash
assets/wallpapers/watermark.sh \
  assets/wallpapers/incoming/<photo>.jpg \
  assets/wallpapers/<theme>/wallpaper.png \
  <theme>
```

If you're adding a new theme, the wallpaper must ship watermarked in the
same commit as the `themes/<theme>/theme.conf` and `assets/wallpapers/<theme>/`
directory. `branding-check.sh` will fail if a theme.conf exists without a
matching watermarked wallpaper.

## Typography

- **UI (waybar, walker, mako):** `JetBrainsMono Nerd Font`, then `Symbols Nerd Font`, then `monospace`.
- **Body / site:** `Inter` (site only, not baked into OS surfaces).
- **Do not use** `Geist` in OS surfaces — it's not shipped with `pacman -Ss ttf-*` and depending on it silently fails to `monospace`.
- **Do not use** web-only CSS: `font-feature-settings`, `text-shadow`, `backdrop-filter`. GTK CSS is a subset — `iso/qa/branding-check.sh` scans style.css for these.

## Voice

- Product name is **vinOS** — one word, lowercase v, uppercase OS. Never "VinOS" or "vin OS" or "Vinos".
- Wordmark in prose uses the lowercase `v`, kept together: **vinOS**.
- User-facing surfaces say "vinOS" only. Heritage attribution (upstream Arch,
  archiso, etc.) lives in `NOTICES.md` and is compliance-only, not brand
  presence.

## Adding a new brand surface

Before you ship a PNG or SVG anywhere in the OS, verify:

- [ ] Sourced from `assets/logo/vinos.svg` or regenerated per this doc
- [ ] `PNG color-type=6`, no `bKGD` chunk
- [ ] Alpha channel actually transparent (corner pixel `alpha=0`, not opaque bg)
- [ ] Colors match the palette table above
- [ ] `iso/qa/branding-check.sh` passes on the modified file
- [ ] `docs/BRANDING.md` updated if you added a new surface type

## Related

- `assets/wallpapers/watermark.sh` — the reproducible watermark pipeline
- `iso/qa/branding-check.sh` — mechanical enforcement at build time
- `themes/<theme>/theme.conf` — palette reference values per theme
- `NOTICES.md` — third-party attribution (Unsplash, upstream Arch, fonts)
