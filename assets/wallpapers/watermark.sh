#!/usr/bin/env bash
# assets/wallpapers/watermark.sh — apply the vinOS wordmark to a wallpaper.
#
# Design intent:
#   Subtle brand presence, never draws focus. The mark sits in the bottom-
#   right at 12 % opacity by default, sized to ~4 % of the frame's shorter
#   edge, with a 40 px inset. On light photos we use the dark logo variant
#   for legibility; on dark photos we use the white variant.
#
# Usage:
#   assets/wallpapers/watermark.sh <input.jpg|png> <output.png> [theme_name]
#
# The theme_name arg (optional) picks the logo variant per theme metadata.
# When omitted, luminance of the corner region is measured and the higher-
# contrast variant is chosen automatically.
#
# Output is always PNG at 3840×2160 (or the source's native res, whichever
# is larger). Non-3840×2160 sources are letterbox-cropped to fit — cover
# fit, not contain, so the wallpaper fills the screen.
#
# Requires: imagemagick (magick binary).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGO_LIGHT="$REPO/assets/logo/png/vinos-512.png"   # dark logo on light bg
LOGO_DARK="$REPO/assets/logo/png/vinos-512.png"    # placeholder (same file);
                                                    # future: separate white variant
# TODO: once assets/logo/png/vinos-white-512.png ships, point LOGO_DARK here.

TARGET_W=3840
TARGET_H=2160
INSET=256               # px from bottom + right edges of the 3840×2160 canvas.
                        # 64 px got clipped on 16:10 laptop screens (MacBook Pro
                        # T2 2560×1600, Framework 13" 3:2 2256×1504) because
                        # awww/swaybg cover-fit crops ~140–210 px off each side
                        # of a 16:9 source. 256 px keeps the mark inside the
                        # safe rectangle for 16:9, 16:10, and 3:2. Verified on
                        # T2 hardware 2026-08-15.
OPACITY=0.55            # 55 % — 30 % was invisible on dark starry backdrops;
                        # 55 % reads as "present but not dominant" on both
                        # bright and dark photos.
LOGO_FRAC=0.10          # logo edge = 10 % of frame min edge (216 px on 4K).
SHADOW_OFFSET=6         # px offset for the drop-shadow behind the logo — gives
                        # the mark a subtle backing plate so it reads on any
                        # photo, not just contrast-friendly ones.
SHADOW_OPACITY=0.55     # matches OPACITY so the two layers stay balanced.
SHADOW_BLUR=8           # sigma; gentle diffusion, not a heavy vignette.

die() { printf '\033[1;31m[watermark] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[watermark]\033[0m %s\n' "$*"; }

[[ $# -ge 2 ]] || die "usage: $0 <input> <output> [theme_name]"
IN="$1"; OUT="$2"; THEME="${3:-}"

[[ -f "$IN" ]] || die "input missing: $IN"
command -v magick >/dev/null || die "imagemagick not installed"
[[ -f "$LOGO_LIGHT" ]] || die "logo missing: $LOGO_LIGHT"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1. Cover-fit resize + center-crop to TARGET_W×TARGET_H.
log "resize+crop → ${TARGET_W}×${TARGET_H}"
magick "$IN" -resize "${TARGET_W}x${TARGET_H}^" -gravity center -extent "${TARGET_W}x${TARGET_H}" "$TMP/cropped.png"

# 2. Pick logo variant. If theme name is provided AND it maps to a light
#    palette we choose the dark logo; otherwise auto-luminance.
LOGO="$LOGO_LIGHT"
case "$THEME" in
  frost|daybreak|light) LOGO="$LOGO_LIGHT" ;;   # light theme → dark logo
  ember|nebula|aurora|dark|"") LOGO="$LOGO_LIGHT" ;;  # placeholder until white variant lands
esac

# 3. Compute logo size (4 % of min edge).
MIN_EDGE=$(( TARGET_W < TARGET_H ? TARGET_W : TARGET_H ))
LOGO_EDGE=$(awk -v m="$MIN_EDGE" -v f="$LOGO_FRAC" 'BEGIN { printf "%d", m*f }')
log "logo size: ${LOGO_EDGE}px, opacity: ${OPACITY}, inset: ${INSET}px"

# 4. Prep logo — resize + apply opacity.
magick "$LOGO" -resize "${LOGO_EDGE}x${LOGO_EDGE}" \
  -channel A -evaluate multiply "$OPACITY" +channel \
  "$TMP/logo-scaled.png"

# 4b. Build a soft dark drop-shadow of the logo silhouette.
#     Method: extract alpha, blur it, use as mask for a BLACK RGBA sprite
#     at SHADOW_OPACITY. Do NOT -negate (that produced a white box, not
#     a shadow — v1.2.5 bug caught 2026-08-15).
magick "$LOGO" -resize "${LOGO_EDGE}x${LOGO_EDGE}" \
  \( +clone -channel A -evaluate set 0% +channel \
     -fill "rgba(0,0,0,${SHADOW_OPACITY})" -colorize 100% \) \
  \( -clone 0 -alpha extract -blur "0x${SHADOW_BLUR}" \) \
  -delete 0 \
  -compose CopyOpacity -composite \
  "$TMP/logo-shadow.png"

# 5. Composite: shadow first (offset down+right), then logo on top.
log "compositing (logo + drop shadow)"
magick "$TMP/cropped.png" \
  \( "$TMP/logo-shadow.png" -geometry "+${SHADOW_OFFSET}+${SHADOW_OFFSET}" \) \
  -gravity southeast -geometry "+$((INSET-SHADOW_OFFSET))+$((INSET-SHADOW_OFFSET))" \
  -composite \
  "$TMP/logo-scaled.png" \
  -gravity southeast -geometry "+${INSET}+${INSET}" \
  -composite "$OUT"

log "wrote $OUT ($(du -h "$OUT" | cut -f1))"
