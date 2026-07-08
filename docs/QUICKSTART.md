# vinOS Quickstart

You booted the ISO or ran `install.sh`. Now what.

## 1. Get on wifi (30s)

Ethernet plugged in? Skip. Otherwise:

```
Super + Ctrl + W
```

opens **impala** — a TUI wifi picker. Arrow keys → your network → enter
your WPA2 password → done. iwd remembers it; next boot connects
automatically.

If nothing shows up: `rfkill unblock wifi` from a terminal, then try
again.

## 2. Add optional bundles (2–15 min per bundle)

Base vinOS is deliberately lean. Apps like Chromium, Signal, Steam,
Obsidian, and every AI tool live in **opt-in bundles**. Pick one:

```
Super + Ctrl + O          # vinos-menu → "Install: <bundle> bundle"
```

Or directly:

```
vinos-install-browser         # chromium + firefox
vinos-install-comms           # signal-desktop + localsend
vinos-install-ai              # ollama + claude-code + torch/openai/anthropic (+ CUDA on NVIDIA)
vinos-install-dev             # postgres/redis/k8s/rust/go/…
vinos-install-media           # mpv/kdenlive/obs/spotify/…
vinos-install-office          # libreoffice + thunderbird
vinos-install-productivity    # obsidian/notion/typora/1password
vinos-install-gaming          # steam/lutris/gamemode/mangohud
```

Set `VINOS_INSTALL_ASSUME_YES=1` to skip the confirm prompt (useful
for dotfiles or provisioning). Every bundle is idempotent — re-run
freely.

Full catalog + install sizes: [docs/BUNDLES.md](BUNDLES.md).

## 3. Change the theme (instant)

```
vinos-theme                   # shows current + available
vinos-theme gruvbox-dark      # switches
vinos-theme --pick            # walker picker
```

The switch rewrites `/usr/share/vinos/wallpaper.png` (relative
symlink), tells swaybg to reload, and remembers your choice at
`~/.config/vinos/active-theme`. To ship a new theme, drop a
`themes/<name>/` dir with `theme.conf` + `wallpaper.png` and rerun
`install/05-branding.sh`.

## 4. Essential keybindings

| Keys | Action |
|---|---|
| `Super + Return` | Terminal (foot) |
| `Super + Space` / `Super + D` | Walker (app launcher) |
| `Super + B` | Chromium (needs browser bundle) |
| `Super + E` | Files (nautilus) |
| `Super + P` | Region screenshot + annotate (satty) |
| `Super + Shift + P` | Region screenshot, plain copy |
| `Super + L` | Lock (hyprlock) |
| `Super + Shift + C` | Color picker (hyprpicker) |
| `Super + Ctrl + W` | Wi-Fi (impala) |
| `Super + Ctrl + O` | vinOS menu |
| `Super + Q` | Kill focused window |
| `Super + F` | Fullscreen |
| `Super + V` | Toggle floating |
| `Super + 1..9` | Switch workspace |
| `Super + Shift + 1..9` | Move window to workspace |
| `XF86 volume/brightness` | swayosd popup |

## 5. Get help / verify

```
vinos-doctor          # health check (files exist, services up)
vinos-version         # what version + commit you're on
vinos-update          # pull latest + rerun install.sh
journalctl -b -p err  # boot errors — should be empty
```

## 6. Persistence (live ISO only)

If you're running from a USB, changes disappear on reboot unless you
booted the **"vinOS Live (persistent)"** entry AND flashed with
persistence enabled via `iso/flash.sh`. See [docs/USB.md](USB.md).

## 7. When something goes wrong

Boot fails / graphics glitchy → boot the **safe graphics (nomodeset)**
menu entry. That's specifically for problem GPUs.

Hyprland won't start → `journalctl --user -u hyprland-*` from a TTY;
often a bad config edit. Restore with `git -C ~/.local/share/vinos
checkout config/`.

Wi-Fi won't connect → `iwctl` from a terminal, `station wlan0
connect <SSID>` — same daemon impala drives.

Hardware not detected → `sudo bash ~/.local/share/vinos/install/06-hardware.sh`
re-runs the hardware detection pass. See [docs/HARDWARE.md](HARDWARE.md).

## Where things live

```
/usr/share/vinos/
  ├── VERSION              (semver)
  ├── logo/                (svg + png assets)
  ├── themes/              (tokyo-night, gruvbox-dark, …)
  └── wallpaper.png        (symlink → active theme)

/usr/local/bin/vinos-*     (symlinks to /usr/share/vinos/bin/*)
~/.config/vinos/           (user preferences: active-theme)
~/.local/state/vinos/      (state: bundle install log, first-boot sentinel)
```
