# Phase 03 — v1.0.19: Docs + Backup Discipline (training run)

**Type:** release (docs-only, no functional changes)
**Depends on:** 01, 02
**Ships as:** `vinos-1.0.19-x86_64.iso`
**Duration:** 5 days
**Requirements satisfied:** R1, R5, R8, R17, R19

## Goal

Ship a docs-freeze release. Prove the 24x7 autonomous dev flow works end-to-end on a low-stakes release before v1.0.20 (LUKS) touches security-critical code. Every design decision documented. Backup discipline machinery in place.

## Scope (in)

- Commit `docs/v2/PLAN-2026-08-03.md` (already exists — verify it matches ship state)
- Commit `docs/v2/DEV-LOOP.md` (already exists — iteration pyramid)
- Commit `docs/v2/KERNEL.md` (already exists — 5-tier kernel control)
- Write `docs/v2/ARCHITECTURE.md` — rewrite existing to reflect four-layer stack + fork policies
- Write `docs/v2/BACKUP.md` — capture the strategy from PLAN §8
- Write `docs/v2/TESTING.md` — capture QA gates + regression harness from PLAN §7
- Write `SECURITY.md` at repo root — public security posture (PLAN §9)
- Rewrite `docs/v2/ROADMAP.md` to be a stub redirecting to PLAN + `.planning/ROADMAP.md`
- Add `iso/qa/verify-baseline.sh` — asserts backup discipline (tags exist, archive branches exist, config symlinks correct)
- Add `iso/qa/tier1-lint.sh` — static-lint harness from DEV-LOOP.md Tier 1
- Add `iso/qa/tier2-container.sh` — container install-script test from DEV-LOOP.md Tier 2
- Update site landing to reference `SECURITY.md` and `docs/v2/PLAN-2026-08-03.md`
- Build ISO from unchanged v1.0.18 code + updated docs → tag v1.0.19

## Scope (out)

- Any code change under `install/`, `bin/`, `configs/vinos/`, `iso/profile/`, `libexec/`
- Any dependency version bump
- Any new package in `iso/profile/packages.x86_64`
- Any Omarchy subtree pull
- Any kernel config change

**Rationale:** v1.0.19 is the TRAINING RUN for the autonomous dev flow. Zero functional risk. If autonomous flow ships a broken v1.0.19, we know it's the flow, not the code.

## Edge coverage

- **covered:** all 5 new docs committed AND git-log-visible
- **covered:** `verify-baseline.sh` present, executable, exits 0
- **covered:** `tier1-lint.sh` runs in <30s and exits 0 on current tree
- **covered:** `tier2-container.sh` runs in <5min and exits 0
- **covered:** no user-facing "Omarchy" string outside NOTICES.md + About page (grep-tested)
- **covered:** ISO sha256 matches build log
- **backstop:** manual verification that site landing reflects new docs
- **backstop:** manual QEMU boot of v1.0.19 ISO (Tier 3 pass)
- **unresolved:** whether the site landing needs a redesign or copy-only update (planner assumption: copy-only; Hallmark theme unchanged)

## Autonomous flow test (this is what v1.0.19 proves)

Success = the flow completes v1.0.19 with:
1. **Kimi/Qwen (executor)** authored all doc drafts
2. **Claude Sonnet (reviewer)** flagged ≥3 issues in doc drafts before merge
3. **Human ACK** recorded on the version tag commit
4. **Ledger** shows ≥80% of routine invocations resolved without escalation
5. **Budget** stayed under $5 for the full phase (no LUKS-class complexity yet)
6. **Zero regressions** in `iso/qa/verify-shipped-iso.sh`

If any of the 6 fail, we PAUSE and diagnose before Phase 04 (LUKS) — that's high-stakes and needs the flow to be proven.

## Human checkpoints

1. Before merging each new doc PR (`docs/v2/ARCHITECTURE.md`, `BACKUP.md`, `TESTING.md`, `SECURITY.md`)
2. Before the v1.0.19 git tag creation
3. Before publishing the ISO to `dl.vinos.computer/releases/v1.0.19/`

## Ship gate

- QA-1 Reproducible build — sha256 across 2 machines
- QA-2 Regression harness clean — `verify-shipped-iso.sh` exit 0
- QA-3 Boots on verified hw — T2 Mac + one non-Mac (Tier 5 burn is OK here since it's the first real ship of the new flow)
- QA-5 No unattributed strings — grep pass
- QA-6 Oneshot verifier — 3-layer pass

## Deliverables (file list)

New files:
- `docs/v2/ARCHITECTURE.md`
- `docs/v2/BACKUP.md`
- `docs/v2/TESTING.md`
- `SECURITY.md` (repo root)
- `iso/qa/verify-baseline.sh`
- `iso/qa/tier1-lint.sh`
- `iso/qa/tier2-container.sh`

Rewritten:
- `docs/v2/ROADMAP.md` (stub redirect)
- `site/content/_index.md` (landing update — copy only)

Already-written (verify committed):
- `docs/v2/PLAN-2026-08-03.md`
- `docs/v2/DEV-LOOP.md`
- `docs/v2/KERNEL.md`
- `.planning/*`
- `configs/vinos/litellm/*`

## Post-ship

- Tag `v1.0.19` on the commit that passes ship gate
- Publish ISO to `dl.vinos.computer/releases/v1.0.19/vinos-1.0.19-x86_64.iso` + `sha256sums.txt`
- Post release notes (drafted by Claude via `vinos-dev-release-notes`, polished by Vin)
- Run `/gsd-audit-uat` to confirm all UAT items closed
- Kick off Phase 04 (LUKS)
