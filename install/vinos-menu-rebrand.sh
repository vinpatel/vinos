#!/usr/bin/env bash
# vinos-menu-rebrand.sh — post-vendor rewriter that rebrands the
# installed omarchy-menu.jsonc from Omarchy names to vinOS names.
#
# The vendored source in configs/omarchy/ stays untouched (Rule:
# "Omarchy configs verbatim + thin overlay 2026-07-22"). This script
# runs after 03-configs.sh has copied the jsonc to
# /usr/share/omarchy/default/omarchy/omarchy-menu.jsonc, and does two
# in-place substitutions on the installed copy only:
#
#   "action":"omarchy-<name>   →   "action":"vinos-<name>
#   "label":"Omarchy           →   "label":"vinOS
#
# Substitutions are narrowed to jsonc keys so we don't touch shell
# fragments that reference internal helpers (e.g. `omarchy-hw-laptop`
# inside a `when:` clause stays as-is; those internal helpers keep
# their omarchy-* names because users never see or type them).
#
# Only actions we've actually shipped a wrapper for get rewritten —
# unshipped actions keep the omarchy-* name so the menu keeps working.
# The wrapper set is the source of truth: whatever lives at
# /usr/local/bin/vinos-<name> is eligible for rewrite.
#
# Idempotent: running twice is a no-op because vinos-* → vinos-* is a
# nop.
#
# When VINOS_ROOT is set (iso/build.sh), rewrites the copy under that
# prefix.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

MENU="$(_rootpath /usr/share/omarchy/default/omarchy/omarchy-menu.jsonc)"
LOCAL_BIN="$(_rootpath /usr/local/bin)"

[[ -f "$MENU" ]] || { log "vinos-menu-rebrand: no $MENU — skipping"; exit 0; }
[[ -d "$LOCAL_BIN" ]] || { log "vinos-menu-rebrand: no $LOCAL_BIN — skipping"; exit 0; }

# Discover which vinos-* wrappers actually exist. For each, if the
# corresponding "action":"omarchy-<name>" appears in the jsonc, rewrite
# it to "action":"vinos-<name>".
_rewrote=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cp -a "$MENU" "$tmp"

for wrapper in "$LOCAL_BIN"/vinos-*; do
  [[ -e "$wrapper" ]] || continue
  name="${wrapper##*/vinos-}"
  # Only rewrite actions where the omarchy analog is actually referenced.
  if grep -q "\"action\":\"omarchy-${name}[\" ]" "$tmp" 2>/dev/null; then
    # Match omarchy-<name> followed by quote (bare command) or space (args).
    sed -i "s|\"action\":\"omarchy-${name}\"|\"action\":\"vinos-${name}\"|g" "$tmp"
    sed -i "s|\"action\":\"omarchy-${name} |\"action\":\"vinos-${name} |g" "$tmp"
    _rewrote=$((_rewrote + 1))
  fi
done

# Label rebrand: any user-facing "Omarchy" label becomes "vinOS".
sed -i 's|"label":"Omarchy"|"label":"vinOS"|g' "$tmp"
sed -i 's|"label":"Omarchy |"label":"vinOS |g' "$tmp"

if ! cmp -s "$tmp" "$MENU"; then
  _sudo install -m 0644 "$tmp" "$MENU"
  log "vinos-menu-rebrand: rewrote $_rewrote action(s) + labels in $MENU"
else
  log "vinos-menu-rebrand: no changes needed in $MENU"
fi
