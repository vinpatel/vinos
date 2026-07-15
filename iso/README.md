# vinOS Live ISO

**Secondary install path.** The primary path is
[docs/INSTALL.md](../docs/INSTALL.md): install Arch, run our one-liner
on top.

The ISO is useful for:
- Trying vinOS on a USB before committing to an Arch install.
- Rescue / boot media on a machine that already runs vinOS.
- Handing to a friend as "here, boot this."

## Build

```bash
bash iso/build.sh
```

Produces `iso/out/vinos-<VERSION>-x86_64.iso`. Requires `docker`,
`/dev/kvm` (optional but 10× faster), ~15 GB scratch space. First
build fetches ~800 MB of packages; subsequent builds hit the cache.

## Test

```bash
bash iso/test.sh --mode matrix    # BIOS+UEFI × 3G/4G × on/off QEMU tests
bash iso/test-desktop.sh          # headless screendump of the settled desktop
bash iso/qemu-desktop.sh          # interactive QEMU window on your host
```

## Flash to USB

```bash
sudo bash iso/flash.sh
```

Interactive; refuses non-USB devices unless `--i-know-what-im-doing`.
With `--with-persistence` adds an ext4 partition labeled
`vinos-persist` for boot-menu-selectable persistence. See
[docs/USB.md](../docs/USB.md).

## What the ISO ships

- Stock `linux` kernel — most modern hardware.
- Same 200-package base as a fresh install (base tools + Hyprland +
  UX stack + Nerd Fonts).
- Live user `vinos`, passwordless, autologin via greetd.
- `Boot vinOS`, `Boot vinOS (safe graphics)`, `Boot vinOS (persistent)`
  in the syslinux/GRUB menu.

## What the ISO does NOT solve

- **T2 Macs**: the stock kernel doesn't drive T2 hardware. Use the
  install-on-Arch path via the [t2linux wiki](https://wiki.t2linux.org)
  — those docs handle the kernel + firmware bootstrap far better than
  we can inside a generic ISO. This is why the ISO is secondary.
- **Hardware with proprietary firmware**: NVIDIA drivers, Broadcom
  wifi, specific vendor quirks — `install/06-hardware.sh` handles all
  of these, but only when run on the installed system. The ISO ships
  what fits comfortably.

## Directory layout

- `profile/` — archiso profile; syslinux + GRUB + systemd-boot menus.
- `packages.releng` — frozen upstream archiso package list.
- `packages.live` — vinOS live-only additions (sof-firmware, marvell
  firmware, etc.).
- `aur.live` — AUR packages built into the local `[vinos-aur]` repo
  and shipped in the ISO (walker-bin, yaru-icon-theme, bibata-cursor,
  elephant).
- `gen-packages.sh` — regenerates `profile/packages.x86_64` from the
  sources above + `install_pkg` args in `install/01,02`.
- `aur-build.sh` — builds `aur.list` packages via makepkg in a
  container, produces `iso/aurrepo/`.
- `build.sh` — orchestrates all of the above + runs mkarchiso.
- `test.sh`, `test-desktop.sh`, `test-plymouth.sh` — QEMU harnesses.
- `flash.sh` — USB writer with safety confirms.
- `qemu-desktop.sh` — interactive QEMU window for local testing.
