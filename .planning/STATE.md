# vinOS — state (auto-reconstructed 2026-08-10)

**Project ref:** [`.planning/ROADMAP.md`](ROADMAP.md) · [`.planning/RULES.md`](RULES.md) · [`.planning/research/PERSONAS.md`](research/PERSONAS.md)

**What this is:** Dual-product agentic Linux — `vinos-dev` (Arch + Hyprland desktop for developers) and `vinos-vm` (Ubuntu 24.04 hardened VM for cloud agent workloads), sharing one bash-authored `vinos` CLI + runtime layer.

## Current position

**Milestone:** v1.2.0 — Persona activation (**Track A shipped 2026-08-10**; Track B in progress)
**Baseline:** v1.1.0 (permanent · `iso/out/vinos-1.1.0-x86_64.iso`)
**Direction:** Option C locked 2026-08-08 (Arch dev + Ubuntu vm + shared bash runtime)

### Track A — vinos-dev

| ID | Item | Status | Commit |
|----|------|--------|--------|
| A1 | Modular hypr sourcing + `bindd =` migration | ✅ Done | `4e2b126b` (P1) |
| A2 | `vinos-menu` binding activation + 9 subcommand handlers | ✅ Done | `1a970144` — 35/35 tests |
| A3 | First-run wizard v2 (gum-driven, 6 screens + short-circuit) | ✅ Done | `fb39fe11` — 16/16 tests |
| A4 | Preinstall Claude Code + Ollama + `vinos-mcp` + curated MCP registry | ✅ Done | `c362c62c` (installer path); P2 shipped the registry |
| A5 | Ship `vinos-dev-1.2.0-x86_64.iso` | ✅ Shipped | `08082ce6` → tag `v1.2.0`; 4.36 GB; sha256 `7fff67bfa…` |
| A5.1 | Patch v1.2.1 — SUPER+Return terminal binding regression | ⚠️ Failed | `ade18c23` → tag `v1.2.1`; static-config bug, xdg-terminal-exec silently no-op'd |
| A5.2 | Patch v1.2.2 — real fix (foot direct, wallpaper path, nwg-drawer, static lint gate) | ⚠️ Still broken | `24fa832a`+`89c2944a` → tag `v1.2.2`; ships `RETURN` keysym + `uwsm-app -- foot` which BOTH no-op on Hyprland 0.57 — proven live in QEMU 2026-08-14; hot-patch (`RETURN` → `Return`, drop `uwsm-app --` prefix) fired foot immediately |
| A5.3 | Patch v1.2.3 — real real fix (`Return` keysym, no uwsm wrapper on foot, hypridle live-skip, obsolete AUR pkgs pruned) | 🟡 Building | source patched; iso/build.sh --no-drift-check running via docker (~15 min) |

### Track B — vinos-vm

| ID | Item | Status | Commit |
|----|------|--------|--------|
| B0 | Ubuntu 24.04 PoC — build + boot + 7-metric measurements | ✅ Done | `fc3e0ad0` (P3) — 4/7 gates pass |
| B1 | Shared vinOS runtime monorepo → `.pkg.tar.zst` + `.deb` | ⬜ Pending | — |
| B2 | Signed apt repo at `apt.vinos.computer` (Cloudflare + GPG) | ⬜ Pending | — |
| B3, B4, B7, B8 | Packer + Ansible + multi-arch + multi-cloud + ship qcow2 | ⬜ Pending | — |
| B5 | vinos-agent-worker polling loop + runner abstraction | ⬜ Pending | — |
| B6 | Full `vinos` CLI (14 subcommands, all tested) | 🟡 Slice done | `65d7a01d` — dispatcher + 6/14 delegates + 15/15 tests. vm-only cmds (join/leave/agent/mission/secrets) queued for cmd/*.sh under vinos-agent-worker.deb |

### Track Q — QA & test harness (added 2026-08-14)

| ID | Item | Status | Notes |
|----|------|--------|-------|
| Q1 | `iso/qa/config-lint.sh` — static Hyprland/autostart gate | ✅ Shipped | `89c2944a` (2026-08-11); catches v1.2.1-class silent no-ops |
| Q2 | `iso/qemu-desktop.sh --lan --keepalive --monitor --hostfwd` | ✅ Landed 2026-08-14 | one-command Mac→QEMU test path; default `vinos` VNC password; virtio-vga + 4 vCPU/8G defaults |
| Q3 | `iso/qa/hmp.sh` + `iso/qa/keepalive.sh` | ✅ Landed 2026-08-14 | HMP client (send/key/dump/status/type) + anti-lock keepalive |
| Q4 | `iso/test-super-return.sh` | ✅ Landed 2026-08-14 | headless sendkey regression: injects SUPER+Return, pixel-diffs; blocks ship on FAIL |
| Q5 | `iso/qa/loop.sh` — Tier 3 hot-patch iteration | ⬜ Pending | inotifywait config/hypr → scp → hyprctl reload |
| Q6 | Enable sshd in live overlay `multi-user.target.wants/` | ⬜ Pending | required by Q5 for hostfwd SSH-in |
| Q7 | Wire Q4 into `iso/test.sh matrix` | ⬜ Pending | mandatory pre-ship gate |

Runbook: `.planning/TESTING.md`.

### Research shipped

- `research/PERSONAS.md` — both-persona design spec (revised targets after P3)
- `research/PILOT-3-RESULTS.md` — vinos-vm PoC measurements
- `research/PILOT-4-PLUGINS.md` — Hyprland ecosystem eval (v1.2.0/v1.3.0 candidates)

## Recent decisions (from memory)

- **No Omarchy ever** (2026-08-08) — zero code/configs/overlay; author every config ourselves. Supersedes prior 07-22 and 08-02 Omarchy directions.
- **Fresh from v1.1.0** (2026-08-08) — dev line branches from v1.1.0 gold; v1.0.19 Omarchy-fork path parked.
- **Themes vinOS-native only** (2026-08-09) — Aurora/Nebula/Ember/Frost only; no ecosystem theme reuse.
- **vinOS logo everywhere** (2026-08-09) — every visual surface shows vinOS brand; third-party integrations rebranded.
- **Retention** — last 3 dev + last 3 vm + v1.1.0 permanent.

## Session continuity

Last session: 2026-08-14 (Track Q + A5.3 v1.2.3 fix)
Resumed via: `/gsd-progress` — user reported SUPER+Return still broken on v1.2.2 real hardware
Stopped at: v1.2.3 building via docker (~15 min); Q5/Q6/Q7 pending; live QEMU on v1.2.2 proved the fix (hot-patched RETURN→Return + dropped uwsm-app wrapper — foot fired instantly)
Next actions:
  - **In-flight:** v1.2.3 build (log: `/tmp/vinos-1.2.3-build.log`); when finished → run `iso/test-super-return.sh --iso iso/out/vinos-1.2.3-x86_64.iso` to prove headlessly
  - **After v1.2.3:** Q5 (loop.sh), Q6 (enable sshd), Q7 (wire test-super-return into `iso/test.sh matrix`)
  - **Then:** back to Track B (B1 monorepo or B5 agent-worker)
Task tracking: see TaskList (#7–#13 tracked this session)

### Session tally (2026-08-10)

| Commit | Item | Tests |
|--------|------|-------|
| `1a970144` | A2: vinos-menu subcommand routing | 35/35 |
| `fb39fe11` | A3: first-run wizard v2 | 16/16 |
| `c362c62c` | A4: Claude Code + Ollama preinstall + gen-packages fix | — |
| `75501b9a` | polish: wizard silent no-op | 16/16 (re-run) |
| `5403edb9` | tests/all.sh + wired into master test.sh | 58/58 aggregate |
| `65d7a01d` | B6 slice: `vinos` CLI dispatcher | 15/15 → 73/73 aggregate |
| `08082ce6` | release: v1.2.0 ship-gate fixes (sha256 heuristic, size budget → 5.0 GB, absolute --iso path) — tagged `v1.2.0` | Matrix PASS (BIOS/UEFI/3G-floor/offline/Plymouth) |

**Full harness state (as of last commit):** 4 harnesses (vinos-mcp, vinos-menu, vinos-first-run, vinos), 73/73 assertions green. `bash tests/all.sh` runs everything in seconds.

## Blockers

None. A5 is dependency-blocked on A2+A3+A4 completing; that's a normal sequence, not a blocker.

## Deferred

- **Site sync** (`vinos.computer` / `site/`) — dual-product story; ~150 lines layout + 4 pages. Queued for post-ISO.
- **Track B (v1.2.0 vinos-vm)** — full Packer/Ansible/apt-repo/multi-cloud stack. B0 (PoC) is the only piece shipped; B1–B8 are downstream.
