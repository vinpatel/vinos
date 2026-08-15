# T2 hardware checkpoint — vinOS ship gate

**Status:** MANDATORY before tagging any release. QEMU-green is not
enough. Passing every item on a 2019 Intel T2 MacBook Pro is the ship
gate — introduced 2026-08-15 after v1.3.0 shipped with tiny-dfr /
t2fanrd / tzdetect regressions the QEMU harness could not catch.

## Why this exists

The Track Q QA harness proves the SOFTWARE works. It cannot test:

- **tiny-dfr** — needs the T2 Touch Bar DRM device (`/dev/dri/card1`).
- **t2fanrd** — needs `applesmc` sensors under
  `/sys/devices/platform/applesmc.768/`.
- **vinos-tzdetect** — needs a real brcmfmac Wi-Fi association race
  to prove the internal retry loop survives the slow first handshake.
- **Slowness under one-foot+swaybg** — needs the real Intel iGPU
  (Coffee Lake i9-9880H on 2019 MBP), which QEMU virtio-vga cannot
  simulate. Hyprland blur/animations cost real cycles.

Every one of the four v1.3.0 regressions Vin found was hardware-only.
Ship gates that can't catch them are broken. This file closes that gap.

## How to run

1. Build the ISO (`iso/build.sh` or `bin/vinos-publish-iso`).
2. Boot in QEMU (`iso/qemu-desktop.sh --lan --keepalive --hostfwd`)
   and confirm the software checkpoint passes.
3. Flash to USB (`sudo iso/flash.sh --dev sdd --iso iso/out/vinos-<ver>-x86_64.iso`).
4. Boot the USB on Vin's 2019 T2 MBP (or any 2018–2020 T2 Mac).
5. Walk the checklist below top to bottom. Every item must PASS.
6. When something fails, run `vinos-t2-perf --out /tmp/perf.log`,
   copy `/tmp/perf.log` off the T2, attach to the release notes.

Failures are release-blockers. Fix and rebuild. Do not tag.

## Checklist

```
[ ] Boot USB → grub/systemd-boot menu appears with vinOS entries
[ ] Boot splash — dark navy bg + centered V logo + blinking caret,
    no black rectangle behind V
[ ] Reaches Hyprland login within 60 s
[ ] Wallpaper — visible, V watermark in corner (not clipped by 16:10 crop)
[ ] Waybar renders top with vinOS pills

# --- Apple T2-specific hardware (v1.3.0 regressions caught here) ----

[ ] Touch Bar shows default keys (escape, brightness, volume …)
    → confirms tiny-dfr running
    → verify: systemctl is-active tiny-dfr   →  active
    → verify: systemctl is-enabled tiny-dfr →  enabled (graphical.target.wants)

[ ] Fans quiet at idle, spin only under load
    → confirms t2fanrd running + reading sensors correctly
    → verify: systemctl is-active t2fanrd    →  active
    → verify: cat /sys/devices/platform/applesmc.768/fan1_input
              returns a number (RPM), not I/O error

[ ] Clock shows the user's local timezone (not UTC, not the ISO-build TZ)
    → confirms vinos-tzdetect ran successfully after brcmfmac associated
    → verify: cat /var/lib/vinos/tzdetect.done  →  e.g. America/New_York
    → verify: timedatectl | grep 'Time zone'    →  matches
    → if it stayed UTC: journalctl -u vinos-tzdetect (should show
      retry attempts, not a single silent 5 s failure)

# --- Desktop surfaces ----------------------------------------------

[ ] SUPER+Return opens foot terminal
[ ] SUPER+Space opens nwg-drawer / walker
[ ] Wi-Fi visible in mako network module; scan finds APs
[ ] Wi-Fi connects and holds (no 5 GHz disassociation — brcmfmac quirk)
[ ] `sudo vinos-install-disk --help` prints without error
[ ] Cursor is Bibata-Modern-Ice (not Adwaita fallback)
[ ] Icons on nautilus are Papirus-Dark blue folders (not Yaru/Adwaita)
[ ] `fastfetch` prints vinOS ascii + palette-matching accent
[ ] hyprbars visible on foot window (red/yellow/green traffic-light buttons)

# --- Performance (slowness regression) -----------------------------

[ ] `htop` while running one foot + swaybg shows idle CPU ≤ 5 %
    → catches the slowness regression
    → if > 5 %, capture:
        vinos-t2-perf --out /tmp/perf.log
      and attach /tmp/perf.log to the release notes for triage
```

## Related

- `iso/qa/oneshot.sh` — Layer 2.5 QEMU pre-flight (still required)
- `iso/qa/verify-shipped-iso.sh` — static ISO regression checks
- `bin/vinos-t2-perf` — one-shot T2 perf snapshot referenced above
- Memory: `project_v130_t2_hardware_findings_2026_08_15.md` — origin
- Memory: `feedback_oneshot_before_ship` — the parallel software gate
