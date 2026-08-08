# vinOS dual-persona spec — Option C locked in

**Date:** 2026-08-08 · **Decision:** Option C · **Baseline:** v1.1.0
**Constraints:** dev = pure Arch · vm = Ubuntu 24.04 LTS minimal · shared vinOS layer is distro-agnostic bash · no Omarchy code

---

## Decision (2026-08-08)

Two personas, two distros, one brand, one runtime API:

| | **`vinos-dev`** (workstation) | **`vinos-vm`** (cloud worker) |
|---|---|---|
| Base distro | **Arch Linux** (rolling, archiso build) | **Ubuntu 24.04 LTS minimal** (LTS, packer build) |
| Kernel | `linux` + `linux-t2` | `linux-image-generic` (with Ubuntu Pro-style hardening drop-in) |
| Package format | `.pkg.tar.zst` (pacman) | `.deb` (apt) |
| vinOS runtime layer | bash scripts + systemd units + `/etc/vinos/*` — **identical on both distros** | ditto |
| Distribution | Signed archiso `.iso` (BIOS+UEFI) | qcow2 / AMI / VHD / DO snapshot + `.deb` via `apt.vinos.computer` |
| Target audience | Solo devs, hackers, "Hyprland power users" | Cloud fleets, AgenticFlow workers, headless boxes |
| First-boot state | greetd → Hyprland session → first-run wizard | cloud-init → `vinos-agent-worker.service` → polling orchestrator |
| Update model | user-driven, `pacman -Syu` | fully unattended `unattended-upgrades` weekly + kernel-reboot gate |
| RAM idle | ~1.5 GB | **~250 MB** |
| Image size | ~4-5 GB ISO | **< 800 MB qcow2** |
| Boot to ready | ~20 s to greetd | **< 45 s to first-agent-heartbeat** |

**Rationale for Option C:** Ubuntu is the *only* base with universal cloud-marketplace presence, Canonical-maintained cloud-init, and apt-native tooling assumptions in the entire agentic-workflow ecosystem. Arch on a cloud VM = < 1 % adoption ceiling. Ubuntu on a cloud VM = universal reach. See appendix for the full option debate that led here.

**The vinOS *layer* is portable across both distros** — the bash CLI, systemd units, and config drop-ins are identical. Only the *base* and *package metadata* differ. Users see one brand, one CLI, one experience.

---

## Persona 1 — `vinos-dev` (developer workstation)

*Unchanged from the earlier research pass. Summary here; full details in commit history if we want to revisit.*

- **UX story:** v1.1.0 already ships **88 `vinos-*` scripts + `vinos-menu` + `vinos-first-run` + `vinos-cheatsheet`** and modular `config/hypr/{bindings,apps,toggles}/` with `bindd = ..., "Description", exec, cmd` self-documenting pattern. The Omarchy-parity UX is 80 % built — it just needs the `hyprland.conf` to source-in the modular subdirs and migrate from `bind =` to `bindd =` everywhere.
- **5 moves to beat Omarchy:** Zero-friction Claude Code onboarding · Baked-in Ollama · `vinos-mcp` CLI · Waybar AI status pill · `vinos-doctor` diagnostic ritual.
- **Stylistic edge:** we use bash where Omarchy uses Lua. Fewer runtime deps, cleaner PRs, easier to grok.
- **Packages added on top of v1.1.0's ~230:** language runtimes (`nodejs`, `python`, `rustup`, `go`, `deno`, `bun`), container/k8s tooling (`docker`, `kubectl`, `k9s`, `helm`), IaC (`terraform`, `ansible`), AI (`ollama`, `llama.cpp` from AUR), editors (`helix`, `zed`), Claude Code preinstalled via npm.
- **Dropped from v1.1.0:** VM guest tools (`virtualbox-guest-utils-nox`, `hyperv`, `open-vm-tools`, `qemu-guest-agent` — belong on `vinos-vm`), rescue heavies (`partimage`, `clonezilla`, `fsarchiver` — live-ISO only, not installed).

---

## Menu system design (`vinos-dev` UX layer)

Three tiers of navigation, one visual language, keyboard-first with mouse-optional:

### Tier 1 — App launcher (Super+Space)

**Backend:** `walker` (already in v1.1.0). Fuzzy-search text-mode launcher — fast, keyboard-first.

- Type to filter apps, files, shell commands, math, emojis, symbols, clipboard history, websearches
- Sub-100 ms response — walker is Go-based, native Wayland
- One row per result with Nerd Font icon + name + subtle secondary text
- Enter = launch, Ctrl+Enter = launch in terminal, Alt+Enter = launch as root

**Configured for beauty:**
```
window {
  gtk-halign = center
  gtk-valign = center
  width = 720
  margin_top = 200
}
list {
  height = 400
  max_entries = 12
  scrollbar_policy = never
}
theme = vinos-aurora   # matches Hyprland border gradient
```

### Tier 2 — Visual app grid (Super+Ctrl+Space)

**Backend:** `nwg-drawer` — full-screen icon grid, macOS Launchpad-style. **MISSING in v1.1.0.**

- Full-screen background blur (Hyprland decoration passes through)
- Grid of every installed `.desktop` app with big icons
- Type-to-filter narrows down in-place
- Arrow keys or mouse-hover to select
- Escape = dismiss without launching
- Categorized rows (Development, Media, Games, Utilities, etc.) driven by XDG category
- Recent apps pinned to first row

**Why both Tier 1 + Tier 2:** power users hit Super+Space and type; visual users hit Super+Ctrl+Space and click. Same app set, two entry points. Discoverability wins.

### Tier 3 — vinOS menu (Super+Alt+Space)

**Backend:** `walker -m menu` with a custom vinOS menu tree fed from `/usr/lib/vinos/menu/root.json`.

The full tree — every setting, action, and toggle reachable in ≤ 3 keystrokes:

```
vinOS ⌘
├── 🖥  Apps                     → nwg-drawer
├── ⚙  System
│   ├── 📶 WiFi                  → impala (TUI)
│   ├── 🔵 Bluetooth             → bluetui
│   ├── 🔊 Audio                 → pavucontrol / wiremix
│   ├── 🖥  Displays              → nwg-displays + vinos-hyprland-monitor-*
│   ├── ⚡ Power profile          → power-profiles-daemon (perf | balanced | saver)
│   ├── 🔒 Lock                   → hyprlock
│   ├── 🔁 Restart                → systemctl reboot
│   └── ⏻ Shutdown                → systemctl poweroff
├── 🤖 AI
│   ├── 💬 Claude Code           → foot -e claude
│   ├── 🧠 Local models          → ollama list / pull / rm submenu
│   ├── 🔌 MCP servers           → vinos-mcp list / add / remove submenu
│   ├── 🎛  LiteLLM proxy         → status + restart + logs
│   └── 📜 Recent sessions       → journalctl -u claude-code
├── 🪟 Windows
│   ├── ◇  Toggle transparency   → vinos-hyprland-window-transparency-toggle
│   ├── ▨  Toggle gaps            → vinos-hyprland-window-gaps-toggle
│   ├── ⬜  Toggle borders         → vinos-hyprland-toggle-disabled/enabled
│   ├── ⛶  Fullscreen             → hyprctl dispatch fullscreen
│   ├── ▧  Float / Center          → vinos-hyprland-window-single-square-aspect-toggle
│   └── ✕  Close all               → vinos-hyprland-window-close-all
├── 📸 Capture
│   ├── ✂  Screenshot (region)   → grim -g "$(slurp)" | satty
│   ├── 🪟 Screenshot (window)    → grim -g "$(hyprctl activewindow -j | jq …)" | wl-copy
│   ├── 🖼  Screenshot (screen)   → grim | wl-copy
│   ├── 🎥 Record screen         → wf-recorder → ~/Videos/
│   └── 📝 OCR clipboard         → vinos-capture-text-extraction
├── 🎨 Theme
│   ├── ✨ Aurora (current)
│   ├── ❄  Nord
│   ├── 🍂 Gruvbox Dark
│   ├── 🌸 Catppuccin
│   └── 🖼  Wallpaper pick        → nwg-look wallpaper submenu
├── 📁 Files
│   ├── 🏠 Home                   → nautilus ~
│   ├── ⬇  Downloads              → nautilus ~/Downloads
│   ├── 💻 Projects               → nautilus ~/projects
│   └── 🕰  Recent                 → xdg-open recent list
├── 🛠  Development
│   ├── ➕ New project            → git clone prompt
│   ├── 📂 Recent projects       → foot in most-recent workdir
│   ├── 🐳 Containers             → podman ps → picker
│   ├── 📦 Distrobox              → distrobox list → enter
│   └── ⌨  Terminal               → foot
├── ❓ Help
│   ├── ⌨  Keybindings            → vinos-cheatsheet
│   ├── 🩺 Doctor                 → foot -e vinos-doctor
│   └── ℹ  About                  → vinos-about
└── ⎋ Session
    ├── 🔒 Lock                   → hyprlock
    ├── 💤 Sleep                  → systemctl suspend
    ├── 🚪 Log out                → hyprctl dispatch exit
    ├── 🔁 Restart                → systemctl reboot
    └── ⏻ Shutdown                → systemctl poweroff
```

**Navigation:**
- `/` to fuzzy-search across the entire tree (jumps directly to matching leaf)
- `hjkl` or arrows to navigate
- Enter to descend or execute
- `Escape` to go back one level (or dismiss at root)
- `Backspace` also goes back
- Number keys `1-9` jump to that entry's position on the current level

**Visual consistency across all three tiers:**

| Attribute | Value |
|---|---|
| Rounded corners | 12px (matches Hyprland `decoration.rounding`) |
| Background | 90 % opacity, blurred (`decoration.blur.enabled`) |
| Accent color | `#33ccff` gradient → `#bb9af7` (matches Hyprland border) |
| Font (UI) | Inter (`inter-font`) |
| Font (mono) | JetBrains Mono Nerd (already shipped) |
| Icon theme | Yaru (already shipped) |
| Icon size | 32px in grid, 20px in list |
| Selected animation | 200 ms cubic-bezier ease-out (matches `animation = layers` config) |

### Missing Hyprland packages — what to add for v1.2.0

v1.1.0 ships **hyprland, hypridle, hyprlock, hyprpicker, hyprsunset, hyprland-guiutils, xdg-desktop-portal-hyprland**. To hit the menu design above + fully-baked Hyprland experience:

**Category A — official Hyprland pkgs we should add (all in Arch official):**
| Package | Purpose | Why we need it |
|---|---|---|
| `hyprcursor` | Cursor theme system (successor to Xcursor) | Config already sets `HYPRCURSOR_THEME` and `HYPRCURSOR_SIZE` but the loader isn't installed — cursor is silently falling back to Xcursor |
| `hyprpolkitagent` | Native Hyprland polkit agent | Replace `polkit-gnome` for cleaner integration + fewer GTK deps |
| `hyprshot` | Screenshot helper wrapping grim+slurp | Simpler than the current hand-wired grim+slurp+satty pipeline; keeps the good parts optional |
| `hyprutils` | Common utility library | Currently pulled in as a transitive dep; making it explicit avoids surprise breakage |
| `hyprwayland-scanner` | Wayland protocol scanner | Needed if we ever compile Hyprland plugins locally |
| `hyprland-protocols` | Extra Wayland protocol definitions | Enables newer Hyprland IPC features |
| `hyprland-qtutils` | Qt helper utilities for Hyprland | Better Qt app integration (settings dialogs) |
| `hyprpm` | Official Hyprland plugin manager | Users can `hyprpm add <plugin>` — parity with modern Hyprland workflow |

**Category B — Hyprland ecosystem plugins (via `hyprpm` or AUR):**
| Package | Purpose |
|---|---|
| `hyprexpo` | Workspaces overview (macOS Mission Control-style — Super+Tab shows all workspaces as a grid). Big UX win. |
| `hyprbars` | Optional title bars for floating windows |
| `hyprsplit` | Per-monitor workspace groups |
| `hyprgrass` | Touch gesture support (three-finger swipe → workspace, pinch → overview) — relevant on T2 MacBooks |
| `hyprscroller` | Scrollable tiling layout (PaperWM-style alternative to dwindle) |
| `hyprdim` | Dim unfocused windows |

**Category C — menu/drawer/notifier packages (Arch official):**
| Package | Purpose |
|---|---|
| **`nwg-drawer`** | Full-screen visual app grid (Super+Ctrl+Space Tier 2 backend) — **NEW, required** |
| **`nwg-displays`** | GUI display config for the vinOS menu → System → Displays entry — **NEW, required** |
| **`nwg-look`** | GTK theme switcher for vinOS menu → Theme submenu — **NEW, required** |
| **`swaync`** | Sway/Hyprland notification center with a settings-panel UX — **replaces mako for the "control center" feel**. Mako stays for headless/minimal setups; swaync is the dev-persona default. |
| **`wlogout`** | Beautiful logout screen (Session → Log out enters this) — **NEW, required** |
| **`fuzzel`** | Backup launcher (fallback if walker has issues) — **NEW, optional** |
| **`inter-font`** | UI font — matches the visual language spec above — **NEW, required** |

**Category D — clipboard / capture / recording (Arch official):**
| Package | Purpose |
|---|---|
| **`cliphist`** | Clipboard history — feeds walker's clipboard mode — **NEW, required** |
| **`wl-clip-persist`** | Keep clipboard contents after closing source app — quality-of-life — **NEW, required** |
| **`wf-recorder`** | Screen recorder — feeds Capture → Record screen — **NEW, required** |
| **`grimblast`** | Higher-level screenshot wrapper (Hyprland-aware) — **NEW, optional** |
| **`ydotool`** | Wayland-native key/mouse automation (xdotool successor) — needed by some Claude Code MCP tools — **NEW, required** |
| **`wtype`** | Simpler text-input tool — **NEW, optional** |

**Category E — animated wallpaper (choose one):**
| Package | Notes |
|---|---|
| `swww` | Animated wallpaper daemon with transition effects. Fits the "beautiful" ask. |
| `hyprpaper` | Official Hyprland static wallpaper daemon. Simpler, more stable. |
| `mpvpaper` | Video wallpapers via mpv. Heavier. |
| ~~`swaybg`~~ | Current in v1.1.0. Solid but static-only. |

**Recommendation:** switch to `swww` — supports smooth transitions when theme changes trigger a wallpaper swap, and has been proven stable on Hyprland since 0.30+.

### Menu implementation approach

- **Menu tree source:** `/usr/lib/vinos/menu/root.json` (declarative, hand-editable, PR-friendly)
- **Renderer:** `walker -m vinos-menu` reads the JSON, feeds walker's menu mode
- **Icons:** Nerd Font glyphs where terminal-friendly, Yaru SVG icons where walker renders them
- **Themes:** menu accent/blur follows the currently-selected vinOS theme — theme swap re-renders the menu automatically
- **Extensibility:** users can drop files into `~/.config/vinos/menu/*.json` to add custom entries (per-user personalization without forking the system menu)

### What ships as v1.2.0 Phase A2 ("`vinos-menu` binding activation")

1. Add all Category A, C, D packages to `packages.x86_64`
2. Ship `hyprpm add hyprexpo` in `install/first-run/` (Category B plugin — opt-in via first-run wizard)
3. Write `/usr/lib/vinos/menu/root.json` with the tree above
4. Bind Super+Space → walker · Super+Ctrl+Space → nwg-drawer · Super+Alt+Space → walker -m vinos-menu
5. Style walker + nwg-drawer + swaync + wlogout with the vinos-aurora theme (CSS drop-ins)
6. Test each menu path in QEMU with `iso/test-desktop.sh` screendumps

Package delta from v1.1.0 for this feature: **+18 packages, all Arch official, ~40 MB total**. No AUR beyond what v1.1.0 already ships.

---

## Persona 2 — `vinos-vm` (Ubuntu 24.04 LTS cloud worker)

### 2.1 Base

- **Ubuntu 24.04 LTS "Noble Numbat" minimal** (`ubuntu-minimal` seed, ~150 MB)
- Kernel: `linux-image-generic-hwe-24.04` (stable + backported HWE for newer instance types)
- Init: systemd (Ubuntu default)
- Locale: `en_US.UTF-8` fixed, no i18n stack
- No snap. Blocked via `/etc/apt/preferences.d/nosnap.pref` — snap adds ~100 MB and telemetry we don't want.

### 2.2 Package composition — ~90 packages total

**Base (25):**
- `ubuntu-minimal`, `ubuntu-server-minimal`
- `openssh-server`, `sudo`, `ca-certificates`, `gnupg`, `curl`, `wget`
- `apt`, `apt-utils`, `unattended-upgrades`, `apt-listchanges`
- `iproute2`, `iputils-ping`, `dnsutils`
- `locales`, `tzdata`
- `vim`, `less`, `htop`, `jq`
- `bash`, `bash-completion`, `coreutils`, `util-linux`

**Cloud (7):**
- `cloud-init`, `cloud-guest-utils`, `cloud-initramfs-growroot`
- `qemu-guest-agent`, `spice-vdagent`, `open-vm-tools`, `hyperv-daemons`

**Security (12):**
- `apparmor`, `apparmor-utils`, `apparmor-profiles`, `apparmor-profiles-extra`
- `nftables` (not ufw — cleaner for our use case)
- `fail2ban`
- `auditd`, `audispd-plugins`
- `haveged`
- `libpam-tmpdir`
- `debsecan`, `debsums`

**Agentic runtime (18):**
- `nodejs` + `npm` (from NodeSource repo, pinned to Node 22 LTS)
- `python3`, `python3-pip`, `python3-venv`, `python3-uv`
- `podman`, `podman-compose` (no docker — rootless podman aligns with security posture)
- `git`, `tmux`
- `yq` (jq already above)
- `systemd-timesyncd` (default), `chrony` optional
- vinOS runtime `.deb` packages:
  - `vinos-agent-worker` — the systemd worker service + CLI dispatcher
  - `vinos-mcp` — MCP server registry CLI
  - `vinos-hardening` — sysctl + ssh + nftables + apparmor drop-ins
  - `vinos-cloudinit` — multi-provider cloud-init defaults + agent bootstrap hook

**Opt-in add-ons via `vinos install <role>`:**
- `vinos install cloud` → `awscli`, `google-cloud-cli`, `azure-cli`
- `vinos install iac` → `terraform`, `ansible`
- `vinos install k8s` → `kubectl`, `helm`
- `vinos install ai-local` → `ollama` (adds ~100 MB base + model weights on demand)

### 2.3 Security posture (all shipped as `vinos-hardening.deb`)

**SSH** (`/etc/ssh/sshd_config.d/10-vinos.conf`):
```
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
X11Forwarding no
AllowAgentForwarding no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
```

**sysctl** (`/etc/sysctl.d/50-vinos.conf`):
```
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.log_martians=1
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
kernel.unprivileged_bpf_disabled=1
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.protected_fifos=2
fs.protected_regular=2
fs.suid_dumpable=0
```

**nftables** (`/etc/nftables.conf`):
```
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        ct state invalid drop
        iif lo accept
        ip protocol icmp accept
        tcp dport 22 accept
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output  { type filter hook output  priority 0; policy accept; }
}
```

**AppArmor:** Ubuntu ships apparmor enforcing by default. We add profiles for:
- `sshd` (already in `apparmor-profiles`)
- `podman` (already in `apparmor-profiles-extra`)
- `claude` (custom — restrict to `~/work/*`, `/etc/vinos/*`, network out)
- `vinos-agent-worker` (custom — same as claude scope + read `/var/lib/vinos/*`)

**Auto-updates** (`/etc/apt/apt.conf.d/50vinos-unattended`):
```
Unattended-Upgrade::Origins-Pattern {
    "origin=Ubuntu,archive=noble-security";
    "origin=vinOS,archive=noble";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
Unattended-Upgrade::Package-Blacklist { };
```
Kernel update → reboots at 03:00 UTC only if no active mission (`vinos-agent-worker` writes a lockfile during active work; reboot script honors it).

**auditd rules** (`/etc/audit/rules.d/vinos.rules`):
- log sudo invocations, ssh logins, pacman/apt package installs, kernel module loads, cron modifications, apparmor denials

### 2.4 Cloud-init as the sole entry point

Ship `/etc/cloud/cloud.cfg.d/10-vinos.cfg`:

```yaml
datasource_list: [ Ec2, GCE, Azure, DigitalOcean, Hetzner, OpenStack, NoCloud, None ]

users:
  - default
  - name: vinos
    gecos: vinOS agent user
    groups: [sudo, podman]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true

# Pull the vinos-agent-worker bootstrap from environment on first boot.
runcmd:
  - [ systemctl, enable, --now, vinos-agent-worker.service ]
```

**User provides on VM spin-up** (any cloud provider):
```yaml
#cloud-config
users:
  - name: vinos
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... me@laptop
write_files:
  - path: /etc/vinos/agent.env
    content: |
      VINOS_ORCHESTRATOR_URL=https://af.example.com
      VINOS_ORCHESTRATOR_TOKEN=<vault-reference>
      VINOS_WORKER_LABELS=gpu=false,region=us-east-1
      VINOS_RUNNER=claude              # or: codex | aider | custom
      VINOS_RUNNER_MODEL=opus-4-7
      # For air-gapped mode with local models only:
      #   VINOS_RUNNER=aider
      #   VINOS_RUNNER_MODEL=ollama/qwen3-coder:30b
```

That's it. VM is agent-ready in ~30-45 s.

### 2.5 Build pipeline

- **Tool:** [Packer](https://www.packer.io/) with builders for each cloud provider + qemu.
- **Base:** `ubuntu/noble` official cloud image (Canonical-signed).
- **Provisioner:** Ansible playbook `provision/vinos-vm.yml` that:
  1. Adds apt repo `https://apt.vinos.computer/ noble main` (signed with our GPG key)
  2. `apt install vinos-agent-worker vinos-mcp vinos-hardening vinos-cloudinit`
  3. Enables systemd units
  4. Applies AppArmor profiles
  5. Runs `cloud-init clean --logs` for image reset
- **Output matrix:**
  - `vinos-vm-1.2.0-amd64.qcow2` (KVM, DigitalOcean, Hetzner, Linode, Vultr)
  - `vinos-vm-1.2.0-arm64.qcow2` (Ampere, DO ARM droplets, Hetzner ARM)
  - `vinos-vm-1.2.0.ami` (AWS, both amd64/arm64 via matrix)
  - `vinos-vm-1.2.0.vhd` (Azure)
  - `vinos-vm-1.2.0.tar.gz` (GCE)
- **CI:** GitHub Actions matrix, one job per (arch × provider). Publishes to marketplace + fallback `https://cdn.vinos.computer/vm/1.2.0/`.
- **Size discipline:** post-build `debfoster --autoremove` + `apt clean` + `journalctl --vacuum-time=1s` + zero-fill unused blocks before qcow2 compression. Target < 800 MB compressed.

---

## Two-tier model architecture

vinOS operates on a **frontier-decides / local-grinds** split, not a single-model story:

| Tier | Runtime | Cost | Role |
|---|---|---|---|
| **Frontier** | Claude Code (Anthropic API) | pay per token | Plans, reviews, decides, handles novel work, orchestrates. Small call volume, high per-call value. |
| **Workhorse** | Ollama local (Qwen3-Coder / DeepSeek-Coder / Kimi) | free after hardware | Grinds bulk mechanical work — apply N similar fixes, refactor M files, generate boilerplate, run background code review. High call volume, low per-call value. |

**On `vinos-dev`:**
- Ollama ships preinstalled. First-run wizard offers to download a starter model (Qwen3-Coder 30B recommended). No models preloaded in the ISO — would bloat by 18-30 GB.
- **LiteLLM proxy** at `http://localhost:4000/v1` fronts both Anthropic and Ollama with named roles: `vinos-planner` / `vinos-reviewer` / `vinos-architect` route to Claude; `vinos-executor` / `vinos-checker` / `vinos-autoexec` route to local models. Apps target one endpoint; the proxy decides.
- Waybar AI pill shows both tiers' status side-by-side (Claude session activity + local model presence + today's approximate spend).

**On `vinos-vm`:**
- Local models are **opt-in only** (`vinos install ai-local`). Most cloud VMs have no GPU — CPU inference on a 30B model is unusable for real work.
- GPU-equipped instances (AWS g5, GCP A100, Hetzner GPU boxes) get local inference automatically once enabled.
- **Air-gapped mode:** setting `VINOS_RUNNER=aider --model ollama/qwen3-coder:30b` makes the VM never hit the Anthropic API — everything local. Useful for compliance / on-prem / paranoid deployments.

## Runner adapter interface

vinOS is **runner-agnostic at the OS layer.** Claude Code ships as the default because it's the best headless agentic CLI in 2026, but the worker doesn't hard-code it. Users swap runners with one env var; new runners land as ~150 lines of bash each.

**Config:** `/etc/vinos/agent.env`
```
VINOS_RUNNER=claude              # or: codex | aider | custom
VINOS_RUNNER_MODEL=opus-4-7      # runner-specific model name
```

**Adapter files** at `/usr/lib/vinos/runners/`:
```
claude.sh    # default — wraps `claude -p ... --output-format stream-json`
codex.sh     # OpenAI Codex CLI adapter
aider.sh     # aider adapter (supports local Ollama models directly)
custom.sh    # documented template for user-written adapters
```

**Every adapter implements 4 verbs:**

| Verb | Contract |
|---|---|
| `runner_check` | Is the CLI installed + authenticated? Return 0 = ready, non-zero = missing/broken with stderr diag |
| `runner_run <prompt_file> <workspace> <mission_id>` | Execute mission, stream `event\t<json>` lines to stdout, exit 0 on success |
| `runner_cancel <mission_id>` | Graceful stop of an in-flight mission (SIGTERM the process tree, 30 s grace, then SIGKILL) |
| `runner_capabilities` | Emit JSON listing what this runner supports (`streaming`, `mcp`, `tool_use`, `subagents`, `file_edit`) so missions can advertise required capabilities |

The worker (`vinos agent run`) sources the configured adapter, invokes `runner_run`, and forwards the streamed events to the orchestrator. It doesn't know or care which runner is active.

**Why this matters:**
- If Anthropic changes pricing / policy / product direction, swap runners with one env var
- Compliance customers who require "no external API" get an air-gapped mode for free
- New agentic CLIs get first-class support without a codebase rewrite
- MCP servers are shared across all runners (MCP is now cross-vendor), so the tool surface is portable

**Claude stays the shipped default because it wins on:** best-in-class headless mode, MCP-native, prompt caching (~90 % cost reduction on repeated context), 1M context on Opus, enterprise compliance (SOC 2, HIPAA, ISO 27001) already attested. But we're not locked to it.

## The `vinos` CLI — light, memorable, POSIX

**Design principle:** one binary (`vinos`), ≤ 15 subcommands, every subcommand takes JSON input via stdin and emits JSON to stdout. Everything scriptable, idempotent, and predictable.

### The full surface

```
vinos                    # print status one-liner
vinos help               # short help ($ vinos help <cmd> for details)

# --- Fleet + orchestrator ---
vinos join <url>         # register with AgenticFlow orchestrator (writes /etc/vinos/agent.env)
vinos leave              # deregister, stop worker
vinos status             # what's running: worker state, current mission, resources

# --- Agent worker ---
vinos agent start        # start worker daemon (systemd unit under the hood)
vinos agent stop         # stop worker (finishes current mission first unless --force)
vinos agent restart
vinos agent tail         # tail journal for vinos-agent-worker.service
vinos agent config       # dump effective config as JSON

# --- Missions (one-shot workflows) ---
vinos mission run <spec>       # run a mission ad-hoc; spec = local file or URL
vinos mission list             # queued / running / done
vinos mission logs <id>        # stream logs for a mission
vinos mission cancel <id>      # graceful cancel

# --- MCP server registry (same as vinos-dev) ---
vinos mcp add <name>           # e.g. `vinos mcp add github`
vinos mcp list
vinos mcp remove <name>

# --- Ops ---
vinos doctor                   # 25-check health scan → JSON
vinos update                   # apt update && apt upgrade → auto-reboot if kernel
vinos install <role>           # opt-in bundles: cloud | iac | k8s | ai-local
vinos secrets set <key>        # write to /etc/vinos/secrets/ (root-owned, 0600)
vinos secrets get <key>        # read from same
```

**14 subcommands. Learnable in 5 min.** Everything else is `systemctl`, `journalctl`, `apt`.

### Implementation

- Language: **bash** (POSIX-portable, zero runtime deps). Same choice as vinos-dev — beat Omarchy's Lua on simplicity.
- Location: `/usr/bin/vinos` (installed by `vinos-agent-worker.deb`)
- Subcommand dispatch via `case` statement; each subcommand is a source-in file at `/usr/lib/vinos/cmd/<name>.sh`.
- Every state-mutating command writes an event to `/var/log/vinos/audit.jsonl` for forensics.
- Every command supports `--json` output flag; default is human-readable.

---

## Full-automation lifecycle — from `terraform apply` to first mission complete

```
────────────────────────────────────────────────────────────────
User (terraform / manual)
  └── spawns VM with:
      • ubuntu 24.04 LTS (base image = vinos-vm-1.2.0.qcow2)
      • cloud-init user-data with SSH key + /etc/vinos/agent.env
      • provider-tagged for orchestrator discovery
────────────────────────────────────────────────────────────────
Cloud provider
  └── boots VM
      ├── UEFI → GRUB → kernel + initramfs (~4 s)
      ├── systemd init → basic.target (~6 s)
      └── cloud-init.target (~15 s)
          ├── cloud-init parses user-data
          ├── writes /home/vinos/.ssh/authorized_keys
          ├── writes /etc/vinos/agent.env
          ├── systemctl enable --now vinos-agent-worker.service
          └── multi-user.target reached
────────────────────────────────────────────────────────────────
vinos-agent-worker.service (~30-45 s total elapsed)
  ├── reads /etc/vinos/agent.env
  ├── POSTs {hostname, ip, labels, version} to $VINOS_ORCHESTRATOR_URL/register
  ├── receives worker_id + assigned_mission_channel
  ├── enters mission poll loop:
  │   ├── GET /missions?assigned_to=<worker_id>&status=pending
  │   ├── if empty → sleep 30 s → repeat
  │   └── if mission →
  │       ├── materialize to /var/lib/vinos/work/<mission_id>/
  │       ├── source /usr/lib/vinos/runners/${VINOS_RUNNER:-claude}.sh
  │       ├── runner_run $PROMPT $WORKSPACE $MISSION_ID   # adapter drives Claude Code / Codex / Aider / etc.
  │       ├── stream events (JSON per line) to journal + POST /missions/<id>/logs
  │       ├── on completion: POST /missions/<id>/result with git diff + artifacts
  │       └── mark done, poll next
────────────────────────────────────────────────────────────────
```

**Zero manual intervention from `terraform apply` to first mission complete.**

### The `vinos-agent-worker.service` unit

`/etc/systemd/system/vinos-agent-worker.service`:
```
[Unit]
Description=vinOS agentic worker — poll orchestrator, run assigned missions
Documentation=man:vinos-agent-worker(8)
After=network-online.target cloud-init.service
Wants=network-online.target
Requires=cloud-init.service

[Service]
Type=simple
User=vinos
Group=vinos
EnvironmentFile=/etc/vinos/agent.env
WorkingDirectory=/var/lib/vinos/work
ExecStart=/usr/bin/vinos agent run
Restart=on-failure
RestartSec=30
StandardOutput=journal
StandardError=journal

# hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/var/lib/vinos /var/log/vinos /tmp
PrivateTmp=yes
MemoryDenyWriteExecute=no       # claude-code needs W|X (JIT)
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
SystemCallFilter=@system-service
SystemCallArchitectures=native
CapabilityBoundingSet=

[Install]
WantedBy=multi-user.target
```

### Fleet observability

- **Journals:** `journalctl -u vinos-agent-worker -f` → local. `systemd-journal-remote` optional for aggregation.
- **Prometheus:** `vinos-agent-worker` exposes metrics on `127.0.0.1:9100/metrics` (missions_completed_total, mission_duration_seconds, claude_tokens_burned_total, current_mission_id).
- **Health:** `vinos doctor` runs 25 checks, emits Prometheus-compatible textfile at `/var/lib/node_exporter/vinos.prom` if node_exporter is installed.

---

## Shared vinOS runtime layer (identical across dev + vm)

Content that lives in **both** `.pkg.tar.zst` for dev and `.deb` for vm, from the same source tree:

- `/usr/bin/vinos` — top-level dispatcher
- `/usr/lib/vinos/cmd/*.sh` — subcommand implementations (14 subcommands)
- `/usr/lib/vinos/runners/*.sh` — runner adapters (`claude.sh` default; `codex.sh`, `aider.sh`, `custom.sh` shipped)
- `/usr/lib/vinos/registry/mcp-servers.json` — curated MCP registry (portable across runners)
- `/etc/vinos/` — config templates including `agent.env` with `VINOS_RUNNER=claude` default
- `/etc/systemd/system/vinos-agent-worker.service` — systemd unit (dev opts in, vm opts in by default)
- `/etc/apparmor.d/vinos-runner` — generic apparmor profile applied to whichever runner is active
- Bash test suite under `/usr/lib/vinos/tests/` for `vinos doctor` (includes per-runner `runner_check` invocations)

**LiteLLM proxy overlay (dev only)** — `configs/vinos/litellm/proxy.yaml`:
- Runs on `vinos-dev` as `litellm.service`; listens on `http://localhost:4000/v1`
- Routes named model roles (`vinos-planner`, `vinos-executor`, `vinos-checker`, etc.) to either Anthropic or Ollama based on the two-tier policy
- Apps target one endpoint; the proxy handles routing + retry + cost tracking
- **Not** shipped on `vinos-vm` (VMs use `VINOS_RUNNER` directly; no proxy layer needed)

**Both packages are built from the same monorepo path** (`vinos-runtime/`) via a Makefile that emits either `.pkg.tar.zst` (via `makepkg`) or `.deb` (via `debhelper`). Same source, different metadata.

---

## Milestone shape (revised for Option C)

**Milestone `v1.2.0 — Persona activation`** — 3-5 weeks, two parallel tracks.

### Track A — vinos-dev (Arch, archiso)

| Phase | Deliverable |
|---|---|
| A1 | Hypr modular source-in + `bindd =` migration + regenerated `vinos-cheatsheet` |
| A2 | `vinos-menu` activation (Super+Alt+Space + subcommands) |
| A3 | First-run wizard v2 (`gum`-driven, 6 screens) |
| A4 | Preinstall Claude Code + Ollama + `vinos-mcp` CLI + curated MCP registry |
| A5 | Ship `vinos-dev-1.2.0-x86_64.iso` |

### Track B — vinos-vm (Ubuntu 24.04, Packer)

| Phase | Deliverable |
|---|---|
| B1 | Build the shared vinOS runtime monorepo (`vinos-runtime/`) + Makefile that emits both `.pkg.tar.zst` and `.deb` |
| B2 | Publish signed apt repo at `apt.vinos.computer` (GPG-signed, hosted on Cloudflare Pages + R2) |
| B3 | Packer template + Ansible provisioner for Ubuntu 24.04 minimal + vinos-* debs |
| B4 | Multi-arch image build: amd64 + arm64 qcow2 |
| B5 | `vinos-agent-worker` polling loop + orchestrator protocol v1 (JSON over HTTPS) |
| B6 | Full `vinos` CLI implementation (14 subcommands, all tested) |
| B7 | Multi-cloud image publish: DO snapshot + Hetzner image first, AWS AMI + Azure VHD + GCE image second wave |
| B8 | Ship `vinos-vm-1.2.0-{amd64,arm64}.qcow2` + apt repo v1 |

### Cross-cutting

- **CI harness** (`iso/qa/oneshot.sh` + regression harness) covers both tracks. New harness checks:
  - vinos-vm boot-to-SSH < 45 s
  - vinos-vm idle RAM < 300 MB
  - vinos-vm image size < 800 MB
  - `vinos` CLI 14/14 subcommands present
  - all systemd hardening flags applied
- **Nothing on either track mentions "omarchy"** in commit messages or file contents.

**Success criteria for milestone:**
1. Fresh `vinos-dev` boots to working agentic dev env in ≤ 5 min post-login
2. Fresh `vinos-vm` on any cloud accepts an agent config via cloud-init and completes a test mission within 60 s of first boot
3. Both images pass the ship gate
4. `apt.vinos.computer` serves signed `.deb` packages that install cleanly on stock Ubuntu 24.04

---

## Open questions to resolve before phase-planning

1. **Orchestrator protocol.** Does AgenticFlow already define a worker/mission protocol we conform to, or do we design v1 here? (Recommend: design a minimal HTTPS JSON protocol first, adapt to AgenticFlow's when we have it.)
2. **Cloud target priority within Track B.** Recommend Hetzner + DigitalOcean first (< 4 weeks, marketplace-friendly APIs), AWS + GCP + Azure second (needs vendor engineering review, 6-12 weeks).
3. **Ubuntu Pro entitlements.** Ubuntu Pro gives free ESM + livepatch on ≤ 5 personal machines. Do we ask users to attach their token, or ship without? Recommend: without, but document how to attach via `pro attach` for hardened deployments.
4. **apt repo hosting.** Cloudflare Pages + R2 (~$5/mo), or self-hosted on the same nginx as vinos.computer? Recommend: Cloudflare — CDN + signed URLs + no maintenance.
5. **GPG key management.** Who holds the private key for signing the apt repo? Options: hardware token (YubiKey), sops-managed in-repo (encrypted), Cloudflare-managed. Recommend: YubiKey for release signing, sops-encrypted CI key for automated builds.
6. **Local model on `vinos-vm`.** Off by default (bandwidth cost + memory cost). Users opt-in via `vinos install ai-local`. Confirmed?
7. **arm64 first-class?** Adds CI matrix cost but opens Ampere/Graviton cheap-cycles + ARM cloud droplets. Recommend: yes, arm64 first-class from day one.

---

## Recommendation for next move

Same three pilots as before, adjusted for Option C:

| Pilot | What we test | Time |
|---|---|---|
| 2 (unchanged) | `vinos-mcp` bash CLI + test suite | 1 hr |
| 1 (unchanged) | Modular hypr sourcing on live host | 30 min |
| **3 (revised)** | **Stripped Ubuntu 24.04 vinos-vm PoC: Packer build + qcow2 → QEMU headless boot → SSH-in → run `hostname; free -m; systemctl status`** | 2-3 hr |

Pilot 3 is where the Option C bet really gets tested: does the Ubuntu-based vm actually hit the size/boot/RAM targets? Answering that in 3 hours before we commit weeks of milestone work.

---

## Appendix — Option comparison (superseded 2026-08-08)

Preserved for context on why we chose C.

| Option | Fork cost | Adoption ceiling | Time to first marketplace listing | 3-yr maintenance |
|---|---|---|---|---|
| A. Arch for both | none | **~5 % max** (tinkerer segment only) | 6-12 months (custom image flow) | low upfront, painful when Arch churn breaks compat |
| B. Ubuntu for both | vinos-dev has to be rebuilt on Ubuntu, loses tinkerer story | high | 4-8 weeks | mid, but generic |
| **C. Arch for dev, Ubuntu for vm** ✓ | one-time monorepo split, shared bash runtime layer keeps brand unity | **highest** | 4-8 weeks for vm image | mid — two clean codebases beats one confused one |

**Verdict:** Option C. Locked in 2026-08-08. Two products, one brand, one CLI, one runtime API, two package formats.
