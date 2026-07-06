#!/usr/bin/env bash
# tests/test.sh — vinOS acceptance test.
# Scope through M3: static guardrails + dry-run smoke + headless container
# install (install.sh --skip 02) executed twice to prove idempotency, then
# vinos-doctor + /etc/os-release assertions. Overlay assertion lands in M4.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

fail() { printf '\n\033[1;31mFAIL:\033[0m %s\n' "$*" >&2; exit 1; }

echo "== guardrail: Rule 1 (no graphical refs outside 02-desktop.sh) =="
if grep -rInE 'hyprland|wayland|waybar' install/ --exclude=02-desktop.sh; then
  fail "graphical reference found outside install/02-desktop.sh"
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
./install.sh --dry-run --overlay overlays/example

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
  '

echo
echo "test: OK"
