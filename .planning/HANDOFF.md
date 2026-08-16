# Session handoff — 2026-08-16 (v1.3.1-rc4)

## Where we are

**Committed:** `19b2c7f1` on `main` — "v1.3.1-rc4: T2 fixes + boot menu +
install-to-disk + waybar polish". 26 files, 338 insertions, 266
deletions. Everything Vin flagged during long QEMU-VNC QA session
is in-tree.

**Built:** `iso/out/vinos-1.3.1-rc4-x86_64.iso`
- Size: 4.5 GB
- sha256: `1c295e912b6a375a7c7976e0febf29101bbbe25e9986441f94cfa09cd1675610`

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

## Open follow-ups (post v1.3.1)

- **#7 Fix elephant provider loading** (walker search backend) — deferred
- **#9 Ship swaync + hyprexpo** (R10 axes 8/9) — deferred
- **#6 Track M Apple Silicon** (v1.6.0) — deferred
- **Boot menu splash** — systemd-boot's EFI-font limits how pretty this
  can get. Follow-up: consider a Limine port for real graphical boot menu.

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
Read .planning/HANDOFF.md. rc4 is built (1c295e91…) and committed on
main (19b2c7f1). Your job this session:

  1. Flash rc4 to /dev/sdd:
       sudo iso/flash.sh --dev sdd --iso iso/out/vinos-1.3.1-rc4-x86_64.iso
     Persistence partition auto-creates.

  2. Boot on Vin's 2019 T2 MBP with the "Boot vinOS + persistence"
     menu entry (first boot only).

  3. Walk iso/qa/t2-hardware-checkpoint.md end-to-end. Every item.

  4. If any item fails:
       vinos-t2-perf --out /tmp/perf.log
     Paste the log back. Do NOT rebuild speculatively — diagnose from
     the journal + the log first.

  5. If every item passes:
       echo 1.3.1 > VERSION
       git add VERSION && git commit -m "release: v1.3.1 — T2 fixes + install-to-disk"
       git tag -a v1.3.1 -m "v1.3.1 — T2 Touch Bar / fans / timezone fixes"
       git push origin main v1.3.1
     Release workflow uploads to Tigris.

Hard rules:
  * VERSION only moves on the ship-tag commit (per
    feedback_no_version_bump_during_iteration).
  * Never overwrite the gold archival ISOs (v1.1.0, v1.3.0).
  * Zero Omarchy code in vinOS — patterns/reference only.
  * No Claude-authored trailers on commits (public repo, sponsor-facing).

Fast facts: /dev/sdd USB, 192.168.1.140:5900 VNC pw vinos, port 2222 SSH.
```
