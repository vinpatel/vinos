---
title: "Keybindings"
description: "The shipped Hyprland keybindings, grouped by purpose. Extend them by dropping conf files into ~/.config/hypr/bindings.d/."
weight: 10
---

vinOS inherits Omarchy's binding table verbatim, then layers the
vinOS-specific overlays on top. If a chord below feels off, that's
because we deliberately kept Omarchy muscle memory intact.

The source of truth is `~/.config/hypr/bindings.lua` (generates
`hyprland.conf` on config reload). What follows is the grouped view;
run <kbd>Super</kbd>+<kbd>K</kbd> at any time to search the live map
in a walker overlay.

<figure class="doc-shot" id="shot-32">
  <img src="/img/screenshots/cheatsheet-overlay.png" alt="Super+K cheatsheet overlay" width="1280" height="800" loading="lazy">
  <figcaption>Live keybinding cheatsheet — see SCREENSHOTS_NEEDED.md #shot-32.</figcaption>
</figure>

## Applications

| Chord | Action |
|---|---|
| <kbd>Super</kbd>+<kbd>Return</kbd> | Terminal (foot) |
| <kbd>Super</kbd>+<kbd>Alt</kbd>+<kbd>Return</kbd> | Terminal + tmux |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Return</kbd> | Browser |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>F</kbd> | File manager |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>N</kbd> | Editor (`$EDITOR`) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>D</kbd> | Docker (lazydocker) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>O</kbd> | Obsidian |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> | Music (Spotify) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>G</kbd> | Signal |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd> | ChatGPT web app |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd> | Calendar |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>E</kbd> | Email |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Y</kbd> | YouTube |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd> | X (Twitter) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>/</kbd> | 1Password |

## Menus + launchers

| Chord | Action |
|---|---|
| <kbd>Super</kbd>+<kbd>Space</kbd> | Launch apps (walker) |
| <kbd>Super</kbd>+<kbd>Alt</kbd>+<kbd>Space</kbd> | Root menu |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>O</kbd> | Toggle menu (vinos-menu) |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>H</kbd> | Hardware menu |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>C</kbd> | Capture menu |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>S</kbd> | Share (or run vinos-doctor) |
| <kbd>Super</kbd>+<kbd>Escape</kbd> | System menu |
| <kbd>Super</kbd>+<kbd>K</kbd> | Show keybindings (live search) |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>E</kbd> | Emoji picker |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Ctrl</kbd>+<kbd>Space</kbd> | Theme menu |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>Space</kbd> | Background switcher |

## TUIs + quick tools

| Chord | Action |
|---|---|
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>W</kbd> | Network (impala Wi-Fi TUI) |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>B</kbd> | Bluetooth (bluetui) |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>U</kbd> | Audio mixer (wiremix) |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>A</kbd> | Audio panel |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>D</kbd> | Display panel |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>P</kbd> | Power panel |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>T</kbd> | Activity (btop) |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>L</kbd> | Lock system |

## Windows + workspaces

| Chord | Action |
|---|---|
| <kbd>Super</kbd>+<kbd>W</kbd> | Close window |
| <kbd>Super</kbd>+<kbd>F</kbd> | Fullscreen |
| <kbd>Super</kbd>+<kbd>T</kbd> | Toggle floating |
| <kbd>Super</kbd>+<kbd>J</kbd> | Toggle window split |
| <kbd>Super</kbd>+<kbd>L</kbd> | Toggle workspace layout |
| <kbd>Super</kbd>+<kbd>1</kbd>…<kbd>9</kbd> | Switch to workspace N |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>1</kbd>…<kbd>9</kbd> | Move window to workspace N |
| <kbd>Super</kbd>+<kbd>Tab</kbd> | Next workspace |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Tab</kbd> | Previous workspace |
| <kbd>Alt</kbd>+<kbd>Tab</kbd> | Cycle windows |
| <kbd>Super</kbd>+<kbd>←</kbd> <kbd>→</kbd> <kbd>↑</kbd> <kbd>↓</kbd> | Focus directional |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>←/→/↑/↓</kbd> | Swap window |
| <kbd>Super</kbd>+<kbd>S</kbd> | Toggle scratchpad |
| <kbd>Super</kbd>+<kbd>BackSpace</kbd> | Toggle window transparency |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>BackSpace</kbd> | Toggle window gaps |

## Screen capture

| Chord | Action |
|---|---|
| <kbd>PrintScr</kbd> | Region screenshot → clipboard |
| <kbd>Alt</kbd>+<kbd>PrintScr</kbd> | Screen recording toggle |
| <kbd>Super</kbd>+<kbd>PrintScr</kbd> | Color picker |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>PrintScr</kbd> | OCR selected region → clipboard |

## Toggles

| Chord | Action |
|---|---|
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>I</kbd> | Toggle idle-lock |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>N</kbd> | Toggle nightlight |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>,</kbd> | Toggle notification silencing |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd> | Toggle top bar |

## Extending

Drop a `.conf` file into `~/.config/hypr/bindings.d/`; it gets sourced
by the shipped `hyprland.conf`. Example — add a chord for
`vinos-focus 45`:

{{% callout kind="tip" %}}
Chords defined in `bindings.d/` **override** the same chord defined in
the base config. Add without fear — you can always remove your file
to get the default back.
{{% /callout %}}

```conf
# ~/.config/hypr/bindings.d/personal.conf
bind = SUPER SHIFT, F, exec, vinos-focus 45 --task "deep work"
bind = SUPER SHIFT, R, exec, vinos-brief
bind = SUPER SHIFT, T, exec, foot -e vinos-standup --week
```

Reload without restarting:

```
$ hyprctl reload
```
