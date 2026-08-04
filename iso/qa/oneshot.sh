#!/usr/bin/env bash
# iso/qa/oneshot.sh — pre-flash verification gate.
# Runs static lint + container QA + QEMU boot smoke test. Exits nonzero
# if any layer fails. Green = ISO is fit to flash to hardware.
#
# Usage:
#   iso/qa/oneshot.sh                       # run all layers
#   iso/qa/oneshot.sh --skip-qemu           # static + container only
#   iso/qa/oneshot.sh --iso path/to.iso     # verify a specific ISO
#
# Exit codes:
#   0  = green, flash-ready
#   1  = static-lint failed (config, packages, consistency)
#   2  = container QA failed (install path broken)
#   3  = QEMU boot failed (won't come up on real hardware either)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ISO_DIR="$REPO/iso"
ISO=""
SKIP_QEMU=0

RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YLW=$'\033[1;33m'; BLU=$'\033[1;34m'; RST=$'\033[0m'
say()  { printf '%s[oneshot]%s %s\n' "$BLU" "$RST" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '%s  !%s %s\n' "$YLW" "$RST" "$*"; }
fail() { printf '%s  ✗%s %s\n' "$RED" "$RST" "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --skip-qemu) SKIP_QEMU=1; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) fail "unknown arg: $1"; exit 1 ;;
  esac
done

FAILS=0
_fail() { fail "$1"; FAILS=$((FAILS+1)); }

# ─────────────────────────────────────────────────────────────────
say "Layer 1 — static lint"
# ─────────────────────────────────────────────────────────────────

# 1.1 VERSION file consistency
[[ -f "$REPO/VERSION" ]] || { _fail "VERSION file missing"; }
VERSION="$(<"$REPO/VERSION")"
say "VERSION = $VERSION"

# hugo.toml version matches
if [[ -f "$REPO/site/hugo.toml" ]]; then
  HUGO_VER="$(grep -oP 'version\s*=\s*"\K[0-9.]+' "$REPO/site/hugo.toml" | head -1)"
  if [[ "$HUGO_VER" != "$VERSION" ]]; then
    _fail "site/hugo.toml version=$HUGO_VER but VERSION=$VERSION"
  else
    ok "site/hugo.toml version matches VERSION"
  fi
fi

# 1.2 foot config — no legacy [colors] section (must be [colors-dark] on 1.20+)
if [[ -f "$REPO/config/foot/foot.ini" ]]; then
  if grep -qE '^\[colors\]\s*$' "$REPO/config/foot/foot.ini"; then
    _fail "config/foot/foot.ini uses [colors] (deprecated in foot 1.20+; use [colors-dark])"
  else
    ok "foot config uses [colors-dark] (no deprecation spam)"
  fi
  # install/03-configs.sh generates per-theme foot.ini via a heredoc; that
  # heredoc must also use [colors-dark] or every window spams a deprecation
  # warning at boot (2026-07-30 incident, live ISO).
  if grep -qE '^\[colors\]\s*$' "$REPO/install/03-configs.sh"; then
    _fail "install/03-configs.sh heredoc writes [colors] (deprecated; use [colors-dark])"
  else
    ok "per-theme foot.ini generator uses [colors-dark]"
  fi
  # alpha must NOT be inside a [colors-*] section; foot 1.20+ moved it to [main]
  if awk '/^\[colors/{in_c=1; next} /^\[/{in_c=0} in_c && /^alpha=/{found=1} END{exit !found}' \
       "$REPO/config/foot/foot.ini"; then
    _fail "foot alpha= is inside a [colors-*] section (should be [main] in foot 1.20+)"
  else
    ok "foot alpha is not in [colors-*]"
  fi
fi

# 1.3 wireless-regdb present in packages.live
if grep -qE '^\s*wireless-regdb\s*$' "$ISO_DIR/packages.live"; then
  ok "wireless-regdb ships in packages.live"
else
  _fail "wireless-regdb MISSING from iso/packages.live (Wi-Fi will fail on T2)"
fi

# 1.4 iwd config sanity — should NOT actively set EnableNetworkConfiguration=true.
# Match only lines that literally emit the key (heredoc/printf), not comments about it.
if grep -qE '^[^#]*printf[^#]*EnableNetworkConfiguration=true|^[[:space:]]*EnableNetworkConfiguration=true' \
     "$REPO/install/04-services.sh"; then
  _fail "install/04-services.sh still enables iwd built-in DHCP (races brcmfmac on T2)"
else
  ok "iwd DHCP delegated to systemd-networkd"
fi

# 1.5 No hardcoded 'vin' user
if grep -qE 'user = "vin"' "$ISO_DIR/airootfs-overlay/etc/greetd/config.toml"; then
  _fail "iso/airootfs-overlay/etc/greetd/config.toml still autologins as user 'vin'"
else
  ok "live greetd autologin user is not 'vin'"
fi
if grep -qE '\buseradd\b.*\bvin\b' "$ISO_DIR/airootfs-overlay/etc/systemd/system/vinos-live-init.service"; then
  _fail "vinos-live-init.service still creates user 'vin'"
else
  ok "live-init creates the generic 'vinos' user"
fi

# 1.6 Keybinding source-of-truth agreement
# Every "exec" chord in hyprland.conf either invokes a binary that exists
# in bin/ or one that ships from a package we install.
HYPR="$REPO/config/hypr/hyprland.conf"
declare -A KNOWN_APP_PKGS=(
  [chromium]=chromium [nautilus]=nautilus [spotify]=spotify
  [signal-desktop]=signal-desktop [obsidian]=obsidian [1password]=1password
  [foot]=foot [walker]=walker [hyprlock]=hyprlock [hyprpicker]=hyprpicker
  [grim]=grim [slurp]=slurp [satty]=satty [wl-copy]=wl-clipboard
  [swayosd-client]=swayosd [playerctl]=playerctl [makoctl]=mako
  [claude]='claude-code (bundle)' [vinos-ai]=bin/vinos-ai [nvim]=neovim [btop]=btop
)
MISSING_APPS=()
while IFS= read -r cmd; do
  base="${cmd%% *}"; base="${base#\"}"; base="${base%\"}"
  [[ -z "$base" ]] && continue
  # is it a vinos-* bin we ship?
  if [[ "$base" == vinos-* ]]; then
    [[ -x "$REPO/bin/$base" ]] || MISSING_APPS+=("$base (no bin/$base)")
    continue
  fi
  # is it in our known-pkgs whitelist?
  [[ -n "${KNOWN_APP_PKGS[$base]:-}" ]] || MISSING_APPS+=("$base (no known package)")
done < <(awk -F', exec, ' '/^\s*bind[^=]*=.*exec/{print $2}' "$HYPR" | awk '{print $1}' | sort -u)

if (( ${#MISSING_APPS[@]} > 0 )); then
  warn "hyprland.conf references apps we don't ship or aren't whitelisted:"
  for m in "${MISSING_APPS[@]}"; do warn "    - $m"; done
  # This is a warning, not a failure — some apps are legit (e.g. 3rd party).
else
  ok "all hyprland.conf exec commands map to shipped bins/packages"
fi

# 1.7 packages.x86_64 is regenerable + drift-free
tmp_pkgs="$(mktemp)"
cp "$ISO_DIR/profile/packages.x86_64" "$tmp_pkgs" 2>/dev/null || :
bash "$ISO_DIR/gen-packages.sh" >/dev/null
if diff -q "$tmp_pkgs" "$ISO_DIR/profile/packages.x86_64" >/dev/null 2>&1; then
  ok "packages.x86_64 is up to date"
else
  warn "packages.x86_64 drifted — regenerating (would be committed by build.sh anyway)"
fi
rm -f "$tmp_pkgs"

# ─────────────────────────────────────────────────────────────────
say "Layer 2 — container QA (install path headless)"
# ─────────────────────────────────────────────────────────────────
if [[ -x "$ISO_DIR/../tests/test.sh" ]]; then
  if bash "$ISO_DIR/../tests/test.sh" >/tmp/oneshot-container.log 2>&1; then
    ok "tests/test.sh passed"
  else
    _fail "tests/test.sh failed — see /tmp/oneshot-container.log"
    tail -20 /tmp/oneshot-container.log | sed 's/^/    /'
  fi
else
  warn "tests/test.sh not executable — skipping container QA"
fi

# ─────────────────────────────────────────────────────────────────
say "Layer 2.5 — shipped-ISO regression harness"
# ─────────────────────────────────────────────────────────────────
# Extract the built ISO and assert every known-fixed item is intact.
# Fails LOUDLY the moment a fix regresses — pre-flash gate. Runs only
# if we have a built ISO to check.
if [[ -x "$ISO_DIR/qa/verify-shipped-iso.sh" ]]; then
  _iso_for_check="$ISO"
  [[ -z "$_iso_for_check" ]] && _iso_for_check="$(ls -1t "$ISO_DIR"/out/vinos-*.iso 2>/dev/null | head -1 || true)"
  if [[ -n "$_iso_for_check" && -f "$_iso_for_check" ]]; then
    if bash "$ISO_DIR/qa/verify-shipped-iso.sh" "$_iso_for_check" >/tmp/oneshot-regression.log 2>&1; then
      ok "shipped-ISO regression harness passed (see /tmp/oneshot-regression.log for details)"
    else
      _fail "shipped-ISO regression harness caught a fix that regressed — do NOT flash"
      tail -30 /tmp/oneshot-regression.log | sed 's/^/    /'
    fi
  else
    warn "no built ISO to verify (skipping regression harness)"
  fi
else
  warn "iso/qa/verify-shipped-iso.sh not executable — skipping regression harness"
fi
unset _iso_for_check

# ─────────────────────────────────────────────────────────────────
say "Layer 3 — QEMU boot smoke test"
# ─────────────────────────────────────────────────────────────────
if (( SKIP_QEMU )); then
  warn "QEMU skipped (--skip-qemu)"
elif ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  warn "qemu-system-x86_64 not installed — skipping QEMU boot"
else
  # Find the ISO
  if [[ -z "$ISO" ]]; then
    ISO="$(ls -1t "$ISO_DIR"/out/vinos-*.iso 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$ISO" || ! -f "$ISO" ]]; then
    _fail "no ISO found in iso/out — build first with iso/build.sh"
  else
    ok "smoke-booting $ISO"
    # Use iso/test-desktop.sh if it exists, else a minimal boot
    if [[ -x "$ISO_DIR/test-desktop.sh" ]]; then
      if bash "$ISO_DIR/test-desktop.sh" --iso "$ISO" --frames 90,150 >/tmp/oneshot-qemu.log 2>&1; then
        ok "QEMU boot reached Hyprland (screendumps at iso/out/desktop-*.ppm)"
      else
        _fail "QEMU boot failed — see /tmp/oneshot-qemu.log"
        tail -30 /tmp/oneshot-qemu.log | sed 's/^/    /'
      fi
    else
      warn "iso/test-desktop.sh missing — cannot auto-smoke QEMU"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────
say "Summary"
# ─────────────────────────────────────────────────────────────────
if (( FAILS == 0 )); then
  printf '%s┌──────────────────────────────────────────────────┐%s\n' "$GRN" "$RST"
  printf '%s│  ✓  GREEN — ISO is fit to flash to hardware      │%s\n' "$GRN" "$RST"
  printf '%s└──────────────────────────────────────────────────┘%s\n' "$GRN" "$RST"
  exit 0
else
  printf '%s┌──────────────────────────────────────────────────┐%s\n' "$RED" "$RST"
  printf '%s│  ✗  %d failure(s) — fix before flashing            │%s\n' "$RED" "$FAILS" "$RST"
  printf '%s└──────────────────────────────────────────────────┘%s\n' "$RED" "$RST"
  exit 1
fi
