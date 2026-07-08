# vinOS Hardware Verification Matrix

This is the running record of machines vinOS has been booted on
end-to-end (ISO → Hyprland → wifi via impala → Chromium loads).
Each row is a real box someone actually put a vinOS USB into —
"looks like it works" doesn't count.

## How to add a row

1. Boot the current vinOS ISO on the target (USB → BIOS/UEFI boot).
2. If graphics come up, `Super+Ctrl+W` → connect wifi with impala.
3. Confirm Chromium loads a page. Post `journalctl -b -p err` to
   `/tmp/vinos-boot.err` and inspect — non-zero output is a
   regression to file.
4. Add a row with hardware ID (`dmidecode -s system-product-name`),
   graphics stack, kernel used, one-line "what worked / didn't".
5. If a step fails, mark it and file an issue with the failure log.

## Verified machines

| Machine | CPU/GPU | Kernel | Boot? | Wifi? | Sleep? | Notes |
|---|---|---|---|---|---|---|
| Apple MacBook Pro 15" (2019, T2) | Coffee Lake i9 / Radeon Pro 560X + UHD 630 | linux-t2 | pending | pending | pending | Primary target machine. `06-hardware.sh` installs linux-t2 + apple-bcm-firmware; user must switch bootloader entry to linux-t2. |
| Dell XPS 13 9310 | Tiger Lake i7 / Iris Xe | linux | pending | pending | pending | 06-hardware.sh detects `Dell Inc.` + `XPS*` and installs the haptic touchpad driver. |
| Lenovo ThinkPad T14 Gen3 (AMD) | Ryzen 6850U / Radeon 680M | linux | pending | pending | pending | AMD branch of 06-hardware.sh: vulkan-radeon, libva-mesa-driver, mesa-vdpau. |
| Framework 13 (AMD 7040) | Ryzen 7 7840U / Radeon 780M | linux | pending | pending | pending | Same AMD branch. Firmware upgrades from Framework installer flow. |
| ASUS ROG Zephyrus G14 (NVIDIA hybrid) | Ryzen 9 / RTX 4070 Mobile | linux | pending | pending | pending | I9 hybrid path: nvidia-open-dkms + nvidia-prime + Hyprland NVIDIA snippet. asusctl via 06-hardware ASUS branch. |

## Known constraints

- **T2 Macs need `linux-t2`** for internal keyboard/trackpad/audio.
  The ISO ships stock `linux` — post-install `06-hardware.sh` pulls
  linux-t2 + linux-t2-headers from the vinos-aur repo when
  `dmi system-manufacturer` returns `Apple Inc.`. User must then
  update bootloader to boot `vmlinuz-linux-t2`.
- **Hybrid NVIDIA + Wayland** needs the env vars in
  `/etc/environment.d/50-vinos-nvidia.conf` plus the Hyprland snippet
  at `/etc/xdg/hypr/nvidia.conf` (both landed by 06-hardware.sh in I9).
- **Broadcom wifi (older Macs, some Chromebooks)** needs
  `broadcom-wl` or `broadcom-wl-dkms`. Not shipped by default; add
  manually or file an issue if your machine hits this.
- **Secure Boot**: out of scope (spec §11). Disable Secure Boot in
  firmware before booting the vinOS USB.
- **Nouveau conflict**: `06-hardware.sh` doesn't blacklist nouveau
  when nvidia-open-dkms is installed — mkinitcpio's regeneration and
  the modprobe.d modeset config together are enough on modern Arch.
  If a specific board disagrees, file an issue.

## Test protocol reference

See `iso/test.sh` for the automated QEMU smoke suite. That verifies
the ISO reaches `graphical.target` in UEFI + BIOS with 3G/4G RAM,
gets a VINOS_BOOT_OK marker on ttyS0, and stays under the 3.5 GB
size budget. Real-hardware verification is what this doc tracks —
QEMU can't confirm brightness keys, wifi chipsets, or T2 hand-off.
