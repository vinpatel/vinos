# Phase 04 — v1.0.20: LUKS full-disk

**Type:** release · **Depends on:** 03 · **Ships as:** `vinos-1.0.20-x86_64.iso`
**Duration:** 5 days · **Requirements:** R12

## Goal
LUKS full-disk encryption default recommendation on laptops, TPM2 opt-in. Freshly implemented on the v1.0.19 base — NOT cherry-picked from the parked `experiments/2.1.0-2026-08-03` branch.

## Scope (in)
- `install/vinos-install-disk` — add `--luks`, `--no-luks`, `--luks-password`, `--luks-tpm2` flags
- Interactive prompt defaults to recommending LUKS on laptop hardware detection
- `configs/vinos/default/etc/mkinitcpio.conf.d/vinos-luks.conf` — sd-encrypt hook
- Kernel cmdline template gains `rd.luks.name=<uuid>=vinos-root rd.luks.options=discard`
- `iso/qa/verify-shipped-iso.sh` — add QA-A1 (LUKS enrollment succeeds end-to-end in Tier 4 QEMU test)
- Install video: capture LUKS flow via QEMU (`iso/qa/tier4-qemu-persistent.sh`)

## Scope (out)
- Anything OTHER than the LUKS path (no unrelated bumps)
- SecureBoot signing (deferred to Phase 12)
- Encrypted `vinos-persist` for live-USB workflows (v1.0.29+)

## Human checkpoints
1. Design of the interactive LUKS prompt copy (public-facing)
2. Kernel cmdline change to include LUKS opts (architecture-affecting)
3. Merge of the LUKS PR (security-affecting)
4. v1.0.20 tag creation (one-way)

## Ship gate
QA-1, QA-2, QA-3, QA-4, QA-5, QA-6, **QA-A1**.

## Deliverables
- Modified `install/vinos-install-disk`
- New `configs/vinos/default/etc/mkinitcpio.conf.d/vinos-luks.conf`
- New `iso/qa/tier4-qemu-persistent.sh`
- Modified `iso/qa/verify-shipped-iso.sh` (adds QA-A1)
- New `iso/qa/adversarial-tests/luks-enrollment.sh`
- New MP4: `site/static/videos/luks-install-1.0.20.mp4`
