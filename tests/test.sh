#!/usr/bin/env bash
# tests/test.sh — vinOS acceptance test. M1 only exercises --dry-run;
# M2+ will run install.sh --skip 02 inside a disposable Arch container.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

echo "== M1: dry-run plan (base only) =="
./install.sh --dry-run

echo
echo "== M1: dry-run plan (with overlays/example) =="
./install.sh --dry-run --overlay overlays/example

echo
echo "== M1: dry-run plan (--skip 02) =="
./install.sh --dry-run --skip 02

echo
echo "M1 dry-run smoke test: OK"
