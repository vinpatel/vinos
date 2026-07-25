# iso/v2/ — vinOS 2.0 ISO builder

Parallel to `iso/` (v1). Never touches `iso/out/vinos-1.1.0-x86_64.iso`,
which is preserved forever per the 1.1.0 archival rule.

## Layout

- `VERSION` — v2 version string (default `2.0.0`). Overrides top-level
  `VERSION` at build time via `VINOS_V2_VERSION`.
- `profile/` — archiso profile, seeded from v1's T2-proven profile.
  Same base + T2 boot fixes; adds Omarchy source tree + vinOS overlays
  on top of the airootfs at build time.
- `build.sh` — orchestrates docker-based mkarchiso build. Layers
  `configs/omarchy/` into `airootfs/root/omarchy/` and `configs/vinos/`
  into `airootfs/usr/share/vinos/`.
- `qa/` — v2-specific pre-flash gates (defers to `iso/qa/oneshot.sh` where
  useful).

## Output

`iso/out/vinos-<version>-x86_64.iso` (e.g. `vinos-2.0.0-x86_64.iso`).
Never overwrites the 1.1.0 file.

## Build

    iso/v2/build.sh

## What lives inside the ISO

- Bootable archiso live env (T2-supported: linux-t2 kernel, apple-bce,
  brcmfmac firmware, iwd, cfg80211 cmdline)
- Full Omarchy source at `/root/omarchy/` — the installer target
- vinOS overlays at `/usr/share/vinos/{security,mac,brand}/` — applied by
  the post-install hook after Omarchy's installer finishes
- Wrapper installer at `/usr/local/bin/vinos-install` that:
  1. Runs Omarchy's installer against the target disk
  2. Applies `security/install.sh`, `mac/install.sh`, `brand/install.sh`
  3. Writes `/etc/vinos-release` marking the target as vinOS 2.x
