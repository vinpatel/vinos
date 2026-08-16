# Streamline the boot / install pipeline

**Purpose:** design doc for the next-session work. Read Vin's frustration
in .planning/HANDOFF.md — five rc-cycles patching individual symptoms
of a fundamentally over-complicated pipeline. This doc plans the fix.

## What everyone else does

### Omarchy (~/.local/share/omarchy)

**Not comparable — they aren't a live-ISO distro.** Omarchy is a
POST-INSTALL script layered on top of an already-installed Arch. Their
"boot.sh" downloads their repo, "install.sh" wires their overlay onto
your live Arch install. `preflight/first-run-mode.sh` writes a NOPASSWD
sudoers drop-in for setup, removes itself when done. No installer,
no live medium, no persistence, no Wi-Fi picker.

**Takeaway for vinOS:** Omarchy's first-run-mode NOPASSWD sudoers
pattern is a clean way to grant temporary elevated privileges during
a one-time setup phase. Steal that pattern for the install-wizard's
temp sudoers file (removes itself after install).

### CachyOS

Uses **Calamares** — the Qt-based graphical installer used by KDE Neon,
Manjaro, Nitrux, Endeavour, and ~30 other distros. Boots into a Live
KDE desktop, Calamares icon on desktop, click → wizard walks user
through language, TZ, disk, user, password, install. Feels like macOS
Setup Assistant. Costs ~150 MB in Qt5+qt5-webengine+dependencies.

**Takeaway:** Calamares is the gold-standard GUI installer for Arch-based
distros, but the cost (Qt bloat + Live-desktop-first UX) doesn't match
vinOS's "boot straight to what you need" ethos. Skip.

### Fedora

Anaconda — dedicated boot target. Fedora Workstation ISO boots
directly into Anaconda TUI-then-GUI. No desktop underneath. Once
install finishes, reboots into installed Fedora. Full-screen wizard.

**Takeaway:** dedicated installer target that BYPASSES the desktop is
the right shape for vinOS. Fedora's Anaconda TUI mode is exactly the
UX we want.

### Ubuntu

Ubiquity (deprecated) → Subiquity (cloud + server) → Flutter installer
(desktop). All variants: dedicated boot target, no user desktop
underneath the install flow. Same pattern as Anaconda.

### Arch (upstream)

`archinstall` — TUI wizard, runs as root on the live ISO. User must
manually launch it. No auto-launch. No wireless picker (relies on
user having connected via `iwctl` before running archinstall).

**Takeaway:** archinstall is what we already use as the backend. Our
pain is the WRAPPING — how it launches, how the network gets ready,
how the user reaches it.

## The vinOS shape we want

**Boot menu selection:**
- **`⚙ Install vinOS to disk`** → dedicated installer boot path
- **`➜ Boot vinOS`** → live desktop (default)
- **`● Boot + persistence`** → live desktop with cow_device

**When user picks Install:**
1. Kernel boots with `systemd.unit=vinos-installer.target`.
2. Plymouth splash shows the vinOS logo during initramfs + early boot.
3. Systemd reaches `vinos-installer.target` (a new custom target).
4. `vinos-installer.target` wants a single service:
   `vinos-installer.service` — Type=idle, ExecStart runs on tty1.
5. Systemd-getty on tty1 is REPLACED by our installer (via
   `Conflicts=getty@tty1.service`).
6. The installer:
   - Full-screen gum TUI on tty1 (no desktop, no waybar, no hyprland).
   - Step 1: Wi-Fi picker via `iwctl` interactive (integrated into
     our wizard — no separate foot window).
   - Step 2: Language / TZ / keymap.
   - Step 3: Disk selection.
   - Step 4: Username + password + hostname.
   - Step 5: Confirmation summary → "Install? [y/N]".
   - Step 6: Runs `archinstall --config <rendered.json> --silent`.
     Progress bar via gum, output to /var/log/vinos-install.log.
   - Step 7: chroot into /mnt, apply vinOS overlay (install.sh).
   - Step 8: "Install complete. Reboot? [Enter to reboot]".
7. On reboot, kernel loads the installed vinOS (not the ISO).

**When user picks Boot vinOS / Boot + persistence:**
Same live-ISO flow as v1.3.0 — greetd → hyprland → desktop. No
`vinos.install=1` cmdline flag. No auto-launcher. No `sudo -n
tzupdate` gated on cmdline. Simplification: kill the exec-once
block entirely — install is a separate boot path, not a mode of the
live desktop.

## Implementation plan

### Files to create

1. **`iso/airootfs-overlay/etc/systemd/system/vinos-installer.target`**
   ```
   [Unit]
   Description=vinOS installer boot target
   Documentation=file:///usr/share/doc/vinos/INSTALL.md
   Requires=multi-user.target
   After=multi-user.target
   AllowIsolate=yes
   ```

2. **`iso/airootfs-overlay/etc/systemd/system/vinos-installer.service`**
   ```
   [Unit]
   Description=vinOS full-screen installer wizard
   Documentation=file:///usr/share/doc/vinos/INSTALL.md
   Conflicts=getty@tty1.service
   After=multi-user.target network-online.target
   Before=vinos-installer.target
   Wants=network-online.target
   
   [Service]
   Type=idle
   ExecStart=/usr/local/bin/vinos-installer-wizard
   StandardInput=tty-force
   StandardOutput=tty
   StandardError=tty
   TTYPath=/dev/tty1
   TTYReset=yes
   TTYVHangup=yes
   TTYVTDisallocate=yes
   
   [Install]
   WantedBy=vinos-installer.target
   ```

3. **`bin/vinos-installer-wizard`** — the gum-based full-screen wizard.
   Replaces `vinos-install-launcher` + hyprland-embedded foot flow.
   Sections: pre-flight, wifi, locale, disk, user, install, reboot.

4. **`iso/airootfs-overlay/etc/systemd/system/vinos-installer.target.wants/vinos-installer.service`**
   → `../vinos-installer.service` (enable symlink so the service starts
   when the target is reached).

### Files to change

1. **`iso/profile/efiboot/loader/entries/00-vinos-install-t2.conf`**
   change kernel `options` — replace `vinos.install=1` with
   `systemd.unit=vinos-installer.target`.

2. **`iso/profile/efiboot/loader/entries/01-vinos-install.conf`**
   same change.

3. **`iso/profile/syslinux/archiso_sys-linux.cfg`** — same on both
   `LABEL vinosInstallT2` and `LABEL vinosInstall`.

4. **`iso/profile/grub/grub.cfg`** — same on both install entries.

5. **`config/hypr/autostart.conf`** — DELETE the `vinos.install=1`
   exec-once. Install is no longer a mode of hyprland.

6. **`bin/vinos-install-launcher`** — DELETE. Superseded by
   `vinos-installer-wizard` running from systemd-target.

7. **`bin/vinos-install-disk`** — refactor into two parts:
   - keep the archinstall + chroot logic as
     `bin/vinos-install-disk-execute` (the "do the install" backend)
   - `vinos-installer-wizard` becomes the frontend gum UI that
     collects answers and calls the backend

### Files to keep as-is

- `install/06-hardware.sh` — T2 detection/enable stays intact.
- `iso/flash.sh` — my fix from `536791b` handles the sgdisk failure
  gracefully. No further change needed.
- All the waybar / theme / T2 fixes from rc4/rc5.

## Testing plan

1. Build → new ISO with `vinos-installer.target`.
2. QEMU boot with `systemd.unit=vinos-installer.target` manually
   set via GRUB edit — should land on tty1 wizard, no desktop.
3. Simulate wizard flow with dummy inputs (no actual install).
4. Real T2 flash + boot into install entry → full wizard flow.

## Success criteria

- Boot menu install entry → tty1 wizard within 10 s of USB boot.
- Wi-Fi picker is INSIDE the wizard (no foot popup over a wallpaper).
- Full install completes end-to-end without user needing to touch
  anything except answering the wizard's questions.
- No hyprland involvement. No greetd. No waybar. No exec-once. No
  wait-for-route poll loops. No install-launcher script.
- If wizard is cancelled (Ctrl+C or "Cancel"), user is dropped to a
  root shell on tty1 with a message: "Run `vinos-installer-wizard`
  to restart, or type `reboot` to start over."

## Effort estimate

~1 day focused work:
- 2 h: wizard script skeleton
- 2 h: systemd unit + target + boot entries wiring
- 2 h: gum UI for each step (wifi, locale, disk, user)
- 1 h: refactor vinos-install-disk into backend
- 1 h: build + QEMU test
- (~ 2 h buffer for T2 real-hardware surprises)

Ship as v1.4.0 (not v1.3.x — this is a real feature, not a patch).

## What this does NOT solve

- Persistence flow (cow_device fallback) — deferred, still separate boot entry
- Website work — deferred, separate track
- Track M Apple Silicon — deferred to v1.6.0
- swaync + hyprexpo — deferred

Focus on the installer this session.
