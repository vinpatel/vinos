#!/usr/bin/env bash
# vinOS orchestrator. Builds an ordered plan of base + overlay install scripts,
# with overlay files shadowing same-named base files (Rule 2). --dry-run prints
# the plan and exits without executing.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"

DRY_RUN=0
OVERLAYS=()
SKIPS=()

usage() {
  cat <<EOF
Usage: install.sh [--dry-run] [--overlay PATH]... [--skip NN]...
  --dry-run       Print the ordered plan and exit; execute nothing.
  --overlay PATH  Apply a fork overlay directory (repeatable).
  --skip NN       Skip any script whose filename begins with NN- (repeatable).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --overlay) [[ $# -ge 2 ]] || die "--overlay needs a path"; OVERLAYS+=("$2"); shift 2 ;;
    --skip)    [[ $# -ge 2 ]] || die "--skip needs NN";        SKIPS+=("$2");    shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

declare -A SEEN=()
PLAN=()   # each entry: "path|source-tag"

add_scripts() {
  local dir="$1" tag="$2" f base i skipped
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    skipped=0
    for s in "${SKIPS[@]:-}"; do
      [[ -n "${s:-}" && "$base" == "$s"-* ]] && skipped=1 && break
    done
    (( skipped )) && continue
    if [[ -n "${SEEN[$base]:-}" ]]; then
      for i in "${!PLAN[@]}"; do
        if [[ "$(basename "${PLAN[$i]%%|*}")" == "$base" ]]; then
          PLAN[$i]="$f|$tag"; break
        fi
      done
    else
      PLAN+=("$f|$tag"); SEEN[$base]=1
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' -print0 | sort -z)
}

add_scripts "$REPO/install" "base"
for o in "${OVERLAYS[@]:-}"; do
  [[ -n "${o:-}" ]] || continue
  [[ -d "$o" ]] || die "overlay not found: $o"
  add_scripts "$o/install" "overlay:$o"
done

CONFIG_SRCS=("$REPO/config|base")
for o in "${OVERLAYS[@]:-}"; do
  [[ -n "${o:-}" && -d "$o/config" ]] && CONFIG_SRCS+=("$o/config|overlay:$o")
done

log "vinOS install plan"
printf '  Scripts (%d):\n' "${#PLAN[@]}"
i=1; for e in "${PLAN[@]:-}"; do
  [[ -n "${e:-}" ]] || continue
  printf '    %2d. %s   [%s]\n' "$i" "${e%%|*}" "${e##*|}"; ((i++))
done
printf '  Config copy order (%d):\n' "${#CONFIG_SRCS[@]}"
i=1; for e in "${CONFIG_SRCS[@]}"; do
  printf '    %2d. %s   [%s]\n' "$i" "${e%%|*}" "${e##*|}"; ((i++))
done
[[ ${#SKIPS[@]} -gt 0 ]] && printf '  Skipped: %s\n' "${SKIPS[*]}"

if (( DRY_RUN )); then
  log "dry-run: no scripts executed"
  exit 0
fi

require_not_root

for e in "${PLAN[@]}"; do
  script="${e%%|*}"
  log "==> $script"
  if ! bash "$script"; then
    die "failed: $script — resume with: $0 --skip $(basename "$script" | cut -c1-2)"
  fi
done

for e in "${CONFIG_SRCS[@]}"; do
  copy_config "${e%%|*}"
done

log "vinOS install complete"
command -v fastfetch >/dev/null && fastfetch || true
