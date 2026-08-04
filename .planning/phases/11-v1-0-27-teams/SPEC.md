# Phase 11 — v1.0.27: Team-shared routines

**Type:** release · **Depends on:** 10 · **Ships as:** `vinos-1.0.27-x86_64.iso` + Cloud 1.0.27
**Duration:** 7 days · **Requirements:** R3, R14

## Goal
Multi-tenant `vinos-routine`. Cross-machine ledger sync. Per-repo API keys.

## Scope (in)
- Ledger sync protocol — local SQLite ↔ shared PostgreSQL/Turso
- `~/.vinos/team.json` — team membership, shared ledger URL, per-agent-role key refs
- `vinos-routine team join <url>` + `team leave` + `team status`
- Per-repo `.vinos/keys.json` (git-ignored) with per-agent-role keys (executor / planner / reviewer)
- Aggregate budget across team members (opt-in)
- Multi-user waybar pill showing team-wide activity

## Scope (out)
- SSO / SAML — enterprise feature deferred to 1.0.29+
- Shared model hosting — each user brings their own inference endpoint
- Team-wide compliance dashboard — deferred

## Human checkpoints
1. Ledger sync schema (architecture-affecting)
2. Per-repo key storage design (security-affecting)
3. `team join` flow copy (public-facing)

## Ship gate
QA-1–15.

## Deliverables
- Modified `libexec/vinos-routine-run.py` for team ledger writes
- New `libexec/vinos-team-sync.py` (background sync daemon)
- New `bin/vinos-routine-team`
- New `docs/v2/TEAMS.md`
- Schema migration in `docs/v2/ledger-schema-v2.sql`
