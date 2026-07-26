---
title: "First-boot customization"
description: "What vinos-first-run and vinos-welcome do on your first login, and how to opt out of the bits you don't want."
weight: 40
---

Two commands run on first login:

1. **`vinos-first-run`** — automated. Starts user services, seeds
   config caches, initializes power profiles, sets the default theme.
   Silent unless something fails.
2. **`vinos-welcome`** — interactive. The walker-dmenu picker that
   asks about Wi-Fi, theme, bundles, keys, and routines.

Both are hyprland `exec-once` entries in the shipped config. Both are
idempotent — rerun any time.

## The vinos-menu deep-dive

`vinos-menu` is the walker-driven surface you'll come back to most.
It's rooted at a small set of top-level actions (Install, Style,
Trigger, System) and each one drills down into a submenu. Here's
what each root branch looks like when opened:

<figure class="doc-shot doc-shot-pending" id="shot-15">
  <div class="doc-shot-slot">Screenshot pending: vinos-menu open at the Style submenu</div>
  <figcaption>Style submenu — theme, wallpaper, font size, lock/idle. See SCREENSHOTS_NEEDED.md #shot-15.</figcaption>
</figure>

<figure class="doc-shot doc-shot-pending" id="shot-16">
  <div class="doc-shot-slot">Screenshot pending: vinos-menu open at the Install bundles submenu</div>
  <figcaption>Install submenu — ai, dev, comms, browser, media. See SCREENSHOTS_NEEDED.md #shot-16.</figcaption>
</figure>

<figure class="doc-shot doc-shot-pending" id="shot-17">
  <div class="doc-shot-slot">Screenshot pending: vinos-menu open at the Trigger submenu</div>
  <figcaption>Trigger submenu — one-shot commands (screenshot, sleep, restart-waybar). See SCREENSHOTS_NEEDED.md #shot-17.</figcaption>
</figure>

## Skip the whole thing

Delete the exec-once entries in `~/.config/hypr/autostart.d/`:

```
$ rm ~/.config/hypr/autostart.d/50-vinos-first-run.conf
$ rm ~/.config/hypr/autostart.d/60-vinos-welcome.conf
```

Log out and back in. Nothing autostart-related runs. You can invoke
either command manually:

```
$ vinos-first-run
$ vinos-welcome
```

## Skip only vinos-welcome

Same as above, but only remove the welcome file:

```
$ rm ~/.config/hypr/autostart.d/60-vinos-welcome.conf
```

`vinos-first-run` still runs automated setup; the interactive picker
never appears.

## Preseed the welcome answers

If you're prepping an image for a lab, seed the answers before first
boot. Drop `~/.config/vinos/welcome-preseed.toml`:

```toml
# ~/.config/vinos/welcome-preseed.toml
[wifi]
skip = true   # already on wired

[theme]
name = "circuit"

[bundles]
install = ["ai", "dev"]

[keys]
anthropic_key_path = "/run/secrets/anthropic"

[routines]
enable = ["day-brief", "evening-shutdown"]
```

On first login, `vinos-welcome` reads this file, applies every choice,
and exits without prompting. If any field is missing, it prompts only
for that field.

## What vinos-first-run actually does

In order:

1. `systemctl --user daemon-reload`
2. `vinos-powerprofiles-init` — sets balanced/performance/power-saver
   from current AC state.
3. Runs any `~/.config/vinos/hooks/first-run.d/*` scripts.
4. Ensures `~/.vinos/routines/state/` exists (mode `0700`).
5. If `/etc/vinos/config/default-theme.txt` names a theme, applies it
   (only if `~/.config/vinos/active-theme` is missing).
6. Runs `vinos-doctor` and stores the result at
   `~/.vinos/state/last-doctor.json`.

Everything is safe to re-run. If you write your own first-run hooks,
make them idempotent too.

## Add your own first-run hooks

Drop executables into `~/.config/vinos/hooks/first-run.d/`:

```
$ mkdir -p ~/.config/vinos/hooks/first-run.d
$ cat > ~/.config/vinos/hooks/first-run.d/10-clone-dotfiles <<'EOF'
#!/usr/bin/env bash
[[ -d ~/dotfiles ]] || git clone git@github.com:you/dotfiles ~/dotfiles
cd ~/dotfiles && ./install.sh
EOF
$ chmod +x ~/.config/vinos/hooks/first-run.d/10-clone-dotfiles
```

Scripts run in lexical order. Prefix with `NN-` (10, 20, 30) to keep
ordering explicit. A non-zero exit stops the run and surfaces via a
mako notification.
