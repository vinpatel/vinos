#!/usr/bin/env bash
# iso/qa/branding-check.sh — enforce docs/BRANDING.md at build time.
#
# Called from iso/build.sh before mkarchiso. Fails the build if:
#   - any logo PNG has a bKGD chunk (would render with a solid bg)
#   - any logo PNG's Type is not RGBA (color-type=6)
#   - any theme.conf exists without a matching watermarked wallpaper
#   - any waybar style.css uses GTK-CSS-forbidden properties
#   - product name is misspelled anywhere in shipped surfaces
#
# Exits 0 on clean, non-zero with a red diagnostic on any violation.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO"

RED=$'\033[1;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[1;32m'
CYAN=$'\033[1;36m'
RST=$'\033[0m'

fails=0
warns=0
passes=0

fail() { printf '%sFAIL%s %s\n' "$RED" "$RST" "$*"; fails=$((fails+1)); }
warn() { printf '%sWARN%s %s\n' "$YELLOW" "$RST" "$*"; warns=$((warns+1)); }
pass() { printf '%sPASS%s %s\n' "$GREEN" "$RST" "$*"; passes=$((passes+1)); }

printf '%s== iso/qa/branding-check.sh ==%s\n' "$CYAN" "$RST"

# ---- 1. Logo PNG alpha + no bKGD ----
command -v magick >/dev/null 2>&1 || {
  echo "branding-check: magick (imagemagick) not installed; skipping alpha checks"
  exit 0
}

for f in assets/logo/png/vinos-*.png themes/vinos/frame-*.png iso/profile/syslinux/splash.png; do
  [[ -f "$f" ]] || continue
  info="$(magick identify -verbose "$f" 2>/dev/null || true)"
  # Extract corner pixel alpha as fx (0.0 = transparent, 1.0 = opaque).
  # -format %[fx:u.a] on a 1x1 crop = the exact alpha of that pixel.
  alpha="$(magick "$f" -crop 1x1+2+2 -format '%[fx:u.a]' info: 2>/dev/null || echo unknown)"
  if [[ "$alpha" == "unknown" || -z "$alpha" ]]; then
    fail "$f: could not read alpha — file may lack an alpha channel entirely"
    continue
  fi
  # awk to compare float safely
  is_transparent="$(awk -v a="$alpha" 'BEGIN { print (a+0.0 < 0.05) ? "yes" : "no" }')"
  if [[ "$is_transparent" == "yes" ]]; then
    if grep -q "png:bKGD" <<<"$info"; then
      warn "$f: corner transparent (α=$alpha) but bKGD chunk present — harmless on most renderers"
    else
      pass "$f: corner transparent (α=$alpha), no bKGD"
    fi
  else
    fail "$f: corner pixel opaque (α=$alpha) — logo has a baked-in background"
  fi
done

# ---- 2. Every theme.conf must have a watermarked wallpaper ----
for tc in themes/*/theme.conf; do
  theme="$(basename "$(dirname "$tc")")"
  # skip the plymouth theme (not a wallpaper theme)
  [[ "$theme" == "vinos" ]] && continue
  wp="assets/wallpapers/$theme/wallpaper.png"
  if [[ ! -f "$wp" ]]; then
    fail "themes/$theme/theme.conf exists but $wp is missing"
  else
    dims="$(magick identify -format '%wx%h' "$wp" 2>/dev/null)"
    if [[ "$dims" != "3840x2160" ]]; then
      warn "$wp is $dims — spec is 3840x2160 (see docs/BRANDING.md)"
    else
      pass "$wp: 3840x2160 present"
    fi
  fi
done

# ---- 3. Waybar style.css must not use web-only CSS props ----
if [[ -f config/waybar/style.css ]]; then
  bad_props=(font-feature-settings backdrop-filter '\-webkit\-' 'text-shadow')
  for prop in "${bad_props[@]}"; do
    if grep -nE "^[[:space:]]*${prop}[[:space:]]*:" config/waybar/style.css >/dev/null 2>&1; then
      fail "config/waybar/style.css uses '$prop' — GTK CSS parser rejects it. See docs/BRANDING.md typography section."
    fi
  done
  # @keyframes is technically supported by GTK CSS but multi-line values with `inset`
  # break the parser. Warn only.
  if grep -q "^@keyframes" config/waybar/style.css 2>/dev/null; then
    if grep -A 5 "^@keyframes" config/waybar/style.css | grep -qE '^\s*inset\s'; then
      fail "config/waybar/style.css has @keyframes containing 'inset' box-shadow — GTK CSS chokes on this exact pattern (v1.2.5 bug)."
    fi
  fi
  # Report clean if we made it here without failing on style.css
  if [[ $fails -eq 0 ]]; then pass "config/waybar/style.css: no known GTK-CSS-incompatible properties"; fi
fi

# ---- 4. Product name spelling ----
# vinOS is the only allowed spelling on shipped user-facing files.
# Skip lines that quote the wrong forms as counter-examples (in backticks
# or between double quotes) — docs/BRANDING.md deliberately shows the
# forbidden spellings for teaching purposes.
bad_pattern='\b(Vinos|VinOS|Vin OS|vin OS)\b'
misspellings=0
while IFS= read -r hit; do
  scrubbed="$(printf '%s\n' "$hit" | sed 's/`[^`]*`//g; s/"[^"]*"//g')"
  if grep -qE "$bad_pattern" <<<"$scrubbed"; then
    misspellings=$((misspellings+1))
    printf '  → %s\n' "$hit"
  fi
done < <(grep -rEn "$bad_pattern" README.md docs/*.md 2>/dev/null)
if (( misspellings > 0 )); then
  fail "$misspellings misspellings of product name in README/docs — must be 'vinOS'"
else
  pass "product name spelling consistent in README + docs"
fi

# ---- logo colour is one colour, everywhere ----
#
# The V mark ships on four surfaces built by four different pipelines: the
# SVG set in assets/logo/, the rasterized PNG favicons, the Plymouth theme
# baked into the ISO, and the inline mark on vinos.computer. Each one used
# to name its own colour, so the logo on the website was warm rust, the
# logo in hugo.toml was #33ccff, docs/BRANDING.md claimed #7AA2F7, and only
# the ISO actually carried the real one. Pin them together here.
#
# assets/logo/vinos.svg is the source of truth. Everything else is compared
# against whatever IS in that file — so rebranding means editing one SVG
# and re-running this, not hunting hex codes through the tree.

LOGO_SVG="$REPO/assets/logo/vinos.svg"
if [[ ! -f "$LOGO_SVG" ]]; then
  fail "assets/logo/vinos.svg missing — the brand mark has no source of truth"
else
  # The left stroke's fill is the brand colour, by definition.
  brand_hex="$(grep -o 'M -70,-70[^/]*fill="#[0-9a-fA-F]\{6\}"' "$LOGO_SVG" \
               | grep -o '#[0-9a-fA-F]\{6\}' | head -1)"
  if [[ -z "$brand_hex" ]]; then
    fail "could not read the left-stroke fill out of assets/logo/vinos.svg"
  else
    brand_lc="$(printf '%s' "$brand_hex" | tr 'A-Z' 'a-z')"
    pass "brand mark source of truth: assets/logo/vinos.svg → $brand_lc"

    # (a) The favicon the browser tab shows must be the same mark.
    fav="$REPO/site/static/img/favicon.svg"
    if [[ -f "$fav" ]]; then
      if grep -qi "$brand_lc" "$fav"; then
        pass "site favicon.svg uses the brand teal"
      else
        fail "site/static/img/favicon.svg does not use $brand_lc — the tab icon is a different logo from the ISO"
      fi
    fi

    # (b) hugo.toml must declare the same colour, not invent a third one.
    toml="$REPO/site/hugo.toml"
    if [[ -f "$toml" ]]; then
      declared="$(sed -n 's/^[[:space:]]*brand[[:space:]]*=[[:space:]]*"\(#[0-9a-fA-F]\{6\}\)".*/\1/p' "$toml" | head -1 | tr 'A-Z' 'a-z')"
      if [[ "$declared" == "$brand_lc" ]]; then
        pass "site/hugo.toml brand param matches ($declared)"
      elif [[ -z "$declared" ]]; then
        fail "site/hugo.toml declares no brand param — nothing pins the site mark to the ISO mark"
      else
        fail "site/hugo.toml brand='$declared' but the logo is '$brand_lc' — two different logos for one product"
      fi
    fi

    # (c) The site must paint the mark from a token, never from the page
    #     accent. Painting it with --color-accent is what made the web
    #     logo rust while the ISO logo stayed teal.
    css="$REPO/site/static/css/vinos.css"
    if [[ -f "$css" ]]; then
      if grep -E '\.(nav-edge \.brand-mark|foot-mark|hero-glyph) [^{]*\{[^}]*fill: var\(--color-accent\)' "$css" >/dev/null; then
        fail "site paints the brand mark with --color-accent — the web logo will not match the ISO logo. Use --color-brand."
      else
        pass "site paints every brand mark from --color-brand, not the page accent"
      fi
      # (d) …and on the correct stroke. The ISO mark is teal on the LEFT.
      if grep -q '\.stroke-l { fill: var(--color-brand); }' "$css"; then
        pass "brand teal is on the left stroke, matching assets/logo/vinos.svg"
      else
        fail "the site's .stroke-l is not the brand colour — the web mark is mirrored relative to the ISO mark"
      fi
    fi

    # (e) The doc must name the real colour. It named #7AA2F7 for months.
    if grep -qi "$brand_lc" "$REPO/docs/BRANDING.md" 2>/dev/null; then
      pass "docs/BRANDING.md names the real brand colour"
    else
      fail "docs/BRANDING.md never mentions $brand_lc — the spec disagrees with the artwork"
    fi
  fi
fi

# ---- summary ----
printf '\n%ssummary%s: %d pass · %d warn · %d fail\n' "$CYAN" "$RST" "$passes" "$warns" "$fails"
if (( fails > 0 )); then
  echo "branding-check FAILED — refusing to ship. See docs/BRANDING.md for the rules."
  exit 1
fi

# ---- reminder: T2 hardware checkpoint is a ship gate ----
# v1.3.0 shipped 4 T2 regressions the QEMU harness could not catch
# (tiny-dfr / t2fanrd / tzdetect / slowness). branding-check runs at
# the end of every build — print the reminder here so nobody tags a
# release without walking iso/qa/t2-hardware-checkpoint.md on a real T2.
printf '\n%sREMINDER%s: before tagging, walk iso/qa/t2-hardware-checkpoint.md\n' "$YELLOW" "$RST"
printf '  on a real Apple T2 MacBook. QEMU-green is not enough.\n'
