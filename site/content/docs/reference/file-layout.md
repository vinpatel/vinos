---
title: "File layout"
description: "Where every vinOS artifact lives on a booted install — bins, configs, state, cache, docs."
weight: 10
---

Everything vinOS ships or writes to. Nothing here is proprietary — you
can `ls`, `cat`, or `rg` any path and see the source of truth.

## Binaries

```
/usr/local/bin/vinos-*        ~90 shipped scripts (bash + python)
/usr/local/libexec/vinos/*    helpers not meant to be run directly
/usr/bin/                     upstream Arch binaries (ollama, docker, etc.)
```

## Configs

```
/etc/vinos/                   system defaults, read on first boot
  routines/*.toml             the 5 shipped routines (all disabled)
  config/                     one-shot defaults (default-theme.txt, etc.)

/etc/xdg/                     shipped app defaults (waybar, walker, hyprland)
  waybar/config.jsonc
  walker/config.toml
  hypr/hyprland.conf          sourced by the user config

~/.config/                    user-scoped overrides — copy from /etc/xdg/
  vinos/
    ai.toml                   route settings for vinos-ai (see /docs/agents/the-80-20-router/)
    active-theme              current theme name, one line
    fonts.toml                font choices
    wallpapers.toml           per-monitor overrides
    welcome-preseed.toml      first-run preseed (optional)
    hooks/                    your custom hooks — first-run.d/, etc.
    secrets/anthropic-key     mode 0600, one line, your API key
  hypr/
    hyprland.conf             your hyprland config
    bindings.d/               drop-in extra keybindings
    autostart.d/              drop-in extra exec-once entries
  waybar/config.jsonc         your waybar layout
  waybar/style.css            your waybar CSS
  walker/config.toml          your walker settings
  mako/config                 your mako notification style
  foot/foot.ini               your foot terminal settings
```

## Routines

```
~/.vinos/                     everything routine-related, user-scoped
  routines/                   user-authored + project-loaded routines
    *.toml                    user-scoped (from `vinos-routine edit`)
    <project>/*.toml          project-scoped (from `vinos-routine load .`)
    state/                    all output + ledger
      <name>/                 per-routine output dir
        YYYY-MM-DD-HHMM.md    one file per run
        last-run.json         metadata for waybar module
      ledger.db               SQLite; every run's cost, tokens, exit
```

## Branding + themes

```
/usr/share/vinos/
  VERSION                     one line: "2.0.5"
  wallpaper.png               symlink → active theme's wallpaper
  logo/
    vinos.svg                 vector mark
    png/vinos-{16,32,64,128,256,512,1024}.png
  themes/<name>/              one dir per shipped theme
    theme.conf                colors + metadata
    wallpaper.png             the branded 4K jpeg
    preview.png               600×338 picker thumbnail
    unlock.png                lockscreen background
    colors.toml               palette (dumped for tools that want TOML)
    keyboard.rgb              single hex for laptop keyboard RGB
    neovim.lua
    vscode.json
```

## Docs (on-disk)

```
/usr/share/doc/vinos/         shipped copies of the specs
  vinos-routine-spec.md
  vinos-routines-yaml-spec.md
  ARCHITECTURE.md
```

If the on-disk copy is stale, the canonical version lives in the repo
at [`docs/v2/`](https://github.com/vinpatel/vinos/tree/main/docs/v2).

## Logs + state

```
~/.vinos/state/               vinOS runtime state (not routine outputs)
  last-doctor.json            last vinos-doctor result
  focus/current               active vinos-focus session
  hardware-hints.json         cached vinos-hw-hints output

/var/log/                     journald handles most logs; systemd-journal --user for user units
```

## Ignored / gitignore recommendations

If you version control `~/.config` or `~/.vinos`, ignore:

```
~/.vinos/secrets/**
~/.vinos/routines/state/**
~/.vinos/state/**
~/.cache/**
```

The `secrets/` exclusion is non-negotiable. The rest is a matter of
size and privacy.
