#!/usr/bin/env bash
# iso/capture-hero.sh — script a multi-pane "agentic workflow" hero shot.
#
# Boots the ISO with 9p host share so the guest can (a) run a scene
# script that installs chromium/neovim/btop, (b) launches a code editor
# + browser + music mock + AI chat mock + system monitor in tiled panes,
# and (c) drops grim-captured PNGs back to the host.
#
# Also re-captures the standard UI shots (desktop, walker, vinos-menu,
# impala wifi, keybindings sheet, theme picker) so the site stays fresh.
#
# Emits site/static/img/screenshots/*.png. Runs ~10-15 min.
set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$ISO_DIR/.." && pwd)"
OUT="$ROOT_DIR/site/static/img/screenshots"
SHARE="$(mktemp -d /tmp/vinos-hero.XXXXXX)"

die() { printf '\033[1;31m[hero] FAIL:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m[hero]\033[0m %s\n' "$*"; }

ISO="$(find "$ISO_DIR/out" -maxdepth 1 -name 'vinos-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)"
[[ -n "$ISO" && -f "$ISO" ]] || die "no ISO — run iso/build.sh first"

IMG="vinos-iso-tester:latest"
docker image inspect "$IMG" >/dev/null 2>&1 || die "tester image missing — run iso/test.sh once first"

mkdir -p "$OUT" "$SHARE/shots"
chmod 0777 "$SHARE" "$SHARE/shots"

# -- The scene script the guest will fetch + run --------------------
cat > "$SHARE/scene.sh" <<'SCENE'
#!/usr/bin/env bash
# Runs INSIDE the vinOS live guest. Assumes Hyprland is up and vin's
# session has HYPRLAND_INSTANCE_SIGNATURE set. Mounted 9p share is at
# /mnt/host; screenshots go to /mnt/host/shots/.
set -eu

SHARE=/mnt/host
SHOTS="$SHARE/shots"
mkdir -p "$SHOTS"

# ── Ensure we're running in the graphical session ──────────────────
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  sig=$(ls -1 "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1 || true)
  [[ -n "$sig" ]] || { echo "no Hyprland session"; exit 1; }
  export HYPRLAND_INSTANCE_SIGNATURE="$sig"
fi
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

log() { echo "[scene] $*"; }
shot() {
  local name="$1"; sleep 2
  grim "$SHOTS/${name}.png" && log "captured $name"
}

# ── 1. Refresh waybar (in case a fresh config landed via mount) ────
if [[ -f "$SHARE/waybar-config.jsonc" ]]; then
  mkdir -p ~/.config/waybar
  cp "$SHARE/waybar-config.jsonc" ~/.config/waybar/config.jsonc
  pkill -SIGUSR2 waybar || pkill waybar || true
  sleep 3
fi

# ── 2. Standard UI shots first (fast, before install) ──────────────
log "01 idle desktop"
shot 01-desktop

log "02 walker launcher"
hyprctl dispatch exec walker &
sleep 3
shot 02-walker
pkill -x walker || true
sleep 1

log "03 vinos-menu"
hyprctl dispatch exec 'vinos-menu' &
sleep 3
shot 03-menu
pkill -f 'vinos-menu' || true
pkill -x walker || true
sleep 1

log "04 impala wifi"
hyprctl dispatch exec 'foot -T impala -e impala' &
sleep 3
shot 04-wifi
pkill -x impala || true
pkill -x foot || true
sleep 1

log "05 keybindings sheet"
hyprctl dispatch exec 'vinos-menu-keybindings' &
sleep 3
shot 05-keys
pkill -x foot || true
sleep 1

log "06 theme picker"
hyprctl dispatch exec 'vinos-menu theme' &
sleep 3
shot 06-theme
pkill -f 'vinos-menu' || true
pkill -x walker || true
sleep 1

# ── 3. Install hero-scene packages ─────────────────────────────────
log "installing hero-scene packages (chromium, neovim, btop) — may take 3-5 min"
sudo pacman -Sy --needed --noconfirm chromium neovim btop 2>&1 | tail -5

# ── 4. Prep a sample code file so nvim shows real content ──────────
mkdir -p ~/hero
cat > ~/hero/agent.py <<'PY'
"""vinOS agent — refactor a Flask endpoint to FastAPI + async DB."""
import anthropic

client = anthropic.Anthropic()


async def refactor(source: str) -> str:
    resp = await client.messages.create(
        model="claude-opus-4-7",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": (
                "Rewrite this Flask handler to FastAPI with "
                "async SQLAlchemy calls, and preserve behavior:\n\n" + source
            ),
        }],
    )
    return resp.content[0].text


if __name__ == "__main__":
    with open("app.py") as f:
        print(refactor(f.read()))
PY

# ── 5. Prep a fake AI chat transcript ──────────────────────────────
cat > ~/hero/ai-chat.txt <<'TXT'

  vinos-ai chat · llama3.2 · local
  ─────────────────────────────────

  > refactor agent.py to use asyncpg
    instead of raw sqlalchemy

  claude ▸ Sure. I'll swap the SQLAlchemy
    session for an asyncpg pool and inline
    the query. Here's the diff:

  - async with async_session() as s:
  -     row = await s.execute(select(User))
  + async with pool.acquire() as conn:
  +     row = await conn.fetchrow(
  +         "SELECT * FROM users WHERE id=$1", uid
  +     )

  > apply it

  claude ▸ Applied. Tests still pass.
    Want me to also switch the connection
    to a shared pool at module level?

  > _
TXT

# ── 6. Prep a fake music player ────────────────────────────────────
cat > ~/hero/music.sh <<'MSH'
#!/usr/bin/env bash
clear
cat <<'END'

  ♫  now playing
  ────────────────────────────────────────

    Aphex Twin — Xtal
    from Selected Ambient Works 85-92

  ────────────────────────────────────────

  ▶  02:31 ══════════▉─────────────  04:52

    ⤺ shuffle   ⟳ repeat   ♡ liked
END
# animate a subtle waveform so it isn't dead
while :; do
  for f in '▁ ▂ ▃ ▅ ▆ ▇ ▆ ▅ ▃ ▂' '▂ ▃ ▅ ▇ ▆ ▅ ▃ ▂ ▁ ▂' '▃ ▅ ▆ ▇ ▅ ▃ ▂ ▁ ▂ ▃'; do
    tput cup 13 4 2>/dev/null || printf '\r'
    printf '  %s  ' "$f"
    sleep 0.35
  done
done
MSH
chmod +x ~/hero/music.sh

# ── 7. Prep a fake game (retro tui) ────────────────────────────────
cat > ~/hero/game.sh <<'GSH'
#!/usr/bin/env bash
clear
cat <<'END'

  ▓▓▓▓▓▓  VINVADERS  ▓▓▓▓▓▓          score  01340
  ────────────────────────────────    lives  ▮▮▮

     👾    👾    👾    👾    👾

        👾    👾    👾    👾

           👾    👾    👾

                 ✦
                 ▲
   ═══════════════════════════════

     hi-score:  25100      wave 03
END
sleep 999
GSH
chmod +x ~/hero/game.sh

# ── 8. Launch the hero scene: 4-5 panes tiled by dwindle ───────────
log "launching hero panes"
hyprctl dispatch workspace 9
sleep 1

# Pane 1: chromium at vinos.computer (upper area)
hyprctl dispatch exec "chromium --new-window --no-default-browser-check https://vinos.computer"
sleep 8

# Pane 2: nvim on agent.py (code editor)
hyprctl dispatch exec "foot -T 'nvim · agent.py' -e nvim ~/hero/agent.py"
sleep 3

# Pane 3: vinos-ai chat mock
hyprctl dispatch exec "foot -T 'vinos-ai' -e bash -c 'cat ~/hero/ai-chat.txt; read'"
sleep 2

# Pane 4: btop (system monitor)
hyprctl dispatch exec "foot -T btop -e btop"
sleep 2

# Pane 5: music player mock
hyprctl dispatch exec "foot -T music -e bash ~/hero/music.sh"
sleep 2

# Settle
sleep 4

log "shot hero-agentic"
shot hero-agentic

log "scene done"
SCENE
chmod +x "$SHARE/scene.sh"

# Copy the updated waybar config into the share so the scene can apply
# it live (otherwise the running ISO still uses the baked-in one).
if [[ -f "$ROOT_DIR/config/waybar/config.jsonc" ]]; then
  cp "$ROOT_DIR/config/waybar/config.jsonc" "$SHARE/waybar-config.jsonc"
fi

log "share dir: $SHARE"
log "booting $(basename "$ISO") with 9p share — will run scene inside guest"

KVM_ARGS=()
[[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]] && KVM_ARGS+=(--device /dev/kvm)

# Guest fetches scene from mounted 9p share and runs it. To trigger the
# fetch, we HMP-sendkey Super+Return to open a foot terminal on the
# already-logged-in vin session, then type a single bootstrap command.
docker run --rm "${KVM_ARGS[@]}" \
  -v "$ISO":/iso.iso:ro \
  -v "$SHARE":/share \
  -v "$OUT":/out \
  "$IMG" \
  bash -euo pipefail -c '
    ACCEL=tcg; [[ -c /dev/kvm ]] && ACCEL="kvm:tcg"
    mkfifo /tmp/hmp.in
    ( sleep 1800 > /tmp/hmp.in ) & hmp_holder=$!
    qemu-system-x86_64 \
      -m 6G -smp 3 -machine accel=$ACCEL \
      -cdrom /iso.iso -boot order=d,menu=off \
      -display none -vga std \
      -nic user,model=virtio-net-pci \
      -fsdev local,security_model=passthrough,id=fsdev0,path=/share \
      -device virtio-9p-pci,fsdev=fsdev0,mount_tag=vinoshare \
      -serial file:/out/hero-serial.log \
      -monitor stdio -no-reboot \
      < /tmp/hmp.in > /tmp/hmp.out 2>&1 &
    qpid=$!

    hmp() { echo "$*" > /tmp/hmp.in; sleep 0.2; }
    type_char() {
      case "$1" in
        " ")  hmp "sendkey spc" ;;
        "-")  hmp "sendkey minus" ;;
        "_")  hmp "sendkey shift-minus" ;;
        ".")  hmp "sendkey dot" ;;
        "/")  hmp "sendkey slash" ;;
        ":")  hmp "sendkey shift-semicolon" ;;
        ";")  hmp "sendkey semicolon" ;;
        ",")  hmp "sendkey comma" ;;
        "|")  hmp "sendkey shift-backslash" ;;
        "=")  hmp "sendkey equal" ;;
        "+")  hmp "sendkey shift-equal" ;;
        "&")  hmp "sendkey shift-7" ;;
        "!")  hmp "sendkey shift-1" ;;
        "@")  hmp "sendkey shift-2" ;;
        "\"") hmp "sendkey shift-apostrophe" ;;
        "\x27") hmp "sendkey apostrophe" ;;
        "(") hmp "sendkey shift-9" ;;
        ")") hmp "sendkey shift-0" ;;
        [A-Z]) hmp "sendkey shift-$(echo "$1" | tr A-Z a-z)" ;;
        [0-9a-z]) hmp "sendkey $1" ;;
        *) echo "SKIP: $1" >&2 ;;
      esac
      sleep 0.04
    }
    type_str() {
      local s="$1" i
      for (( i=0; i<${#s}; i++ )); do type_char "${s:$i:1}"; done
    }

    # Wait 180s for Hyprland to settle
    echo "[hero-inside] waiting 180s for Hyprland to settle"
    sleep 180

    # Mount the 9p share inside the guest — do this via Super+Return foot
    hmp "sendkey meta_l-ret"
    sleep 4

    # Type: sudo mkdir -p /mnt/host && sudo mount -t 9p -o trans=virtio,version=9p2000.L vinoshare /mnt/host && bash /mnt/host/scene.sh 2>&1 | tee /mnt/host/scene.log
    CMD="sudo mkdir -p /mnt/host && sudo mount -t 9p -o trans=virtio,version=9p2000.L vinoshare /mnt/host && bash /mnt/host/scene.sh 2>&1 | tee /mnt/host/scene.log"
    echo "[hero-inside] typing bootstrap"
    type_str "$CMD"
    hmp "sendkey ret"

    # Wait for scene to run: 3-5 min pacman + launch + settle.
    # Total budget: 10 min to be safe.
    echo "[hero-inside] waiting 10 min for scene to complete"
    for i in $(seq 1 120); do
      # Check whether hero-agentic shot has landed
      if [[ -f /share/shots/hero-agentic.png ]]; then
        echo "[hero-inside] hero-agentic.png landed after ${i}0s of poll"
        break
      fi
      sleep 5
    done

    # Give it 8 more seconds to flush
    sleep 8

    hmp "quit"
    wait $qpid 2>/dev/null || true
    kill $hmp_holder 2>/dev/null || true
    ls -la /share/shots/*.png 2>&1 || echo "no shots produced"
  '

log "shots produced:"
ls -la "$SHARE/shots/" 2>/dev/null

# Copy shots back into site/static/img/screenshots/
if compgen -G "$SHARE/shots/*.png" >/dev/null; then
  cp "$SHARE/shots/"*.png "$OUT/"
  # Fix ownership
  docker run --rm -v "$OUT":/o archlinux:latest chown -R "$(id -u):$(id -g)" /o
  log "copied to $OUT"
  ls -la "$OUT"
else
  die "no PNGs in $SHARE/shots — check $SHARE/scene.log"
fi
