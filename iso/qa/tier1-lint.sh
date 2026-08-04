#!/usr/bin/env bash
#
# vinOS Tier 1 static lint — DEV-LOOP.md Tier 1
#
# Runs in <30 seconds. Called by:
#   - .githooks/pre-commit
#   - .github/workflows/vinos-dev-flow.yml
#   - vinos-dev-lint routine (configs/vinos/routines/dev/vinos-dev-lint.toml)
#
# Modes (mutually exclusive):
#   --only shellcheck    Run only shellcheck
#   --only structured    Run only JSON/YAML/TOML validity checks
#   --only attribution   Run only the attribution grep
#   (no flag)            Run all three
#
# Exit 0 if all checks pass, 1 if any fail.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'; NC='\033[0m'
declare -i FAILS=0

MODE="${1:-all}"
if [[ "$MODE" == "--only" ]]; then
  MODE="${2:-all}"
fi

log()  { echo -e "$*" >&2; }
ok()   { log "${GRN}✓${NC} $*"; }
fail() { log "${RED}✗${NC} $*"; FAILS+=1; }
skip() { log "${YEL}·${NC} $* (skipped)"; }

# ─── Shellcheck ───────────────────────────────────────────────────────────
run_shellcheck() {
  log "── shellcheck ──"
  if ! command -v shellcheck &>/dev/null; then
    skip "shellcheck not installed"
    return
  fi
  local -a shell_files
  # Only lint files we own; skip omarchy/ subtree (upstream)
  mapfile -t shell_files < <(
    find install/ bin/ iso/qa/ .githooks/ configs/vinos/ \
      -type f \( -name "*.sh" -o -name "*.bash" \) 2>/dev/null | \
    grep -v -E "/omarchy/" || true
  )
  if [[ ${#shell_files[@]} -eq 0 ]]; then
    skip "no shell files found"
    return
  fi
  if shellcheck --shell=bash --severity=error "${shell_files[@]}" 2>&1; then
    ok "shellcheck: ${#shell_files[@]} files clean"
  else
    fail "shellcheck: errors found"
  fi
}

# ─── Structured file validity ─────────────────────────────────────────────
run_structured() {
  log "── structured file validity ──"

  # JSON
  local json_files json_errors=0
  mapfile -t json_files < <(
    find .planning/ configs/vinos/ .github/ -type f -name "*.json" 2>/dev/null | \
    grep -v -E "/node_modules/|/omarchy/" || true
  )
  for f in "${json_files[@]}"; do
    # Allow comments starting with $comment (JSON-with-comments convention we use)
    if ! jq . "$f" >/dev/null 2>&1; then
      fail "invalid JSON: $f"
      json_errors+=1
    fi
  done
  if [[ $json_errors -eq 0 && ${#json_files[@]} -gt 0 ]]; then
    ok "JSON: ${#json_files[@]} files valid"
  fi

  # YAML
  local yaml_files yaml_errors=0
  mapfile -t yaml_files < <(
    find configs/vinos/ .github/ -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | \
    grep -v -E "/omarchy/" || true
  )
  for f in "${yaml_files[@]}"; do
    if ! python3 -c "import yaml,sys; yaml.safe_load(open('$f'))" 2>/dev/null; then
      fail "invalid YAML: $f"
      yaml_errors+=1
    fi
  done
  if [[ $yaml_errors -eq 0 && ${#yaml_files[@]} -gt 0 ]]; then
    ok "YAML: ${#yaml_files[@]} files valid"
  fi

  # TOML
  local toml_files toml_errors=0
  mapfile -t toml_files < <(
    find configs/vinos/ -type f -name "*.toml" 2>/dev/null | \
    grep -v -E "/omarchy/" || true
  )
  for f in "${toml_files[@]}"; do
    if ! python3 -c "import tomllib,sys; tomllib.load(open('$f','rb'))" 2>/dev/null; then
      fail "invalid TOML: $f"
      toml_errors+=1
    fi
  done
  if [[ $toml_errors -eq 0 && ${#toml_files[@]} -gt 0 ]]; then
    ok "TOML: ${#toml_files[@]} files valid"
  fi
}

# ─── Attribution grep ─────────────────────────────────────────────────────
run_attribution() {
  log "── attribution grep ──"
  # "Omarchy" is legit in these paths — everywhere else it's a bug
  local allowed_paths=(
    "NOTICES.md"
    "SECURITY.md"
    "docs/v2/ARCHITECTURE.md"
    "docs/v2/PLAN-2026-08-03.md"
    "docs/v2/DEV-LOOP.md"
    "docs/v2/KERNEL.md"
    "docs/v2/BACKUP.md"
    "docs/v2/TESTING.md"
    "docs/v2/ROADMAP.md"
    "docs/v2/vinos-routine-spec.md"
    "docs/v2/vinos-routines-yaml-spec.md"
    "docs/v2/vinos-cloud-spec.md"
    "site/content/about/_index.md"
    "site/content/attribution.md"
    ".planning/"
    "README.md"
    "CONTRIBUTING.md"
    "CODE_OF_CONDUCT.md"
    "iso/archive/build-logs/"
  )
  local exclude_pattern
  exclude_pattern=$(printf "|%s" "${allowed_paths[@]}")
  exclude_pattern="${exclude_pattern:1}"

  local hits
  hits=$(grep -rIln "Omarchy" \
    --exclude-dir=omarchy \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=site/public \
    --exclude-dir=iso/out \
    configs/ bin/ iso/ install/ docs/ site/content/ overlays/ libexec/ 2>/dev/null | \
    grep -v -E "$exclude_pattern" || true)

  if [[ -z "$hits" ]]; then
    ok "attribution: user-facing surfaces clean"
  else
    fail "attribution: unexpected 'Omarchy' references:"
    echo "$hits" | head -10 >&2
    if [[ $(echo "$hits" | wc -l) -gt 10 ]]; then
      log "  ... and $(( $(echo "$hits" | wc -l) - 10 )) more"
    fi
  fi
}

# ─── Dispatch ─────────────────────────────────────────────────────────────
case "$MODE" in
  shellcheck)  run_shellcheck ;;
  structured)  run_structured ;;
  attribution) run_attribution ;;
  all)
    run_shellcheck
    run_structured
    run_attribution
    ;;
  *)
    log "usage: $0 [--only shellcheck|structured|attribution]"
    exit 2
    ;;
esac

if [[ $FAILS -eq 0 ]]; then
  log "${GRN}Tier 1 lint: PASS${NC}"
  exit 0
else
  log "${RED}Tier 1 lint: FAIL ($FAILS check(s) failed)${NC}"
  exit 1
fi
