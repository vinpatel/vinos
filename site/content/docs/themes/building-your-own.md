---
title: "Building your own theme"
description: "Add a wallpaper, add a palette row, run build-themes.sh. About 15 minutes end-to-end if you already have the JPG."
weight: 30
---

Themes live in-tree at `configs/vinos/brand/themes/`. The build script
takes a source wallpaper and a one-row palette definition and
generates every artifact — the branded background, the unlock screen,
the preview thumbnails, the palette files for every consuming app.

## The three-step recipe

### 1. Add the source wallpaper

Drop your source image into `assets/wallpapers-hd/`. Requirements:

- **Format** — JPEG or PNG.
- **Resolution** — 3840×2160 minimum. Higher is fine; it'll be
  downsampled with high-quality resampling.
- **License** — must be freely redistributable. Unsplash License,
  Creative Commons, or your own work.

Naming: `<photographer-slug>-<unsplash-id>.jpg`. This lets the
attribution file stay consistent.

```
$ cp ~/Downloads/aurora-borealis-4k.jpg \
     assets/wallpapers-hd/marek-piwnicki-KX7CGmL9xwc.jpg
```

### 2. Add a palette row

Open `configs/vinos/brand/themes/build-themes.sh` and find the
`palettes()` heredoc. Add a row:

```bash
palettes() {
  cat <<'EOF'
# name       mode   base-palette          source-wallpaper                          accent    keyboard-rgb
circuit      dark   tokyonight            a-chosen-soul-D_ivYIn4jWw.jpg             #4EC1B8   #33CCFF
cosmos       dark   tokyonight            pascal-debrunner-HUYPJupBvwE.jpg          #4EC1B8   #7ECFB8
...
aurora       dark   nord                  marek-piwnicki-KX7CGmL9xwc.jpg            #4EC1B8   #7AF7C1
EOF
}
```

Field meanings:

- **name** — theme directory name. `[a-z-]+`.
- **mode** — `dark` or `light`. Determines lockscreen fg/bg and which
  vscode built-in theme gets pinned.
- **base-palette** — one of: `tokyonight`, `gruvbox-dark`, `nord`,
  `catppuccin-latte`, `everforest`, `everforest-light`. Determines the
  16-color base before the accent override.
- **source-wallpaper** — filename in `assets/wallpapers-hd/`.
- **accent** — hex. Almost always `#4EC1B8` (the vinOS override); use
  something different only if you have a strong reason.
- **keyboard-rgb** — hex. What color your laptop keyboard glows when
  this theme is active. Pick a color that reads well against the
  wallpaper mood.

### 3. Regenerate

```
$ bash configs/vinos/brand/themes/build-themes.sh
[build-themes] reading palettes table
[build-themes] found 11 themes (10 shipped + 1 new: aurora)
[build-themes] processing aurora:
  → downsampling wallpaper to 3840x2160
  → compositing branded overlay (5% mark, 55% opacity)
  → rendering unlock screen (1920x1080)
  → rendering preview thumbnails (600x338)
  → writing colors.toml (base=nord, accent=#4EC1B8)
  → writing shell.lock.toml
  → writing keyboard.rgb (#7AF7C1)
  → writing neovim.lua (tokyonight fallback)
  → writing vscode.json (Dark Modern)
[build-themes] done. 11 themes, 178 files.
```

## Requirements

The build script needs:

- **ImageMagick 7** — `magick` binary (not the old `convert`).
- **librsvg** — `rsvg-convert` for the vector mark composite.

Both ship in the default `vinos-install-common` bundle, so a booted
vinOS already has them.

## Try it locally

```
$ vinos-theme aurora
✓ switched to aurora
```

If you like it, PR the row addition to
[github.com/vinpatel/vinos](https://github.com/vinpatel/vinos). We'll
review, then ship in the next release. Please credit the photographer
in the PR description.

## Regen without adding

If you tweaked the palette table or the branded-overlay logic and want
every theme rebuilt:

```
$ bash configs/vinos/brand/themes/build-themes.sh
```

The script is idempotent — same inputs produce byte-identical outputs.
