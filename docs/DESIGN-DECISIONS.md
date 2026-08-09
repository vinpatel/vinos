# Design decisions log

Every big architectural choice in vinOS, with date, context, and rationale. New decisions land at the top. Superseded decisions stay in place for history — annotated where they were reversed and why.

Format follows [ADR](https://adr.github.io/) conventions loosely: each entry has **Context**, **Decision**, **Rationale**, **Consequences**, and optional **Supersedes** links.

---

## ADR-012 · Themes: vinOS-native only, no ecosystem theme reuse

**Date:** 2026-08-09 · **Status:** locked HARD RULE

### Context

Earlier PERSONAS.md and ROADMAP.md drafts recommended shipping four themes: aurora + nord + gruvbox-dark + catppuccin. Nord, Gruvbox, and Catppuccin are independent community projects (predating Omarchy by 3-10 years) — so shipping them wouldn't violate the letter of [ADR-007](#adr-007) (no Omarchy code). But that specific three-theme selection mirrors Omarchy's shipped set, which does violate the *spirit* of ADR-007 — anyone familiar with Omarchy would read that lineup as Omarchy-influenced.

### Decision

**vinOS ships only vinOS-native themes.** No ecosystem theme reuse. The v1.3.0 theme system ships exactly four themes, all authored by us:

| Theme | Palette | Vibe |
|---|---|---|
| **Aurora** (default) | teal `#33ccff` → purple `#bb9af7` gradient, dark bg | agentic, atmospheric — matches the Hyprland border gradient |
| **Nebula** | deep indigo `#1a1a2e`, soft violet `#a29bfe`, cyan `#00d9ff` | night-owl coder, deep-space |
| **Ember** | charcoal `#1c1917`, amber `#f59e0b`, rust `#dc2626` | warm terminal-heavy, on-call ops energy |
| **Frost** | off-white `#f5f5f7`, slate blue `#4a5568`, mint `#10b981` | light theme for outdoor coding |

### Rationale

- **Brand consistency.** Users see one visual language across the OS. Aurora is the identity; Nebula/Ember/Frost are its siblings, not borrowed neighbours.
- **Zero possible confusion with Omarchy.** No cognitive overlap. When a reviewer sees the theme list, no one thinks "Omarchy influence."
- **Author-everything discipline.** Ties directly to [ADR-007](#adr-007) — we author our configs; the same rule extends to visual identity.
- **Community themes still work for users.** Nothing prevents a user from installing catppuccin-gtk or nord themes themselves. We just don't ship them as "vinOS themes."

### Consequences

- v1.3.0 theme system ships Aurora + Nebula + Ember + Frost
- `vinos-theme` CLI applies vinOS-native theme sets — Hyprland colors, waybar CSS, walker CSS, mako colors, foot palette, GTK theme, cursor accent, wallpaper — atomically
- Each theme lives under `/usr/share/vinos/themes/<name>/` with a manifest + per-tool config drop-ins
- If future themes are added, they must also be vinOS-authored — this rule is permanent, not just for the initial four

### Supersedes

Earlier PERSONAS.md § Menu system Theme submenu naming (Aurora + Nord + Gruvbox Dark + Catppuccin). PERSONAS.md and ROADMAP.md updated in the same commit that landed this ADR.

---

## ADR-011 · Menu system: three tiers with consistent visual language

**Date:** 2026-08-08 · **Status:** planned for v1.2.0 Phase A2

### Context

Omarchy popularized `Super+Space` for launcher and `Super+Alt+Space` for menu on Linux Hyprland setups. Users coming from macOS Cmd+Space (Spotlight/Raycast) and Cmd+Opt+Space (Alfred/menu bar) expect similar patterns. v1.1.0 has walker installed but only wires `Super+Space` → walker; the menu is not activated.

### Decision

Ship three-tier navigation with one visual language:

1. **Super+Space** → `walker` fuzzy text launcher (already ships)
2. **Super+Ctrl+Space** → `nwg-drawer` full-screen visual app grid (new)
3. **Super+Alt+Space** → `walker -m vinos-menu` command palette tree (new)

Menu tree source: `/usr/lib/vinos/menu/root.json`. Full tree covers 8 paths (Apps, System, AI, Windows, Capture, Theme, Files, Development, Help, Session) — every setting/toggle/action reachable in ≤ 3 keystrokes.

Visual constants applied everywhere: 12px rounding, 90 % opacity + blur, `#33ccff → #bb9af7` accent gradient, Inter UI font, Yaru icons.

### Rationale

- **Two launcher entry points** because power users want fuzzy text (walker) and visual users want icon grids (nwg-drawer). Same app set, two entry points, discoverability wins.
- **Menu tree ships pre-built** — users don't have to configure their way to a working system. Personal customization via `~/.config/vinos/menu/*.json` overlays.
- **Consistent visual language across all three tiers** so the OS *feels* coherent, not a mash-up of upstream defaults.

### Consequences

- **+18 packages** land in `packages.x86_64`: hyprcursor, hyprpolkitagent, hyprshot, hyprutils, hyprwayland-scanner, hyprland-protocols, hyprland-qtutils, hyprpm, nwg-drawer, nwg-displays, nwg-look, swaync, wlogout, fuzzel, inter-font, cliphist, wl-clip-persist, wf-recorder, ydotool
- **swaync replaces mako** as the default notification daemon on `vinos-dev`. mako remains for headless setups.
- **swww replaces swaybg** as the wallpaper daemon (smooth transitions on theme change).

Full spec: [`.planning/research/PERSONAS.md § Menu system design`](../.planning/research/PERSONAS.md).

---

## ADR-010 · Two-tier model policy: frontier decides, local grinds

**Date:** 2026-08-08 · **Status:** locked

### Context

Previous vinOS thinking oscillated between "AI = only frontier via Claude" and "AI = local models via Ollama". Neither extreme is right for actual developer workflow.

### Decision

Codify a two-tier split for both products:

| Tier | Runtime | Role |
|---|---|---|
| **Frontier** | Claude Code (Anthropic API) | Plans, reviews, decides, orchestrates. Small call volume, high per-call value. |
| **Workhorse** | Ollama local (Qwen3-Coder / DeepSeek-Coder / Kimi) | Bulk mechanical work. High call volume, low per-call value. |

On `vinos-dev`: **LiteLLM proxy** at `localhost:4000/v1` routes named model roles between the tiers. Apps target one endpoint. Ships in v1.3.0.

On `vinos-vm`: local models are opt-in via `vinos install ai-local` (most cloud VMs have no GPU). GPU-equipped instances get local inference once enabled.

### Rationale

- Frontier calls are expensive at volume. Grinding a 500-file refactor through Claude burns $50 in tokens; grinding it through local Qwen3-Coder is free after hardware amortization.
- Local models can't yet match Sonnet/Opus for planning-level agentic work. Trying to use them as the driver produces confused sessions.
- Two-tier routing hidden behind LiteLLM means app code doesn't have to know which tier — the proxy decides based on the named role.

### Consequences

- `configs/vinos/litellm/proxy.yaml` shipped as canonical routing config
- LiteLLM proxy installed as systemd service on `vinos-dev` (v1.3.0)
- First-run wizard offers to download a starter local model (~18 GB Qwen3-Coder 30B recommended); no models pre-loaded in the ISO
- `vinos-vm` stays lean by default; local models are one command away for GPU workloads

---

## ADR-009 · Runner abstraction: Claude default, not lock-in

**Date:** 2026-08-08 · **Status:** locked

### Context

Initial `vinos-agent-worker` design hard-coded `claude -p "$PROMPT" --output-format stream-json`. That commits the entire OS to one vendor's CLI. If Anthropic changes pricing, policy, or product direction, vinOS is exposed. Compliance customers who require "no external API" have no path.

### Decision

Design `vinos-agent-worker` around a **runner adapter interface**. Ship Claude Code as the default because it's the best agentic CLI in 2026. But make the runner replaceable via one env var:

```
/etc/vinos/agent.env:
  VINOS_RUNNER=claude|codex|aider|custom
```

Each adapter is ~150 lines of bash at `/usr/lib/vinos/runners/<name>.sh` implementing 4 verbs: `runner_check`, `runner_run`, `runner_cancel`, `runner_capabilities`.

MCP servers are portable across runners (MCP is now cross-vendor). Tool surface stays consistent regardless of which runner is active.

### Rationale

Claude Code stays the default on 6 concrete axes:
- Best-in-class headless mode (`--output-format stream-json`)
- MCP-native (Anthropic invented the protocol)
- Prompt caching baked in (~90 % cost reduction on repeated context)
- 1M context on Opus (competitors max ~200k)
- Enterprise compliance already attested (SOC 2, HIPAA, ISO 27001)
- Alignment with our own tooling ([ADR-006](#adr-006))

But we're not dogmatic:
- Anthropic could change pricing 3× — users switch to aider + local Ollama
- Compliance may require air-gapped operation — `VINOS_RUNNER=aider --model ollama/qwen3-coder:30b`
- OpenAI Codex, Google Gemini CLI, xAI Grok CLI all exist and improve — plug-in support is trivial

### Consequences

- v1.2.0 ships Claude adapter as default + Codex + Aider adapters
- `/usr/lib/vinos/runners/custom.sh` is a documented template for third-party runners
- `runner_capabilities` lets missions declare requirements (`streaming`, `mcp`, `tool_use`, `subagents`, `file_edit`)
- ~4 hours of extra design work upfront saves us from a vendor-lock-in rewrite later

---

## ADR-008 · vinos-vm base: Ubuntu 24.04 LTS, not Arch (Option C)

**Date:** 2026-08-08 · **Status:** locked

### Context

For the VM persona, we debated three options:

- **A. Arch for both dev and vm.** Zero fork cost, one codebase. But Arch has < 1 % cloud VM adoption and zero marketplace presence.
- **B. Ubuntu for both dev and vm.** Highest cross-product unification. But `vinos-dev` loses the Hyprland/tinkerer aesthetic that defines it.
- **C. Arch for dev, Ubuntu for vm.** Two bases, one shared bash runtime. Higher fork cost, highest adoption ceiling.

### Decision

Option C. `vinos-dev` stays Arch. `vinos-vm` uses Ubuntu 24.04 LTS minimal (packer-built, apt-native).

### Rationale

Real market data on cloud Linux VMs (2024-25 CNCF surveys, DataDog State of Cloud, provider marketplace stats):

| Distro | % cloud Linux VMs | Marketplace-listed |
|---|---|---|
| **Ubuntu LTS** | ~40-50 % | Every major cloud |
| **Amazon Linux** | ~15-20 % | AWS only |
| **Debian** | ~10-15 % | Every major cloud |
| **CentOS/Rocky/RHEL clones** | ~10-15 % | Every major cloud |
| **Arch** | **< 1 %** | Zero — user must import custom image |

Ubuntu wins on:
- Canonical maintains cloud-init → every cloud tests Ubuntu first
- Every AI infra vendor (Modal, Replicate, Fly.io, Anthropic sandbox, OpenAI Codex env) targets Ubuntu first
- LTS = 5-year support → enterprise procurement passes
- APT is the ecosystem assumption in every Ansible playbook, Terraform template, Docker guide
- Every cloud marketplace has Ubuntu as first-class citizen

The technical purity of "one distro for everything" loses to the market reality that adoption > elegance.

### Consequences

- Two package formats: `.pkg.tar.zst` (dev) + `.deb` (vm)
- Monorepo build (`vinos-runtime/`) with Makefile emitting both
- Maintenance overhead: slightly more, but manageable — the vinOS *layer* is shared bash
- Marketplace listings possible from day one on Ubuntu-native marketplaces
- Bridge: `vinos-dev` (Arch) natively runs Ubuntu containers via podman + distrobox — devs test vm behavior without leaving Hyprland

Full comparison table + tradeoffs: [PERSONAS.md § Appendix](../.planning/research/PERSONAS.md).

---

## ADR-007 · No Omarchy code, ever

**Date:** 2026-08-08 · **Status:** locked HARD RULE

### Context

vinOS's direction flip-flopped multiple times in 2026:
- 2026-07-13: Omarchy reversed (vinOS active dev, Omarchy as parity reference)
- 2026-07-22: v2.0 planned as "Arch + Omarchy configs verbatim"
- 2026-08-02: "OFFICIAL direction: vinOS builds on Omarchy (desktop) + Arch (base)"
- 2026-08-04: v2.x line dropped, "build forward from v1.0.19 on Omarchy fork"
- 2026-08-08: **This decision.**

Every flip-flop cost cycles and left the tree confused about what's ours vs upstream.

### Decision

**Zero Omarchy in vinOS.** Ever. No install script, no forked configs, no vendor tree, no overlay. We author every configuration file ourselves under `iso/profile/` and `iso/airootfs-overlay/`.

Commit messages must not contain the word "omarchy" (case-insensitive). Attribution isn't required — since we ship none of their code, MIT's attribution obligation doesn't trigger.

### Rationale

v1.1.0 already proves we can assemble the Hyprland + Walker + Waybar + Mako + Alacritty + Foot stack directly from raw Arch packages with vinOS-authored configs. There is no capability gap that requires Omarchy code.

If a feature-parity gap appears vs Omarchy, we **read** their public repo for ideas and **write our own** implementation from scratch. Stylistic influence is fine; code reuse is not.

Owning every line of config is also non-negotiable for the "vinOS is its own thing" brand posture.

### Consequences

- ADR-006 (Omarchy as base or overlay, dated 2026-08-02) is REVOKED
- Prior "Omarchy-fork" v1.0.19 line is parked in archive branches, not the forward direction
- Rule enforced by (a) commit-message scanning in CI, (b) directory-name scanning in the ISO harness, (c) memory-persistence for the AI collaborator sessions
- Verified 2026-08-08: `git log v1.1.0 --grep=omarchy` returns 0 commits, `git grep omarchy v1.1.0` returns 0 file mentions — the frozen baseline is naturally clean

---

## ADR-006 · Fresh dev line from v1.1.0

**Date:** 2026-08-08 · **Status:** locked · **Supersedes:** v1.0.19 as forward-build base

### Context

At the start of the 2026-08-08 session, `main` was diverged from `origin/main` (6 remote commits ahead of `v1.1.0` had a v2.1.0 release with Omarchy decouple; 26 local commits ahead had the v1.0.19 Omarchy-fork ship). Both directions represented work in abandoned/parked paths.

### Decision

Reset `main` (local + remote) to `v1.1.0`. Archive both diverged tips as named branches on GitHub so nothing is lost. Restart the dev line from the v1.1.0 tree.

### Rationale

- `v1.1.0` is the only ISO verified working end-to-end on T2 hardware
- `v1.1.0` tree contains zero Omarchy references (predates the pivot)
- Starting from the gold copy removes the "which fix is in which branch" tax that ate cycles
- Force-push to `main` was safe: no open PRs, one other collaborator (heads-up given), tags untouched, archive branches preserved

### Consequences

- `main` on GitHub reset to commit `e5c44b9e` (v1.1.0) + 4 new commits from this session (rules + roadmap + architecture + persona spec + design decisions)
- Archive branches on remote: `archive/local-2026-08-08` (26 commits of the v1.0.19 line), `archive/remote-2026-08-08` (6 commits of the v2.1.0 line), `archive/pre-gsd-2026-08-03` (older)
- Any useful bits from either archived branch cherry-pickable when needed
- v1.1.0 tag itself never re-pointed; SHA `8bf79af1…` unchanged

---

## ADR-005 · Claude Opus 4.7 (1M) as sole driver until stable release

**Date:** 2026-08-08 · **Status:** locked, revisit-on-stable

### Context

vinOS's own AI-driven development workflow has thrashed between local models (Qwen3-Coder, DeepSeek-Coder) and Claude. Mixing tiers for driver-seat work has repeatedly cost more time than it saved — local models can't hold vinOS's full context (`iso/`, `configs/`, `.planning/`) coherently across sessions.

### Decision

**100 % Claude Opus 4.7 (1M context)** as the driver for all planning, execution, review, and debug work until vinOS ships a stable ISO release. No routing planning or execution through `vinos-executor` / `vinos-autoexec` / local Ollama for the driver seat during this stretch.

Local models remain the workhorse tier for autonomous background grinding — see [ADR-010](#adr-010).

### Rationale

- 1M-context window holds vinOS's full working tree without paging — biggest source of wasted cycles was forgetting which fix landed where
- Frontier reasoning quality matters more than cost during pre-release stabilization
- Once stable release ships, reassess against Sonnet 4.6 for routine phases

### Consequences

- `.planning/config.json` model roles all set to `anthropic/claude-opus-4-7`
- No local-model routing for the driver seat
- Estimated spend: bounded by mission volume, not per-token cost concerns for now
- Sunset condition: v1.2.0 stable ship triggers reassessment

---

## ADR-004 · ISO storage in `iso/out/`, retention = last 3 + v1.1.0 permanent

**Date:** 2026-08-08 · **Status:** locked · **Supersedes:** earlier "last 2 + 1.1.0" and "only latest" rules

### Context

Prior retention rules had drifted:
- 2026-07-14: "keep only latest ISO"
- 2026-08-01: "last 2 + 1.1.0 permanent"
- 2026-08-02: "last 3 + 1.1.0 + 2.0.18 permanent" (2.0.18 was declared golden)
- ISOs were split between `~/vinos-iso-archive/isos/` and `iso/out/` — two sources of truth

### Decision

- **Single canonical location:** `/data/projects/vinos/iso/out/` (the build output dir)
- **Retention:** last 3 successful builds + `vinos-1.1.0-x86_64.iso` permanent
- **Prune:** older builds ONLY after the newest passes the regression harness

v2.0.18's "permanent gold copy" status is REVOKED (v2.x line was abandoned in ADR-002).

### Rationale

- User directive 2026-08-08: "never confused, ISOs live in one place"
- Two-deep regression fallback: if a new build introduces a regression the harness misses, we still have two older ISOs to fall back to
- v1.1.0 is the only ISO with T2-hardware end-to-end verification; keep it forever

### Consequences

- `~/vinos-iso-archive/` deleted; 1.1.0 moved into `iso/out/` (sha256 verified)
- All ISOs older than the last 3 pruned after new successful build
- Rule encoded in `.planning/RULES.md` § ISO storage & retention

---

## ADR-003 · Preserve v1.1.0 ISO forever

**Date:** 2026-07-22 (reinforced 2026-08-08) · **Status:** permanent

### Decision

`vinos-1.1.0-x86_64.iso` — the ISO built 2026-07-18 (sha256 `3bd3657e…873ef2`) — is never overwritten, rebuilt, or deleted under any circumstance. The `v1.1.0` git tag is never re-pointed.

### Rationale

It's the first ISO verified working end-to-end on real T2 Mac hardware. It's the immovable baseline everything else builds on. Losing it would mean losing the ability to prove any regression against a known-good reference.

### Consequences

- Preservation rule enforced in three places:
  1. Retention policy ([ADR-004](#adr-004))
  2. Ship-gate harness verifies its presence
  3. Memory persistence for AI collaborator sessions

---

## ADR-002 · v2.x line abandoned

**Date:** 2026-08-04 · **Status:** locked

### Context

The v2.x line (v2.0.0-alpha through v2.1.0) attempted an aggressive redesign: linux-hardened kernel, LUKS installer, Omarchy-config-verbatim base, waybar AI pill, agentic-flow integration. Accumulated too much unproven change too fast.

### Decision

Drop v2.x entirely. Build forward from v1.0.19 on the Omarchy-fork line. *(Later superseded by ADR-006: build forward from v1.1.0 with no Omarchy at all.)*

### Rationale

Ship-gate failures on v2.1.0 traced to too many simultaneous changes rather than any single bug. Reverting to a known-good baseline lets us reintroduce features one at a time with proper regression harness coverage.

### Consequences

- v2.0.18 gold-copy status: revoked ([ADR-004](#adr-004))
- v2.1.0 experimental branch: archived to `archive/pre-gsd-2026-08-03` on remote
- v1.0.19 became temporary forward-build base until superseded 4 days later

---

## ADR-001 · Ship-gate discipline: never hand a user an ISO without oneshot.sh

**Date:** 2026-08-02 · **Status:** locked HARD RULE

### Decision

Never hand the user an ISO to burn/flash without running `iso/qa/oneshot.sh` first. The gate runs:

1. **Layer 1 — static:** lint scripts, verify VERSION, check config sanity
2. **Layer 2 — container:** build inside archiso Docker, inspect manifest
3. **Layer 2.5 — regression:** `iso/qa/verify-shipped-iso.sh` asserts every past fix is intact
4. **Layer 3 — QEMU:** boot the ISO headless, take screendumps, assert desktop reached

### Rationale

The 2.1.0 "red-banner incident" — user booted a shipped ISO to find a Plymouth-splash red error banner that was never caught pre-ship. Root cause: someone shipped without oneshot.

### Consequences

- Gate is mandatory before every ship
- Failure at any layer = do not hand off; investigate + fix
- Post-v1.1.0 milestones extend the harness with new checks per feature

---

## Format for future ADRs

Copy this template when adding a new decision:

```
## ADR-NNN · Short title

**Date:** YYYY-MM-DD · **Status:** proposed | locked | superseded | permanent

### Context
What situation prompted this decision?

### Decision
What we're doing.

### Rationale
Why we're doing it — the strongest arguments for the choice.

### Consequences
What changes as a result. What we've committed ourselves to.

### Supersedes (optional)
Links to ADRs this replaces.
```
