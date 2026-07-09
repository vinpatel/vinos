# Install vinOS

vinOS is an opinionated Arch Linux layer — you install Arch first, then
run one command to add the vinOS desktop + configs + tools on top.

Two paths depending on your hardware. Both end at the same
`install.sh` and the same desktop.

## Which one are you?

- **You have a 2018-2020 Intel Mac with a T2 chip** (MBP, MBA,
  iMac Pro, Mac Mini, iMac): → [T2 Mac path](#path-a-t2-mac).
- **Everything else** (any other laptop or desktop): →
  [Standard path](#path-b-standard).

---

## Path A — T2 Mac

The T2 chip owns internal keyboard, trackpad, wifi, and audio. Stock
Arch's `linux` kernel can't drive that hardware. Use the community
[t2linux](https://wiki.t2linux.org/) build of Arch, which ships a
patched `linux-t2` kernel.

**On the Mac:**

1. Read + follow the **t2linux pre-install guide**:
   <https://wiki.t2linux.org/guides/preinstall/> — Secure Boot off,
   allow external boot, shrink macOS partition.
2. Follow the **t2linux Arch install guide**:
   <https://wiki.t2linux.org/distributions/arch/installation/>. Use
   `t2archinstall` (guided) if you want the easy path.
3. When it asks which packages to `pacstrap`, use their recommended
   set: `base linux-t2 linux-t2-headers arch-mact2-mirrorlist
   arch-mact2-rankmirrors apple-t2-audio-config apple-bcm-firmware
   linux-firmware iwd grub efibootmgr t2fanrd`.
4. Finish the Arch install, reboot into your new Arch system, log in
   as your user.

**Then install vinOS on top:**

```bash
curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
```

That's it. Reboot; you'll be in the vinOS Hyprland desktop with your
T2 hardware fully working.

## Path B — Standard laptop / desktop

**On the machine** (2018+ Intel or AMD, any modern laptop):

1. Flash the official Arch install ISO to USB (or the vinOS live ISO
   in `iso/out/` if you have it — same as Arch's plus our branding).
2. Boot the USB. At the Arch prompt, run `archinstall` (guided).
   Pick your kernel (`linux` is fine), filesystem, timezone, user, and
   `sudo`. When asked about profile, pick **minimal** — vinOS does the
   rest.
3. Reboot into your new Arch, log in.

**Then install vinOS on top:**

```bash
curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
```

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
