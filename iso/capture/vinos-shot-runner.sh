#!/usr/bin/env bash
# vinos-shot-runner — in-guest orchestrator for the docs screenshot
# pipeline. Runs as the "vinos" user under Hyprland after the host driver
# injects it via serial console. Writes PNGs to /mnt/caps/ (a QEMU virtfs
# share from the host), then touches /mnt/caps/DONE so the host driver
# knows to shut down.
#
# Never mutates the ISO. Everything happens live in the running session.
#
# Fragile-bit fixes from the last run (2026-07-25 pass 2):
#   * dismiss() now WAITS for `hyprctl layers` to report the overlay
#     namespaces empty before returning, so subsequent grim shots don't
#     capture the cheatsheet still on top.
#   * foot captures wait for the app-id to show up in `hyprctl clients`
#     with a bounded timeout, not a blind sleep.
#   * every successful grab() runs md5sum against the last N frames and
#     WARNs + marks-failed if the new PNG is a byte-identical dup — that
#     was why some pass-1 shots were literal copies with different names.
set -u
LC_ALL=C
export LC_ALL

CAPS=/mnt/caps
LOG="$CAPS/runner.log"
mkdir -p "$CAPS" 2>/dev/null || true
export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

# Rolling md5 window: keep the last 6 shot digests. Any new capture that
# matches one already in the window is flagged as a duplicate and the
# .png is renamed to *.dup.png so post-processing skips it.
declare -a MD5_WINDOW=()
MD5_WINDOW_MAX=6

# ImageMagick can either accept a font-family name (looked up via fontconfig
# and its own -list-font cache) or a raw .ttf/.otf path. The name form is
# fragile — the exact string varies across distros ("DejaVu-Sans-Mono" vs
# "DejaVuSansMono" vs "DejaVu Sans Mono") — so prefer a direct file path.
FONT_MONO=""
for candidate in \
  /usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf \
  /usr/share/fonts/TTF/DejaVuSansMono.ttf \
  /usr/share/fonts/dejavu/DejaVuSansMono.ttf \
  /usr/share/fonts/liberation-mono/LiberationMono-Regular.ttf \
  /usr/share/fonts/TTF/LiberationMono-Regular.ttf; do
  [[ -f "$candidate" ]] && { FONT_MONO="$candidate"; break; }
done
if [[ -z "$FONT_MONO" ]]; then
  FONT_MONO=$(find /usr/share/fonts -type f \( -iname '*mono*.ttf' -o -iname '*mono*.otf' \) 2>/dev/null | head -1)
fi
: "${FONT_MONO:=monospace}"

log()   { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOG"; }
mark()  { printf '%s|%s|%s\n' "$1" "$2" "$3" >>"$CAPS/capture.log"; }

# --- readiness ---------------------------------------------------------
log "waiting for Hyprland IPC…"
for _ in $(seq 1 90); do
  hyprctl monitors -j >/dev/null 2>&1 && break
  sleep 1
done
hyprctl monitors -j >/dev/null 2>&1 || { log "FATAL: hyprctl never came up"; touch "$CAPS/DONE"; exit 1; }
log "Hyprland is up."

# Try to force a large-enough backing mode so grim shots are usable in
# the docs (target 2560x1600). The std VGA framebuffer usually maxes at
# 1280x800; virtio-gpu clients can go higher. Failure is silent.
for mon in Virtual-1 X11-1 HDMI-A-1 ""; do
  hyprctl keyword monitor "${mon},2560x1600@60,0x0,1" >>"$LOG" 2>&1 && break
done

# waybar/quickshell/first-run all fire on hyprland.start. The docs list a
# 90–120s settle window; be conservative and give the shell time to render.
log "settling desktop (30s)…"
sleep 30

hyprctl monitors -j 2>>"$LOG" | head -c 1500 >>"$LOG"; echo >>"$LOG"

# --- helpers -----------------------------------------------------------
# Push a new md5 onto the window, evicting the oldest if we're over cap.
push_md5() {
  local md5="$1"
  MD5_WINDOW+=("$md5")
  if (( ${#MD5_WINDOW[@]} > MD5_WINDOW_MAX )); then
    MD5_WINDOW=("${MD5_WINDOW[@]:1}")
  fi
}

# Return 0 if the given md5 is already in the window.
is_dup() {
  local md5="$1"
  local m
  for m in "${MD5_WINDOW[@]}"; do
    [[ "$m" == "$md5" ]] && return 0
  done
  return 1
}

grab() {
  local out="$1"; shift || true
  if grim "$@" "$CAPS/$out" 2>>"$LOG"; then
    local sz md5
    sz=$(stat -c%s "$CAPS/$out" 2>/dev/null || echo "?")
    md5=$(md5sum "$CAPS/$out" 2>/dev/null | cut -d' ' -f1)
    log "  grabbed $out (${sz} bytes, md5=$md5)"
    if is_dup "$md5"; then
      log "  DUP: $out matches a recent frame — renaming to .dup.png"
      mv "$CAPS/$out" "$CAPS/${out%.png}.dup.png" 2>>"$LOG" || true
      return 1
    fi
    push_md5 "$md5"
    return 0
  fi
  log "  grim FAILED for $out"
  return 1
}

# dismiss(): fully nuke overlays. Fires the kill, then WAITS for
# `hyprctl layers` to show no walker/menu layers before returning.
# This was the fragile bit: pass-1 fired grim before the cheatsheet
# actually vanished, so theme-summit and theme-circuit shot the
# cheatsheet-over-summit and cheatsheet-over-circuit.
dismiss() {
  pkill -x walker         2>/dev/null || true
  pkill -x rofi           2>/dev/null || true
  pkill -f omarchy-menu   2>/dev/null || true
  pkill -f omarchy-shell  2>/dev/null || true
  # Also close any dangling layer surfaces via hyprctl (belt + braces).
  hyprctl dispatch closelayer walker      >/dev/null 2>&1 || true
  hyprctl dispatch closelayer quickshell  >/dev/null 2>&1 || true
  local t=0
  while [[ $t -lt 20 ]]; do
    local layers
    layers=$(hyprctl layers -j 2>/dev/null || echo '{}')
    if ! grep -q -E '"namespace":"(walker|quickshell|rofi|omarchy)"' <<<"$layers"; then
      # No overlay-owned layer surfaces remain.
      sleep 0.3
      return 0
    fi
    sleep 0.3; t=$((t+1))
  done
  log "  dismiss: overlays still visible after wait — continuing anyway"
  return 0
}

set_theme() {
  local name="$1"
  log "theme -> $name"
  omarchy-theme-set "$name" >>"$LOG" 2>&1 || log "  theme-set failed for $name"
  # Give hyprland+swaybg+waybar time to fully repaint. 5s was tight;
  # bump to 6s so the wallpaper is actually swapped before we grab.
  sleep 6
}

render_terminal() {
  local out="$1" title="$2" text="$3"
  local w=1280 h=800 pad=32
  local tmp; tmp=$(mktemp)
  printf '%s\n' "$text" >"$tmp"
  # Use magick's `caption:` operator: word-wraps + honours newlines.
  magick \
    -size "${w}x${h}" xc:'#0f1218' \
    -fill '#1a1e26' -draw "rectangle 0,0 ${w},40" \
    -fill '#4EC1B8' -draw "circle 20,20 20,26" \
    -fill '#e0e2e7' -font "$FONT_MONO" -pointsize 14 \
      -annotate +48+26 "$title" \
    \( -background '#0f1218' -fill '#c9d1d9' \
       -font "$FONT_MONO" -pointsize 15 \
       -size "$((w - 2*pad))x$((h - 80))" \
       "caption:@$tmp" \) \
    -geometry "+${pad}+56" -composite \
    "$CAPS/$out" 2>>"$LOG" \
    && log "  rendered $out" \
    || log "  render_terminal FAILED for $out"
  rm -f "$tmp"
}

# wait_for_class: block until a hyprland client with matching class
# (initialClass or class) appears. Bounded, returns 1 on timeout.
wait_for_class() {
  local cls="$1" timeout="${2:-10}"
  local t=0
  while [[ $t -lt $timeout ]]; do
    if hyprctl clients -j 2>/dev/null | grep -q -E "\"(class|initialClass)\":\"$cls\""; then
      return 0
    fi
    sleep 0.5; t=$((t+1))
  done
  return 1
}

# open_foot: spawn foot running the given bash command line, then wait
# for it to actually map so the screenshot captures a rendered window
# instead of the desktop underneath. Times out at 10s.
open_foot() {
  local title="$1" cmdline="$2"
  pkill -x foot 2>/dev/null || true
  sleep 0.5
  setsid foot --title="$title" -e bash -c "$cmdline; sleep 999" </dev/null >/dev/null 2>&1 &
  # foot's app-id in hyprctl is "foot" by default. Wait for it to appear.
  wait_for_class foot 10 || log "  open_foot: foot never appeared for '$title'"
  # Give bash time to run the command + foot to render its output.
  sleep 3
}

# --- Phase 0: baseline theme ------------------------------------------
CURRENT_THEME=$(readlink -f /home/vinos/.config/omarchy/current/theme 2>/dev/null | xargs -r basename)
log "current theme: ${CURRENT_THEME:-unknown}"
if [[ "$CURRENT_THEME" != "cosmos" ]]; then
  set_theme cosmos
fi

# --- Shot 30: waybar full width --------------------------------------
sleep 2
grab waybar-full.png            && mark shot-30 waybar-full.png "clean desktop top bar"

# --- Shot 12: theme-cosmos.png (also our baseline desktop) -----------
grab theme-cosmos.png           && mark shot-12 theme-cosmos.png "cosmos active"

# --- Shot 06: first-desktop.png (clean cosmos, no overlays, no toast)
dismiss
sleep 1
grab first-desktop.png          && mark shot-06 first-desktop.png "clean cosmos desktop"

# --- Shot 33: waybar-close-up.png ------------------------------------
# Crop the top-right corner of the primary monitor. grim's -g accepts
# a "XxY WxH" geometry string (space-separated). At 1280x800 (default
# std VGA), grab the top-right 600x60 slice. At 2560x1600 grab 1200x80.
if hyprctl monitors -j 2>/dev/null | grep -q '"width": *2560'; then
  grab waybar-close-up.png -g "1360,0 1200x80" && mark shot-33 waybar-close-up.png "waybar right cluster"
else
  grab waybar-close-up.png -g "680,0 600x60"   && mark shot-33 waybar-close-up.png "waybar right cluster (1280 mode)"
fi

# --- Shot 40: vinos-focus-active -------------------------------------
setsid bash -c 'vinos-focus 25 --task "shipping" </dev/null >/dev/null 2>&1 &' 2>/dev/null || true
sleep 3
grab vinos-focus-active.png     && mark shot-40 vinos-focus-active.png "focus session waybar"
pkill -f vinos-focus 2>/dev/null || true

# --- Shot 03: welcome-dmenu.png --------------------------------------
if command -v vinos-welcome >/dev/null 2>&1; then
  setsid bash -c 'vinos-welcome </dev/null >/dev/null 2>&1 &' 2>/dev/null || true
  sleep 5
  grab welcome-dmenu.png          && mark shot-03 welcome-dmenu.png "welcome walker picker"
  # Shot 07: welcome-checklist.png — the checklist walker view. Same
  # process as shot-03; capture again while the overlay is up under a
  # different filename so docs can annotate both stages.
  grab welcome-checklist.png      && mark shot-07 welcome-checklist.png "welcome checklist walker"
  dismiss
fi

# --- Shot 02: first-boot-tty.png (foot terminal running vinos-welcome)
if command -v vinos-welcome >/dev/null 2>&1; then
  open_foot vinos-welcome "vinos-welcome"
  grab first-boot-tty.png       && mark shot-02 first-boot-tty.png "vinos-welcome in foot"
fi
pkill -x foot 2>/dev/null || true
sleep 1

# --- Overlay shots ---------------------------------------------------
# omarchy-shell exec'd via `summon` (always open, never toggle-close).
# quickshell needs 2-3s to render the overlay + walker window. We give
# each capture 5s of settle time. dismiss() kills walker + omarchy-menu
# AND waits for the layer to actually disappear.

open_menu() {
  local route="$1"
  log "  summon menu $route"
  omarchy-shell shell summon omarchy.menu \
    "$(printf '{"menu":"%s"}' "$route")" >>"$LOG" 2>&1 &
  disown 2>/dev/null || true
}

open_launcher() {
  log "  summon launcher"
  omarchy-shell shell summon omarchy.launcher '{}' >>"$LOG" 2>&1 &
  disown 2>/dev/null || true
}

# --- Shot 10: menu-root.png -----------------------------------------
open_menu root
sleep 5
grab menu-root.png              && mark shot-10 menu-root.png "menu root open"
dismiss

# --- Shot 11: theme-picker.png --------------------------------------
open_menu theme
sleep 5
grab theme-picker.png           && mark shot-11 theme-picker.png "theme walker overlay"
dismiss

# --- Shot 15: menu-style.png ----------------------------------------
open_menu style
sleep 5
grab menu-style.png             && mark shot-15 menu-style.png "menu style submenu"
dismiss

# --- Shot 16: menu-install.png --------------------------------------
open_menu install
sleep 5
grab menu-install.png           && mark shot-16 menu-install.png "menu install bundles"
dismiss

# --- Shot 17: menu-trigger.png --------------------------------------
open_menu trigger
sleep 5
grab menu-trigger.png           && mark shot-17 menu-trigger.png "menu trigger submenu"
dismiss

# --- Shot 31: walker-launcher.png -----------------------------------
open_launcher
sleep 5
grab walker-launcher.png        && mark shot-31 walker-launcher.png "walker launcher open"
dismiss

# --- Shot 32: cheatsheet-overlay.png (Super+K) ----------------------
# omarchy-menu-keybindings is a script that builds + summons a menu.
# Run it detached; give the walker layer time to render.
setsid bash -c 'omarchy-menu-keybindings </dev/null >/dev/null 2>&1 &' 2>/dev/null || true
sleep 5
grab cheatsheet-overlay.png     && mark shot-32 cheatsheet-overlay.png "cheatsheet overlay"
dismiss

# --- Shot 20: vinos-brief-panel.png ---------------------------------
if command -v vinos-brief >/dev/null 2>&1; then
  setsid bash -c 'vinos-brief </dev/null >/dev/null 2>&1 &' 2>/dev/null || true
  sleep 4
  if grab vinos-brief-panel.png; then
    mark shot-20 vinos-brief-panel.png "vinos-brief live"
  else
    render_terminal vinos-brief-panel.png "vinos-brief" \
"vinos ~ vinos-brief

TODAY - Fri Jul 25 2026
  * ship the screenshot pipeline
  * verify T2 wifi on the new build
  * respond to sponsors
  * plan v2.0.6 routines UI"
    mark shot-20 vinos-brief-panel.png "vinos-brief rendered fallback"
  fi
  dismiss
fi

# --- Shot 26: brief-panel.png (vinos-brief in foot, markdown) -------
# Same content as shot-20 but rendered inside a real foot terminal so
# docs can show both "walker panel" and "terminal output" variants.
if command -v vinos-brief >/dev/null 2>&1; then
  open_foot vinos-brief "vinos-brief 2>&1 | head -60"
  grab brief-panel.png          && mark shot-26 brief-panel.png "vinos-brief foot output"
  pkill -x foot 2>/dev/null || true
  sleep 0.5
fi

# --- Shot 23: routine-list.png --------------------------------------
if command -v vinos-routine >/dev/null 2>&1; then
  open_foot vinos-routine-list "vinos-routine list 2>&1 | head -30"
  grab routine-list.png         && mark shot-23 routine-list.png "vinos-routine list output"
  pkill -x foot 2>/dev/null || true
  sleep 0.5
fi

# --- Shot 24: routine-run.png (may fail w/o API key — that's OK) ----
if command -v vinos-routine >/dev/null 2>&1; then
  # Capture the failure or in-progress state either way — the docs
  # want to show what the run pipeline LOOKS LIKE, not necessarily a
  # succeeding one.
  open_foot vinos-routine-run \
    "(vinos-routine list 2>&1 | head -5; echo; echo '\$ vinos-routine run day-brief'; vinos-routine run day-brief 2>&1 | head -20) || true"
  grab routine-run.png          && mark shot-24 routine-run.png "vinos-routine run day-brief"
  pkill -x foot 2>/dev/null || true
  sleep 0.5
fi

# --- Shot 25: routine-cost.png --------------------------------------
if command -v vinos-routine >/dev/null 2>&1; then
  open_foot vinos-routine-cost "vinos-routine cost 2>&1 | head -30"
  grab routine-cost.png         && mark shot-25 routine-cost.png "vinos-routine cost ledger"
  pkill -x foot 2>/dev/null || true
  sleep 0.5
fi

# --- Shot 34: terminal-vinos-fix.png --------------------------------
# Pipe a failed command through vinos-fix. May emit an "ai bundle not
# installed" pointer on the live ISO — that's fine, doc the pointer.
if command -v vinos-fix >/dev/null 2>&1; then
  open_foot vinos-fix \
    "(echo '\$ false 2>&1 | vinos-fix'; false 2>&1 | vinos-fix 2>&1) || true; echo; echo '(exit)'"
  grab terminal-vinos-fix.png   && mark shot-34 terminal-vinos-fix.png "vinos-fix on failed command"
  pkill -x foot 2>/dev/null || true
  sleep 0.5
fi

# --- Shot 35: terminal-vinos-standup.png ----------------------------
if command -v vinos-standup >/dev/null 2>&1; then
  open_foot vinos-standup \
    "(echo '\$ vinos-standup --yesterday'; vinos-standup --yesterday 2>&1 | head -20) || true; echo"
  grab terminal-vinos-standup.png && mark shot-35 terminal-vinos-standup.png "vinos-standup terminal"
  pkill -x foot 2>/dev/null || true
  sleep 0.5
fi

# --- CLI shots: rendered via ImageMagick for reproducibility --------
render_terminal vinos-commit-tui.png "vinos ~ vinos-commit" \
"vinos ~ vinos-commit
+ staged: iso/capture-shots.sh iso/capture/
+ drafting commit message...

feat(iso): screenshot pipeline for docs

Adds host driver + in-guest runner + overlay
so all 24 SCREENSHOTS_NEEDED.md shots capture
automatically on a headless QEMU boot.

[ E ]dit  [ A ]ccept  [ R ]etry  [ Q ]uit"
mark shot-41 vinos-commit-tui.png "vinos-commit rendered"

render_terminal vinos-standup-out.png "vinos ~ vinos-standup" \
"vinos ~ vinos-standup

YESTERDAY
  * closed v2.0.5 regression on brcmfmac firmware
  * merged Hallmark critical-fix pass

TODAY
  * ship screenshot pipeline for /docs/
  * verify T2 wifi on hardware
  * tag v2.0.6 alpha

BLOCKED
  * sponsor Stripe onboarding needs Vin's ID
  * awaiting v2.0.6 waybar routine widget"
mark shot-42 vinos-standup-out.png "vinos-standup rendered"

render_terminal vinos-ai-chat.png "vinos ~ vinos-ai chat" \
"vinos ~ vinos-ai chat

> how do I rebind Super+K?

Edit ~/.config/hypr/bindings.lua and add:

  o.bind('SUPER + K', 'my action', 'my-command')

Then reload: hyprctl reload.

> thanks

Anytime - try 'vinos-ai explain <cmd>' for
per-command drilldowns."
mark shot-43 vinos-ai-chat.png "vinos-ai rendered"

render_terminal doctor-passing.png "vinos ~ vinos-doctor" \
"vinos ~ vinos-doctor

  [PASS] hyprland running
  [PASS] waybar running
  [PASS] walker installed
  [PASS] greetd active
  [PASS] iwd active + connected
  [PASS] brcmfmac loaded
  [PASS] Broadcom firmware present
  [PASS] docker service running
  [PASS] all 87 vinos-* wrappers +x
  [PASS] Omarchy themes /usr/share/omarchy/themes (21)
  [PASS] vinOS themes /usr/share/omarchy/themes (10)

everything looks good."
mark shot-60 doctor-passing.png "vinos-doctor rendered"

render_terminal docker-lazydocker.png "vinos ~ lazydocker" \
" CONTAINERS                              LOGS
 * archlinux         Up 4 minutes         2026-07-25T14:22:10  archlinux init
   vinos-iso-tester  Up 12 minutes        2026-07-25T14:14:03  qemu boot ok
   vinos-qemu-desk   Exited (0) 1 hour    2026-07-25T13:10:11  clean shutdown

 IMAGES
   vinos-iso-tester:latest     b72628d791cf   953MB
   vinos-qemu-desktop:latest   91409d24d5d1   1.73GB
   archlinux:latest            068a765646e7   571MB

 [d] delete  [l] logs  [r] restart  [q] quit"
mark shot-61 docker-lazydocker.png "lazydocker rendered"

# --- Theme rotation: shots 13 & 14 ----------------------------------
# For each theme swap, DISMISS first (fragile-bit #1 from pass 1: the
# cheatsheet overlay was still up when these fired), then also grab a
# "*-clean" variant so docs can pick which to show.
dismiss

set_theme summit
dismiss
grab theme-summit.png           && mark shot-13 theme-summit.png "summit active"
grab theme-summit-clean.png     && mark shot-13b theme-summit-clean.png "summit clean (no overlay)"

set_theme circuit
dismiss
grab theme-circuit.png          && mark shot-14 theme-circuit.png "circuit active"
grab theme-circuit-clean.png    && mark shot-14b theme-circuit-clean.png "circuit clean (no overlay)"

set_theme cosmos
dismiss
grab theme-cosmos-clean.png     && mark shot-12b theme-cosmos-clean.png "cosmos clean (no overlay)"

# --- Shot 51: t2-wifi-connected.png ---------------------------------
grab t2-wifi-connected.png      && mark shot-51 t2-wifi-connected.png "waybar network (stand-in for real T2)"

# --- explicitly-skipped shots ---------------------------------------
# shot-01 boot-plymouth.png  — captured host-side via HMP screendump
# shot-04 boot-syslinux-menu — captured host-side via HMP screendump
# shot-05 login-greeter      — captured host-side via HMP before Hyprland
# shot-21 waybar-routine-widget.png  — module not shipped until v2.0.6
# shot-22 routine-notification.png   — needs API key + real routine run
# shot-50 t2-mbp-boot.png            — physical phone photo required
# shot-70..79 vinos-*-help.png       — rendered host-side via ImageMagick

log "sequence complete."
sync
touch "$CAPS/DONE"
