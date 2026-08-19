# Session handoff — 2026-08-18 (v1.4.0 phased installer)

> Supersedes the 2026-08-16 rc4/rc5 handoff entirely. That document described
> the archinstall-wrapper install flow, which no longer exists — `73302575`
> deleted the gum wizard and the archinstall backend on 08-17.

## Target

**v1.4.0** — "install-to-disk that actually installs." `VERSION` stays `1.3.0`
through iteration; it moves to `1.4.0` only in the ship-tag commit.

## Done (08-17 15:08 → 08-18)

### 1. Installer left the desktop, moved to its own boot target

The core of `.planning/streamline-boot.md` is landed and verified on disk:

- `vinos-installer.target`, `vinos-installer.service`, and the
  `.target.wants` enable symlink ship in
  `iso/airootfs-overlay/etc/systemd/system/`.
- All four boot surfaces pass `systemd.unit=vinos-installer.target`
  instead of `vinos.install=1`: both systemd-boot install entries,
  `grub/grub.cfg`, `syslinux/archiso_sys-linux.cfg`.
- The Hyprland `exec-once` install hook is gone from
  `config/hypr/autostart.conf`; `bin/vinos-install-launcher` is deleted.

This retires the entire bug class patched across rc1–rc5: no Hyprland,
no greetd, no waybar, no wait-for-route poll loops, no foot popup over a
wallpaper.

### 2. Phased installer replaces archinstall — 1,059 lines

| phase | lines | does |
|---|---|---|
| `helpers/all.sh` | 195 | logging, `chroot_run`, `run`, `die`, marker helpers |
| `preflight/all.sh` | 60 | UEFI-only gate |
| `prompts/all.sh` | 249 | keyboard, timezone, disk, user, hostname |
| `disk/all.sh` | 85 | UEFI-only partition layout |
| `pacstrap/all.sh` | 80 | base package set + verify kernel/initramfs/os-release |
| `bootloader/all.sh` | 156 | limine onto the ESP, themed `limine.conf` + generated entries, verified by reading the files back |
| `config/all.sh` | 154 | fstab, locale, tz, host, users, services, branding |
| `finalize/all.sh` | 50 | scrub password, unmount, reboot prompt |

Entry point `iso/installer/vinos-install` (93 lines) sources them in
order. `bin/vinos-install-disk` is now a thin shim. Every mutating
command flows through `run()` so silent failure is caught at the call
site — the exact class of bug that spoiled `archinstall --silent`.

### 3. `iso/qa/install-smoke.sh` — the 9-step hard gate

Fully unattended, ~15-25 min. Boots the ISO in UEFI QEMU → waits for
live sshd → isolates `vinos-installer.target` → drives the wizard by HMP
keystrokes on a fixed profile (`qatest`/`qatest123`/UTC/us/`/dev/vda`) →
polls the install over SSH → shuts down → **boots the installed qcow2
with no ISO attached** → verifies hostname, user, limine (EFI binaries,
vinOS entry, root UUID, branding), sshd, and a clean journal.

### 4. The base-only pivot (`bea50968`)

Running the 300-package overlay with AUR builds inside arch-chroot
inside QEMU caused cycles 4–7 (sudo tty, fakeroot semop, guest freeze,
OOM at +18 min). Install-to-disk now ships a **base system**; the chroot
runs only `install/05-branding.sh` (~5 s, no AUR, no network). Install
time drops 30–60 min → ~5 min.

## Smoke gate history — 8 cycles, never green

| # | died at | fix |
|---|---|---|
| 1–3 | ISO wouldn't emit / `vinos-install` not executable | `c35e6d12` `+x` whitelist in `profiledef.sh` |
| 4 | chpasswd tmpfs collision, nonexistent vconsole FONT | `3f3fa9e5` |
| 5 | `sudo` needs a tty in chroot | `552b3283` NOPASSWD sudoers |
| 5b | sudoers rule matched literal `'qatest'` | `b49266a9` strip quotes |
| 5c | `10-vinos-wheel` won the lex race | `4f6c8737` rename to `99-*` |
| 6 | fakeroot semop failure | `a2ceb070` → `fakeroot-tcp` |
| 7 | SSH dead at +18 min, OOM under AUR storm | `bea50968` base-only pivot |
| 7b | branding lost its NOPASSWD along with the pivot | `f0697dd5` restore, scoped |
| **8** | **`sudo: rsync: command not found`** | **add `rsync` to pacstrap PKGS** |

Every cycle has died inside the **config** phase. Furthest markers
reached: `10-preflight.done 20-prompts.done 30-disk.done
40-pacstrap.done 50-bootloader.done`.

Cycle 8's cause is a direct consequence of the pivot: `rsync` used to
arrive via `install/01-base.sh` during the full overlay run, and that
run is gone. Command surface of `05-branding.sh` has now been audited in
full — `install`, `ln`, `chmod`, `find`, `cp`, `grep`, `printf` all come
from `base`; `rsync` was the only gap.

## Pending

### Blocking v1.4.0

1. ~~**Smoke gate green end-to-end.**~~ **GREEN 2026-08-19**, twice —
   once on the pre-limine tree (443 s) and again as `iso/build.sh`'s
   own built-in gate after the limine migration (350 s, 10/10).
   Note for future sessions: **`iso/build.sh` runs `install-smoke`
   itself** at the end of a build, so a separate invocation afterwards
   is redundant.
2. **`bin/vinos-install-desktop` exists (`c4e0d018`) but has never
   completed a run.** Two blocking bugs are fixed — it passed `""` to
   `install.sh` on every default invocation (`9de2b412`), and the
   installer left `~/.local` root-owned so its own state dir could not
   be created (`ec5f3948`). `iso/qa/desktop-smoke.sh` now gates it, but
   **no green run yet**: the guest pinned its full 8 G under the AUR
   build storm and sshd stopped answering, so the harness went blind.
   Raised to 12 G with a serial console (`c1d5e120`); needs a re-run.
   Until that is green, a finished install still has no proven path to
   a desktop.
3. **11 commits unpushed, and this is now load-bearing for T2.**
   `config/all.sh` clones `--branch main` from GitHub, so an installed
   machine's `/usr/share/vinos/bin/` is origin's, not local. origin/main
   has **no `bin/vinos-boot-entry`** and still carries the systemd-boot
   version of `bin/vinos-t2-enable` — which on a limine system takes its
   `else` branch, warns "systemd-boot not detected", and never writes
   the entry. `linux-t2` would install and never boot: exactly the
   failure `38371352` fixed.

   Note this did NOT invalidate the smoke gate. The bootloader phase
   reads the theme from the **live ISO's** `/usr/share/vinos/limine/`,
   which the build stages from the local tree — that is why
   `limine branding` passed. It is the *installed* system's copy of
   `bin/` that comes from origin. Push before any T2 hardware run.
4. **Zero hardware validation** of this arc. Last T2 data is the 08-16
   rc4/rc5 checkpoint, taken against an installer that no longer exists.
5. **Ship mechanics**: `VERSION` → `1.4.0` in the tag commit, tag, push;
   release workflow uploads to Tigris.

### Known, deferred

- First-boot `vinos-install-desktop` prompt → v1.4.1 (per `bea50968`).
- ~~**Limine migration**~~ — **DONE 2026-08-19** (`38371352`). The
  installed disk boots limine; `bootloader/all.sh` writes the authored
  theme header from `/usr/share/vinos/limine/` and generates entries
  beneath it. Proven by `install-smoke` GREEN 10/10 against ISO
  `8f4a1305`, including that the installed qcow2 boots with no ISO
  attached. **The live medium still boots systemd-boot/syslinux** —
  archiso offers no limine bootmode (`bios.syslinux.*`,
  `uefi-x64.grub.*`, `uefi-x64.systemd-boot.*` only), so limine on the
  USB needs separate ISO post-processing. Not attempted.
- **No fallback initramfs.** Upstream Arch now ships
  `PRESETS=('default')` with the fallback line commented out, so
  `initramfs-linux-fallback.img` is never built and the bootloader phase
  correctly skips that entry. This is an upstream default, not a
  regression — but it leaves an installed machine with no recovery
  image if a module or microcode change breaks the autodetect initramfs.
  Enabling it costs ~120 MB on a 512 MiB ESP that must also hold
  `linux-t2` + its initramfs. Decision pending.
- Boot entry carries `quiet splash` and branding writes
  `plymouthd.conf Theme=vinos`, but plymouth is not in the base pacstrap
  set — the splash is a silent no-op on a base install.
- BIOS/syslinux boots the live medium, but `preflight/all.sh` is hard
  UEFI-only — a legacy-BIOS user boots fine, launches the installer, and
  gets a `die`.
- `grub` and `refind` sit in `packages.x86_64` and `grub/grub.cfg` is
  still maintained, but `bootmodes` declares only
  `bios.syslinux` + `uefi.systemd-boot`.
- Persistence / `cow_device` fallback — still its own boot entry.
- Hyprland `.conf` → `.lua` (deprecating in 0.57), website track,
  swaync + hyprexpo, Track M Apple Silicon → v1.6.0.

## Re-run the gate

```
iso/build.sh                     # runs install-smoke itself; artifacts in iso/out/smoke-latest/

# Desktop layer — needs an installed image to work from. install-smoke
# leaves one behind with --keep; keep a pristine copy and drive
# desktop-smoke against a COW overlay so a re-run costs seconds, not a
# whole reinstall:
#   qemu-img create -f qcow2 -b base-installed.qcow2 -F qcow2 target.qcow2
iso/qa/desktop-smoke.sh --from-dir <dir-with-target.qcow2> --local-repo
```

Post-mortem state is kept on failure at `iso/out/smoke-latest/` —
`summary.txt`, `vinos-install.log.tail`, wizard screendumps, and the
`target.qcow2`.
