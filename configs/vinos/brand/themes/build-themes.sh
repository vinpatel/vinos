#!/usr/bin/env bash
# build-themes.sh — regenerate every vinOS theme's schema files
# (colors.toml, shell.lock.toml, icons.theme, keyboard.rgb, neovim.lua,
# vscode.json) from the palette table below. Wallpapers and preview
# thumbnails must already exist under <theme>/backgrounds/<theme>.jpg.
#
# Design principle: vinOS teal (#4EC1B8) is the accent across ALL themes.
# Different primary hues, one brand signature. Beats the "unrelated colors"
# spread of Omarchy's 21 themes — vinOS's 10 read as one family.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

# Palette spec — each row: name, mode, bg, bg-dark, bg-darker, bg-light, fg, fg-dark, fg-bright,
#                          accent(teal always), selection, muted,
#                          red, yellow, orange, green, cyan, blue, magenta, brown,
#                          keyboard-rgb (hex without #)
# All designed hand — reflects the actual dominant character of each NASA wallpaper source.
palettes() {
cat <<'SPEC'
Void|dark|#08090C|#04050A|#010203|#141618|#E6ECEE|#8A9298|#FFFFFF|#4EC1B8|#1A2E33|#2A3236|#C46A6A|#D4A45E|#E08A5A|#7ABF6A|#4EC1B8|#89B4C4|#B48EAD|#5F4A3C|4EC1B8
Console|dark|#1A140F|#120E0A|#0A0806|#2A241E|#EFE8DE|#A99C88|#FFFDF6|#4EC1B8|#3A2E22|#4A3E32|#C46A5A|#D4A45E|#E8945A|#7AA96A|#4EC1B8|#89A0B4|#B48EAD|#8A6E52|D4A45E
Aurora|dark|#0A1220|#050A18|#020610|#141E30|#E8ECF4|#8A93A8|#FBFDFF|#4EC1B8|#1E2E48|#2E3E56|#E8845A|#E8B45A|#EC9868|#7ABFA6|#4EC1B8|#7AA0E8|#B48EDD|#5F5A72|F0A868
Mare|dark|#050506|#020203|#000000|#0D0D0F|#DEDEE0|#7A7A80|#FAFAFC|#4EC1B8|#1A1A1C|#2A2A2E|#C46A6A|#D4A45E|#E08A5A|#7ABF6A|#4EC1B8|#89B4C4|#B48EAD|#5F5A54|787880
Origin|dark|#08111C|#040A14|#02060E|#12213A|#E4EAF2|#8898B0|#FAFDFF|#4EC1B8|#1A3452|#2C4368|#C46A6A|#E8B060|#E89868|#7ABF6A|#4EC1B8|#5A9CE8|#B48EDD|#5F6A82|4EA8E8
Ochre|dark|#140A06|#0E0704|#080402|#241812|#F4E8DE|#B0937A|#FEFAF2|#4EC1B8|#4A2E1E|#5A3E28|#E8845A|#E8B060|#E89540|#8AB07A|#4EC1B8|#89A0B4|#B48EAD|#8A5A3E|E8945A
Canopy|dark|#0A140E|#050E08|#020604|#152218|#DFE9E2|#889888|#FAFEF6|#4EC1B8|#1A2E20|#2A3E30|#C4785A|#D4B45E|#E0985A|#8ABF6A|#4EC1B8|#89B4A4|#B4AE8D|#5F6A4A|6AAB6A
Flare|dark|#050C1A|#02060E|#010306|#0D1830|#E4EAF2|#8898B4|#FAFDFF|#4EC1B8|#1A2C4A|#2A3E5E|#E8845A|#E8B060|#E89568|#7ABF9A|#4EC1B8|#5AAAE8|#B48EDD|#5F5A82|5AAAF0
Glacier|light|#F0F4F6|#E4EAEC|#D8E0E4|#FAFCFD|#0F1518|#4A5460|#000000|#2AA198|#DDE4E8|#B0BDC4|#B85A5A|#B08A3A|#C87A3A|#5AA050|#2AA198|#4A85B8|#8A6EA0|#6A5A48|A0C4D8
Nebula|dark|#0F0814|#08050E|#040208|#1A1024|#EDE8F4|#A088B8|#FAFDFF|#4EC1B8|#2E1E48|#3E2E58|#E85A9E|#E8B060|#E85AAA|#7A8BE8|#4EC1B8|#7A5AE8|#B84EAE|#5A4A82|E85AAA
SPEC
}

write_theme() {
  local name=$1 mode=$2 bg=$3 bgd=$4 bgdd=$5 bgl=$6 fg=$7 fgd=$8 fgb=$9 \
        accent=${10} sel=${11} muted=${12} \
        red=${13} yellow=${14} orange=${15} green=${16} \
        cyan=${17} blue=${18} magenta=${19} brown=${20} \
        kbdrgb=${21}
  local dir="$HERE/$name"
  mkdir -p "$dir/backgrounds"

  cat > "$dir/colors.toml" <<EOF
# $name — vinOS theme
# Mode: $mode. vinOS teal ($accent) is the signature accent across the family.
mode = "$mode"

accent           = "$accent"
selection        = "$sel"
muted            = "$muted"

background        = "$bg"
dark_background   = "$bgd"
darker_background = "$bgdd"
lighter_background = "$bgl"

foreground        = "$fg"
dark_foreground   = "$fgd"
light_foreground  = "$fg"
bright_foreground = "$fgb"

red     = "$red"
yellow  = "$yellow"
orange  = "$orange"
green   = "$green"
cyan    = "$cyan"
blue    = "$blue"
magenta = "$magenta"
brown   = "$brown"

bright_red     = "$red"
bright_yellow  = "$yellow"
bright_green   = "$green"
bright_cyan    = "$accent"
bright_blue    = "$blue"
bright_magenta = "$magenta"
EOF

  cat > "$dir/shell.lock.toml" <<EOF
text             = "$fg"
placeholder      = "$fgd"
text-error       = "$red"
border           = "$accent"
border-active    = "$accent"
border-error     = "$red"
EOF

  cat > "$dir/icons.theme" <<EOF
Papirus-Dark
EOF

  cat > "$dir/keyboard.rgb" <<EOF
$kbdrgb
EOF

  cat > "$dir/neovim.lua" <<EOF
-- $name — vinOS Neovim colorscheme pin
-- Uses the tokyonight base as the closest maintained palette parent; v2.1
-- will ship a proper vinOS Neovim theme derived from this palette.
return {
  { "folke/tokyonight.nvim", priority = 1000 },
  { "LazyVim/LazyVim",
    opts = { colorscheme = "tokyonight-${mode/dark/night}${mode/light/day}" } },
}
EOF

  cat > "$dir/vscode.json" <<EOF
{
  "name": "vinOS $name",
  "extension": "enkia.tokyo-night"
}
EOF
}

palettes | while IFS='|' read -r name mode bg bgd bgdd bgl fg fgd fgb accent sel muted red yellow orange green cyan blue magenta brown kbdrgb; do
  [[ -z "$name" ]] && continue
  write_theme "$name" "$mode" "$bg" "$bgd" "$bgdd" "$bgl" "$fg" "$fgd" "$fgb" \
              "$accent" "$sel" "$muted" \
              "$red" "$yellow" "$orange" "$green" \
              "$cyan" "$blue" "$magenta" "$brown" \
              "$kbdrgb"
  echo "wrote $name"
done
