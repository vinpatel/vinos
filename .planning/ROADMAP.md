# vinOS Roadmap — Milestone M1 (Dual-edition GA)

**Cadence:** 1 phase per week, 12 phases, ~12 weeks total
**Model routing:** local Qwen/Kimi executor + Anthropic planner+reviewer via LiteLLM proxy
**Ship discipline:** every phase = 1 tagged release; small increments on v1.0.18 baseline

**Iteration model:** container → QEMU with persistent overlay → USB burn (only for hardware-specific issues). See `docs/v2/DEV-LOOP.md`.

## Milestones

### M1 · Dual-edition GA (target: 2026-11 · ~12 weeks from 2026-08-03)

Ship both Developer (ISO) and Headless (container) editions from one tree, all 17 QA gates green.

---

## Phases

### Phase 01: Capture (v1.0.18 baseline lock)
**Type:** infrastructure
**Depends on:** none
**Ships as:** git tag `v1.0.18` (retroactive), archive branches, `.planning/` init
**Duration:** 3 days
**Requirements:** R1, R8, R19

Goal: Everything backed up, `.planning/` initialized, LiteLLM+Kimi+Qwen live.

Deliverables:
- `git tag v1.0.18 <sha>` retroactive
- `experiments/2.1.0-2026-08-03` branch (preserves 2.1.0 work)
- `archive/pre-gsd-2026-08-03` branch (main HEAD snapshot)
- R2 sync of `docs/`, `iso/`, memory refs
- `.planning/` fully initialized (this file + STATE.md + REQUIREMENTS.md + config.json + all phase SPECs)
- LiteLLM proxy running + smoke test passes
- Kimi-Linear registered with Ollama as `kimi-code`

Ship gate: `/gsd-plan-phase 3` succeeds using LiteLLM-routed executor.

---

### Phase 02: 24x7 dev flow bootstrap
**Type:** infrastructure
**Depends on:** 01
**Ships as:** commits to `configs/vinos/routines/dev/*.toml` (no ISO)
**Duration:** 4 days
**Requirements:** R3, R14, R15, R18

Goal: vinOS builds vinOS. 10 dev routines defined + firing.

Deliverables:
- 10 TOML routine files under `configs/vinos/routines/dev/`
- Ledger schema in `~/.vinos/dev-flow-ledger.sqlite`
- Budget enforcement wire in `libexec/vinos-routine-run.py`
- First automated PR review posted by `vinos-dev-code-review`
- First automated changelog entry drafted by `vinos-dev-changelog`
- systemd user timers for scheduled routines

Ship gate: ledger records ≥100 routine invocations with 80/20 split ±5%.

---

### Phase 03: v1.0.19 — Docs + backup discipline
**Type:** release
**Depends on:** 02
**Ships as:** `vinos-1.0.19-x86_64.iso` (docs-only release, functionally same as 1.0.18)
**Duration:** 5 days
**Requirements:** R1, R5, R8, R17, R19

Goal: Ship a docs-freeze release. Every design decision documented. Training run for the autonomous flow.

Deliverables:
- Commit `docs/v2/PLAN-2026-08-03.md` (done)
- Write `docs/v2/ARCHITECTURE.md`
- Write `docs/v2/BACKUP.md`
- Write `docs/v2/TESTING.md`
- Write `docs/v2/DEV-LOOP.md` (iteration pyramid)
- Write `SECURITY.md` at repo root
- Rewrite `docs/v2/ROADMAP.md` to redirect to PLAN
- Add `iso/qa/verify-baseline.sh` (asserts backup discipline)
- Update site landing to reference `SECURITY.md`

Ship gate: QA-1, QA-2, QA-3, QA-5, QA-6.

---

### Phase 04: v1.0.20 — LUKS full-disk
**Type:** release
**Depends on:** 03
**Ships as:** `vinos-1.0.20-x86_64.iso`
**Duration:** 5 days
**Requirements:** R12

Goal: LUKS default recommendation, TPM2 opt-in, freshly implemented (NOT cherry-picked from 2.1.0 experimental — clean rebuild on v1.0.19).

Deliverables:
- `install/vinos-install-disk` gains `--luks`, `--no-luks`, `--luks-password`, `--luks-tpm2` flags
- Interactive prompt defaults to recommending LUKS on laptops
- QA-A1 assertion added to `verify-shipped-iso.sh`
- Install video captured in QEMU showing LUKS flow

Ship gate: QA-1–6 + QA-A1.

---

### Phase 05: v1.0.21 — Attribution audit
**Type:** release
**Depends on:** 04
**Ships as:** `vinos-1.0.21-x86_64.iso`
**Duration:** 3 days
**Requirements:** R5, R10

Goal: Every user-facing surface attribution-clean.

Deliverables:
- grep audit: no "Omarchy" outside `NOTICES.md` + About page
- `NOTICES.md` updated with any newly discovered deps
- Legal review of MIT + MIT + GPL composition
- CI check added to prevent regression

Ship gate: QA-5 clean.

---

### Phase 06: v1.0.22 — Hardware certification
**Type:** release
**Depends on:** 05
**Ships as:** `vinos-1.0.22-x86_64.iso`
**Duration:** 7 days (hardware-bound)
**Requirements:** R7

Goal: 3+ non-Mac boards certified in addition to T2 Mac.

Deliverables:
- ThinkPad X1 Carbon Gen 11+ verified
- Dell XPS 13 (2024) verified
- Framework 13 verified
- `iso/qa/hardware-matrix.md` populated with per-board test results
- Any hardware-specific fixes overlaid

Ship gate: QA-7 (multi-hardware) — 3+ boards boot + canary routine passes.

---

### Phase 07: v1.0.23 — Developer edition polish
**Type:** release
**Depends on:** 06
**Ships as:** `vinos-1.0.23-x86_64.iso`
**Duration:** 5 days
**Requirements:** R2

Goal: Beat Omarchy visibly on the agentic axis.

Deliverables:
- Hyprland `.conf` → `.lua` migration (per Hyprland 0.57 deprecation)
- Firejail profiles for browser + AI shell
- nwg-drawer as ⌥+Space default (full-screen icon grid)
- `vinos-update` command with snapshot-pinned upgrades

Ship gate: QA-1–7 + QA-8 (local agent latency < 5s p50).

---

### Phase 08: v1.0.24 — Routine gallery
**Type:** release
**Depends on:** 07
**Ships as:** `vinos-1.0.24-x86_64.iso`
**Duration:** 5 days
**Requirements:** R3, R18

Goal: 10 pre-shipped routines + community submission flow.

Deliverables:
- 5 new system-default routines (total 10)
- Community gallery page on vinos.computer
- `vinos-routine install <slug>` command
- Per-routine waybar widget

Ship gate: QA-12 (80/20 escalation accuracy) on the shipped routine set.

---

### Phase 09: v1.0.25 — Site + docs + video
**Type:** release
**Depends on:** 08
**Ships as:** `vinos-1.0.25-x86_64.iso` + site update
**Duration:** 5 days
**Requirements:** R5

Goal: Every page true, screenshots real, install video published.

Deliverables:
- 24 screenshots from booted 1.0.25 (replace SCREENSHOTS_NEEDED.md)
- MP4 install video (2–3 min) captured from QEMU
- Hallmark audit findings closed (per memory: 2 critical / 2 major / 3 minor)
- Site pages match reality

Ship gate: QA-1–8 + QA-12.

---

### Phase 10: v1.0.26 — Headless edition
**Type:** release (multi-artifact)
**Depends on:** 09
**Ships as:** Docker image + systemd-nspawn tarball + Helm chart
**Duration:** 10 days
**Requirements:** R2, R4

Goal: Same runtime, no desktop, on VPS or K8s.

Deliverables:
- `ghcr.io/vinpatel/vinos-cloud:1.0.26` (~200 MB compressed)
- `vinos-cloud-1.0.26.tar.zst` for nspawn
- `charts/vinos-agents/` Helm chart
- Cloud-init template for Hetzner / DigitalOcean / Fly.io
- Webhook sinks (Slack, Discord, generic HTTP POST)
- K8s CronJob-based scheduling as alternative

Ship gate: QA-9 (image size), QA-10 (idle power), QA-11 (K8s canary).

---

### Phase 11: v1.0.27 — Team-shared routines
**Type:** release
**Depends on:** 10
**Ships as:** `vinos-1.0.27-x86_64.iso` + updated Cloud image
**Duration:** 7 days
**Requirements:** R3, R14

Goal: Multi-tenant `vinos-routine`, shared ledger, per-repo API keys.

Deliverables:
- Ledger sync protocol (SQLite → shared PostgreSQL)
- Per-repo `.vinos/keys.json` (git-ignored) with per-agent-role keys
- `vinos-routine team` command

Ship gate: QA-1–15.

---

### Phase 12: v1.0.28 — Dual-edition GA
**Type:** release (public launch)
**Depends on:** 11
**Ships as:** `vinos-1.0.28-x86_64.iso` + Cloud 1.0.28
**Duration:** 5 days
**Requirements:** R6, R16, R20

Goal: Public launch. Both editions production-quality.

Deliverables:
- Reproducible build (QA-1 clean across 3 machines)
- SecureBoot signing (if key acquired; else deferred to 1.0.29)
- Sponsor deck sent (Anthropic first, GH Sponsors second, NLnet third)
- v1.1.0 archival memorial page on site
- Public launch (HN, r/archlinux, Anthropic dev community)
- 30-day fleet uptime target on reference Cloud deployment

Ship gate: QA-1 through QA-16, all green.

---

## Ship-gate quick reference

| Gate | Foundation | v1.0.20+ | Headless | Agentic |
|---|---|---|---|---|
| QA-1 Reproducible build | ✓ | ✓ | ✓ | — |
| QA-2 Regression harness clean | ✓ | ✓ | ✓ | — |
| QA-3 Boots on verified hw | ✓ | ✓ | — | — |
| QA-4 First-run to agent < 5min | ✓ | ✓ | — | — |
| QA-5 No unattributed strings | ✓ | ✓ | ✓ | — |
| QA-6 Oneshot verifier | ✓ | ✓ | — | — |
| QA-A1 LUKS enrollment | — | ✓ | — | — |
| QA-7 Multi-hardware | — | v1.0.22+ | — | — |
| QA-8 Local agent latency | — | v1.0.23+ | — | — |
| QA-9 Image size < 300MB | — | — | ✓ | — |
| QA-10 Idle power < 5W | — | — | ✓ | — |
| QA-11 K8s canary | — | — | ✓ | — |
| QA-12 80/20 accuracy | — | — | — | ✓ |
| QA-13 Budget accuracy | — | — | — | ✓ |
| QA-14 Sandbox resistance | — | — | — | ✓ |
| QA-15 Human checkpoint | — | — | — | ✓ |
| QA-16 30-day fleet uptime | — | — | — | v1.0.28 |
| QA-17 No CVE > 90 days | — | — | — | ongoing |
