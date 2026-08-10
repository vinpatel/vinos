#!/usr/bin/env bash
# tests/test.sh — vinOS acceptance test.
# Scope through M4: static guardrails + dry-run smoke + headless container
# install (install.sh --skip 02) executed twice for idempotency, os-release
# and vinos-doctor assertions, then a third run with --overlay overlays/
# example asserting §6 (cowsay installed + overlay-applied marker in
# ~/.config/fastfetch/config.jsonc).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

fail() { printf '\n\033[1;31mFAIL:\033[0m %s\n' "$*" >&2; exit 1; }

echo "== unit test suites (tests/*.test.sh) =="
if ! bash tests/all.sh; then
  fail "unit test suites failed — fix before running container acceptance"
fi

echo
echo "== guardrail: Rule 1 (no graphical operations outside 02-desktop.sh) =="
# Rule 1's spirit: scripts must work headless. We flag graphical
# operations (hyprland/waybar/etc. commands being invoked), not text
# mentions in comments or file-drop paths. 06-hardware.sh writes
# GPU driver env files that Hyprland/wlroots read at compositor
# start — the write itself is headless (no display required), so it
# is exempt. Comments (leading #) are also exempt.
if grep -rInE '^[^#]*\b(hyprland|waybar|wofi)\b' install/ --exclude=02-desktop.sh --exclude=06-hardware.sh; then
  fail "graphical reference found outside install/02-desktop.sh + 06-hardware.sh"
fi
echo "OK"

echo
echo "== guardrail: Rule 2 (base does not reference overlay paths) =="
if grep -rInE 'overlays/' install/ install.sh lib/; then
  fail "base file references overlays/"
fi
echo "OK"

echo
echo "== dry-run plan (base only) =="
./install.sh --dry-run

echo
echo "== dry-run plan (with overlays/example) =="
overlay_plan="$(./install.sh --dry-run --overlay overlays/example)"
printf '%s\n' "$overlay_plan"
# §6: overlay script must appear after 05-branding in the ordered plan.
script_lines="$(printf '%s\n' "$overlay_plan" | grep -E '\.sh   \[')"
last_base_line="$(printf '%s\n' "$script_lines" | grep -n '05-branding.sh' | tail -n1 | cut -d: -f1)"
overlay_line="$(printf '%s\n' "$script_lines" | grep -n '10-hello.sh'    | tail -n1 | cut -d: -f1)"
[[ -n "$last_base_line" && -n "$overlay_line" && "$overlay_line" -gt "$last_base_line" ]] \
  || fail "overlay script must be listed after 05-branding.sh"
# §6: overlay config must appear after base in the copy order (overlay wins).
config_lines="$(printf '%s\n' "$overlay_plan" | awk '/Config copy order/{f=1;next} /Skipped:|dry-run:/{f=0} f')"
base_cfg="$(printf '%s\n' "$config_lines" | grep -n '\[base\]'    | tail -n1 | cut -d: -f1)"
over_cfg="$(printf '%s\n' "$config_lines" | grep -n '\[overlay:' | tail -n1 | cut -d: -f1)"
[[ -n "$base_cfg" && -n "$over_cfg" && "$over_cfg" -gt "$base_cfg" ]] \
  || fail "overlay config source must be listed after base in copy order"

echo
echo "== dry-run plan (--skip 02) =="
./install.sh --dry-run --skip 02

if [[ "${VINOS_TEST_SKIP_DOCKER:-0}" == "1" ]]; then
  echo
  echo "VINOS_TEST_SKIP_DOCKER=1 — stopping before container run"
  exit 0
fi

command -v docker >/dev/null 2>&1 || fail "docker not found; install docker or set VINOS_TEST_SKIP_DOCKER=1"

IMAGE="${VINOS_TEST_IMAGE:-archlinux:latest}"

echo
echo "== container install: $IMAGE, install.sh --skip 02, run twice + doctor =="
docker run --rm \
  -v "$REPO":/vinos-src:ro \
  -e VINOS_ENABLE_SSH="${VINOS_ENABLE_SSH:-0}" \
  "$IMAGE" \
  bash -euo pipefail -c '
    pacman -Sy --needed --noconfirm sudo git
    useradd -m -G wheel vin
    install -d -m 0750 /etc/sudoers.d
    echo "vin ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/vin
    chmod 0440 /etc/sudoers.d/vin
    cp -a /vinos-src /home/vin/vinos
    chown -R vin:vin /home/vin/vinos
    # Snapshot the working tree so the test copy looks like a clean deployed
    # clone (vinos-doctor treats uncommitted changes as FAIL by design).
    sudo -u vin -H git -C /home/vin/vinos -c user.email=test@vinos -c user.name=test add -A
    sudo -u vin -H git -C /home/vin/vinos -c user.email=test@vinos -c user.name=test commit --allow-empty -m "test snapshot" >/dev/null
    echo
    echo "---- run 1 ----"
    sudo -u vin -H bash -lc "cd ~/vinos && ./install.sh --skip 02"
    echo
    echo "---- run 2 (idempotency) ----"
    sudo -u vin -H bash -lc "cd ~/vinos && ./install.sh --skip 02"
    echo
    echo "---- M3: /etc/os-release identity ----"
    grep -E "^(NAME|PRETTY_NAME|ID|ID_LIKE|VERSION_ID)=" /etc/os-release
    grep -q "^NAME=\"vinOS\"" /etc/os-release || { echo "os-release NAME check failed"; exit 1; }
    echo
    echo "---- M3: vinos-doctor ----"
    sudo -u vin -H bash -lc "vinos-doctor"
    echo
    echo "---- M4: overlay run (--overlay overlays/example) ----"
    sudo -u vin -H bash -lc "cd ~/vinos && ./install.sh --skip 02 --overlay overlays/example"
    echo
    echo "---- M4: cowsay installed ----"
    pacman -Q cowsay
    echo
    echo "---- M4: overlay marker present in ~/.config/fastfetch/config.jsonc ----"
    grep -F "overlay-applied" /home/vin/.config/fastfetch/config.jsonc \
      || { echo "overlay marker missing — shadowing did not win"; exit 1; }
    echo
    echo "---- M4: vinos-doctor still green after overlay ----"
    sudo -u vin -H bash -lc "vinos-doctor"
  '

echo
echo "test: OK"
