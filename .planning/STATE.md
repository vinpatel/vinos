# vinOS — state (auto-reconstructed 2026-08-10)

**Project ref:** [`.planning/ROADMAP.md`](ROADMAP.md) · [`.planning/RULES.md`](RULES.md) · [`.planning/research/PERSONAS.md`](research/PERSONAS.md)

**What this is:** Dual-product agentic Linux — `vinos-dev` (Arch + Hyprland desktop for developers) and `vinos-vm` (Ubuntu 24.04 hardened VM for cloud agent workloads), sharing one bash-authored `vinos` CLI + runtime layer.

## Current position

**Milestone:** v1.2.0 — Persona activation (in progress)
**Baseline:** v1.1.0 (permanent · `iso/out/vinos-1.1.0-x86_64.iso`)
**Direction:** Option C locked 2026-08-08 (Arch dev + Ubuntu vm + shared bash runtime)

### Track A — vinos-dev

| ID | Item | Status | Commit |
|----|------|--------|--------|
| A1 | Modular hypr sourcing + `bindd =` migration | ✅ Done | `4e2b126b` (P1) |
| A2 | `vinos-menu` binding activation (Super+Alt+Space) | 🟡 In progress | binding wired via P1; subcommand routing next |
| A3 | First-run wizard v2 (gum-driven, 6 screens) | ⬜ Pending | — |
| A4 | Preinstall Claude Code + Ollama + `vinos-mcp` + curated MCP registry | 🟡 Partial | `f5f242f0` (P2 shipped mcp CLI + registry); CC+Ollama pending |
| A5 | Ship `vinos-dev-1.2.0-x86_64.iso` | ⬜ Pending | blocked by A2/A3/A4 |

### Track B — vinos-vm

| ID | Item | Status | Commit |
|----|------|--------|--------|
| B0 | Ubuntu 24.04 PoC — build + boot + 7-metric measurements | ✅ Done | `fc3e0ad0` (P3) — 4/7 gates pass |
| B1 | Shared vinOS runtime monorepo → `.pkg.tar.zst` + `.deb` | ⬜ Pending | — |
| B2 | Signed apt repo at `apt.vinos.computer` (Cloudflare + GPG) | ⬜ Pending | — |
| B3–B8 | Packer + Ansible + multi-arch + orchestrator + multi-cloud + ship qcow2 | ⬜ Pending | — |

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

Last session: 2026-08-10 (P1–P4 shipped previous session)
Resumed via: `/gsd-resume-work`
Stopped at: A2 — `vinos-menu` subcommand routing (siblings from `utilities.conf` need submenu handlers)
Next action: Implement A2 subcommand dispatch in `bin/vinos-menu`
Task tracking: TaskList (A2 in_progress; A3, A4 pending; A5 blocked by A2+A3+A4)

## Blockers

None. A5 is dependency-blocked on A2+A3+A4 completing; that's a normal sequence, not a blocker.

## Deferred

- **Site sync** (`vinos.computer` / `site/`) — dual-product story; ~150 lines layout + 4 pages. Queued for post-ISO.
- **Track B (v1.2.0 vinos-vm)** — full Packer/Ansible/apt-repo/multi-cloud stack. B0 (PoC) is the only piece shipped; B1–B8 are downstream.
