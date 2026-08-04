# Phase 06 — v1.0.22: Hardware certification

**Type:** release · **Depends on:** 05 · **Ships as:** `vinos-1.0.22-x86_64.iso`
**Duration:** 7 days (hardware-bound) · **Requirements:** R7

## Goal
Three non-Mac boards certified in addition to T2 Mac. Note: per memory, hardware breadth is largely assumed via Omarchy base — this phase VERIFIES, doesn't develop from scratch.

## Scope (in)
- Test targets: ThinkPad X1 Carbon Gen 11+, Dell XPS 13 (2024), Framework 13
- Per-board test log — boot, install, LUKS, wifi, keyboard/trackpad, audio, sleep/resume, canary routine
- `iso/qa/hardware-matrix.md` — table with per-board pass/fail + tweaks required
- Any hardware-specific fixes overlaid as `configs/vinos/<board>/`
- Screenshots of each board's booted desktop for `site/content/for/hardware/`

## Scope (out)
- New hardware families (AMD Ryzen mobile, ARM) — deferred to 1.0.29+
- NVIDIA proprietary driver polish beyond ThinkPad testing (deferred)
- Any change that would regress T2 Mac support

## Human checkpoints
1. Adding a new `configs/vinos/<board>/` overlay (architecture-affecting)
2. Publishing hardware compatibility statements on site (public-facing)

## Ship gate
QA-1–6 + **QA-7 (3+ boards boot to desktop + complete canary routine)**.

## Deliverables
- New `iso/qa/hardware-matrix.md`
- New `configs/vinos/thinkpad/` (if any tweaks needed)
- New `configs/vinos/xps/` (if any tweaks needed)
- New `configs/vinos/framework/` (if any tweaks needed)
- New `site/content/for/hardware/` page with certified list
- 3 hardware boot screenshots
