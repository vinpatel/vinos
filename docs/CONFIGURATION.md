# Changing configs in vinOS

Every user-facing config, where it lives in the repo, where it lands on a
running system, and how to reload it without rebuilding the ISO.

**Golden rule:** for anything in this table, edit the file in the repo,
save. If `iso/qa/loop.sh` is running against a live QEMU guest, the change
lands in the guest in under a second. **Do not rebuild the ISO for config
changes** — see [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) hot-reload section.

## Config surface map

| Repo path | Guest path | Owned by | Hot-reload trigger |
|---|---|---|---|
| `config/hypr/hyprland.conf` | `~/.config/hypr/hyprland.conf` | Hyprland core | `hyprctl reload` |
| `config/hypr/autostart.conf` | `~/.config/hypr/autostart.conf` | exec-once list | `hyprctl reload` (existing `exec-once` don't respawn — bounce with `killall <cmd>`) |
| `config/hypr/bindings/apps.conf` | `~/.config/hypr/bindings/apps.conf` | keybinds → apps | `hyprctl reload` |
| `config/hypr/bindings/utilities.conf` | `~/.config/hypr/bindings/utilities.conf` | keybinds → utils (screenshot, brightness, hyprlock) | `hyprctl reload` |
| `config/hypr/looknfeel.conf` | `~/.config/hypr/looknfeel.conf` | gaps, rounding, blur, borders | `hyprctl reload` |
| `config/hypr/plugins.conf` | `~/.config/hypr/plugins.conf` | hyprpm plugin loader (opt-in) | `hyprpm reload && hyprctl reload` |
| `config/waybar/config.jsonc` | `~/.config/waybar/config.jsonc` | modules layout | `pkill -SIGUSR2 waybar` |
| `config/waybar/style.css` | `~/.config/waybar/style.css` | GTK CSS styling | `pkill -SIGUSR2 waybar` |
| `config/mako/config` | `~/.config/mako/config` | notification style + timeout | `makoctl reload` |
| `config/walker/config.toml` | `~/.config/walker/config.toml` | launcher behaviour | `pkill walker` (respawns on next Super+Space) |
| `config/walker/themes/vinos.css` | `~/.config/walker/themes/vinos.css` | launcher visual | `pkill walker` |
| `config/nwg-drawer/drawer.css` | `~/.config/nwg-drawer/drawer.css` | visual app grid | none — reopens with new CSS on next launch |
| `bin/vinos-*` | `~/.local/bin/vinos-*` (dev) or `/usr/local/bin/` (ship) | vinOS CLI subcommands | none — next invocation gets new script |
| `assets/wallpapers/<theme>/wallpaper.png` | `/usr/share/vinos/themes/<theme>/wallpaper.png` (ship) | wallpaper image | `pkill swaybg` + respawn via `hyprctl dispatch exec swaybg -i /usr/share/vinos/wallpaper.png -m fill` |
| `themes/<theme>/theme.conf` | `/usr/share/vinos/themes/<theme>/theme.conf` (ship) | palette + gradient border + swaybg tuning | `vinos-theme apply <theme>` |

## Rebuild-triggering paths

The following changes CANNOT hot-reload and DO trigger a full ISO rebuild:

- `iso/packages.live`, `iso/aur.list`, `iso/profile/packages.x86_64` — package list
- Anything under `install/**` — early boot / branding assembly
- `iso/profile/**` (except boot menu edits below) — archiso profile
- `iso/airootfs-overlay/etc/**` — early boot files (sshd, systemd units, ssh config)
- Kernel or initrd changes — `mkinitcpio` presets, `boot/loader/entries/`
- Anything you want to ship in `/usr/share/vinos/` — the wallpaper *symlink* is
  live-writable via `sudo cp`, but the shipped default is baked at build

## Persistent vs ephemeral changes

The live ISO's root is on tmpfs — any hot-reload change you push into a
running guest **disappears on reboot**. To make a change permanent:

1. Edit the file in the repo (`config/...`, `bin/...`, `themes/...`).
2. `iso/qa/loop.sh` (if running) pushes it into the live guest — verify it works.
3. Commit + push.
4. Next `iso/build.sh` bakes the change into the ISO.

The dev loop is:
```
edit → save → hot-reload verifies → commit → push → build (only at ship-time)
```

## First-run wizard

`bin/vinos-first-run` runs once per user session. To reset for testing:

```bash
rm ~/.local/state/vinos/first-run-done
```

Then log out + back in, or `hyprctl dispatch exec vinos-first-run` from a terminal.

## Toggles (feature flags)

vinOS ships a lightweight toggle system:

```bash
vinos-toggle-enable waybar-off    # creates the flag
vinos-toggle-enabled waybar-off   # exits 0 if flag exists
vinos-toggle-disable waybar-off   # removes the flag
```

Flags live at `~/.local/state/vinos/toggles/<name>`. Autostart lines like
`! vinos-toggle-enabled X && cmd` gate on these — see `config/hypr/autostart.conf`.

## Debugging: which config is actually being read?

- **Hyprland:** `hyprctl -j getoption <option> | jq` shows the current value.
- **Waybar:** `waybar --dry-run` parses the config + CSS without launching. Recommended sanity check before committing style.css.
- **Mako:** `makoctl mode` shows the loaded mode; `journalctl --user -u mako` for parse errors.
- **Walker:** launched fresh each Super+Space press; logs to `journalctl --user -u walker` or `~/.cache/walker/`.

## Adding a new config file

If the config's app isn't in the table above:

1. Add the file under `config/<app>/`.
2. Add an install rule to `install/02-desktop.sh` (or the appropriate installer) that stages it into `/etc/skel/.config/<app>/` at build time.
3. Add a dispatch rule to `iso/qa/loop.sh` `dispatch()` so hot-reload works.
4. Add a row to the table above.
5. Update `iso/qa/config-lint.sh` if the app's config format has known gotchas
   (e.g. GTK CSS strictness for anything gtkmm-based).
