# Install vinOS

Three install paths, all end at the same working vinOS desktop. Pick
whichever matches your situation:

- **Path A** — Flash the vinOS ISO to USB, boot, run one command from the
  live desktop. Zero prior Arch knowledge needed. Detects hardware
  automatically. See [Path A — single ISO](#path-a-single-iso-recommended).
- **Path B** — You already have Arch (or Omarchy, EndeavourOS, etc.)
  running. One `curl | bash` layers vinOS on top. See [Path B — on
  existing Arch](#path-b-on-existing-arch).
- **T2 Mac path** — On 2018-2020 T2 Macs, use the community
  [t2linux Arch build](https://wiki.t2linux.org) and then Path B. Or
  wait for Path A which auto-detects T2 hardware. See [T2 Mac](#t2-mac).

---

## Path A — Single ISO (recommended)

**No prior Arch install needed.**

1. Download the latest ISO from [Releases](https://github.com/vinpatel/vinos/releases) (~3 GB).
2. Flash to USB. On Linux/Mac:
   ```bash
   sudo dd if=vinos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync && sync
   ```
   Or use [Etcher](https://etcher.balena.io) / [Rufus](https://rufus.ie).
3. Boot the target machine off the USB. syslinux menu appears; press Enter for the default entry.
4. Wait ~2 minutes → live vinOS desktop.
5. Open a terminal (`Super+Return`) and run:
   ```bash
   sudo vinos-install-disk
   ```
6. Three prompts: which disk, username (defaults to `vin`), hostname (defaults to `vinos`). Confirm the wipe. `vinos-install-disk` auto-detects your hardware (Apple T2 / NVIDIA / generic), picks the right kernel + firmware, installs Arch, layers vinOS, configures the bootloader.
7. ~15 min later, reboot when prompted.

Non-interactive (for provisioning tools):
```bash
sudo vinos-install-disk --disk /dev/nvme0n1 --user vin --hostname vinos-mbp --yes --reboot
```

## Path B — On existing Arch

If you already have Arch running (or Omarchy, EndeavourOS, CachyOS, Manjaro):

```bash
curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
```

That clones this repo to `~/.local/share/vinos` and runs `install.sh`. Everything is idempotent — safe to re-run.

## T2 Mac

On 2018-2020 T2 Macs, you have three options:

- **Easiest (Path A)**: flash the vinOS ISO. `vinos-install-disk` detects `Apple Inc.` in DMI and auto-selects the `linux-t2` kernel + `apple-bcm-firmware` + `tiny-dfr` + friends from the arch-mact2 repo. Bootloader is systemd-boot pinned to `linux-t2` by default.

- **Path B, existing Arch install**: if you're already running Arch on the Mac (e.g. via t2linux's `t2archinstall`), just:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
  ```

- **Manual (if you want control)**: follow the t2linux wiki for the base Arch install:
  - [Pre-install](https://wiki.t2linux.org/guides/preinstall/) — Secure Boot off, allow external boot.
  - [Arch install guide](https://wiki.t2linux.org/distributions/arch/installation/).
  Then run our one-liner.

## What `boot.sh` does

- Installs `git` if missing.
- Clones this repo to `~/.local/share/vinos`.
- Runs `install.sh` which orchestrates the numbered scripts:
  - `01-base.sh` — core packages + yay AUR helper
  - `02-desktop.sh` — Hyprland stack + terminals + UX apps
  - `03-configs.sh` — copies `config/` → `~/.config/`
  - `04-services.sh` — enables iwd, resolved, ufw; disables
    wait-online
  - `05-branding.sh` — os-release, wallpaper, logos, vinos-* CLIs,
    Plymouth theme, docs
  - `06-hardware.sh` — detects Apple / NVIDIA / AMD / Intel / Dell /
    ASUS and installs the appropriate drivers + config

Everything is **idempotent** — re-running is safe. Each script logs
what it does. If any script fails, resume with:

```bash
cd ~/.local/share/vinos && ./install.sh --skip NN
```

## First moves after install

Log out (or reboot) → greetd → tuigreet → Hyprland → wallpaper +
waybar. Then:

- **`Super + K`** — open the keybindings cheat sheet.
- **`Super + Ctrl + O`** — open the vinOS menu. Install optional
  bundles (AI, dev, media, gaming, office, productivity, comms,
  browser) from here.
- **`Super + Ctrl + W`** — connect wifi via impala.
- **`Super + A`** — AI chat (needs `vinos-install-ai` first).

## Optional bundles

Base vinOS is lean. Persona-specific apps opt in via bundle scripts.
Full catalog: [docs/BUNDLES.md](BUNDLES.md).

```bash
vinos-install-ai            # ollama + claude-code + torch + aichat + open-webui
vinos-install-dev           # postgres + redis + k8s + rust + go + docker + mise
vinos-install-media         # mpv + kdenlive + obs + spotify + evince + pinta
vinos-install-office        # libreoffice + thunderbird
vinos-install-gaming        # steam + lutris + gamemode
vinos-install-productivity  # obsidian + notion + typora + 1password
vinos-install-comms         # signal + localsend
vinos-install-browser       # chromium + firefox
```

Set `VINOS_INSTALL_ASSUME_YES=1` to skip the confirm prompt (useful in
dotfiles / provisioning).

## Overlay forks

Ship a persona variant on top of vinOS by running `install.sh` with
your overlay directory:

```bash
./install.sh --overlay overlays/education
./install.sh --overlay overlays/health
```

Each overlay adds its own scripts (numbered 10+, per Rule 2) and can
shadow any config file. See [overlays/README.md](../overlays/README.md).

## Where things live after install

```
/usr/share/vinos/
  ├── VERSION
  ├── logo/                # svg + png
  ├── themes/              # tokyo-night, catppuccin-mocha, rose-pine, everforest, gruvbox-dark
  ├── docs/KEYBINDINGS.txt # what Super+K shows you
  └── wallpaper.png        # symlink → active theme

/usr/local/bin/vinos-*     # symlinks
~/.config/                 # copied from config/ (hypr, waybar, foot, walker, mako, kvantum, ...)
~/.local/share/vinos/      # the repo checkout, for updates
~/.local/state/vinos/      # bundle install log, first-boot sentinels
```

## Uninstall / roll back

vinOS doesn't modify base Arch packages — everything additive. To
remove:

```bash
sudo pacman -Rns hyprland waybar foot mako walker-bin ...  # any bundle
rm -rf ~/.config/hypr ~/.config/waybar ~/.config/vinos ~/.local/share/vinos
sudo mv /etc/os-release.arch.bak /etc/os-release          # if 05-branding ran
```

## Live ISO (secondary path)

If you'd rather try vinOS before installing Arch, we ship a live ISO
too — see [iso/README.md](../iso/README.md) and [docs/USB.md](USB.md).
Install-on-Arch (this document) is the primary supported path;
the ISO is a convenience for the "try before you commit" case.
