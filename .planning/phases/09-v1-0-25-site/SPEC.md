# Phase 09 — v1.0.25: Site + docs + video

**Type:** release · **Depends on:** 08 · **Ships as:** `vinos-1.0.25-x86_64.iso` + site update
**Duration:** 5 days · **Requirements:** R5

## Goal
Every page true, screenshots real, install video published. Close Hallmark audit findings (2 critical / 2 major / 3 minor per memory).

## Scope (in)
- 24 screenshots from booted 1.0.25 replacing `SCREENSHOTS_NEEDED.md` placeholders
- MP4 install video (2–3 min) captured from QEMU showing: boot → live desktop → `vinos-install-disk` → LUKS enrollment → reboot → first-boot → first routine
- Hallmark audit findings closed — teal-logo-vs-rust-accent clash is the through-line
- Site pages match reality: /install, /models, /bundles, /for/{founders,engineers,enterprise,platform,researchers,mac,homelab,privacy,developers}
- New /docs pages: /docs/dev-loop (from DEV-LOOP.md), /docs/kernel (from KERNEL.md), /docs/security (from SECURITY.md)

## Scope (out)
- Redesign of Hallmark theme (stays Almanac)
- New brand palette (cosmos stays default)
- Any functional OS change

## Human checkpoints
1. Every site page copy change (public-facing)
2. Install video final polish (public-facing)
3. Hallmark audit finding closure verification (public-facing brand)

## Ship gate
QA-1–8 + QA-12 + manual site review for accuracy.

## Deliverables
- 24 PNG screenshots in `site/static/images/1.0.25/`
- MP4 at `site/static/videos/install-1.0.25.mp4`
- Modified site pages (all)
- New site pages for dev-loop, kernel, security
- Hallmark audit closure memo at `.hallmark/audit-closure-2026-<month>.md`
