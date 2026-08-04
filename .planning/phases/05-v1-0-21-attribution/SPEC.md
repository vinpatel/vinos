# Phase 05 — v1.0.21: Attribution audit

**Type:** release · **Depends on:** 04 · **Ships as:** `vinos-1.0.21-x86_64.iso`
**Duration:** 3 days · **Requirements:** R5, R10

## Goal
Every user-facing surface attribution-clean. Legal review of MIT+MIT+GPL composition. CI check prevents regression.

## Scope (in)
- Grep audit — no "Omarchy" outside `NOTICES.md` + `site/content/about/_index.md` line + install-time NOTICES display
- `NOTICES.md` updated with every newly discovered dependency (packages.x86_64 diff since 1.0.18)
- `SECURITY.md` cross-links to NOTICES for supply-chain surface
- `.github/workflows/attribution-check.yml` — CI grep that fails PRs adding stray unattributed strings
- Legal review artifact: one-page memo saved to `docs/v2/legal-review-2026-<month>.md`

## Scope (out)
- Any functional code change
- Adding new NOTICES for dependencies we don't actually ship

## Human checkpoints
1. Legal review sign-off (out-of-band with counsel or equivalent)
2. Every About-page copy change (public-facing)

## Ship gate
QA-1, QA-2, QA-3, **QA-5 (must be clean)**, QA-6.

## Deliverables
- Modified `NOTICES.md`
- Modified `site/content/about/_index.md` (single-line heritage attribution)
- New `.github/workflows/attribution-check.yml`
- New `docs/v2/legal-review-2026-<month>.md`
- Verification: `grep -rIn "Omarchy" configs/ bin/ iso/ install/ docs/ site/content/ | grep -v -E "NOTICES\.md|about/_index\.md" | wc -l` returns 0
