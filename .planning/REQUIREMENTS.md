# vinOS Requirements Catalog — M1 (Dual-edition GA)

Every requirement has an ID. Every phase in `.planning/ROADMAP.md` references the IDs it satisfies. Plans and SPECs cite the ID they close.

## R1 · Baseline immovability
v1.0.18 is the floor. No future ship regresses any QA-1–6 assertion valid at 1.0.18. Enforced by `iso/qa/verify-shipped-iso.sh`.

## R2 · Two editions from one tree
Developer (ISO) and Headless (container + nspawn + Helm) build from the same source tree. No forks per edition. Enforced by CI matrix in Phase 10.

## R3 · 80/20 model split
80% of dev-flow inference on local models (Qwen3-Coder + Kimi-Linear via Ollama). 20% escalates to Claude via LiteLLM. Measured by ledger. Target: 80% ±5% locally resolved on QA-12 test suite.

## R4 · Sovereign compute
No telemetry, no accounts, no forced network calls at install or first-boot. API keys are BYO from user. Enforced by strace-based test in Phase 10.

## R5 · Full attribution
Every user-facing surface either says "vinOS" or is in NOTICES.md. Enforced by grep-based CI check.

## R6 · Reproducible builds
Same source → same sha256 across independent build machines. Target v1.0.28. Enforced by Phase 12 gate.

## R7 · Multi-hardware
T2 Mac + 3 non-Mac laptops as certified targets before v1.0.23. Certified means: boots to desktop + completes canary routine + no red-banner errors. Logged in `iso/qa/hardware-matrix.md`.

## R8 · Backup discipline
Every ship archived to R2 + local NAS with sha256, retained forever for tagged releases. Documented in `docs/v2/BACKUP.md`.

## R9 · Rollback path
Every ship rollback-able via one of: BTRFS snapper, kernel choice (multi-kernel Limine), ISO re-flash. Documented in `docs/v2/BACKUP.md`.

## R10 · Omarchy fork
Omarchy vendored via git subtree at `omarchy/`, pinned per ISO. LKG tag `omarchy-lkg-<date>` maintained. Quarterly bump discipline. **HARD RULE:** no inline edits to `omarchy/`.

## R11 · Arch snapshot pinning
Every ISO built against a specific Arch snapshot URL, retained on R2 for 12 months. Snapshot URL written to `/etc/vinos-release` at build time.

## R12 · LUKS default (from v1.0.20)
Installer defaults to recommending LUKS on laptops; TPM2 opt-in via flag. Non-LUKS install requires explicit `--no-luks` flag.

## R13 · Sandbox
Agent tools run via bwrap with whitelist-only file access + network gating. Enforced by QA-14 adversarial test.

## R14 · Budget enforcement
Every routine has per-run and per-day caps in USD. Ledger enforces ±$0.01 accuracy. Verified by QA-13.

## R15 · Human checkpoints
8 change classes require explicit ACK recorded in ledger (see `docs/v2/PLAN-2026-08-03.md` §5.3):
1. Version tag creation
2. `main` force-push
3. `SECURITY.md` changes
4. `install/` or `iso/profile/` changes
5. Public-facing copy
6. Sponsor / licensing changes
7. Budget cap changes
8. Model swaps

Verified by QA-15.

## R16 · 30-day fleet uptime
Reference Headless deployment on Hetzner ≥99.9% over 30 days before public v1.0.28 launch. Verified by QA-16.

## R17 · Security disclosure
`SECURITY.md` published at repo root. 90-day CVE patch SLA. Verified by QA-17.

## R18 · Escalation router
80% of routine invocations resolve locally ±5%. Escalations that COULD have been local (self-report confidence >0.9) < 5% false-positive rate. Verified by QA-12.

## R19 · GSD-driven ships
Every phase runs through `/gsd-plan-phase N` → `/gsd-execute-phase N` → `/gsd-audit-milestone` at M1 close. No off-book releases.

## R20 · Public launch prerequisites
All success criteria (see `docs/v2/PLAN-2026-08-03.md` §11) green before v1.0.28 public launch.

---

## Requirement → Phase coverage matrix

| Req | Covered by phases |
|---|---|
| R1 | 01 (Capture), enforced 03+ |
| R2 | 07, 10, 12 |
| R3 | 02, 08 |
| R4 | 10 |
| R5 | 03, 05, 09 |
| R6 | 12 |
| R7 | 06 |
| R8 | 01, 03 |
| R9 | 03, 04 |
| R10 | 05 |
| R11 | 04, 05 |
| R12 | 04 |
| R13 | 07 |
| R14 | 02, 11 |
| R15 | 02, 03 |
| R16 | 10, 12 |
| R17 | 03 |
| R18 | 02, 08 |
| R19 | 01–12 (all) |
| R20 | 12 |
