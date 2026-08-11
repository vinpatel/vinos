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
| A5.1 | Patch v1.2.1 — SUPER+Return terminal binding regression | ✅ Shipped | `ade18c23` → tag `v1.2.1`; 4.37 GB; sha256 `956d52e34…` |

### Track B — vinos-vm

| ID | Item | Status | Commit |
|----|------|--------|--------|
| B0 | Ubuntu 24.04 PoC — build + boot + 7-metric measurements | ✅ Done | `fc3e0ad0` (P3) — 4/7 gates pass |
| B1 | Shared vinOS runtime monorepo → `.pkg.tar.zst` + `.deb` | ⬜ Pending | — |
| B2 | Signed apt repo at `apt.vinos.computer` (Cloudflare + GPG) | ⬜ Pending | — |
| B3, B4, B7, B8 | Packer + Ansible + multi-arch + multi-cloud + ship qcow2 | ⬜ Pending | — |
| B5 | vinos-agent-worker polling loop + runner abstraction | ⬜ Pending | — |
| B6 | Full `vinos` CLI (14 subcommands, all tested) | 🟡 Slice done | `65d7a01d` — dispatcher + 6/14 delegates + 15/15 tests. vm-only cmds (join/leave/agent/mission/secrets) queued for cmd/*.sh under vinos-agent-worker.deb |

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

Last session: 2026-08-10 (A2 + A3 + A4 + B6-slice + polish + tests/all.sh)
Resumed via: `/gsd-resume-work`
Stopped at: Track A code-complete; B6 dispatcher shipped; A5 gated on user ISO build
Next actions:
  - **User-triggered:** `iso/build.sh && iso/test.sh matrix` → tag v1.2.0 (A5)
  - **Auto-continuable:** Track B — B5 (agent-worker + runner abstraction) or B1 (runtime monorepo)
Task tracking: TaskList (#1–#3 completed; #4 pending A5 ship gate)

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
