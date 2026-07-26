---
title: "Install"
description: "Flash the ISO. Boot it. Run one command. ~15 minutes end-to-end. Same path on any x86_64 — T2 Mac included."
---

vinOS is a **live ISO**. Boot it, run one command, reboot into your new
system. No Arch install first. No manual partitioning. Same path for
every machine — the installer detects your hardware.

## The whole flow

1. **[Download and flash the ISO](/docs/getting-started/download-and-flash/)**
   to a USB stick. ~5 minutes with `dd` or Balena Etcher.
2. **Boot the USB.** The live desktop comes up in ~90 seconds.
3. **Install to disk** from the live session:

    ```bash
    sudo vinos-install-disk
    ```

    Auto-detects hardware (Apple T2 · NVIDIA · generic), partitions,
    installs, reboots. ~15 minutes end-to-end.

That's it — same command whether you're on a 2019 MacBook Pro or a
generic x86_64 laptop. T2-specific bits (`linux-t2` kernel,
`brcmfmac` firmware, `tiny-dfr` for Touch Bar, T2 audio routing) ship
in the ISO; the installer copies them to disk when it sees a T2.

## T2 Mac prerequisites

Before you flash, on the Mac itself:

1. Boot to Recovery (**⌘+R** at chime).
2. **Startup Security Utility** → set to **No Security** and **Allow booting
   from external media**.
3. Shrink the macOS partition to leave space for vinOS (Disk Utility →
   resize).

That's the only Mac-specific step. Everything after is the same
one-command install.

## Try before you install

The live USB **is** vinOS — you can use it directly without touching
your disk:

- **`Super`** — menu
- **`Super + K`** — keybindings cheat sheet
- **`Super + Ctrl + W`** — Wi-Fi (impala)
- **`Super + Ctrl + O`** — vinOS menu (bundles, theme, doctor, lock)
- **`Super + A`** — AI chat (after `vinos-install-ai`)

Wi-Fi works on T2 out of the box. Ethernet auto-connects via DHCP.

## Bundles

Base is lean. Add what you need after installing:

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

vinOS is a full Linux distribution, not a package overlay — there is
no in-place uninstall. To remove it, boot another OS's installer USB
(macOS Recovery, Windows installer, or another Linux ISO) and
repartition the drive.

Full source: [github.com/vinpatel/vinos](https://github.com/vinpatel/vinos)
