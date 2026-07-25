#!/usr/bin/env bash
# build-themes.sh — generate all vinOS themes from assets/wallpapers-hd/.
# Produces per-theme full Omarchy-schema dirs:
#   colors.toml, shell.lock.toml, icons.theme, keyboard.rgb,
#   neovim.lua, vscode.json, backgrounds/<name>.jpg (4K master crop),
#   backgrounds/<name>-branded.jpg (vinOS-logo composite),
#   unlock.png (solid bg + centered logo), preview.png / preview-unlock.png,
#   wallpaper.png (symlink → backgrounds/<name>-branded.jpg)
#
# Palette design: each theme layers a battle-tested community palette
# (tokyonight, gruvbox, nord, catppuccin-latte, everforest, …) with vinOS
# teal #4EC1B8 as the family-signature accent. Best of both — proven color
# science + brand cohesion.
#
# Requires: ImageMagick 7 (`magick`), rsvg-convert (from librsvg).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
SRC_DIR="$REPO/assets/wallpapers-hd"
LOGO_WHITE="$REPO/assets/logo/vinos-mono-white.svg"
LOGO_DARK="$REPO/assets/logo/vinos-mono-dark.svg"
LOGO_COLOR_PNG="$REPO/assets/logo/png/vinos-512.png"

command -v magick >/dev/null 2>&1 || { echo "magick (ImageMagick 7) required"; exit 1; }
command -v rsvg-convert >/dev/null 2>&1 || { echo "rsvg-convert required (librsvg)"; exit 1; }
[[ -f "$LOGO_WHITE" && -f "$LOGO_DARK" ]] || { echo "vinos mono logo SVGs missing"; exit 1; }

# name|source_stem|mode|logo(white|dark)|bg|bg_dark|bg_darker|bg_light|fg|fg_dark|fg_bright|accent|selection|muted|red|yellow|orange|green|cyan|blue|magenta|brown|kbd_rgb
palettes() { cat <<'SPEC'
circuit|a-chosen-soul-D_ivYIn4jWw|dark|white|0a0e14|05070a|020304|141a24|cbd5e8|7a869c|ffffff|4EC1B8|24344d|414868|f7768e|e0af68|ff9e64|9ece6a|7dcfff|7aa2f7|bb9af7|cfad6e|4EC1B8
egret|david-clode-pWDUJYt0faU|dark|white|0a0a0c|050506|020203|16161a|efefe8|8a8a80|ffffff|4EC1B8|1e1e22|2a2a2f|d47070|e0b060|e89060|78ba6a|4EC1B8|8ab0c8|b48ea8|8f6a5a|E0B060
reef|david-clode-xISv9EMQ1BY|dark|white|0a1410|050c08|020604|14221c|ebdbb2|928374|fbf1c7|4EC1B8|1a2e20|2a3e30|fb4934|fabd2f|fe8019|b8bb26|4EC1B8|83a598|d3869b|d65d0e|8ABF6A
crater|nasa-E7q00J_8N7A|dark|white|180c06|0e0704|060302|241812|f0dfd0|b0937a|fffaef|4EC1B8|4a2818|5a3820|dc6a4a|e8b060|f08050|8ab07a|4EC1B8|7a94a8|b48eaa|a06848|F08050
cosmos|pascal-debrunner-HUYPJupBvwE|dark|white|0e1220|060a14|02040a|1a1e30|d8dee9|7a86a0|eceff4|4EC1B8|2e344c|4c566a|bf616a|ebcb8b|d08770|a3be8c|4EC1B8|81a1c1|b48ead|8f6a5a|B48EAD
dusk|pascal-debrunner-V7EgUtCnvLY|dark|white|0c0e14|070810|03040a|16181f|d0d4dc|6a7380|f8fafc|4EC1B8|202430|2c3040|d97757|e0a468|e28860|7fa878|4EC1B8|7a90b0|a884a0|8f705a|E28860
prism|a-chosen-soul-Aj18oWR97sE|light|dark|f5f2ee|e8e4dc|d8d2c8|fdfbf7|1a1918|6a6560|000000|2AA198|dcd2c2|beb4a4|d7566a|d4a45e|dc7a2c|64a852|2AA198|4a80c8|a860a8|8a5c48|A860A8
bloom|natalie-kinnear-a39dZ_gddHA|light|dark|f0ede0|e4dfd0|d4cebe|faf6ea|3b3a24|6a6a58|1a1a10|2AA198|d8d0b8|b4ac94|c85450|d4a020|eb7d3c|6b9c3f|2AA198|4d84c8|a06090|8c6a3a|EB7D3C
summit|eugene-ga-infssQ2tjeM|light|dark|eff1f5|e6e9ef|d8dde4|f9fafd|4c4f69|7c7f93|1e1e2e|179299|d8dbe4|acb0be|d20f39|df8e1d|fe640b|40a02b|179299|1e66f5|ea76cb|8c6a3a|179299
ridge|marek-piwnicki-dlEUrYSnOOc|light|dark|f5eeef|ede4e6|dcd0d3|fbf6f7|5c4e50|8a7c7e|2a2224|4EC1B8|e0d2d4|c6b4b6|d2668d|d4a45e|e88474|7aab7a|4EC1B8|7a90c0|b884b0|8f6a5a|D2668D
SPEC
}

nvim_pin() {
  case "$1" in
    circuit|egret|dusk) echo "tokyonight-night" ;;
    reef|crater)         echo "tokyonight-storm" ;;
    cosmos)              echo "tokyonight-moon" ;;
    prism|bloom|summit|ridge) echo "tokyonight-day" ;;
    *) echo "tokyonight-storm" ;;
  esac
}

vscode_pin() {
  case "$1" in
    prism|bloom|summit|ridge) echo "Default Light Modern" ;;
    *)                        echo "Default Dark Modern" ;;
  esac
}

# Watermark: composite the vinOS mono logo at 5% width, bottom-right,
# ~55% opacity so it reads as a signature, not a stamp.
watermark_wallpaper() {
  local src="$1" dst="$2" logo_variant="$3"
  local logo_svg
  [[ "$logo_variant" == "dark" ]] && logo_svg="$LOGO_DARK" || logo_svg="$LOGO_WHITE"

  local w; w=$(magick identify -format '%w' "$src")
  local lw=$(( w * 5 / 100 )); [[ "$lw" -lt 80 ]] && lw=80

  local tmp_logo; tmp_logo="$(mktemp --suffix=.png)"
  rsvg-convert -w "$lw" "$logo_svg" -o "$tmp_logo"

  magick "$src" \
    \( "$tmp_logo" -alpha set -channel A -evaluate multiply 0.55 +channel \) \
    -gravity SouthEast -geometry +48+48 -composite \
    -strip -quality 90 "$dst"
  rm -f "$tmp_logo"
}

# Normalize source → 4K JPEG (3840x2160), center-crop to preserve subject.
prepare_master() {
  magick "$1" -resize '3840x2160^' -gravity center -extent '3840x2160' \
              -colorspace sRGB -strip -quality 92 "$2"
}

# 600x338 (16:9) thumbnail for the picker.
make_thumb() {
  magick "$1" -resize '600x338^' -gravity center -extent '600x338' \
              -strip -quality 85 "$2"
}

# Solid-bg unlock — bg-color rectangle with centered color logo.
build_unlock() {
  local bg_hex="$1" dst="$2"
  local tmp_logo; tmp_logo="$(mktemp --suffix=.png)"
  magick "$LOGO_COLOR_PNG" -resize 360x "$tmp_logo"
  magick -size 1920x1080 "xc:#$bg_hex" \
    "$tmp_logo" -gravity center -composite -strip -quality 90 "$dst"
  rm -f "$tmp_logo"
}

write_theme() {
  local name=$1 src_stem=$2 mode=$3 logo_var=$4 \
        bg=$5 bg_dark=$6 bg_darker=$7 bg_light=$8 \
        fg=$9 fg_dark=${10} fg_bright=${11} \
        accent=${12} selection=${13} muted=${14} \
        red=${15} yellow=${16} orange=${17} green=${18} \
        cyan=${19} blue=${20} magenta=${21} brown=${22} \
        kbd_rgb=${23}

  local dir="$HERE/$name"
  echo "→ building $name (source stem: $src_stem, mode: $mode)"
  mkdir -p "$dir/backgrounds"

  local src
  src=$(find "$SRC_DIR" -maxdepth 1 -type f \( -iname "${src_stem}*.jpg" -o -iname "${src_stem}*.png" \) 2>/dev/null | head -1)
  [[ -n "$src" && -f "$src" ]] || { echo "  ! source wallpaper not found for '$src_stem'"; return 1; }

  local master="$dir/backgrounds/${name}.jpg"
  local branded="$dir/backgrounds/${name}-branded.jpg"
  prepare_master "$src" "$master"
  watermark_wallpaper "$master" "$branded" "$logo_var"
  ln -sfn "backgrounds/${name}-branded.jpg" "$dir/wallpaper.png"

  local title="$(printf '%s' "${name^}")"
  cat > "$dir/colors.toml" <<EOF
# ${title} — vinOS theme
# Wallpaper source: assets/wallpapers-hd/$(basename "$src")
# Mode: ${mode}. vinOS teal (#4EC1B8) is the family-signature accent.
mode = "${mode}"

accent           = "#${accent}"
selection        = "#${selection}"
muted            = "#${muted}"

background         = "#${bg}"
dark_background    = "#${bg_dark}"
darker_background  = "#${bg_darker}"
lighter_background = "#${bg_light}"

foreground         = "#${fg}"
dark_foreground    = "#${fg_dark}"
light_foreground   = "#${fg}"
bright_foreground  = "#${fg_bright}"

red     = "#${red}"
yellow  = "#${yellow}"
orange  = "#${orange}"
green   = "#${green}"
cyan    = "#${cyan}"
blue    = "#${blue}"
magenta = "#${magenta}"
brown   = "#${brown}"

bright_red     = "#${red}"
bright_yellow  = "#${yellow}"
bright_green   = "#${green}"
bright_cyan    = "#${cyan}"
bright_blue    = "#${blue}"
bright_magenta = "#${magenta}"
EOF

  cat > "$dir/shell.lock.toml" <<EOF
[lock]
text_color   = "#${fg_bright}"
border_color = "#${accent}"
EOF

  echo "Papirus-Dark" > "$dir/icons.theme"
  echo "${kbd_rgb}"    > "$dir/keyboard.rgb"

  local nvim_scheme; nvim_scheme=$(nvim_pin "$name")
  local nvim_style="${nvim_scheme#tokyonight-}"
  cat > "$dir/neovim.lua" <<EOF
-- ${title} — vinOS Neovim colorscheme pin
-- Uses tokyonight (LazyVim default). Users can swap in their nvim config.
return {
  { "folke/tokyonight.nvim", opts = { style = "${nvim_style}" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "${nvim_scheme}" } },
}
EOF

  cat > "$dir/vscode.json" <<EOF
{
  "name": "vinOS ${title}",
  "workbench.colorTheme": "$(vscode_pin "$name")"
}
EOF

  build_unlock "$bg" "$dir/unlock.png"
  make_thumb "$branded"      "$dir/preview.png"
  make_thumb "$dir/unlock.png" "$dir/preview-unlock.png"

  echo "  ✓ $name"
}

palettes | while IFS='|' read -r name src_stem mode logo_var \
  bg bg_dark bg_darker bg_light fg fg_dark fg_bright \
  accent selection muted red yellow orange green cyan blue magenta brown kbd_rgb; do
  [[ -z "$name" ]] && continue
  write_theme "$name" "$src_stem" "$mode" "$logo_var" \
              "$bg" "$bg_dark" "$bg_darker" "$bg_light" \
              "$fg" "$fg_dark" "$fg_bright" \
              "$accent" "$selection" "$muted" \
              "$red" "$yellow" "$orange" "$green" \
              "$cyan" "$blue" "$magenta" "$brown" \
              "$kbd_rgb"
done

echo ""
echo "done — $(find "$HERE" -maxdepth 1 -type d ! -path "$HERE" | wc -l) theme dirs"
