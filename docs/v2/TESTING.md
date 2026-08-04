# vinOS Testing & QA

**Rule:** Every claim about vinOS is measurable. If we can't measure it, we can't claim it. The regression harness IS the immune system.

## The 5-tier iteration pyramid

Detailed in `docs/v2/DEV-LOOP.md`. Summary:

| Tier | What | Time | When |
|---|---|---|---|
| 1 | Static lint (shellcheck, JSON/YAML/TOML validity, attribution grep) | <30 s | Every commit (pre-commit hook) |
| 2 | Container install-script test | 30 s – 2 min | Every PR (GH Actions) |
| 3 | QEMU live-ISO boot + screendumps | 2–5 min | Per candidate build |
| 4 | QEMU persistent install (LUKS, first-boot, install flow) | 5–15 min | Per ship candidate |
| 5 | USB burn + real hardware | 15+ min | Only for hardware-specific behavior (T2, NVIDIA, real BIOS) |

Never skip a tier. Never burn USB for a bug Tier 4 could catch.

## QA gates — the 17 assertions

Each gate is a **measurable** check. `iso/qa/verify-shipped-iso.sh` adds one assertion per new gate, per phase. If the assertion doesn't exist in code, the gate can't count.

### Foundation gates (every ship must pass)

| Gate | Assertion | Where verified |
|---|---|---|
| **QA-1** | Reproducible build — sha256 of `vinos-<VER>-x86_64.iso` deterministic across 2 build machines | Manual until Phase 12 automation |
| **QA-2** | Regression harness clean — `iso/qa/verify-shipped-iso.sh` exit 0 | Every ship |
| **QA-3** | Boots on verified hardware — T2 Mac + one non-Mac, cold boot to login < 60 s | Manual + `iso/qa/oneshot.sh` QEMU layer |
| **QA-4** | First-run to agent < 5 min — flash → install → first `vinos-routine run` completes | Manual + timed |
| **QA-5** | No unattributed strings — user-facing = "vinOS" only (Omarchy allowed only in NOTICES + About page) | `iso/qa/tier1-lint.sh --only attribution` |
| **QA-6** | Oneshot verifier passes — `iso/qa/oneshot.sh` exit 0 | Every ship |

### Feature gates (add per phase)

| Gate | Assertion | First required |
|---|---|---|
| **QA-A1** | LUKS enrollment end-to-end (Tier 4 QEMU) | v1.0.20 (Phase 04) |
| **QA-7** | Multi-hardware — ≥3 non-Mac boards boot + canary routine | v1.0.22 (Phase 06) |
| **QA-8** | Local agent latency — Qwen3-Coder < 5 s p50 at 16 GB RAM baseline | v1.0.23 (Phase 07) |
| **QA-H1** | Hardened profile assertions — apparmor enforcing, hardened_malloc in ld.so.preload, nftables rules present | v1.0.26 (Phase 10) |
| **QA-H2** | Adversarial hardening test — attempts to write `/etc/`, escalate root, spawn unsigned binary all deny | v1.0.26 (Phase 10) |

### Headless gates (Phase 10 introduces)

| Gate | Assertion | Where verified |
|---|---|---|
| **QA-9** | Docker image size < 300 MB compressed | CI on tag |
| **QA-10** | Idle power < 5 W on Hetzner CX22 (single vCPU, 4 GB RAM baseline) | Manual perf test |
| **QA-11** | K8s canary — Helm install → CronJob → webhook in 60 s on fresh K3s | CI + manual |

### Agentic quality gates

| Gate | Assertion | First required |
|---|---|---|
| **QA-12** | 80/20 routing accuracy — ≥80% of 100-run test suite resolves locally ±5% | v1.0.24 (Phase 08) |
| **QA-13** | Budget enforcement — per-run + per-day caps accurate to ±$0.01 | v1.0.24 (Phase 08) |
| **QA-14** | Sandbox escape resistance — adversarial suite denies rm -rf, sudo, curl attacker.com, secrets read | v1.0.23 (Phase 07) |
| **QA-15** | Human checkpoint honored — `human_checkpoint: true` blocks without ACK | v1.0.23 (Phase 07) |

### Long-term gates

| Gate | Assertion | When verified |
|---|---|---|
| **QA-16** | 30-day fleet uptime ≥99.9% on reference Headless deployment | v1.0.28 (Phase 12) |
| **QA-17** | No CVE unpatched > 90 days | Continuous |

## Harness scripts

### `iso/qa/oneshot.sh` — 3-layer verifier (existing)

Runs before every ship. Three layers:

1. **Static lint** — VERSION consistency, packages.x86_64 syntax, config file validity
2. **Container QA** — install path smoke test inside a fresh Arch container
3. **QEMU boot test** — captures screendumps at bootloader, greetd login, post-login desktop; detects red-banner errors

Exit 0 = safe to flash. Any failure blocks ship.

### `iso/qa/verify-shipped-iso.sh` — regression harness (grows per phase)

Immune system for the baseline. Every gate above adds one assertion. Currently 11+ items (T2 wifi recipe: regdb, iwd Country=US, brcmfmac feature_disable, T2 initramfs modules, cfg80211 cmdline, model-specific firmware symlinks, MAC randomization off, ANQP off, wifi powersave off).

Runs as Layer 2.5 of `oneshot.sh`. Also runs standalone before every USB burn — **hard rule per memory `oneshot-before-ship`.**

### `iso/qa/verify-baseline.sh` — NEW in Phase 03

Asserts backup discipline separate from ISO validity:
- Git tag `v1.0.18` exists on origin
- `archive/pre-gsd-2026-08-03` branch on origin
- `experiments/2.1.0-2026-08-03` branch on origin
- Config symlinks resolve: `~/.hermes/config.json`, `~/.gsd/config.json`, `~/.litellm/config.yaml` all point at expected repo files
- No ISOs in `iso/out/` (they belong in `~/vinos-iso-archive/` and R2)
- `iso/archive/build-logs/` non-empty
- `omarchy/` subtree pinned to expected commit
- LKG Omarchy tag exists

### `iso/qa/tier1-lint.sh` — NEW in Phase 03

Static lint from DEV-LOOP.md Tier 1. Runs in <30 s. Modes:
- `--only shellcheck` — shellcheck on all `.sh` files
- `--only structured` — JSON/YAML/TOML validity across configs
- `--only attribution` — grep for "Omarchy" outside NOTICES + About page
- (no flag) — runs all three

Used by `.githooks/pre-commit` and `.github/workflows/vinos-dev-flow.yml`.

### `iso/qa/tier2-container.sh` — NEW in Phase 03

Container install-script test from DEV-LOOP.md Tier 2. Runs install/*.sh in a fresh `archlinux:latest` container with the repo mounted. Verifies:
- All install scripts syntactically valid
- Packages listed in packages.x86_64 are available in the current Arch snapshot
- No install script assumes host state (fresh container = clean install)

Runs in <5 min on typical CI. Deployed to `.github/workflows/vinos-dev-flow.yml` for every PR.

### `iso/qa/adversarial-tests/` — NEW in Phase 07+

Suite of security tests. Each script attempts a specific attack and must be denied:
- `harden.sh` — attempt to write `/etc/`, escalate root, spawn unsigned binary
- `sandbox-escape.sh` — routine attempts rm -rf, sudo, curl attacker.com, read `~/.vinos/secrets/`
- `luks-enrollment.sh` — end-to-end LUKS enrollment via QEMU

### `iso/qa/hardware-matrix.md` — NEW in Phase 06

Per-hardware test log. One row per certified board:

```markdown
| Board | Kernel | Wifi | Trackpad | Audio | Suspend | Canary | Last tested |
|---|---|---|---|---|---|---|---|
| MacBook Pro 15" 2019 (T2) | linux-t2 | pass | pass | pass | pass | pass | 2026-08-03 |
| ThinkPad X1 Carbon Gen 11 | linux-cachyos | ... | ... | ... | ... | ... | pending Phase 06 |
```

## Continuous testing

### `vinos-dev-qa-nightly` routine (Phase 02 deliverable)
Fires at 03:00 daily. Runs the full harness on current `main` HEAD. Reports:
- Pass/fail per gate
- Diff since last night
- New assertions added or removed

Posts summary to Discord webhook. Failures notify human within 15 min.

### `vinos-dev-code-review` routine (Phase 02 deliverable)
Fires on every PR opened / synchronized. Claude Sonnet 4.6 reviews the diff, posts findings as inline PR comments. Human ACK required to merge (per R15).

### GitHub Actions

`.github/workflows/vinos-dev-flow.yml`:
- **tier1-lint** — always runs, blocks merge
- **tier2-container** — runs on PR, blocks merge if fails
- **code-review** — runs on PR (non-draft), posts comments (non-blocking)
- **arch-review** — fires on changes to `install/` or `iso/profile/`
- **security-review** — fires on changes to `SECURITY.md`, `install/`, `iso/`, `bin/vinos-*`

`.github/workflows/iso.yml` (existing) — builds ISO on tag push.

## Ship-gate matrix

Per-phase ship gate requirements:

| Phase | Ships as | Foundation (1-6) | LUKS (A1) | HW (7) | Latency (8) | Headless (9-11) | Agentic (12-15) | Long-term (16-17) |
|---|---|---|---|---|---|---|---|---|
| 01 Capture | tag only | — | — | — | — | — | — | — |
| 02 Dev flow | routine files | — | — | — | — | — | ✓ (basic) | — |
| **03 v1.0.19** | ISO | **✓** | — | — | — | — | — | — |
| 04 v1.0.20 | ISO | ✓ | **✓** | — | — | — | — | — |
| 05 v1.0.21 | ISO | ✓ | ✓ | — | — | — | — | — |
| 06 v1.0.22 | ISO | ✓ | ✓ | **✓** | — | — | — | — |
| 07 v1.0.23 | ISO | ✓ | ✓ | ✓ | **✓** | — | ✓ (14, 15) | — |
| 08 v1.0.24 | ISO | ✓ | ✓ | ✓ | ✓ | — | ✓ (12, 13) | — |
| 09 v1.0.25 | ISO | ✓ | ✓ | ✓ | ✓ | — | ✓ | — |
| 10 v1.0.26 | Docker + Helm | ✓ | ✓ | — | — | **✓** | ✓ | — |
| 11 v1.0.27 | ISO + Cloud | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| 12 v1.0.28 GA | ISO + Cloud | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **✓** |

**Bold** = first phase requiring the gate.

## Test artifacts (per release)

Published to `dl.vinos.computer/qa-reports/<VERSION>.json`:

```json
{
  "version": "1.0.19",
  "build_date": "2026-08-08T12:00:00Z",
  "build_machine": "vinpatel-workstation",
  "sha256": "...",
  "gates": {
    "QA-1": {"passed": false, "reason": "single-build-machine — deferred to Phase 12"},
    "QA-2": {"passed": true, "duration_s": 42},
    "QA-3": {"passed": true, "hardware": ["T2 MBP 2019"]},
    "QA-4": {"passed": true, "wall_clock_s": 187},
    "QA-5": {"passed": true, "grep_count": 0},
    "QA-6": {"passed": true, "layers": ["static", "container", "qemu"]}
  },
  "regression_assertions": 14,
  "adversarial_tests": []
}
```

## What we DON'T test

- **User's own routines.** Community submissions are signed but not vetted for correctness. Ledger + budget caps + sandbox contain damage.
- **Third-party API reliability.** If Anthropic/OpenRouter is down, we notify and fall back to local; that's not a vinOS bug.
- **Hardware we don't ship for.** ARM, PowerPC, x86 32-bit — out of scope. Testing = we don't fake support.

## Related

- `docs/v2/DEV-LOOP.md` — iteration pyramid detail
- `docs/v2/PLAN-2026-08-03.md` §7 — QA gate rationale
- `docs/v2/ARCHITECTURE.md` — what we're testing
- `docs/v2/BACKUP.md` — includes backup-related tests
- `iso/qa/verify-shipped-iso.sh` — grows per phase
- `SECURITY.md` — includes security-specific tests (QA-14, QA-H2)
