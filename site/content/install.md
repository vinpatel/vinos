---
title: "Install"
description: "One command on any Arch. T2 Mac path included."
---

vinOS is an Arch layer — install Arch first, then run one command on top.

## Which path are you?

- **You have a 2018-2020 T2 Mac**: [T2 Mac path](#t2-mac).
- **Everything else**: [Standard path](#standard).

## T2 Mac

The T2 chip owns internal keyboard, trackpad, wifi, audio. Stock Arch
can't drive that. Use the community [t2linux](https://wiki.t2linux.org)
Arch build with the patched `linux-t2` kernel.

1. Read + follow **[t2linux pre-install](https://wiki.t2linux.org/guides/preinstall/)** — Secure Boot off, allow external boot, shrink macOS partition.
2. Follow **[t2linux Arch install](https://wiki.t2linux.org/distributions/arch/installation/)**. Use `t2archinstall` (guided) for the easy path.
3. Finish Arch. Log in as your user. Then:

```bash
curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
```

Reboot; you're in the vinOS Hyprland desktop with T2 hardware fully working.

## Standard

Any 2015+ Intel or AMD laptop/desktop.

1. Boot the official Arch install ISO (or any Arch flavor's live media).
2. Run `archinstall`. Pick your kernel, filesystem, timezone, user, sudo. **Profile: minimal** — vinOS handles the rest.
3. Reboot into your new Arch. Log in.
4. Run:

```bash
curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
```

## What the one-liner does

- Installs `git` if missing.
- Clones this repo to `~/.local/share/vinos`.
- Runs `install.sh` which orchestrates the numbered scripts (`01-base` → `06-hardware`).

Everything is **idempotent** — safe to re-run. On failure, resume with:

```bash
cd ~/.local/share/vinos && ./install.sh --skip NN
```

## First moves

- **`Super + K`** — the keybindings cheat sheet.
- **`Super + Ctrl + O`** — vinOS menu (bundles, wifi, theme, doctor, lock).
- **`Super + Ctrl + W`** — wifi via impala.
- **`Super + A`** — AI chat (install first with `vinos-install-ai`).

## Bundles

Base is lean. Add what you need:

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

vinOS is additive — no base package modifications. To remove:

```bash
sudo pacman -Rns hyprland waybar foot mako walker ...  # any bundle
rm -rf ~/.config/{hypr,waybar,foot,mako,walker} ~/.local/share/vinos
sudo mv /etc/os-release.arch.bak /etc/os-release
```

Full source: [github.com/vinpatel/vinos](https://github.com/vinpatel/vinos)
