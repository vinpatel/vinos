# vinOS Backup & Rollback Strategy

**Rule:** Nothing built by vinOS is at risk of loss. Every ship, every config, every prior effort is preserved and reachable.

## What gets backed up (and where)

| Asset | Primary location | Backup destination | Frequency | Retention |
|---|---|---|---|---|
| Git history | `origin/main` on GitHub | R2 mirror + local NAS | Daily | Forever |
| Git tags (releases) | `origin` tags | R2 mirror | Immediate on tag | Forever |
| Memory / notes | `~/.claude/projects/-data-projects-vinos/memory/` | R2 + external drive | Weekly | Forever |
| ISO artifacts | `~/vinos-iso-archive/isos/` | R2 (`s3://vinos-archive/isos/`) + external drive | Per ship | Forever for tagged releases |
| Build logs | `iso/archive/build-logs/` (in git) | Git history | Per build | Forever |
| Site content | `site/` | Git | Per commit | Forever |
| User ledger | `~/.vinos/routines/state/ledger.sqlite` | User's cloud (opt-in) | Nightly | 90 days rolling |
| Arch snapshot manifests | `dl.vinos.computer/snapshots/<ver>/` | R2 | Per ISO build | 12 months |
| Omarchy pins | Git tag `omarchy-lkg-<date>` | Git | Per bump | Forever |
| Kernel configs | `configs/vinos/kernel/config` (in git from Phase 07) | Git | Per release | Forever |

## Rollback contracts

### ISO rollback
Any shipped ISO can be re-flashed from `dl.vinos.computer/releases/<VERSION>/` with matching `sha256sums.txt`. Retention: **forever for tagged releases** (v1.1.0 archival gold, v1.0.18 baseline, all future GA).

Command:
```bash
curl -O https://dl.vinos.computer/releases/v1.0.19/vinos-1.0.19-x86_64.iso
curl -O https://dl.vinos.computer/releases/v1.0.19/sha256sums.txt
sha256sum -c sha256sums.txt
sudo dd if=vinos-1.0.19-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### Config rollback (installed system)
vinOS ships with BTRFS + Snapper (via `linux-cachyos` default). Per-boot snapshots. Also snapshots before every `pacman -Syu` via Snapper hooks.

Commands:
```bash
snapper list                     # see all snapshots
snapper rollback <number>        # roll to specific snapshot
snapper delete <number>          # prune old
```

Snapper config lives at `/etc/snapper/configs/root` — ships in Phase 04 with sane defaults (auto-snapshot on package ops, hourly for /home, monthly retention).

### Kernel rollback
Multi-kernel Limine boot menu. Every install has at least `linux-cachyos` + `linux-hardened` (+ `linux-t2` on Macs, + `linux-vinos` from Phase 07).

If a kernel update breaks boot, reboot into another via Limine menu. Command from a working system:
```bash
sudo vinos-update kernel-rollback              # Phase 07 deliverable
# equivalent manual: edit /boot/limine.conf, set default_entry to a working kernel
```

### Omarchy pin rollback
Every Omarchy subtree bump creates `omarchy-lkg-<YYYY-MM-DD>` tag on the previous known-good version. Rollback:
```bash
git subtree pull --prefix omarchy https://github.com/basecamp/omarchy.git omarchy-lkg-2026-08-03 --squash
```

Fresh install: point `omarchy/` submerge to LKG tag.

### Arch snapshot rollback
Every vinOS ISO is built against a specific Arch snapshot URL. URL is written to `/etc/vinos-release` at build. All blessed snapshots retained on R2 for 12 months:
```
https://dl.vinos.computer/snapshots/2026-08-01/
https://dl.vinos.computer/snapshots/2026-11-01/
https://dl.vinos.computer/snapshots/2027-02-01/
...
```

Rebuild v1.0.19 bit-for-bit from any of them:
```bash
export VINOS_ARCH_MIRROR=https://dl.vinos.computer/snapshots/2026-08-01/
bash iso/build.sh
sha256sum iso/out/vinos-1.0.19-x86_64.iso   # matches published sha256
```

### Config symlink rollback
Config source-of-truth lives in git at `.planning/config.json` and `configs/vinos/litellm/proxy.yaml`. Local symlinks (`~/.hermes/config.json`, `~/.gsd/config.json`, `~/.litellm/config.yaml`) can be broken. Fix:
```bash
ln -sfn /data/projects/vinos/.planning/config.json ~/.hermes/config.json
ln -sfn /data/projects/vinos/.planning/config.json ~/.gsd/config.json
ln -sfn /data/projects/vinos/configs/vinos/litellm/proxy.yaml ~/.litellm/config.yaml
```

`iso/qa/verify-baseline.sh` checks these symlinks resolve correctly.

### Ledger rollback
User agent ledger at `~/.vinos/routines/state/ledger.sqlite`. If corrupted:
- Nightly cloud sync (opt-in) preserves last 90 days
- Local SQLite dump kept at `~/.vinos/routines/state/ledger-YYYY-MM-DD.sql` for 30 days
- If both unavailable — ledger regenerates from routine invocation logs (each routine writes JSON to `~/.vinos/routines/state/<name>/`)

## Off-site backup

### R2 setup
```bash
# One-time — configure rclone
rclone config    # add remote "vinos-r2" pointing at Cloudflare R2

# Full snapshot to R2
rclone sync docs/ vinos-r2:vinos-archive/2026-08-03/docs/
rclone sync iso/ vinos-r2:vinos-archive/2026-08-03/iso/
rclone sync ~/vinos-iso-archive/ vinos-r2:vinos-archive/isos/
rclone sync ~/.claude/projects/-data-projects-vinos/memory/ vinos-r2:vinos-archive/memory/
```

Automated via `vinos-dev-qa-nightly` routine (Phase 02 deliverable), fires at 03:00.

### Verify off-site
```bash
# Random-file sha256 check
rclone md5sum vinos-r2:vinos-archive/isos/vinos-1.0.18-x86_64.iso
sha256sum ~/vinos-iso-archive/isos/vinos-1.0.18-x86_64.iso
# both must match
```

## Disaster recovery drill (quarterly)

Every 3 months, execute:

1. **Wipe a spare machine** (or fresh QEMU disk)
2. **Flash the latest shipped ISO** from `dl.vinos.computer` alone (no local caches, no laptop help)
3. **Install to disk with LUKS** (v1.0.20+)
4. **Run a canary routine** (`vinos-standup` or `vinos-brief`)
5. **Time-to-agent must be < 5 min** (QA-4 gate)
6. **Record the run** in `docs/v2/disaster-recovery-log.md` with pass/fail + wall-clock time

If the drill fails → **halt all forward development until it passes.** No new shipping happens on a broken DR.

## What we DON'T back up

- User's cleartext API keys (bring-your-own, no vinOS-side storage)
- User personal data on installed systems (their responsibility)
- Third-party package caches (rebuildable from Arch snapshots)
- Docker layer cache (rebuildable from `iso/build.sh`)
- QEMU disk images used for testing (ephemeral)

## Recovery time objectives

| Scenario | RTO | How |
|---|---|---|
| Fresh install broken | ~15 min | Re-flash + install + first-boot |
| Config regression on installed system | ~30 sec | `snapper rollback` |
| Kernel regression | ~1 min | Reboot into alternate Limine entry |
| Omarchy upstream break | ~10 min | Revert to LKG tag + rebuild |
| Arch snapshot break | ~1 hour | Build against prior snapshot from R2 |
| Full-repo loss (worst case) | ~30 min | `git clone` from GitHub + `rclone sync` from R2 |

## Related

- `docs/v2/PLAN-2026-08-03.md` §8 — backup strategy overview
- `docs/v2/ARCHITECTURE.md` — the layers being backed up
- `docs/v2/TESTING.md` — QA gates that verify backup discipline
- `iso/qa/verify-baseline.sh` — enforces backup rules on every ship
- `SECURITY.md` — includes backup-related threat mitigations (A4 supply chain)
