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
Read .planning/HANDOFF.md end-to-end BEFORE proposing any action. The
last 3 sessions have been whack-a-mole on individual boot/install/
persistence failures — Vin explicitly said "this needs streamlining,
not more patches" at the end of the last session.

The PRIORITY section at the top of HANDOFF.md is the actual next-session
job: pick one of the four streamline targets (recommend: dedicated
`vinos-installer.target` for install boots so the flow doesn't route
through hyprland + foot + wifi wrap), design it in
`.planning/streamline-boot.md`, then implement.

Do NOT rebuild the ISO speculatively this session. Plan first. One
focused implementation. Then rebuild once, then test on Vin's T2.

Two tracks still open in parallel (do NOT start until streamline is
either shipped or explicitly deferred by Vin):

TRACK A — vinos.computer website work (secondary, after streamline).

  Start by reading:
    * memory: project_site_state (positioning + pages + brand)
    * memory: feedback_site_design_direction (design + screenshot rules)
    * memory: feedback_hallmark_audit_findings (2 critical / 2 major /
      3 minor unfixed findings from the last audit)
    * site/ directory in the repo (existing Hallmark landing)

  Ask Vin what specifically he wants to move on: fix the hallmark
  audit findings, add v1.3.1 release notes page, refresh screenshots
  from rc5, or something else. Don't guess — the site's a big
  surface. One targeted focus per session.

  Hard rules for site work:
    * Keep Hallmark aesthetic — do not swap frameworks or restructure.
    * Screenshots MUST render (broken IMGs are a critical audit fail).
    * Keybindings table on the site must match config/hypr/bindings/
      exactly — a mismatch is a critical audit fail.
    * `bash iso/qa/branding-check.sh` still runs before any site
      commit; product name must be "vinOS" everywhere.

TRACK B — v1.3.1 tag (blocked on Vin's T2 verification).

  rc5 is built (sha256 791b27763047b690eb8b94f6b997a516094d4e404f7fb89703d06612235ca1ff)
  at iso/out/vinos-1.3.1-rc5-x86_64.iso. Vin was flashing it last session
  to verify the install-to-disk network-wait fix works on his 2019 T2 MBP.

  If Vin says "rc5 install worked + checkpoint passes":
    echo 1.3.1 > VERSION
    git add VERSION
    git commit -m "release: v1.3.1 — T2 fixes + install-to-disk"
    git tag -a v1.3.1 -m "v1.3.1 — T2 Touch Bar / fans / timezone fixes + install-to-disk"
    git push origin main v1.3.1
  Release workflow (.github/workflows/release.yml) auto-uploads to Tigris.

  If Vin says "install still failed" or any T2 checkpoint item failed:
    Have him run `vinos-t2-perf --out /tmp/perf.log` and paste the log.
    Diagnose from journalctl -u vinos-tzdetect / systemctl status
    tiny-dfr / systemctl status t2fanrd BEFORE proposing a rebuild.

Hard rules (both tracks):
  * VERSION only moves on ship-tag commit (feedback_no_version_bump_during_iteration).
  * Never overwrite gold archival ISOs (v1.1.0, v1.3.0 sha256 70bf8c…).
  * Zero Omarchy code in vinOS — patterns/reference only (per
    feedback_no_omarchy_ever_2026_08_08).
  * No Claude-authored trailers on commits (public repo, sponsor-facing).

Fast facts: /dev/sdd USB, 192.168.1.140:5900 VNC pw vinos, port 2222 SSH,
rc5 sha256 791b27763047b690eb8b94f6b997a516094d4e404f7fb89703d06612235ca1ff.
```
