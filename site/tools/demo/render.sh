#!/usr/bin/env bash
# render.sh — render each demo scene to PNG via chromium headless,
# then stitch into an MP4 with ffmpeg (crossfades, no audio).
#
# Output:
#   site/tools/demo/frames/scene-*.png (1920x1080)
#   site/static/video/vinos-demo.mp4
#   site/static/img/demo-poster.jpg
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE="$(cd "$HERE/../.." && pwd)"
FRAMES="$HERE/frames"
OUT_VIDEO="$SITE/static/video/vinos-demo.mp4"
OUT_POSTER="$SITE/static/img/demo-poster.jpg"

SCENES=(1 2 3 4 5 6)
PER_SCENE=3.0        # seconds each scene is on screen
CROSSFADE=0.5        # seconds of crossfade between scenes
FPS=30

command -v chromium >/dev/null 2>&1 || { echo "chromium required" >&2; exit 1; }
command -v ffmpeg   >/dev/null 2>&1 || { echo "ffmpeg required"   >&2; exit 1; }

log() { printf '\033[1;34m[demo]\033[0m %s\n' "$*"; }

log "render: $((${#SCENES[@]})) scenes @ 1920x1080"
mkdir -p "$FRAMES" "$(dirname "$OUT_VIDEO")" "$(dirname "$OUT_POSTER")"
rm -f "$FRAMES"/scene-*.png

for i in "${SCENES[@]}"; do
  out="$FRAMES/scene-$i.png"
  # file:// URL so backdrop-filter + relative image paths both work
  chromium \
    --headless \
    --disable-gpu \
    --hide-scrollbars \
    --force-device-scale-factor=1 \
    --window-size=1920,1080 \
    --virtual-time-budget=1500 \
    --screenshot="$out" \
    "file://$HERE/scenes.html?scene=$i" >/dev/null 2>&1
  [[ -s "$out" ]] || { echo "scene $i render failed" >&2; exit 1; }
  log "  scene $i → $(basename "$out") ($(stat -c %s "$out") bytes)"
done

# Cinematic crossfade sequence via ffmpeg's xfade filter.
# Each scene runs for PER_SCENE seconds, then CROSSFADE seconds fading
# into the next scene. Duration = N*PER_SCENE - (N-1)*CROSSFADE.
log "encode: stitching $((${#SCENES[@]})) scenes with ${CROSSFADE}s crossfades"

# Build ffmpeg args: one -loop input per scene at PER_SCENE seconds.
inputs=()
for i in "${SCENES[@]}"; do
  inputs+=( -loop 1 -t "$PER_SCENE" -i "$FRAMES/scene-$i.png" )
done

# Build filter chain: v0-v1 xfade → v01; v01-v2 xfade → v012; ...
n=${#SCENES[@]}
filter=""
prev="[0:v]"
acc_offset=$(awk -v p="$PER_SCENE" -v c="$CROSSFADE" 'BEGIN{print p-c}')
for ((k=1; k<n; k++)); do
  next="[${k}:v]"
  out_label="[v$k]"
  filter+="${prev}${next}xfade=transition=fade:duration=${CROSSFADE}:offset=${acc_offset}${out_label};"
  prev="${out_label}"
  acc_offset=$(awk -v a="$acc_offset" -v p="$PER_SCENE" -v c="$CROSSFADE" 'BEGIN{print a + p - c}')
done
# Strip trailing semicolon and add scale/format for web-safe output
filter="${filter%;}"
# Final label is [v(n-1)]
last="[v$((n-1))]"
filter+=";${last}format=yuv420p[vout]"

ffmpeg -y -hide_banner -loglevel error \
  "${inputs[@]}" \
  -filter_complex "$filter" \
  -map "[vout]" \
  -c:v libx264 -preset slow -crf 20 -movflags +faststart \
  -r "$FPS" -pix_fmt yuv420p \
  "$OUT_VIDEO"

# Poster = scene 1 downscaled to 1280 wide, jpeg for lightweight page load
ffmpeg -y -hide_banner -loglevel error \
  -i "$FRAMES/scene-1.png" -vf "scale=1280:-2" -q:v 3 "$OUT_POSTER"

log "done"
log "  video:  $OUT_VIDEO  ($(stat -c %s "$OUT_VIDEO") bytes)"
log "  poster: $OUT_POSTER ($(stat -c %s "$OUT_POSTER") bytes)"
