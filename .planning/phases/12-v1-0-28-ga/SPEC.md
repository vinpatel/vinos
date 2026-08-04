# Phase 12 — v1.0.28: Dual-edition GA

**Type:** release (public launch) · **Depends on:** 11
**Ships as:** `vinos-1.0.28-x86_64.iso` + Cloud 1.0.28 + sponsor deck + public launch
**Duration:** 5 days · **Requirements:** R6, R16, R20

## Goal
Public launch. Both editions production-quality. All 17 QA gates green. vinOS earns the "top of class agentic OS" claim.

## Scope (in)
- Reproducible builds — QA-1 clean across 3 independent build machines
- SecureBoot signing — if key acquired (contingent on Foundation cert or paid key); else deferred to 1.0.29
- v1.1.0 archival memorial page on site — permanent
- Sponsor deck sent — Anthropic first, GH Sponsors second, NLnet third
- Public launch execution:
  - HN post drafted + timed
  - r/archlinux post
  - Anthropic dev community post
  - Twitter/BlueSky launch thread
- Reference Cloud deployment on Hetzner — 30-day uptime target ≥99.9% (running since Phase 10)

## Scope (out)
- Any new feature — freeze from Phase 11 close
- Rebranding — brand stays as-is
- Redesign — theme stays

## Human checkpoints
1. Every launch surface (HN post, Reddit post, Twitter thread — ALL public-facing)
2. Sponsor deck content (business-critical)
3. SecureBoot key acquisition decision (one-way, expensive)
4. v1.0.28 tag creation (one-way, PUBLIC)
5. The launch button (one-way, PUBLIC)

## Ship gate
**QA-1 through QA-16, ALL green** (no waivers).

Plus all 10 success criteria from `docs/v2/PLAN-2026-08-03.md` §11:
1. Both editions ship from one tree ✓
2. QA-1–15 pass ✓
3. Docs match reality ✓
4. Reference Cloud ≥30 days ≥99.9% uptime ✓
5. ≥1 external routine in gallery ✓
6. ≥1 sponsor committed ✓
7. Attribution audit-clean ✓ (from Phase 05)
8. DR drill passed 2 quarters in a row ✓
9. 24x7 dev flow authored ≥50% of merged commits over 30 days ✓
10. Public launch executed ✓ (this phase)

## Deliverables
- Signed ISO + Cloud image
- `docs/v2/RELEASE-1.0.28.md` (release notes, human-polished)
- Sponsor deck at `docs/business/sponsor-deck-2026-<month>.pdf`
- Site launch banner
- All social posts published
- Post-launch retro at `docs/v2/retro-1.0.28.md` (1 week post-launch)

## After 1.0.28
Milestone M1 CLOSED. Next milestone (M2) TBD — options include:
- **M2a — Enterprise:** SSO/SAML, RBAC, air-gapped install, SOC2 track
- **M2b — NixOS variant:** declarative + atomic rollback for enterprise buyers
- **M2c — AgenticFlow integration:** deep couple with Vin's other project
- **M2d — Mobile companion:** paired mobile app for routine oversight

M2 planning kicks off ~2 weeks post-launch.
