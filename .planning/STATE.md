# vinOS Project State

**As of:** 2026-08-03
**Baseline:** v1.0.18 (untagged as of this file — Phase 01 fixes)
**Current phase:** 01 (Capture)
**Active milestone:** M1 — Dual-edition GA (target v1.0.28)

## Version line

- **v1.1.0** — permanent archival gold copy (T2 wifi verified). NEVER overwrite.
- **v1.0.18** — Phase A CLOSED baseline. First working install-to-disk. NOT yet tagged in git (Phase 01 fixes).
- **v1.0.19** — next ship. Docs freeze + backup discipline. Built entirely on top of Omarchy.
- **v2.1.0** — experimental branch, PARKED. Not merged. Features re-planned from clean 1.0.18.

## Team

- Lead: Vin Patel (vinpatel.pro@gmail.com)
- Autonomous dev (planned): local Qwen3-Coder + Kimi-Linear (via Ollama) as 80% executor; Claude Sonnet/Opus (via Anthropic API) as 20% planner/reviewer. Routed through LiteLLM proxy on `http://localhost:4000`.

## Repo layout

- `origin/main` — current HEAD contains 2.1.0 experimental work; Phase 01 preserves it in `experiments/2.1.0-2026-08-03` then resets `main` to v1.0.18.
- `omarchy/` — git subtree, pinned Omarchy 3.8.4. Never edited in place.
- `configs/vinos/` — vinOS overlay configs (never inline-edit `omarchy/`)
- `bin/` — 130 `vinos-*` wrappers
- `libexec/` — routine executor + ledger
- `iso/` — archiso profile + QA harness (`oneshot.sh` + `verify-shipped-iso.sh`)
- `docs/v2/` — design specs + this plan

## Hardware inventory (dev server, 2026-08-03)

- CPU-only (no GPU)
- 125 GB RAM
- 1.6 TB free disk
- Arch Linux, rolling
- Ollama 0.24.0 running
- Python 3.14.5 + venv at `~/.vinos-venv/`
- LiteLLM 1.95 + anthropic SDK installed in venv

## Model inventory

Installed (Ollama):
- `qwen3-coder:30b` (18 GB) — GSD executor + researcher
- `qwen2.5-coder:7b` (4.7 GB) — GSD checker
- `qwen2.5-coder:32b` (19 GB) — alternate executor
- `kimi-code:latest` (30 GB, Kimi-Linear-48B-A3B-Instruct-Q4_K_M) — local Kimi variant, 3B active per token (pull completed 2026-08-03)

Not installed (unusable on this hardware):
- Kimi-K2.7-Code full quants (300+ GB, would disk-mmap at 0.3 tok/s)
- Kimi-K3 (700+ GB)

Cloud API (via LiteLLM):
- Claude Sonnet 4.6 → `vinos-planner`, `vinos-reviewer`
- Claude Opus 4.7 → `vinos-architect`
- OpenRouter Kimi K2.7-Code → `vinos-kimi` (on-demand only, needs OPENROUTER_API_KEY)

## Constraints (immovable)

1. v1.0.18 is the floor. No future ship regresses any harness assertion valid at 1.0.18.
2. Omarchy 3.8.4 pinned. No inline edits to `omarchy/`.
3. Attribution audit-clean required for public claims (NOTICES.md is source of truth).
4. Human checkpoints mandatory on 8 change classes (see docs/v2/PLAN-2026-08-03.md §5.3).
5. All 12 phases run through /gsd-plan-phase + /gsd-execute-phase + /gsd-audit-milestone.
6. LUKS default from v1.0.20 onward.
7. Two editions from one tree — no forks per edition.
