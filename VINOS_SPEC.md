# VINOS_SPEC.md — vinOS Build Specification

**Version:** 1.0
**Owner:** Vin Patel
**Purpose of this document:** Complete, self-sufficient spec for Claude Code to build vinOS from zero. Follow it exactly. Where the spec is silent, choose the simplest option that preserves the Three Rules.

---

## 1. What vinOS is

vinOS is an opinionated Arch Linux layer: **stock Arch + curated packages + configs + idempotent install scripts = a personal distro.** No custom packages, no custom kernel, no custom repos.

vinOS is also a **base for forks**. The first planned fork is `vinos-edu` (offline education OS with a local LLM for rural schools). The base must therefore be modular from day one.

Two consumption modes:
1. **Installer mode (v1, this spec):** run on an existing fresh Arch install via one command:
   `curl -fsSL https://raw.githubusercontent.com/<VIN_GH_USER>/vinos/main/boot.sh | bash`
2. **ISO mode (v2, Milestone 5):** archiso profile that bakes the same scripts into a bootable live ISO.

---

## 2. The Three Rules (LAW — never violate)

### Rule 1 — Desktop is a module, not the base
- `install/02-desktop.sh` is the ONLY file allowed to install or configure a DE/WM, display server, compositor, login manager, or bar.
- vinOS base ships 02 with **Hyprland** (Wayland).
- No other script (01, 03, 04, 05) may assume Wayland, Hyprland, X11, or any desktop exists. They must succeed on a headless system.
- Forks swap desktops by shadowing this one file only.

### Rule 2 — Forks overlay, never edit
- Base owns install script numbers **01–09**. Forks own **10–99**.
- Forks may: (a) ADD scripts numbered 10+, (b) SHADOW config files (fork's `config/X` replaces base's `config/X` at copy time), (c) SHADOW `02-desktop.sh` and `05-branding.sh` specifically.
- Forks may NEVER modify a base file. If a fork needs different base behavior, the base gains a variable or hook.
- EVERY script, base and fork, must be **idempotent**: safe to re-run any number of times. Check-before-install, no duplicate lines appended to files, no failures on "already exists."

### Rule 3 — Identity lives in one place
- `install/05-branding.sh` is the ONLY script that touches identity: writes `/etc/os-release` overrides, sets wallpaper, installs `vinos-*` commands from `bin/`, installs logo assets.
- os-release values: `NAME="vinOS"`, `PRETTY_NAME="vinOS <version>"`, `ID=vinos`, `ID_LIKE=arch`, `VERSION_ID` read from the repo `VERSION` file.
- Forks re-brand by shadowing only this script.

---

## 3. Repository layout

```
vinos/
├── boot.sh                  # curl-able entrypoint: installs git if missing,
│                            # clones repo to ~/.local/share/vinos, runs install.sh
├── install.sh               # orchestrator (see §5)
├── install/
│   ├── 01-base.sh           # core packages + AUR helper
│   ├── 02-desktop.sh        # Hyprland module (swappable)
│   ├── 03-configs.sh        # copy config/ → ~/.config with shadowing logic
│   ├── 04-services.sh       # enable systemd units
│   └── 05-branding.sh       # identity (Rule 3)
├── config/                  # dotfiles, mirrored to ~/.config
│   ├── hypr/hyprland.conf
│   ├── waybar/{config.jsonc,style.css}
│   ├── alacritty/alacritty.toml
│   └── fastfetch/config.jsonc      # shows vinOS logo + name
├── default/
│   └── wallpaper.png
├── assets/
│   └── logo/                # vinos.svg, vinos-mono.svg, png/{16,32,128,512}.png
├── bin/
│   ├── vinos-update         # git pull repo + re-run install.sh
│   ├── vinos-doctor         # health checks (see §7)
│   └── vinos-version        # prints VERSION
├── lib/
│   └── common.sh            # shared helpers: log(), install_pkg(), copy_config(),
│                            # append_once(), require_not_root()
├── overlays/
│   └── example/             # dummy fork proving the overlay contract (see §6)
│       ├── install/10-hello.sh
│       └── config/fastfetch/config.jsonc
├── iso/                     # archiso profile (Milestone 5)
├── tests/
│   └── test.sh              # containerized acceptance test (see §8)
├── VERSION                  # e.g. 1.0.0
├── LICENSE                  # MIT, © Vin Patel
├── ATTRIBUTIONS.md          # prior art / borrowed patterns (MIT chain-of-credit)
└── README.md
```

---

## 4. Script specifications

All scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, source `lib/common.sh`, log every action with the `log()` helper, and be idempotent (Rule 2).

### lib/common.sh
- `log "msg"` — timestamped colored output.
- `install_pkg pkg...` — `pacman -S --needed --noconfirm` (the `--needed` flag is the idempotency mechanism).
- `install_aur pkg...` — same via `yay`.
- `copy_config SRC_ROOT` — rsync `SRC_ROOT/` into `~/.config/`, overwriting (this is the shadowing mechanism: called first with base `config/`, then with each overlay's `config/`).
- `append_once "line" file` — grep before append.
- `require_not_root` — abort if EUID 0; scripts use `sudo` internally where needed.

### boot.sh
1. Abort if not Arch (`/etc/arch-release` check).
2. `sudo pacman -Sy --needed --noconfirm git`.
3. Clone (or pull if exists) repo to `~/.local/share/vinos`.
4. `exec ~/.local/share/vinos/install.sh "$@"`.

### install.sh (orchestrator)
1. Parse flags: `--dry-run` (print actions, execute nothing), `--overlay <path>` (repeatable), `--skip <NN>` (skip a numbered script).
2. Build script list: base `install/[0-9][0-9]-*.sh` sorted, then each overlay's `install/[0-9][0-9]-*.sh` sorted. Overlay files with the SAME filename as a base file REPLACE it in the list (this implements shadowing of 02/05).
3. Run each script; on failure, print which script failed and the resume command (`install.sh --resume NN` acceptable alternative to --skip).
4. After scripts: call `copy_config` for base then overlays (config shadowing).
5. Print summary + `fastfetch`.

### install/01-base.sh
- Packages: `base-devel git curl wget rsync openssh ufw fastfetch btop unzip man-db bash-completion`.
- Install `yay` from AUR if absent (clone to /tmp, makepkg).
- MUST NOT touch anything graphical (Rule 1).

### install/02-desktop.sh  (Hyprland module — base default)
- Packages: `hyprland waybar alacritty wofi mako grim slurp xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-gnome greetd greetd-tuigreet ttf-jetbrains-mono-nerd`.
- Configure greetd to launch Hyprland.
- This is the ONLY graphical script (Rule 1).

### install/03-configs.sh
- Just calls `copy_config "$REPO/config"`. Overlay configs are applied by the orchestrator afterward. Keep dumb.

### install/04-services.sh
- `systemctl enable` (not `--now` in dry contexts): `greetd` (only if installed — check, don't assume; Rule 1), `ufw`, `sshd` optional behind a variable `VINOS_ENABLE_SSH=1`.
- UFW: default deny incoming, allow outgoing, allow ssh if enabled. (Note: on some Arch setups UFW's nftables sync fails; if `ufw enable` errors, log a warning and continue — do not hard-fail the install.)

### install/05-branding.sh  (Rule 3)
- Write `/etc/os-release` override safely: copy original to `/etc/os-release.arch.bak` once, then write vinOS fields (keep all other original fields intact).
- Copy `assets/logo/` → `/usr/share/vinos/logo/`.
- Copy `default/wallpaper.png` → `/usr/share/vinos/wallpaper.png`.
- Symlink `bin/vinos-*` → `/usr/local/bin/`.
- fastfetch config already points at the vinOS logo via 03.

---

## 5. bin/ commands

- **vinos-update:** `git -C ~/.local/share/vinos pull` then re-run `install.sh` (idempotency makes this safe).
- **vinos-doctor:** checks and prints PASS/FAIL for: os-release says vinos, all base packages present, configs in place, enabled services active or enabled, repo clean/up-to-date. Exit non-zero on any FAIL.
- **vinos-version:** cat VERSION.

---

## 6. Overlay contract proof (overlays/example)

Ship a dummy fork inside the repo proving Rule 2 end-to-end:
- `overlays/example/install/10-hello.sh` — installs `cowsay`, idempotent.
- `overlays/example/config/fastfetch/config.jsonc` — identical to base but with a marker comment `// overlay-applied`.
- Test: `install.sh --dry-run --overlay overlays/example` must list 10-hello.sh after 05, and final config copy order must show the overlay winning.

---

## 7. Milestones (one Claude Code session each)

1. **M1 — Skeleton:** repo tree, common.sh, boot.sh, install.sh with --dry-run working. DONE WHEN: `./install.sh --dry-run` prints the full ordered plan on any Linux box.
2. **M2 — Base install:** 01, 03, 04 run clean on fresh Arch container. DONE WHEN: tests/test.sh passes headless (no 02).
3. **M3 — Branding:** 05 + bin commands + fastfetch shows "vinOS". DONE WHEN: `vinos-doctor` all-PASS in container; `cat /etc/os-release` shows NAME="vinOS".
4. **M4 — Overlay proof:** orchestrator overlay/shadow logic + overlays/example passing. DONE WHEN: overlay test in §6 passes.
5. **M5 — Desktop + ISO:** 02 verified on real hardware (Acer), then `iso/` archiso profile that embeds the repo and runs install at build time into airootfs. DONE WHEN: ISO boots in QEMU (4GB RAM) to greetd → Hyprland with vinOS branding.

Do not start a milestone until the previous one's DONE WHEN is green.

---

## 8. Acceptance tests (tests/test.sh)

Runs in a disposable Arch container (prefer `docker run --rm archlinux:latest` or systemd-nspawn; never test destructive steps on the host):
1. Copy repo in, create non-root user with sudo.
2. Run `install.sh --skip 02` (headless — Rule 1 says this must work).
3. Run it a SECOND time — must succeed with zero changes/errors (idempotency test).
4. Run with `--overlay overlays/example` — cowsay present, overlay config marker present.
5. Run `vinos-doctor` — exit 0.
6. Grep guardrails: `grep -rE "hyprland|wayland|waybar" install/ --exclude=02-desktop.sh` must return nothing (Rule 1 enforcement); no base file references overlay paths (Rule 2).

---

## 9. Conventions for Claude Code

- Bash only. No Python dependencies in install path.
- Every commit message: `M<milestone>: <what>`.
- Never `pacman -Syu` inside scripts except boot.sh's initial `-Sy` (partial-upgrade safety: use `--needed` installs only).
- Ask nothing interactive; all scripts fully non-interactive (`--noconfirm`).
- If a step can fail on some hardware (UFW/nftables, GPU drivers), warn-and-continue; never brick the run.
- Keep every script under ~80 lines; push shared logic into lib/common.sh.

## 10. Out of scope for v1

Secure Boot, disk encryption, multi-user provisioning, NVIDIA drivers, vinos-edu content (LLM/Kiwix — that's the fork's 10+ scripts, separate spec).
