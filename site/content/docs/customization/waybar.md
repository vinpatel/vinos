---
title: "Waybar"
description: "The shipped top-bar layout, the modules, and how to reorder or hide them without losing the default when you rebuild."
weight: 20
---

The vinOS waybar is the Omarchy waybar with a couple of vinOS modules
grafted on (routine status, focus countdown, cost ticker). The whole
thing is a single JSON file plus a CSS file, both readable and
recoverable.

## Where it lives

| Path | What it is |
|---|---|
| `/etc/xdg/waybar/config.jsonc` | Shipped default. Never edit here. |
| `~/.config/waybar/config.jsonc` | Your override. Copy the shipped one and edit. |
| `~/.config/waybar/style.css` | Your CSS override (themes inject their palette here). |

## Shipped modules

Left cluster:
- **hyprland/workspaces** — the numeric workspaces.
- **hyprland/window** — active window title.

Center:
- **clock** — 12-hour by default; click to open a mini-agenda.

Right cluster:
- **custom/vinos-focus** — focus countdown when active, hidden otherwise.
- **custom/vinos-routine** — routine status widget (last-run, next-run,
  today's cost).
- **network** — reads `vinos-hw-external-monitors`-style helpers.
- **pulseaudio** — output level, click to switch.
- **battery** — reads `vinos-battery-status`.
- **tray** — mako, blueman, network manager, walker's helper.

<figure class="doc-shot" id="shot-30">
  <img src="/img/screenshots/waybar-full.png" alt="waybar full width with all modules populated" width="1280" height="800" loading="lazy">
  <figcaption>Shipped waybar layout — see SCREENSHOTS_NEEDED.md #shot-30.</figcaption>
</figure>

## Reorder or hide

Copy once, then edit:

```
$ mkdir -p ~/.config/waybar
$ cp /etc/xdg/waybar/config.jsonc ~/.config/waybar/
$ $EDITOR ~/.config/waybar/config.jsonc
```

To hide the workspace numbers, delete the `hyprland/workspaces` entry
from the `modules-left` array. To move the clock right, add `clock`
to `modules-right` and remove it from `modules-center`.

After a save, reload:

```
$ vinos-restart-waybar
```

## Add your own module

Waybar's `custom/*` modules run a command and show the output. Wire
one to a `vinos-*` command:

```jsonc
{
  "custom/coffee": {
    "exec": "vinos-ai chat 'one emoji: coffee status'",
    "interval": 3600,
    "return-type": "text",
    "on-click": "foot -e vinos-standup"
  }
}
```

Add `"custom/coffee"` to your `modules-right` array. Reload.

## Move to top / bottom / side

Shipped keybindings do this without a restart:

- <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Ctrl</kbd>+<kbd>↑</kbd> — top
- <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Ctrl</kbd>+<kbd>↓</kbd> — bottom
- <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Ctrl</kbd>+<kbd>←</kbd> — left
- <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Ctrl</kbd>+<kbd>→</kbd> — right

Or hide the bar entirely: <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd>.

## Theming

Waybar's palette is regenerated from the active theme on every
`vinos-theme <name>` switch. If you have custom rules in
`~/.config/waybar/style.css`, keep them scoped to your custom modules —
the shipped rules use CSS variables that theme switching rewrites.

```css
/* Safe: uses the theme variable */
#custom-coffee {
  color: var(--accent);
}

/* Fragile: hardcoded color loses the theme switch */
#custom-coffee {
  color: #33ccff;
}
```
