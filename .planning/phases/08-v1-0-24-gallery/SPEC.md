# Phase 08 — v1.0.24: Routine gallery

**Type:** release · **Depends on:** 07 · **Ships as:** `vinos-1.0.24-x86_64.iso` + site update
**Duration:** 5 days · **Requirements:** R3, R18

## Goal
10 pre-shipped routines + community gallery on vinos.computer + install command.

## Scope (in)
- 5 new system-default routines (total: 10) — categories: dev, ops, research, writing, personal
- `site/content/routines/` — gallery page with search + tags + submit-your-own form
- `bin/vinos-routine install <slug>` — pulls TOML from gallery, verifies signature, installs to `~/.vinos/routines/`
- Per-routine waybar widget (shows next run time + last output)
- Signature scheme — routines signed with vinOS-owned key; unsigned = warning at install

## Scope (out)
- Community moderation policy (out-of-scope for 1.0.24; add in 1.0.25 with legal review)
- Payment or premium routine tier (no monetization in 1.0.x line)

## Human checkpoints
1. Each new system-default routine (each is a code+config change)
2. Gallery submission moderation policy (public-facing)
3. Signature key rotation policy (security-affecting)

## Ship gate
QA-1–8 + **QA-12 (80/20 escalation accuracy on 100-run test suite)**.

## Deliverables
- 5 new TOMLs under `configs/vinos/routines/` (system defaults)
- New `bin/vinos-routine-install`
- New `site/content/routines/` (gallery + submission page)
- New waybar module `vinos-waybar-routine-next.py`
- New `configs/vinos/keys/routines-signing.pub` (public key ships in ISO)
