# Phase 02 — 24x7 dev flow bootstrap

**Type:** infrastructure (routine files + service configs, no ISO)
**Depends on:** 01
**Ships as:** commits to `configs/vinos/routines/dev/*.toml` and `configs/vinos/systemd/`
**Duration:** 4 days
**Requirements satisfied:** R3, R14, R15, R18

## Goal

vinOS builds vinOS. Ten dev routines defined and firing on their triggers. Ledger + budget enforcement operational. First real automated PR review posted.

## Scope (in)

- Author 10 TOML routine files (list in `docs/v2/PLAN-2026-08-03.md` §5.5):
  - `vinos-dev-lint.toml`
  - `vinos-dev-test.toml`
  - `vinos-dev-code-review.toml`
  - `vinos-dev-arch-review.toml`
  - `vinos-dev-security-review.toml`
  - `vinos-dev-docs-sync.toml`
  - `vinos-dev-changelog.toml`
  - `vinos-dev-release-notes.toml`
  - `vinos-dev-qa-nightly.toml`
  - `vinos-dev-triage.toml`
- Extend `libexec/vinos-routine-run.py` to enforce budget via LiteLLM's `max_budget` + our own SQLite ledger
- Wire git hooks (`.git/hooks/pre-commit`, `pre-push`) to invoke lint + test routines locally
- Wire GitHub Actions to invoke code-review + arch-review + security-review on PR events
- systemd user units for scheduled routines (`vinos-dev-qa-nightly.service` + `.timer`, `vinos-dev-triage.service` + `.timer`)
- Ledger schema at `~/.vinos/dev-flow-ledger.sqlite` with columns: run_id, timestamp, routine, model, prompt_tokens, completion_tokens, cost_usd, escalated, human_ack

## Scope (out)

- Any change to the routine EXECUTION engine — reuse existing `libexec/vinos-routine-run.py`
- Any change to Ollama or LiteLLM config (Phase 01 owns those)
- Any user-facing UI (waybar pill etc. — that's Phase 08)

## Edge coverage

- **covered:** 10 TOML files exist, valid, referenced by their triggers
- **covered:** ledger schema exists, has at least 100 rows after burn-in period
- **covered:** budget enforcement stops a routine at $0.50 per run (verified by adversarial test — a routine that tries to spam Claude Opus)
- **covered:** 80/20 split measured on the burn-in period: ≥80% of invocations resolved locally ±5%
- **covered:** GitHub Actions posts a real PR review from `vinos-dev-code-review` on a test PR
- **backstop:** nightly QA routine fires at 03:00 and posts to Discord webhook
- **unresolved:** whether Discord webhook URL is user-provided or auto-provisioned (planner assumption: user provides, we template)

## Human checkpoints

1. First PR reviewed by autonomous flow — Vin reads the review and either merges or rejects with feedback
2. First auto-drafted changelog — Vin edits before merge
3. Budget cap first tripped — Vin confirms whether to raise cap or investigate why routine cost so much

## Ship gate

- Ledger records ≥100 routine invocations with 80/20 split ±5%
- First real PR review posted successfully
- Nightly QA routine fires at least once
- All 10 TOML files pass Tier 1 lint

## Deliverables (file list)

New:
- `configs/vinos/routines/dev/vinos-dev-lint.toml`
- `configs/vinos/routines/dev/vinos-dev-test.toml`
- `configs/vinos/routines/dev/vinos-dev-code-review.toml`
- `configs/vinos/routines/dev/vinos-dev-arch-review.toml`
- `configs/vinos/routines/dev/vinos-dev-security-review.toml`
- `configs/vinos/routines/dev/vinos-dev-docs-sync.toml`
- `configs/vinos/routines/dev/vinos-dev-changelog.toml`
- `configs/vinos/routines/dev/vinos-dev-release-notes.toml`
- `configs/vinos/routines/dev/vinos-dev-qa-nightly.toml`
- `configs/vinos/routines/dev/vinos-dev-triage.toml`
- `configs/vinos/systemd/vinos-dev-qa-nightly.service`
- `configs/vinos/systemd/vinos-dev-qa-nightly.timer`
- `configs/vinos/systemd/vinos-dev-triage.service`
- `configs/vinos/systemd/vinos-dev-triage.timer`
- `.github/workflows/vinos-dev-flow.yml` (triggers routines on PR events)
- `.git/hooks/pre-commit` (calls lint routine)
- `.git/hooks/pre-push` (calls test routine)

Modified:
- `libexec/vinos-routine-run.py` (ledger writes + budget enforcement — additive, no behavior change to non-dev routines)
