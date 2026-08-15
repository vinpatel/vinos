# Session handoff — 2026-08-15

## What just happened

**Shipped:** `v1.3.0` tag pushed, ISO archived to `~/vinos-iso-archive/isos/` and
`iso/out/`, 4.5 GB, sha256 `70bf8cb7e260253d7bfabbe97e78cf29216f893900392352b5a74160035b8357`.

Also pushed: `bin/vinos-publish-iso` + `.github/workflows/release.yml` for the
Tigris bucket `nameless-cloud-628`. GitHub Actions secret: `TIGRIS_KEY` (format
`<access_key_id>:<secret_access_key>`, colon-separated).

## What the user found on real T2 hardware (release-blockers for v1.3.1)

Boot of `vinos-1.3.0-x86_64.iso` on 2019 T2 MacBook Pro surfaced 4 issues that
the QEMU harness could not catch:

1. **Touch Bar not working.** tiny-dfr symlink shipped, doesn't take effect.
2. **Fans running hot.** t2fanrd symlink shipped, doesn't take effect.
3. **Slowness** — not yet quantified; needs `htop` on T2.
4. **Timezone wrong.** `vinos-tzdetect.service` exists in overlay + wired
   into `multi-user.target.wants/`, but clock still on UTC/build-TZ.

Full findings + hardware checkpoint in
`~/.claude/projects/-data-projects-vinos/memory/project_v130_t2_hardware_findings_2026_08_15.md`.

## Open tasks going into next session

- **#6** — Track M Apple Silicon (deferred to v1.6.0)
- **#7** — Fix elephant provider loading (walker search)
- **#9** — Ship swaync + hyprexpo (R10 axes 8/9)
- **#10** — v1.3.1 boot-menu Install entry + gum wizard
- **NEW** — v1.3.1 T2 hardware fixes: tiny-dfr / t2fanrd / tzdetect / slowness
  → make **iso/qa/t2-hardware-checkpoint.md** the ship gate

## Next-session prompt to paste

Copy this into a fresh Claude Code session in `/data/projects/vinos`:

```
Read .planning/HANDOFF.md first. We just shipped v1.3.0 stable and the user
hit 4 blocker regressions on real T2 hardware:

  1. Touch Bar dead — tiny-dfr overlay symlink shipped but service not
     actually running on the guest, or running but can't reach DFR device.
  2. Fans hot — t2fanrd overlay symlink shipped but not effective.
  3. General slowness — unquantified, needs htop on T2 to root-cause.
  4. Timezone regression — vinos-tzdetect.service present in overlay AND
     wired into multi-user.target.wants but clock stays on UTC/build-TZ.

Root-cause approach:
  - Boot the current 1.3.0 ISO in QEMU (still running at :5900 or restart).
  - SSH in on port 2222 (authorized_keys seeded from ~/.ssh/id_ed25519.pub).
  - For each service: `systemctl status <service>`, `journalctl -u <service>`,
    verify units are enabled AND active, check /dev nodes present.
  - Diff overlay symlinks against a known-working comparable distro's
    approach (Fedora Asahi remix for reference; DO NOT copy their code).
  - For slowness: htop + iotop under one foot + swaybg baseline.

Once root causes are identified:
  - Fix in-tree (`config/hypr/autostart.conf`, overlay unit files,
    install/06-hardware.sh live-path).
  - Verify via loop.sh hot-reload where possible.
  - Rebuild ONCE, verify on T2, tag v1.3.1.

Do NOT rebuild speculatively — use hot-reload for anything under
config/ or bin/. Rebuild only for package/install/kernel changes.

Ship gate for v1.3.1: the hardware checkpoint in memory
`project_v130_t2_hardware_findings_2026_08_15.md` must pass on Vin's
2019 T2 MBP before tagging. No exceptions — QEMU-green is not enough.

The bin/vinos-publish-iso pipeline is ready; user has TIGRIS_KEY in
GitHub Actions secrets (format id:secret). Once v1.3.1 tag is pushed,
the release.yml workflow fires and creates the GitHub Release with
Tigris download links.

v1.3.0 stable is PRESERVED per feedback_preserve_130_forever — do NOT
rebuild or overwrite it. Any fixes ship as v1.3.1.

Also carry forward the ~/.config/vinos/tigris.env file check for
local uploads (bin/vinos-publish-iso reads it, 0600 perms).

Start with: read the 4 relevant memories (preserve-130-forever,
v130-t2-hardware-findings, iso-burn-command, use-stored-specifics),
then boot the ISO in QEMU and start diagnosing.
```

## Fast facts to load into the next session

- USB device on this server: **`/dev/sdd`** (never `sdX`)
- VNC host: **`192.168.1.140:5900`** pw `vinos`
- SSH forward: **`2222`** → guest `22`, key `~/.ssh/id_ed25519.pub`
- Current ISO: `iso/out/vinos-1.3.0-x86_64.iso` (permanent, do not rebuild)
- Archive: `~/vinos-iso-archive/isos/vinos-1.3.0-x86_64.iso` + `.sha256`
- Tigris console: `console.storage.dev/flyio_208vk53kogxmlyqo/buckets/nameless-cloud-628`
- Tigris public URL base: `https://nameless-cloud-628.fly.storage.tigris.dev/`
- GitHub Actions secret: `TIGRIS_KEY` (`<access_key_id>:<secret_access_key>`)
