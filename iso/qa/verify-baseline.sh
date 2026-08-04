#!/usr/bin/env bash
#
# vinOS baseline discipline verifier — asserts backup + git + config invariants
# valid at any point on the v1.0.x line.
#
# Runs standalone AND as part of iso/qa/oneshot.sh (Layer 2.4).
# Exit 0 if all checks pass, 1 if any fail.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'; NC='\033[0m'
declare -i FAILS=0 WARNS=0

ok()   { echo -e "${GRN}✓${NC} $*" >&2; }
fail() { echo -e "${RED}✗${NC} $*" >&2; FAILS+=1; }
warn() { echo -e "${YEL}⚠${NC} $*" >&2; WARNS+=1; }

echo "── vinOS baseline discipline ──" >&2

# 1. v1.0.18 tag exists (locally at minimum)
if git rev-parse -q --verify "refs/tags/v1.0.18" >/dev/null; then
  ok "git tag v1.0.18 exists"
else
  fail "git tag v1.0.18 missing — Phase 01 deliverable"
fi

# 2. Archive branch exists
if git rev-parse -q --verify "refs/heads/archive/pre-gsd-2026-08-03" >/dev/null; then
  ok "archive/pre-gsd-2026-08-03 branch exists"
else
  fail "archive/pre-gsd-2026-08-03 branch missing"
fi

# 3. Experiments branch exists
if git rev-parse -q --verify "refs/heads/experiments/2.1.0-2026-08-03" >/dev/null; then
  ok "experiments/2.1.0-2026-08-03 branch exists"
else
  fail "experiments/2.1.0-2026-08-03 branch missing"
fi

# 4. Omarchy subtree present + pinned
if [[ -d omarchy && -f omarchy/README.md ]]; then
  ok "omarchy/ subtree present"
else
  fail "omarchy/ subtree missing or empty"
fi

# 5. .planning/ structure complete
for f in STATE.md ROADMAP.md REQUIREMENTS.md config.json; do
  if [[ -f ".planning/$f" ]]; then
    ok ".planning/$f present"
  else
    fail ".planning/$f missing"
  fi
done

# 6. Phase SPECs present
declare -i phase_count=0
for d in .planning/phases/*/; do
  if [[ -f "$d/SPEC.md" ]]; then
    phase_count+=1
  fi
done
if [[ $phase_count -ge 12 ]]; then
  ok ".planning/phases/ has $phase_count SPECs (>=12 expected)"
else
  fail ".planning/phases/ has $phase_count SPECs (12 expected — Phase 01 deliverable)"
fi

# 7. Master plan doc + supporting docs
for doc in docs/v2/PLAN-2026-08-03.md docs/v2/DEV-LOOP.md docs/v2/KERNEL.md; do
  if [[ -f "$doc" ]]; then
    ok "$doc present"
  else
    fail "$doc missing"
  fi
done

# 8. Phase 03 deliverables (this is a self-check for the phase we're in)
for doc in docs/v2/ARCHITECTURE.md docs/v2/BACKUP.md docs/v2/TESTING.md SECURITY.md; do
  if [[ -f "$doc" ]]; then
    ok "$doc present"
  else
    warn "$doc missing — Phase 03 deliverable"
  fi
done

# 9. LiteLLM proxy config
if [[ -f configs/vinos/litellm/proxy.yaml ]]; then
  ok "configs/vinos/litellm/proxy.yaml present"
else
  fail "configs/vinos/litellm/proxy.yaml missing"
fi

# 10. Dev-flow routine seed
if [[ -f configs/vinos/routines/dev/vinos-dev-lint.toml ]]; then
  ok "configs/vinos/routines/dev/vinos-dev-lint.toml present"
else
  fail "configs/vinos/routines/dev/vinos-dev-lint.toml missing"
fi

# 11. Git hooks installed
if [[ "$(git config --get core.hooksPath 2>/dev/null || echo)" == ".githooks" ]]; then
  ok "git core.hooksPath = .githooks"
else
  warn "git core.hooksPath not set to .githooks — run: git config core.hooksPath .githooks"
fi
if [[ -x .githooks/pre-commit ]]; then
  ok ".githooks/pre-commit exists + executable"
else
  fail ".githooks/pre-commit missing or not executable"
fi

# 12. Config symlinks resolve (only checked if symlinks exist)
for pair in \
    "$HOME/.hermes/config.json:.planning/config.json" \
    "$HOME/.gsd/config.json:.planning/config.json" \
    "$HOME/.litellm/config.yaml:configs/vinos/litellm/proxy.yaml"
do
  link="${pair%:*}"
  target_rel="${pair#*:}"
  target_abs="$REPO_ROOT/$target_rel"
  if [[ -L "$link" ]]; then
    resolved="$(readlink -f "$link")"
    if [[ "$resolved" == "$target_abs" ]]; then
      ok "symlink $link → $target_rel"
    else
      warn "symlink $link resolves to $resolved (expected $target_abs)"
    fi
  else
    warn "symlink $link not present (will re-create at first use)"
  fi
done

# 13. No ISOs in iso/out/ (belong in ~/vinos-iso-archive/ + R2)
if compgen -G "iso/out/*.iso" >/dev/null 2>&1; then
  warn "ISOs in iso/out/ — should be in ~/vinos-iso-archive/ + R2 after ship"
else
  ok "iso/out/ has no ISO artifacts (correct)"
fi

# 14. Build logs archived
log_count=$(find iso/archive/build-logs/ -maxdepth 1 -name "build-*.log" 2>/dev/null | wc -l)
if [[ $log_count -ge 1 ]]; then
  ok "iso/archive/build-logs/ has $log_count log(s)"
else
  warn "iso/archive/build-logs/ empty — first ship on v1.0.x line?"
fi

# 15. .gitignore protects binary artifacts
if grep -qE "^iso/archive/isos/|^\*\.iso" .gitignore 2>/dev/null; then
  ok ".gitignore protects binary ISO artifacts"
else
  warn ".gitignore missing iso/archive/isos/ or *.iso entry"
fi

# ─── Verdict ──────────────────────────────────────────────────────────────
echo >&2
if [[ $FAILS -eq 0 && $WARNS -eq 0 ]]; then
  echo -e "${GRN}baseline discipline: PASS${NC}" >&2
  exit 0
elif [[ $FAILS -eq 0 ]]; then
  echo -e "${YEL}baseline discipline: PASS with $WARNS warning(s)${NC}" >&2
  exit 0
else
  echo -e "${RED}baseline discipline: FAIL — $FAILS check(s) failed, $WARNS warning(s)${NC}" >&2
  exit 1
fi
