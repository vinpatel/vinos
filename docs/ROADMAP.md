# vinOS Roadmap

*Written 2026-08-01 · The strategic plan for making vinOS the category-defining OS for agent operators. Each phase has measurable exit criteria. Every feature ships with 5 mandatory artifacts (see `docs/spec/README.md`).*

## Category

**vinOS is the OS for agent operators.** People whose day is 20+ AI workflows, who care about local privacy AND hosted flexibility, who want the OS itself to think for them overnight. The category is empty — Ubuntu/Fedora aren't competing here, macOS+Copilot isn't, LM Studio isn't an OS. **We define it.**

## Where we came from

- **v1.1.0** (2026-07) — "T2 Mac Linux that works." Solved: T2 wifi, T2 keyboard, T2 audio, linux-t2 kernel + firmware. Positioning: hardware-specific niche. **Permanent archival.**
- **v2.0.x** (2026-07 → 2026-08) — added Omarchy aesthetic (vendored), offline installer (rsync-from-live), agentic surface (`vinos-ai`, `vinos-routine`, `/models/`, `/hosted/` + OmniRoute), 19-check regression harness. Positioning: "agentic OS" but the *feel* isn't yet unmistakably agentic.

## Top-of-class criteria (measurable)

| # | Metric | Today | Target |
|---|--------|-------|--------|
| 1 | Install → first agent running | 30-40 min | **< 20 min** |
| 2 | First routine live | ~10 min manual | **< 5 min wizard** |
| 3 | Median local-model latency (7B) | ~1.5 s | **< 800 ms** |
| 4 | Cost vs pure-API stack (moderate use) | Unknown | **≥ 60% saved** |
| 5 | Hardware auto-detect success | T2 only verified | **≥ 90% x86_64** |
| 6 | Update never breaks routines | Not guaranteed | **Deterministic, harness-guarded** |
| 7 | One-cmd backup + restore agent state | None | **`vinos-backup` / `vinos-restore`** |
| 8 | Harness surface coverage | 19 checks | **~100 surfaces** |

## Phases

### Phase A — Install cycle stable

**Version window:** 2.0.18 → 2.0.20 · **Timeline:** ~1 week · **Status:** in progress

- Install-to-disk architecture proven (offline clone from live)
- 19-check regression harness live and enforcing
- ISO retention: last 3 builds + 1.1.0

**Exit criteria:**
- User completes 3 consecutive install cycles without a new bug
- Harness green on every build in the window
- No `omarchy-*` command failure in `vinos-doctor`

### Phase B — Ownership

**Version window:** 2.1.0 · **Timeline:** ~2 weeks · **Status:** kicked off in parallel to Phase A

Two parallel workstreams.

**B1 — Full Omarchy decouple** (see `docs/spec/phase-b-decoupling.md`)
- Rewrite `configs/omarchy/config/hypr/` as vinOS-native → `configs/vinos/hypr/`
- Rename every `require("hypr.X")` → `require("vinos.X")`
- Rewrite all defaults (waybar, walker, mako, foot) as vinOS-native in `configs/vinos/default/`
- Drop HEY / Basecamp / third-party PWA entries from menu
- `install/03-configs.sh` sources from `configs/vinos/`
- `/usr/share/omarchy/` disappears from the shipped ISO
- `configs/omarchy/` deleted from the repo entirely — the new `configs/vinos/` is a clean-room rewrite, not a fork. Nothing Omarchy-authored ships anywhere.
- **Keybindings preserved 1:1** — SUPER+SPACE (launcher), SUPER+ALT+SPACE (menu), SUPER+K (keybindings viewer), SUPER+A (AI), all others

**B2 — Hardened kernel + container-native tuning** (see `docs/spec/b-secure-kernel.md` and `docs/spec/b-k8s-optimized.md`)
- Ship `linux-hardened` (Arch's hardened kernel) as **default** for generic profile; `linux-t2` remains default for T2 profile with hardened patchset overlay where possible
- Enable KASLR, SMEP, SMAP, KPTI, KUSER_HELPERS=n, SLUB hardening, page poisoning
- Enable seccomp, cgroups v2, unprivileged user namespaces (locked to root by default)
- Kernel modules baked in: `overlay`, `br_netfilter`, `veth`, `nf_conntrack`, `xt_conntrack`, `ip_vs`, `wireguard`
- Ship: `containerd`, `runc`, `crun`, `podman`, `docker`, `docker-compose`, `kubectl`, `kubeadm`, `kubelet`, `helm`, `k9s`, `cilium-cli`
- `/etc/sysctl.d/99-vinos-k8s.conf` — bridge-nf, ip_forward, max_map_count, inotify limits
- `vinos-install-k8s` bundle — one command to init a single-node cluster (`kubeadm init` + cilium CNI)
- Harness checks: hardened kernel present, containerd running, cgroups v2 mounted, sysctl values pinned

**B3 — LUKS installer option** (see `docs/spec/b-luks-installer.md`)
- Prompt during install: "Encrypt disk? (recommended) [Y/n]"
- `cryptsetup luksFormat` root partition, LUKS2 + argon2id
- Optional TPM2 auto-unlock via `systemd-cryptenroll --tpm2-device`
- Kernel cmdline: `cryptdevice=UUID=…:root`
- /boot stays FAT32 (spec requirement) — random-seed warning acknowledged in install summary as cosmetic
- Adds ~30s to install time

**Exit criteria:**
- `grep -ri omarchy /` on the running installed system returns 0 hits
- All existing keybindings work identically
- Fresh install with LUKS chosen boots to disk-unlock prompt
- `uname -r` shows `-hardened` suffix on generic profile boots
- `containerd`, `runc`, `docker`, `kubectl` all in `$PATH` on fresh install
- `sudo vinos-install-k8s` initializes a working local cluster
- Harness grows from 19 → ~55 checks (every keybinding + LUKS invariants + kernel hardening + container runtime)

### Phase C — Agent-native UX

**Version window:** 2.2.0 · **Timeline:** ~3 weeks · **Status:** started in parallel

Ship 10 improvements, one PR per improvement, each with a harness check and a memory entry. **Discipline: pick 5 and STOP for evaluation before starting the next 5.**

**First batch (highest ROI):**
1. **AI status pill in waybar** — model · tokens today · active routines · monthly Claude spend. Click → dropdown showing `vinos-ai status`. (see `docs/spec/ai-status-pill.md`)
2. **Consistent brand accent** — waybar highlights, mako accent, walker selected row, window border all pinned to `#33ccff` regardless of theme. (see `docs/spec/consistent-brand-accent.md`)
3. **Routine notifications channel** — mako `routines` category, different color, groupable, separated from system notifications. (see `docs/spec/routine-notification-channel.md`)
4. **Dedicated agent workspace** — SUPER+A switches to workspace 6 with a preset layout (chat left, routine output right). (see `docs/spec/agent-workspace.md`)
5. **Focus mode ↔ routines** — long routine starts → DND auto-enables, waybar dims, clock shows `routine 4m 23s`. (see `docs/spec/focus-mode-routines.md`)

**Second batch:**
6. Faster animations (Omarchy 300ms → vinOS 180-220ms, single bezier)
7. Preset window chords (SUPER+SHIFT+ENTER = terminal+editor split; SUPER+SHIFT+D = 3-column dev)
8. Lockscreen glance widget (uptime, unread, next routine, weather)
9. Walker AI-augmented search (natural question → "→ ask vinos-ai" inline row)
10. Semantic terminal prompt (git-aware, model-aware in routines)

**Exit criteria:**
- A first-time visitor screenshots the desktop and immediately identifies it as an agentic OS
- Muscle memory from Omarchy still works
- All 10 improvements harness-guarded

### Phase D — Agentic infrastructure

**Version window:** 2.3.0 → 2.5.0 · **Timeline:** ~2 months · **Status:** planning

This is where we become **category-defining**.

- **`vinos-ai` → real agent runtime** (streaming, tool calls, persistent memory, error recovery). Not a wrapper anymore.
- **`vinos-tools`** — standard tool registry (files, browser, git, shell, HTTP, calendar, email) that all routines share. Signed, versioned.
- **`vinos-context`** — persistent memory across sessions. Based on the Claude auto-memory pattern (typed entries, semantic index, decay policy).
- **`vinos-observability`** — one dashboard: token spend, tool calls, routine timings, error rate, cost per outcome.
- **`vinos-marketplace`** — routines shareable as signed `.tar` bundles with metadata + spend caps + tool requirements.

**Exit criteria:** metrics 3-7 from the top-of-class table above are met.

### Phase E — Ecosystem + category leadership

**Version window:** 3.0.0+ · **Timeline:** ~6 months · **Status:** planning

- **vinOS Hub** — the "GitHub for routines" (web-hosted community + submission workflow)
- **Team edition** — multi-user, shared routines, spend caps, workspace budgets
- **Enterprise** — SSO, audit logs, policy enforcement, cost dashboards
- **Optional cloud sync** — routine state e2e-encrypted, restorable to fresh install

**Exit criteria:** revenue-generating; industry writing uses "agent-native OS" as a category name; vinOS is the reference implementation.

## Non-goals

- vinOS is not a general-purpose desktop Linux. Users looking for that get Ubuntu.
- vinOS is not a Linux distribution for servers. That's Debian/RHEL territory.
- vinOS does not compete on package variety. We ship what agent operators need; the AUR is available for the rest.
- vinOS does not chase iOS/macOS aesthetic parity. We chase agentic-native aesthetic — different problem, different answers.

## The discipline that makes this work

Every feature ships with 5 artifacts, always. If it can't produce all 5, it's not ready:

1. **Problem statement** — one paragraph, no jargon
2. **User story** — "As an operator, I want X so that Y"
3. **Behavior spec** — deterministic + testable, includes error exit codes
4. **Harness check** — grep or extract-and-verify in `iso/qa/verify-shipped-iso.sh` that fails on regression
5. **Memory entry** — `.md` file explaining why, when to reconsider, links to related decisions

The regression harness (currently 19 checks) is the load-bearing artifact. It grows with every ship. Every past bug becomes a check. **A fix isn't complete until its harness check exists.**

See `docs/spec/README.md` for the full spec template.
