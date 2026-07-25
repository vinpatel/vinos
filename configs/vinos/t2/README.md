# vinOS T2 overlay — LIVE ISO ONLY

The installed system's T2 setup is handled by Omarchy's
`install/hardware/apple/fix-t2.sh`, which installs `linux-t2`,
`apple-bcm-firmware`, `t2fanrd`, `tiny-dfr` and configures initramfs
modules. We do not duplicate that work.

This overlay is scoped to the **live archiso environment** — the running
state between "insert USB" and "user reaches the installer." That
environment needs T2 support too so Wi-Fi and keyboard work while
someone is picking their timezone.

## What this overlay contributes

- `packages.append` — extra packages baked into the live archiso image:
  - `linux-t2`, `linux-t2-headers` (replaces stock linux for live env)
  - `apple-bcm-firmware` (Broadcom Wi-Fi/BT firmware for T2 Macs)
  - `t2fanrd` (fan control daemon)
  - `linux-firmware` (baseline firmware set)
- `airootfs/etc/mkinitcpio.conf.d/vinos-t2.conf` — live initramfs modules
  so brcmfmac + apple-bce load in the live environment.
- `airootfs/etc/modprobe.d/vinos-brcmfmac.conf` — feature_disable tunables
  from the T2 wifi recipe.
- `airootfs/etc/modules-load.d/vinos-t2.conf` — apple-bce + hci_bcm4377.
- `bootloader-cmdline.append` — kernel command-line args for reliable T2
  boot (cfg80211, no watchdog, etc).

## References

- [project_t2_wifi_recipe](memory) — the verified 8-item recipe from
  2026-07-16, which we honor in the live env too.
- Omarchy's `install/hardware/apple/fix-t2.sh` — the installed-system
  equivalent. Read that before touching this file.
