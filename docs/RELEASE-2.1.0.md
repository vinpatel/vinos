# vinOS 2.1.0 — The Ownership Release

*Released 2026-08-02 · Codename: "Cosmos"*

## Where we are

vinOS is the operating system for AI-agent operators. People whose day is 20+ agent workflows, who care about local privacy AND hosted flexibility, who want the desktop itself to think for them overnight. **2.1.0 is the release where every line of vinOS is ours.** Clean-room configs, hardened kernel, offline-installable, LUKS-encrypted by default, agent-native from the taskbar down.

Between the last archival release and today we shipped eighteen release candidates, hit every install-to-disk failure mode Linux has to offer, fixed each one, and built a **63-check regression harness** so those bugs cannot silently return. This release is that discipline made visible.

---

## Highlights

### 🧠 The AI status pill

Waybar shows a **live agent status pill** — model in use, tokens used today, active routine count, monthly Claude spend. Click for a dropdown with the full `vinos-ai status`. Pulses cyan when routines are running.

Nothing else in Linux signals "agent-native" this immediately. Screenshot the desktop, know instantly what you're looking at.

### 🔒 LUKS full-disk encryption in the installer

Fresh install asks *"Encrypt disk with LUKS? (recommended) [Y/n]"* — default yes. `luksFormat --type luks2 --hash sha512 --pbkdf argon2id --pbkdf-memory 1048576`. Optional TPM2 auto-unlock via `--luks-tpm2`. Every partition below the ESP is encrypted. Stolen laptop = zero data leak.

The stubborn *"random seed file is world accessible, which is a security hole!"* warning that alarmed users during install is now gone. ESP mounts with `fmask=0137,dmask=0027,umask=0077` — root-only, no cosmetic warnings, no encryption sleight-of-hand.

### 🛡 Hardened kernel by default

Generic profile now defaults to **`linux-hardened`** — KASLR max, SLUB hardening, page poisoning, hardened usercopy, KSPP-adjacent patches. T2 profile keeps `linux-t2` (hardware requirement) but exposes `linux-hardened` as a bootloader fallback.

- **24 sysctl values pinned** in `/etc/sysctl.d/99-vinos-hardening.conf`
- **13 rarely-used kernel modules blacklisted** (dccp, sctp, cramfs, firewire-core, hfs, hfsplus, and more)
- Kernel cmdline: `init_on_alloc=1 init_on_free=1 lockdown=confidentiality module.sig_enforce=1`
- **AppArmor** enabled by default with profiles for chromium/firefox/foot/waybar
- **audit** service on for AppArmor DENIED tracking

### 🐳 Docker + Kubernetes ready out of the box

`docker` + `docker-compose` + `containerd` + `runc` + `crun` + `podman` in every install. `kubectl` in `$PATH`. `containerd` uses systemd cgroup driver. `daemon.json` uses overlay2 + buildkit. `br_netfilter` + `overlay` baked into initramfs.

**One-command local Kubernetes cluster:**
```bash
sudo vinos-install-k8s               # kubeadm + Cilium CNI + test pod
sudo vinos-install-k8s --lightweight # k3s alternative (~200MB footprint)
```

25 more sysctl values pinned in `/etc/sysctl.d/99-vinos-k8s.conf` for bridge-nf, ip_forward, inotify limits, max_map_count, tcp keepalive.

### ⚡ One-keystroke install from the boot menu

`⚡ Install vinOS to disk (Apple T2 Mac — guided)` and `⚡ Install vinOS to disk (Intel / AMD / generic PC — guided)` are the first two boot menu entries. Pick one → plymouth splash → wallpaper → installer window opens fullscreen automatically. No terminal, no menu diving, four prompts and done.

---

## Agent-native UX

### Consistent brand accent

`#33ccff` (vinOS cyan) is pinned across waybar highlights, mako notification borders, walker's selected row, hyprland active-window border, hyprlock password field. Theme changes swap wallpaper + palette; the vinOS accent stays. **Brand identity is constant.**

### Routine notifications channel

Mako now has a dedicated **routines** channel — purple accent (`#bb9af7`), groups by routine name, longer default timeout, distinct format:

```
󰚉 day-brief
   finished · 4 items summarized · 2.4k tokens
```

Routine work never drowns in system noise, and vice versa.

### Walker with agent-native quick actions

Search bar with live-filtered app list, plus 6 pinned custom actions:

- **→ Ask vinOS AI** — natural-language query into `vinos-ai chat`
- **→ Run a routine**
- **→ Screenshot region**
- **→ Focus 25 min** — DND + timer via `vinos-focus`
- **→ Switch theme**
- **→ Connect Wi-Fi**

Also: `fd`-backed file search that respects `.gitignore`, calc, clipboard history (20 items with image previews), symbols/emoji picker.

### Faster animation language

Animations are **200ms** with a **single bezier** everywhere: `cubic-bezier(0.16, 1, 0.3, 1)` — the "swift out" curve. Sharp attack, gentle settle. Responsive without twitchy.

### Hyprlock with glance widget

Lock screen shows a subtle one-line status:

```
up 3h 42m  •  4 unread  •  next: day-brief 45m  •  ☁ 68°F
```

Cosmos wallpaper blurred, glass card centered, brand-accent password field. Weather from `vinos-weather-status`, next routine from `vinos-routine next`, unread from mako.

---

## Installer improvements

### Offline clone install

The installer (`bin/vinos-install-disk`) rsyncs the live filesystem to the target instead of pulling packages over the network. **Offline install works.** No mirror dependencies, no DNS bugs, no keyring races. ~90 seconds to clone 5.5 GB to NVMe.

### Ordered install flow (9 phases)

1. Detecting hardware
2. Choosing target disk
3. Choosing username, password, hostname
4. **LUKS encryption prompt**
5. Partitioning
6. Cloning vinOS to target
7. Configuring hostname, user, bootloader
8. Layering vinOS
9. Done

Every phase emits `━━ [N/9] Phase name`. On failure, `✗ Install failed at phase [N/9]: <name>` with an actionable diagnostic.

### First-boot state

Fresh install boots to greetd (tuigreet), password login (no auto-login), Hyprland with cosmos wallpaper, waybar with AI + routines pills, mako standing by. No login-prompt log spam, no leftover users, no error banners.

---

## Under the hood

### 63-check regression harness

Every historical fix has a corresponding automated check in `iso/qa/verify-shipped-iso.sh`. The harness extracts the built ISO, verifies invariants, prints:

```
✓  ALL 63 fixes intact — safe to flash
```

or

```
✗  N REGRESSION(S) — DO NOT FLASH
```

Every failure names the memory entry that describes the fix that regressed. **No fix ships without a corresponding harness check.** This is the discipline that ends "we already fixed this last week" loops.

### Package expansion (295 → 413)

Full dev language runtimes (Python, Node.js, pnpm, Go, Rust, Ruby, Lua), editors (nvim, vim, emacs-nox, helix), fonts (JetBrains Mono Nerd, Fira Code, Noto CJK/emoji), media apps (mpv, imv, obs-studio, kdenlive, audacity), communication (signal-desktop, thunderbird), full container stack (docker, containerd, runc, crun, podman, kubectl), agent tooling (python-httpx, python-pydantic, direnv, age, chezmoi), the hardened kernel + AppArmor + audit.

Every package accountable to a category in `iso/packages.live`. Users install more via `sudo vinos-install-{ai,dev,browser,comms,gaming,media,office,productivity}` bundles.

### Retention policy

`iso/out/` keeps the **three most recent builds** plus TWO permanent archival golden copies:

- `vinos-1.1.0-x86_64.iso` — v1 T2 baseline (2026-07)
- `vinos-2.0.18-x86_64.iso` — v2 install-to-disk baseline (2026-08-02)

Fallback to a proven-working ISO is always one flash away.

---

## Known limitations & non-goals

**What 2.1.0 does not do:**

- **Apple Silicon (M1/M2/M3/M4) — unsupported.** vinOS is x86_64 only today. arm64 support is on the Phase D roadmap.
- **Microsoft Surface — unsupported.** Needs `surface-kernel` for touchscreen + cameras.
- **Chromebooks — mostly unsupported.** Only models with unlocked Coreboot.
- **NVIDIA GPUs older than Turing (pre-2018)** — `nvidia-open-dkms` requires Turing+. Older cards can install `nvidia-dkms` (proprietary legacy) manually.
- **No cloud sync yet.** Routine state stays local. Phase E adds optional e2e-encrypted sync.
- **No first-run onboarding tour.** New users land on the desktop and discover keybindings via `Super+K`. `vinos-welcome` wizard planned for 2.2.0.
- **No native mobile companion.** Roadmap for 3.x.

**"Meticulous UI" is a Phase C goal, not a 2.1.0 claim.** 2.1.0 is a strong first pass — visibly branded, agent-native, functional. Real design polish (typography audit, custom cursor asset, sound scheme, empty-state design, accessibility audit) is 2-3 iterations away.

---

## Verified hardware

**Confirmed working (2.1.0):**
- 2019 T2 MacBook Pro (13-inch, Intel i5, 8 GB RAM)

**High-confidence should-work (2.1.0):**
- All T2 Macs 2018-2020 (MBP/MBA/iMac Pro/iMac/Mini)
- Intel/AMD laptops 2018+ (Dell XPS, Framework 13/16, ThinkPad X1/T-series, HP EliteBook, Lenovo Legion)
- NVIDIA RTX 20-series and newer
- Pre-T2 Intel Macs 2015-2017 (with `macbook12-spi-driver-dkms` from `aur.live`)

Community hardware compatibility DB planned for `vinos.computer/compat/` in Phase C.

---

## Verification & test coverage

Every 2.1.0 build must pass:

1. **Static QA** (`iso/qa/oneshot.sh` Layer 1) — VERSION consistency, foot config sanity, wireless-regdb presence, keybinding audit, package list drift check, hyprland exec binding sanity
2. **Container QA** (Layer 2) — headless install-path test in a docker container
3. **Regression harness** (Layer 2.5) — 63 checks against the built ISO
4. **QEMU boot smoke test** (Layer 3) — verifies the ISO reaches Hyprland desktop in a VM

Only ISOs passing all four layers are released.

---

## What's next (Phase C — 2.2.0)

Coming in the next 3-4 weeks:

- `vinos-webapp-add <url>` — user-installable PWA helper
- **Custom cursor theme** — vinOS-branded, subtle
- **Sound scheme** — soft chime on notify/error/success
- **First-boot welcome tour** — walks new users through Super+A / Super+K / vinos-menu
- **Preset window chords** — Super+Shift+Return (terminal + editor split), Super+Shift+D (3-column dev)
- **Dedicated agent workspace** — Super+A switches to workspace 6 with a preset layout
- **Focus mode ↔ routines integration** — long routine starts DND automatically, waybar dims, clock shows progress
- **AI-augmented walker search** — natural questions inline as "→ Ask vinOS AI" row
- **Recent files** — pinned to top of walker
- **Empty-state design pass** — walker, mako, waybar all get considered empty states
- **Hardware compatibility DB** — user reports + tracked matrix on vinos.computer

Phase D (2.3.0 - 2.5.0): agentic infrastructure — `vinos-tools` standard registry, `vinos-context` persistent memory, `vinos-observability` dashboard, `vinos-marketplace` signed routine bundles.

Phase E (3.0.0): platform opening — vinOS Hub, team edition, enterprise, optional e2e-encrypted cloud sync.

Read the full plan: [`docs/ROADMAP.md`](ROADMAP.md).

---

## The scorecard

| Metric | Before | 2.1.0 |
|---|---|---|
| **Position** | Niche hardware distro | The OS for agent operators |
| **Install-to-disk** | Manual, undocumented | One-keystroke from boot menu, offline, LUKS-encrypted |
| **First agent running** | Not shipped | `sudo vinos-install-ai` → chat in 5 min |
| **Hardware coverage** | T2 Macs only | T2 + modern Intel/AMD/NVIDIA (~90% x86_64 laptops) |
| **Kernel hardening** | Vanilla | linux-hardened + 24 sysctl + AppArmor + module blacklist |
| **Disk encryption** | Not offered | LUKS2 + argon2id in installer, TPM2 optional |
| **Container-ready** | No | docker + containerd + kubectl + one-command k8s |
| **Regression harness** | None | 63 checks, mandatory pre-flash gate |
| **Agent-native UX** | None | AI pill + routines channel + agent workspace prep |
| **Regression policy** | Ad-hoc | Every fix ships with a harness check + memory entry |

---

## Thank you

To the operator who tested every release candidate on a real T2 MacBook, screenshotted every crash, and kept pushing when it would have been reasonable to walk away: **this release exists because you did.**

To the upstream projects that make vinOS possible: Arch Linux, Hyprland, waybar, walker, mako, foot, hyprlock, linux-t2, systemd, cryptsetup, and the linux-firmware maintainers.

---

*vinOS is MIT-licensed. Source: [github.com/vinpatel/vinos](https://github.com/vinpatel/vinos). Site: [vinos.computer](https://vinos.computer/). Download: `iso/out/vinos-2.1.0-x86_64.iso` from the releases page.*
