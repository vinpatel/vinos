# Session handoff — 2026-08-16 (v1.3.1-rc4)

## Where we are

**Committed:** `19b2c7f1` on `main` — "v1.3.1-rc4: T2 fixes + boot menu +
install-to-disk + waybar polish". 26 files, 338 insertions, 266
deletions. Everything Vin flagged during long QEMU-VNC QA session
is in-tree.

**Built:** `iso/out/vinos-1.3.1-rc5-x86_64.iso` (rc4 superseded — install-to-disk auto-launcher fixed to wait for network)
- Size: 4.5 GB
- sha256: `791b27763047b690eb8b94f6b997a516094d4e404f7fb89703d06612235ca1ff`
- Prior rc4 (`1c295e91…`) kept in `iso/out/` for comparison

**VERSION file:** still `1.3.0` (bumps to `1.3.1` in the tag commit AFTER
the T2 hardware checkpoint passes — per `feedback_no_version_bump_during_iteration`).

## What rc4 fixed vs. v1.3.0

- **Touch Bar** — tiny-dfr enabled into `graphical.target.wants` (not
  multi-user), matches its arch-mact2 drop-in's `[Install]` section.
- **Fans** — t2fanrd enabled into `default.target.wants` + shipped
  `/etc/t2fand.conf` (Omarchy Fan1 curve) — daemon errors on start
  without this file.
- **Timezone first-boot** — `systemd-networkd-wait-online` unmasked
  with `--timeout=15` so `network-online.target` actually waits for
  brcmfmac. `vinos-tzdetect.service` bounded 30 s + journal logs.
  `greetd.service.d/00-vinos-wait-tzdetect` makes login screen block
  on tzdetect. Belt-and-suspenders: Hyprland exec-once `sudo -n
  tzupdate` gated on sentinel.
- **video group** — vinos live user in `wheel,video,audio,input,storage,network`
  (tiny-dfr needs `video` for `/dev/dri`).
- **pcie_ports=compat** — added to every T2 kernel cmdline.
- **Persistence-by-default** — `iso/flash.sh` `WITH_PERSIST=1` default.
- **Boot menu** — 9 → 5 clean entries: Boot T2, Install T2, Persist T2,
  Boot PC, Install PC. Install entries pass `vinos.install=1` on cmdline;
  Hyprland exec-once auto-launches `sudo vinos-install-disk`. Timeout 30 → 10 s.
- **Waybar** — pills fully opaque `#1A1B26` solid (no wallpaper bleed on
  light backgrounds), V logo teal on dark, subtle workspace-active bg.
  Wifi launcher graceful when no radio (QEMU/hard-blocked/missing).
- **vinos-hypr-plugin-setup** — no more phantom "Plugin build failed"
  toast (verifies actual `hyprpm list` state, not `hyprpm add` exit).
- **vinos-tz-select** — new gum picker, wired to waybar clock right-click.
- **vinos-menu ai** — new AI-only submenu (chat / status / pull / role / back).
- **Ollama** — `systemctl_enable ollama` on the live ISO so
  `ollama pull` works after boot without manual `systemctl start`.

## What to do this session

1. **Flash rc4** to Vin's USB:
   ```
   sudo iso/flash.sh --dev sdd --iso iso/out/vinos-1.3.1-rc4-x86_64.iso
   ```
   Persistence partition auto-creates.

2. **Boot on Vin's 2019 T2 MBP.** Pick the **`● Boot vinOS + persistence — Apple T2 Mac`**
   entry from the boot menu (first boot only — Wi-Fi/TZ/etc. stick after that).

3. **Walk `iso/qa/t2-hardware-checkpoint.md` top to bottom.** Every item
   must pass. Two must-pass items that were broken on v1.3.0 rc1/rc2:
   - Touch Bar shows keys (`systemctl is-active tiny-dfr` → active)
   - Fans quiet at idle (`systemctl is-active t2fanrd` → active,
     `cat /sys/devices/platform/applesmc.768/fan1_input` returns a
     number)
   - Clock shows local TZ on FIRST boot (not UTC — the whole point of
     the greetd wait fix)

4. **If any item fails:** capture with
   ```
   vinos-t2-perf --out /tmp/perf.log
   ```
   and paste the log back for triage. Do NOT rebuild speculatively.

5. **If everything passes:** bump VERSION to 1.3.1, tag, push. Release
   workflow (`.github/workflows/release.yml`) fires and creates the
   GitHub Release with Tigris download links via `TIGRIS_KEY`.

## Ship-gate command sequence (once checkpoint green)

```
echo 1.3.1 > VERSION
git add VERSION
git commit -m "release: v1.3.1 — T2 hardware fixes + install-to-disk"
git tag -a v1.3.1 -m "v1.3.1 — T2 Touch Bar / fans / timezone fixes + install-to-disk boot entry"
git push origin main v1.3.1
```

Release workflow auto-uploads the ISO to Tigris.

## If Vin says "these still fail on T2"

The rc4 log points to look at:
- `sudo journalctl -u vinos-tzdetect --no-pager` — 6 attempt log lines
  will pinpoint whether curl reached ipapi.co / ip-api.com or if
  brcmfmac never came up.
- `sudo journalctl -u tiny-dfr --no-pager` — dependency chain, whether
  `dev-tiny_dfr_display.device` udev alias got created.
- `systemctl is-enabled tiny-dfr t2fanrd` — should both be `enabled`.
- `readlink /etc/systemd/system/graphical.target.wants/tiny-dfr.service` —
  must resolve to `/usr/lib/systemd/system/tiny-dfr.service`.
- `cat /var/lib/vinos/tzdetect.done` — sentinel file if tzdetect succeeded.
- `ls /sys/class/net/*/wireless/` — kernel-authoritative wifi presence.

## FRESH BUG reported after rc4 build — install-to-disk boots without Wi-Fi

Vin reported (2026-08-16 post-rc4-build): the **"Install vinOS to disk"
boot menu entry doesn't work because Wi-Fi isn't connected** by the
time `vinos-install-disk` auto-launches. Installer needs network
(archinstall pacstraps from mirrors, git clones the vinOS repo into
chroot) → fails without a connected radio.

### Root cause (untested but confident)

`config/hypr/autostart.conf` has:
```
exec-once = sh -c 'grep -q "vinos.install=1" /proc/cmdline && sleep 3 && foot -T "Install vinOS" -a vinos-installer sh -c "sudo vinos-install-disk; ..."'
```

`sleep 3` is not enough for brcmfmac to associate + DHCP. Installer
fires with no route to any mirror, `pacstrap` fails, user is stuck.

### Fix approaches (pick in next session)

**A. Gate installer on network-online.target instead of `sleep 3`.**
   Replace the exec-once with a wait loop:
   ```
   exec-once = sh -c 'grep -q "vinos.install=1" /proc/cmdline || exit 0; \
     for i in {1..60}; do ping -c1 -W1 1.1.1.1 >/dev/null 2>&1 && break; sleep 2; done; \
     foot -a vinos-installer -T "Install vinOS" sh -c "sudo vinos-install-disk; ..."'
   ```
   Waits up to 2 min for real internet before launching. If never
   reaches internet, installer fires anyway with a diagnostic.

**B. Have the auto-launcher pop `vinos-launch-wifi` first if no route.**
   User picks Wi-Fi via impala UI, connects, then the installer opens.
   Better UX. Requires a wrapper script:
   ```
   #!/bin/bash
   # bin/vinos-install-launcher
   if ! ip route show default | grep -q .; then
     foot -a org.vinos.impala -T "Connect Wi-Fi first" -- impala
     # wait for user to connect, then re-check
     for i in {1..60}; do ip route show default | grep -q . && break; sleep 2; done
   fi
   foot -a vinos-installer -T "Install vinOS" -- sudo vinos-install-disk
   ```
   Cleaner separation of concerns.

**C. Make `vinos-install-disk` itself prompt for network.**
   Add a `require_network` step to the installer's preflight that
   pops impala if no route, waits for user to connect, retries.

Recommended: **B** — dedicated launcher, keeps autostart.conf simple,
provides clear UX (user sees impala, connects, installer opens
automatically).

Once B lands, next rebuild becomes v1.3.1-rc5 (or ship straight to
1.3.1 if the T2 checkpoint also passes on that build).

## PRIORITY for next session — streamline the boot / flash / install pipeline

We've been iterating on individual failures (sgdisk error, tzdetect
race, install auto-launch, wifi wrap, etc.) instead of stepping back
to fix the shape of the pipeline. Vin's frustration is legitimate —
each release cycle keeps hitting a new corner of the same underlying
mess. This is the real work.

### What "streamline" means concretely

**Boot menu** (5 entries currently — good, keep):
  1. `➜ Boot vinOS — Apple T2 Mac`
  2. `⚙ Install vinOS to disk — Apple T2 Mac`
  3. `● Boot vinOS + persistence — Apple T2 Mac`
  4. `➜ Boot vinOS — Intel / AMD / generic PC`
  5. `⚙ Install vinOS to disk — Intel / AMD / generic PC`

**flash.sh** (currently 3 modes: normal, --with-persistence, --no-persistence):
  Simplify to ONE mode. Persistence should be created if the tooling
  supports it, warn+continue if it doesn't. Remove the --with-persistence
  / --no-persistence flags entirely — just do the right thing.

**Install auto-launch pipeline** (vinos.install=1 cmdline):
  Currently: cmdline flag → hypr exec-once → vinos-install-launcher →
  wifi wait → foot → sudo vinos-install-disk → archinstall. Too many hops.
  Consolidate: skip hyprland entirely for install boots. Boot into a
  dedicated systemd target `vinos-installer.target` that runs a TTY-based
  installer wizard with gum. No desktop. No greetd. No Wi-Fi picker in
  a foot window over a wallpaper. Just a full-screen installer that:
    - Shows a splash on boot
    - Picks Wi-Fi via iwctl
    - Runs disk / user / password wizard
    - Installs
    - Reboots into new system
  This is how Fedora / Ubuntu / Arch iso installers work.

**Persistence flow:**
  Currently uses `cow_device=/dev/disk/by-label/vinos-persist` which
  hard-requires the partition. If the partition doesn't exist, kernel
  hangs waiting for it. Alternative: hook into archiso's `overlay_fs`
  mkinitcpio hook to gracefully fall back to tmpfs. Or (Fedora-style):
  detect a `vinos-persist` label at boot via a script in
  `mkinitcpio-archiso` and mount only if present. Removes the need for
  a separate boot menu entry.

**First-boot vs. subsequent-boot on persistent USB:**
  First boot: no Wi-Fi creds, no TZ. User has to go through Wi-Fi picker.
  Subsequent boots: everything persisted, boot straight to desktop.
  Right now these two paths are the same boot entry. A better UX might
  gate the Wi-Fi picker only on first-boot (detect via /var/lib/iwd
  being empty).

**Ship gate**: the T2 hardware checkpoint (`iso/qa/t2-hardware-checkpoint.md`)
  is 15 items. Add an INSTALL-TO-DISK checkpoint that runs end-to-end:
  boot USB → pick install entry → complete install → reboot into
  installed vinOS → check items again. This is what Vin has been
  doing manually 5 times this session.

### Suggested approach for next session

Don't touch anything yet. First session activity:
  1. Read this section end-to-end with Vin
  2. Pick ONE of the four bullets above (recommend: dedicated
     installer.target route)
  3. Plan it in-repo (`.planning/streamline-boot.md`)
  4. Implement it as a single focused change
  5. Rebuild ONCE, test on T2

Do NOT rebuild speculatively. Do NOT chase individual failures. If
the streamline design surfaces the individual issues as consequences,
fix them in-scope; if not, defer them.

## Open follow-ups (post v1.3.1)

- **#7 Fix elephant provider loading** (walker search backend) — deferred
- **#9 Ship swaync + hyprexpo** (R10 axes 8/9) — deferred
- **#6 Track M Apple Silicon** (v1.6.0) — deferred
- **Boot menu splash** — systemd-boot's EFI-font limits how pretty this
  can get. Follow-up: consider a Limine port for real graphical boot menu.
- **vinos.computer website** — Vin also wants to touch this soon
  (see project_site_state, feedback_hallmark_audit_findings memories).

## Fast facts (from memory)

- USB device on this server: **`/dev/sdd`** (always — never `sdX`)
- VNC host: **`192.168.1.140:5900`** pw `vinos`
- SSH forward to running QEMU: **`2222`** → guest `22`
- Vin's email: **vinpatel.pro@gmail.com**
- Gold v1.1.0 archival: `~/vinos-iso-archive/isos/vinos-1.1.0-x86_64.iso`
- Gold v1.3.0 archival: `~/vinos-iso-archive/isos/vinos-1.3.0-x86_64.iso`
  (sha256 `70bf8cb7e260253d…`, permanent — do not overwrite)
- rc4 candidate: `iso/out/vinos-1.3.1-rc4-x86_64.iso`
  (sha256 `1c295e912b6a375a…`)

## Next-session prompt (paste into a fresh Claude Code session in `/data/projects/vinos`)

```
Read .planning/streamline-boot.md end-to-end BEFORE proposing any action.
Also read .planning/HANDOFF.md for context on why we're doing this
(five rc-cycles of whack-a-mole patches on the install pipeline).

Your job this session: implement the plan in streamline-boot.md.

That means, in this order:
  1. Create bin/vinos-installer-wizard (gum-based full-screen TUI:
     preflight → wifi via iwctl → locale → disk → user → confirm →
     archinstall backend → chroot vinOS overlay → reboot prompt).
  2. Refactor bin/vinos-install-disk: keep the archinstall + chroot
     logic as bin/vinos-install-disk-execute (backend); the frontend
     is now the wizard.
  3. Create iso/airootfs-overlay/etc/systemd/system/vinos-installer.target
     and .service (see spec in streamline-boot.md — Type=idle, tty1,
     Conflicts=getty@tty1.service).
  4. Wire the enable symlink: airootfs-overlay/etc/systemd/system/
     vinos-installer.target.wants/vinos-installer.service.
  5. Change kernel `options` in the two Install boot entries:
       iso/profile/efiboot/loader/entries/00-vinos-install-t2.conf
       iso/profile/efiboot/loader/entries/01-vinos-install.conf
     Replace `vinos.install=1` with `systemd.unit=vinos-installer.target`.
     Same edit for the two syslinux Install labels and the two GRUB
     install menuentries.
  6. DELETE the `vinos.install=1` exec-once in config/hypr/autostart.conf.
  7. DELETE bin/vinos-install-launcher (superseded).
  8. Build ONCE. Test in QEMU by manually adding
     `systemd.unit=vinos-installer.target` via boot-menu edit (e).
     Should land on tty1 wizard, no desktop.
  9. If green in QEMU, hand off to Vin to flash + test on his T2.

Hard rules:
  * Do NOT touch waybar, theme, T2 driver code, or website. Focus.
  * Do NOT rebuild speculatively — plan → implement → build ONCE → test.
  * VERSION stays 1.3.0 during dev; bump to 1.4.0 in the ship-tag commit
    only after the wizard works end-to-end on Vin's T2.
  * Zero Omarchy code in vinOS — patterns/reference only
    (feedback_no_omarchy_ever_2026_08_08).
  * No Claude-authored trailers on commits.

Fast facts: /dev/sdd USB, 192.168.1.140:5900 VNC pw vinos, port 2222 SSH.
Current baseline: rc5 sha256 791b27763047b690eb8b94f6b997a516094d4e404f7fb89703d06612235ca1ff
at iso/out/vinos-1.3.1-rc5-x86_64.iso. Gold v1.1.0 + v1.3.0 preserved in
~/vinos-iso-archive/isos/ — do NOT overwrite.
```
