---
title: "Install"
description: "Flash the ISO and install to disk, including Apple T2 Macs, which the installer handles on its own."
---

There are two ways in. Take the first one unless you have a reason not to.

## 1. The ISO (recommended)

Download `vinos-1.4.0-x86_64.iso` from the
[releases page](https://github.com/vinpatel/vinos/releases/latest), verify it
against the published `sha256sums.txt`, and write it to any 8 GB+ stick:

```bash
# Linux: replace sdX with your actual USB device, and check it twice
sudo dd if=vinos-1.4.0-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Etcher and Rufus work fine too. Boot the stick, pick **Install vinOS to disk**
from the menu, and answer the prompts. The installer partitions, pacstraps,
installs the bootloader, creates your user, and reboots you into the installed
system.

### On an Apple T2 Mac

Nothing extra to do. The installer detects Apple hardware and installs the
`linux-t2` kernel to disk alongside the stock one, wires the Broadcom Wi-Fi
quirks and the `apple-bce` early-boot modules, enables fan control and the
Touch Bar daemon, and makes the T2 kernel the boot default.

Two things worth knowing:

- **Before you boot the stick:** on the Mac, disable Secure Boot and allow
  booting from external media in Startup Security Utility (hold ⌘R at power-on
  → Utilities → Startup Security Utility). Apple ships both locked down.
- **If the installer cannot reach the T2 package mirror**, it says so and
  finishes on the stock kernel instead of failing. That system boots to a
  readable console, deliberately unsplashed, with the internal keyboard and
  Wi-Fi still dead. Attach a USB keyboard and a wired connection, then run
  `vinos-t2-enable` to finish the job.

**Known T2 limits:** suspend is unreliable upstream, and Touch ID does not work
under Linux. Everything else does.

## 2. Layer it onto an Arch install you already have

If you have a working Arch box you do not want to reinstall, vinOS can go on
top of it. It is additive and does not modify base packages.

```bash
curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
```

That installs `git` if missing, clones the repo to `~/.local/share/vinos`, and
runs `install.sh`, which orchestrates the numbered scripts (`01-base` through
`06-hardware`). Every step is idempotent, so it is safe to re-run. If one
fails, resume past it:

```bash
cd ~/.local/share/vinos && ./install.sh --skip NN
```

This path does **not** set up the T2 kernel for you the way the ISO installer
does. Run `vinos-t2-enable` afterwards on Apple hardware.

## First moves

- **`Super + K`**: the keybindings cheat sheet.
- **`Super + Ctrl + O`**: vinOS menu (bundles, wifi, theme, doctor, lock).
- **`Super + Ctrl + W`**: wifi via impala.
- **`Super + A`**: AI chat (install first with `vinos-install-ai`).

## Bundles

The base install is deliberately small. Add what you actually use:

```bash
vinos-install-ai            # ollama + claude-code + torch + aichat
vinos-install-dev           # postgres + redis + k8s + rust + go + docker + mise
vinos-install-media         # mpv + kdenlive + obs + spotify + evince
vinos-install-office        # libreoffice + thunderbird
vinos-install-gaming        # steam + lutris + gamemode
vinos-install-productivity  # obsidian + notion + typora + 1password
vinos-install-comms         # signal + localsend
vinos-install-browser       # chromium + firefox
```

Full catalog: [Bundles](/bundles/).

## Uninstall

For the layered install, vinOS is additive, with no base package modifications:

```bash
sudo pacman -Rns hyprland waybar foot mako walker ...  # and any bundle
rm -rf ~/.config/{hypr,waybar,foot,mako,walker} ~/.local/share/vinos
sudo mv /etc/os-release.arch.bak /etc/os-release
```

Full source: [github.com/vinpatel/vinos](https://github.com/vinpatel/vinos)
