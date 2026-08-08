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
  │       ├── spawn `claude -p "$MISSION_PROMPT" --output-format stream-json` in sandbox
  │       ├── stream logs to journal + POST /missions/<id>/logs
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
- `/usr/lib/vinos/cmd/*.sh` — subcommand implementations
- `/usr/lib/vinos/registry/mcp-servers.json` — curated MCP registry
- `/etc/vinos/` — config templates
- `/etc/systemd/system/vinos-agent-worker.service` — systemd unit (dev opts in, vm opts in by default)
- `/etc/apparmor.d/vinos-claude` — apparmor profile
- Bash test suite under `/usr/lib/vinos/tests/` for `vinos doctor`

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
