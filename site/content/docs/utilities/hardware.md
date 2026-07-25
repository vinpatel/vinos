---
title: "Hardware utilities"
description: "Battery, brightness, audio, capture. Small composable primitives waybar and hyprland call — every one prints exactly one line."
weight: 40
---

Every hardware helper follows the same shape: one line of output, one
job done, safe to script against. Waybar modules, hyprland dispatchers,
and your own scripts all read them the same way.

## Battery + power

```
$ vinos-battery-present     # true if a battery exists
true

$ vinos-battery-status      # formatted for the waybar
󰁹  74%   1h 42m   -8.4 W / 51 Wh

$ vinos-battery-capacity    # full capacity in Wh
51

$ vinos-battery-remaining-time
1h 42m

$ vinos-ac-present          # true if AC is plugged in
false

$ vinos-powerprofiles-init  # auto-pick profile from current AC state
[vinos-powerprofiles-init] AC=off → power-saver

$ vinos-powerprofiles-set performance   # explicit override
```

Waybar's power module calls `vinos-battery-status` on a 10-second poll;
the shipped waybar config wires it up already.

## Brightness

`vinos-brightness-display` handles the common laptop case. On an Apple
Studio Display or XDR, use the `-apple` variant which drives
`asdcontrol` over the display's USB-C control channel.

```
$ vinos-brightness-display +10%    # increase 10%
$ vinos-brightness-display 40%     # set to 40%
$ vinos-brightness-display off     # blank
$ vinos-brightness-display on      # restore

$ vinos-brightness-keyboard        # cycle backlight steps
$ vinos-brightness-keyboard-mute   # toggle mic-mute LED (where present)
```

## Audio

```
$ vinos-audio-input-mute           # toggle mic mute; drives hardware LED
$ vinos-audio-output-switch        # cycle audio sinks, preserving mute
```

Both talk to PipeWire/WirePlumber. If you have a mic-mute LED on your
laptop chassis, `vinos-audio-input-mute` will drive it — the same
button that used to only work under macOS.

## Capture

```
$ vinos-capture-screenshot         # region → annotate → clipboard
$ vinos-capture-text-extraction    # OCR selected region → clipboard
```

Bound to <kbd>Super</kbd>+<kbd>P</kbd> and
<kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>PrintScr</kbd> by default.
Screenshots go straight to the clipboard so you can paste into any app.

## Hardware reports

Two commands help when you're filing an issue or updating the
HARDWARE.md table:

```
$ vinos-hw-report
## vinOS hardware report — 2026-07-25T23:17:50Z

### Machine

| Field | Value |
|---|---|
| **Vendor** | Dell Inc. |
| **Model** | PowerEdge T430 |
| **BIOS** | Dell Inc. 2.5.4 (08/17/2017) |
| **Kernel** | 7.0.9-arch2-1 |
| **vinOS** | 2.0.5 |

### CPU

  Architecture:                            x86_64
  CPU(s):                                  12
  Vendor ID:                               GenuineIntel
  Model name:                              Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz
...
```

The output is straight markdown — paste it into a GitHub issue.

```
$ vinos-hw-hints                   # detect quirks, post one-shot notifications
$ vinos-hw-touchpad                # print detected hyprland touchpad name
$ vinos-hw-external-monitors       # true if any external monitor connected
```
