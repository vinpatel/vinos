# vinOS Mac muscle-memory overlay

Applied **post-install**, after Omarchy's installer finishes. Makes a
Mac migrant's fingers feel at home on Linux.

## What this overlay does

| Behavior | Mechanism |
|---|---|
| Cmd → Ctrl (for `Cmd+C`, `Cmd+V`, `Cmd+T`, etc.) | `kanata` config (`kanata/vinos.kbd`) |
| Cmd+Shift+4 → area screenshot | Hyprland bind fragment |
| Cmd+Space → app launcher | Hyprland bind fragment (mapped to walker) |
| Natural scroll (Mac-style two-finger) | Hyprland input drop-in |
| Three-finger drag | libinput override |
| Hot corners: bottom-left = launcher, bottom-right = show desktop | Hyprland `windowrule` fragment |

## Files

- `kanata/vinos.kbd` — key remap definition, loaded by a systemd user unit
- `airootfs/etc/systemd/user/vinos-kanata.service` — starts kanata for the user
- `hypr/vinos-mac.conf` — Hyprland fragment sourced from Omarchy's hyprland.conf
- `install.sh` — enables the kanata service, sources the Hyprland fragment

## Why not just remap in Hyprland?

Hyprland-level Cmd→Ctrl mapping works within Hyprland but breaks in the
console, in Xwayland-native apps, and during the login screen. kanata
sits at the evdev layer so the remap is universal.
