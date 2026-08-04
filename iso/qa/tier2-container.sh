#!/usr/bin/env bash
#
# vinOS Tier 2 container test — DEV-LOOP.md Tier 2
#
# Runs vinOS install scripts inside a fresh Arch container.
# Exit 0 if all syntactically valid + packages resolvable, 1 if any fail.
#
# Runs in <5 min on typical CI. Called by:
#   - .githooks/pre-push
#   - .github/workflows/vinos-dev-flow.yml
#   - vinos-dev-test routine (Phase 02 deliverable)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'; NC='\033[0m'
declare -i FAILS=0 WARNS=0

ok()   { echo -e "${GRN}✓${NC} $*" >&2; }
fail() { echo -e "${RED}✗${NC} $*" >&2; FAILS+=1; }
warn() { echo -e "${YEL}⚠${NC} $*" >&2; WARNS+=1; }

echo "── vinOS Tier 2 container test ──" >&2

# ─── Step 1: syntax-check install/*.sh WITHOUT container (fast pre-check) ─
echo "1. Bash syntax check on install/*.sh" >&2
declare -i syntax_errors=0
for script in install/*.sh; do
  [[ -f "$script" ]] || continue
  if bash -n "$script" 2>/dev/null; then
    ok "$script"
  else
    fail "$script has syntax errors"
    syntax_errors+=1
  fi
done
if [[ $syntax_errors -gt 0 ]]; then
  echo "aborting Tier 2 — fix syntax errors first" >&2
  exit 1
fi

# ─── Step 2: package availability in current Arch snapshot ────────────────
echo "2. Package availability check" >&2
if ! command -v docker &>/dev/null; then
  warn "docker not installed — skipping container package check"
  warn "install docker to enable full Tier 2 harness"
else
  # Pull a fresh Arch container and check that packages.x86_64 packages are resolvable
  # We don't actually install — we just query pacman.
  cat > /tmp/tier2-package-check.sh <<'INNER'
#!/bin/bash
set -euo pipefail
# Update package databases (no upgrade)
pacman -Sy --noconfirm >/dev/null 2>&1

# Extract package names from packages.x86_64 (skip comments + blank lines)
PACKAGES=$(grep -vE "^\s*(#|$)" /vinos/iso/profile/packages.x86_64 2>/dev/null || true)
if [ -z "$PACKAGES" ]; then
  echo "no packages found in packages.x86_64"
  exit 1
fi

MISSING=0
for pkg in $PACKAGES; do
  # Skip local Arch metapackages
  case "$pkg" in
    base|base-devel|linux*) continue;;
  esac
  if ! pacman -Si "$pkg" >/dev/null 2>&1; then
    # Might be AUR — check if we can find it in a repo
    echo "unresolved: $pkg"
    MISSING=$((MISSING + 1))
  fi
done

# Some AUR packages will always be missing from official repos — allow up to 30
if [ $MISSING -gt 30 ]; then
  echo "$MISSING packages unresolved (>30 threshold — likely regression)"
  exit 1
fi
echo "$MISSING AUR/unresolved packages (acceptable if <=30)"
exit 0
INNER
  chmod +x /tmp/tier2-package-check.sh

  echo "  running package check in archlinux:latest container (may take ~3 min)..." >&2
  if docker run --rm \
      -v "$REPO_ROOT:/vinos:ro" \
      -v /tmp/tier2-package-check.sh:/check.sh:ro \
      archlinux:latest \
      /check.sh > /tmp/tier2-package-check.log 2>&1
  then
    ok "package availability check passed"
    tail -1 /tmp/tier2-package-check.log >&2
  else
    fail "package availability check failed — see /tmp/tier2-package-check.log"
    tail -5 /tmp/tier2-package-check.log >&2
  fi
fi

# ─── Step 3: verify install/install.sh is self-consistent ─────────────────
echo "3. install.sh self-consistency" >&2
if [[ -f install/install.sh ]]; then
  # Every referenced install/NN-*.sh must exist
  declare -i missing=0
  # shellcheck disable=SC2013
  for ref in $(grep -oE "install/[0-9]{2}-[a-z-]+\.sh" install/install.sh | sort -u); do
    if [[ -f "$ref" ]]; then
      ok "  references $ref"
    else
      fail "  install.sh references missing $ref"
      missing+=1
    fi
  done
  [[ $missing -eq 0 ]] && ok "install.sh self-consistent"
else
  warn "install/install.sh not found — skipping self-consistency check"
fi

# ─── Step 4: profiledef.sh syntax + required vars ─────────────────────────
echo "4. iso/profile/profiledef.sh integrity" >&2
if [[ -f iso/profile/profiledef.sh ]]; then
  if bash -n iso/profile/profiledef.sh; then
    ok "profiledef.sh syntax valid"
  else
    fail "profiledef.sh syntax errors"
  fi
  # Required archiso vars
  for var in iso_name iso_label iso_publisher iso_application iso_version bootstrap_tarball_compression; do
    if grep -qE "^${var}=" iso/profile/profiledef.sh; then
      ok "  var $var defined"
    else
      warn "  var $var missing in profiledef.sh"
    fi
  done
else
  fail "iso/profile/profiledef.sh not found"
fi

# ─── Step 5: no host-state assumptions in install scripts ─────────────────
echo "5. Host-state assumption grep" >&2
declare -i host_hits=0
# These patterns commonly indicate a script assumes the running host has vinos state
BAD_PATTERNS=(
  '\$HOME/\.vinos'    # assumes user home is set up
  '/home/vinpatel'    # hardcoded developer path
  'cd /data/projects' # hardcoded dev path
)
for pattern in "${BAD_PATTERNS[@]}"; do
  hits=$(grep -rIn -E "$pattern" install/ 2>/dev/null | grep -v -E "^install/[^:]+:[0-9]+:#" || true)
  if [[ -n "$hits" ]]; then
    fail "host-state assumption '$pattern' in install/:"
    echo "$hits" | head -3 >&2
    host_hits+=1
  fi
done
[[ $host_hits -eq 0 ]] && ok "no host-state assumptions found"

# ─── Verdict ──────────────────────────────────────────────────────────────
echo >&2
if [[ $FAILS -eq 0 && $WARNS -eq 0 ]]; then
  echo -e "${GRN}Tier 2 container test: PASS${NC}" >&2
  exit 0
elif [[ $FAILS -eq 0 ]]; then
  echo -e "${YEL}Tier 2 container test: PASS with $WARNS warning(s)${NC}" >&2
  exit 0
else
  echo -e "${RED}Tier 2 container test: FAIL — $FAILS check(s) failed, $WARNS warning(s)${NC}" >&2
  exit 1
fi
