# vinOS Roadmap

> **This file is a stub.** The authoritative roadmap lives elsewhere.

## For the master plan

Read **[docs/v2/PLAN-2026-08-03.md](./PLAN-2026-08-03.md)** — the current 12-week ship queue from v1.0.19 through v1.0.28 dual-edition GA.

## For the executable phase queue

Read **[.planning/ROADMAP.md](../../.planning/ROADMAP.md)** — the GSD-driven phase list with per-phase SPEC.md at `.planning/phases/NN-slug/`.

## For historical context

The prior roadmap (v2.0.5 era) was superseded 2026-08-03. It stopped at v2.0.7 and listed "Forking Omarchy" as a non-goal — both since reversed:
- We ship v1.0.19+ next, not v2.0.x
- Omarchy is now vendored at `omarchy/` as a git subtree, pinned to 3.8.4 (see `docs/v2/ARCHITECTURE.md` Layer 2)

The prior roadmap contents are preserved in `git log docs/v2/ROADMAP.md` for archaeological purposes.

## Version lines

| Line | Purpose | Status |
|---|---|---|
| v1.0.x | Current dev + ship line (v1.0.18 baseline, ships v1.0.19 through v1.0.28 GA) | Active |
| v1.1.0 | Permanent archival gold copy (2026-07 T2-verified) | Frozen forever |
| v2.x | Experimental branch parked as `experiments/2.1.0-2026-08-03` — LUKS + Omarchy + AI pill work that will be re-planned freshly on top of v1.0.18 | Parked |

## Why the redirect

The master plan changes faster than a single doc could. Keeping ROADMAP.md as a stub with pointers means:
1. No stale-info trap ("what does the roadmap say?" → always the current PLAN doc)
2. GSD phase execution reads from `.planning/ROADMAP.md` (its native format)
3. Human-readable rationale lives in `PLAN-2026-08-03.md` (the source of truth)

If you're contributing to vinOS or evaluating it: **read `PLAN-2026-08-03.md` first.**
