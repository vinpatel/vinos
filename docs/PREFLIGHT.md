# vinOS live-ISO pre-flight checklist

Run this once, from the live desktop, right after boot. Separates
"the ISO is broken" from "QEMU is eating my Super key" from
"real-hardware quirk". Copy-paste block by block.

## 0. Where am I?

Open a TTY with **Ctrl+Alt+F2** (login: `vinos`, empty password). If
graphical Hyprland is up, you can also press **Super+Return** to get a
foot terminal — if that doesn't work, keep going here in the TTY, that
is exactly what this checklist exists to diagnose.

## 1. Session identity

```
whoami                    # → vinos (NOT root)
echo $XDG_SESSION_TYPE    # → wayland
echo $XDG_CURRENT_DESKTOP # → Hyprland
loginctl show-user vinos | grep -E 'State|Sessions'
```

Failure modes:
- `whoami` says `root` → greetd autologin didn't fire; check
  `journalctl -u greetd`.
- `XDG_SESSION_TYPE` empty → Hyprland isn't running; you're on a bare TTY.

## 2. Did /etc/skel seed the home dir?

```
ls -la ~/.config/hypr/    # hyprland.conf must be here
ls -la ~/.config/waybar/  # config + style.css
ls -la ~/.config/walker/  # config.toml
test -f ~/.vinos-live-init-done && echo OK || echo MISSING
```

Failure mode: `.config/hypr/` is empty → `vinos-live-init.service`
didn't run or `/etc/skel` was empty in the built ISO. Check:

```
systemctl status vinos-live-init
ls /etc/skel/.config/hypr/
```

## 3. Is Hyprland actually receiving keys?

```
hyprctl version           # confirms compositor is up
hyprctl monitors          # confirms display is registered
hyprctl clients | head    # what windows are open
hyprctl binds | head -40  # confirms our bindings loaded
```

`hyprctl binds` should list ~40 bindings including
`SUPER, Return → exec, foot`. If the list is short or empty, the
config in `~/.config/hypr/hyprland.conf` isn't being read — check for
syntax errors in the tail of `~/.local/share/hyprland/hyprland.log`.

## 4. Is the Super key reaching Hyprland?

The killer test. Run in a foot terminal (or from the TTY,
`WAYLAND_DISPLAY=wayland-1 hyprctl ...`):

```
wev                       # then press Super; you should see keycode 133 (Super_L)
```

If `wev` shows nothing when you press Super **and you're in QEMU**,
your host WM (Omarchy Hyprland on the outside) is stealing the key
before QEMU sees it. Grab the keyboard in QEMU:

- GTK display: **Ctrl+Alt+G** (or View → Grab Keyboard)
- SDL display: add `-display sdl,grab-mod=lshift-lctrl`
- virt-manager: Send key → Grab keyboard

If `wev` shows the keycode on press but bindings still don't fire,
then it's a Hyprland config problem, not a key-capture problem.

## 5. Fast binding smoke test

Not sure which shortcut to trust? Try them in this order — they
escalate in complexity:

```
# 5a. Non-Super binding (proves compositor sees the keyboard at all)
Press:  Print
Expect: screenshot area picker (grim/slurp)

# 5b. Simple Super binding
Press:  Super+Return
Expect: foot terminal opens

# 5c. Super binding that runs a vinos-* helper
Press:  Super+Ctrl+O
Expect: vinos-menu overlay

# 5d. Cheatsheet (proves helpers + windowrule work)
Press:  Super+/
Expect: floating vinos-cheatsheet window
```

If 5a works but 5b doesn't → host is eating Super.
If 5b works but 5c doesn't → `vinos-*` bins aren't on `$PATH`.
If 5c works but 5d doesn't → cheatsheet helper missing (rare).

## 6. Network

```
ip -brief link            # look for enp*/ens* (QEMU) OR wlan* (real HW)
ip -brief addr            # should have a 10.0.2.x on QEMU, LAN IP on HW
ping -c1 archlinux.org    # NAT sanity check
```

On QEMU there is **no wifi radio** — `iwctl device list` will be empty
and that's expected. Test the wifi flow on real hardware only.

On real hardware:

```
rfkill list
iwctl device list
iwctl station wlan0 scan
iwctl station wlan0 get-networks
```

Then either `iwctl station wlan0 connect <SSID>` or fire
**Super+Ctrl+W** for the impala TUI.

## 7. Autostart pieces

```
pgrep -a waybar hypridle hyprsunset mako walker swayosd-server swaybg
```

Expect one PID per name. Missing entries:
- `waybar` missing → check `journalctl --user -u waybar` or run
  `waybar` in a terminal to see the error.
- `swaybg` missing → wallpaper won't render; not fatal.
- `mako` missing → no notifications; try `notify-send hi` after
  starting it manually.

## 8. Report template

If something above fails and you want a bug report, paste:

```
{ echo === uname; uname -a
  echo === session; whoami; echo $XDG_SESSION_TYPE; echo $XDG_CURRENT_DESKTOP
  echo === skel; ls ~/.config/hypr/ ~/.config/waybar/ 2>&1
  echo === hypr; hyprctl version 2>&1 | head -3
  echo === binds; hyprctl binds 2>&1 | wc -l
  echo === net; ip -brief addr
  echo === procs; pgrep -a waybar hypridle mako walker swaybg
} 2>&1 | tee /tmp/vinos-preflight.txt
```

Attach `/tmp/vinos-preflight.txt` to the issue.
