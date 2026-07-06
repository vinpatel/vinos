# vinOS Live USB — flash & boot

vinOS ships as a bootable live ISO. Flash it to an 8 GB+ USB stick and
you have a portable Arch-based desktop with the vinOS layer on top.

## Minimum hardware
- **x86_64** CPU (Intel or AMD, ≤ 10-year-old chips are fine).
- **4 GB RAM** recommended, **3 GB floor** — the ISO boots to Hyprland
  with 3 GB in QEMU; leave headroom for browsers/editors.
- **8 GB USB 3.0 stick** (7 GB free after flashing the ~2 GB ISO).
- **UEFI or Legacy BIOS**. Both boot paths are tested.

## 1. Get the ISO
Either build it locally:
```bash
iso/build.sh
# Emits iso/out/vinos-<VERSION>-x86_64.iso + sha256sums.txt
```
Or download a release: `https://github.com/vinpatel/vinos/releases`.

Always verify:
```bash
sha256sum -c iso/out/sha256sums.txt
```

## 2. Flash the USB

### Linux (recommended: `iso/flash.sh`)
```bash
sudo iso/flash.sh
```
The script:
- Lists USB block devices.
- Asks you to type the device name AND the exact model string as a
  double confirmation — the primary guard against dd'ing onto your
  laptop's own drive.
- Refuses anything that isn't `tran=usb` unless you pass
  `--i-know-what-im-doing`.
- Runs `dd if=... of=... bs=4M oflag=direct conv=fsync` + `sync`.
- If you pass `--with-persistence`, adds an ext4 partition labelled
  `vinos-persist` covering the rest of the USB (see §4).

Direct dd (if you know what you're doing):
```bash
sudo dd if=iso/out/vinos-*.iso of=/dev/sdX bs=4M status=progress oflag=direct conv=fsync
sync
```
Replace `sdX` with your USB device. **`sdX`, not `sdX1`.** Wrong device
= data loss on your host disk.

### macOS
```bash
diskutil list                 # find /dev/diskN for the USB
diskutil unmountDisk /dev/diskN
sudo dd if=vinos-<ver>-x86_64.iso of=/dev/rdiskN bs=4m
```

### Windows
Use [Rufus](https://rufus.ie) in **DD Image mode** (not ISO mode).
[balenaEtcher](https://etcher.balena.io) also works.

## 3. Boot

Insert the USB, power on, and hit the boot-menu key. Common ones:

| Vendor          | Key                     |
|-----------------|-------------------------|
| Acer            | F12 (or F9)             |
| Dell            | F12                     |
| HP              | F9 (BIOS: Esc → F9)     |
| Lenovo ThinkPad | F12                     |
| MSI             | F11                     |
| Asus            | F8                      |
| Framework       | F12                     |
| Apple Intel     | Option (hold at chime)  |

Pick the USB entry, and choose one of:

- **Boot vinOS** — normal live boot to Hyprland (autologin as `vin`).
- **Boot vinOS (safe graphics, nomodeset)** — try if the first entry
  hangs on your GPU.
- **Boot vinOS (persistent)** — requires §4 setup.
- **Boot vinOS with speech** — screen-reader-friendly BIOS session.

## 4. Persistence (optional)

Without persistence, every reboot returns to a clean state. To keep
wifi passwords, downloads, and installed packages across reboots:

```bash
sudo iso/flash.sh --with-persistence
```

This adds an ext4 partition labelled `vinos-persist` after the ISO's
data. On boot, choose **Boot vinOS (persistent)** — archiso's COW
device mount will overlay `/` from that partition.

Manual creation (if the USB was flashed elsewhere):
```bash
sudo sgdisk --new=0:0:0 --typecode=0:8300 --change-name=0:vinos-persist /dev/sdX
sudo mkfs.ext4 -L vinos-persist /dev/sdX3   # or whatever partition N appeared
```

Persistence stores **all** changes — including secrets and package
installs. Encrypt the persist partition (LUKS) if the USB might leave
your custody.

## 5. Install to disk

Once booted live, run `vinos-install-disk` from a terminal. It's a
thin wrapper around `archinstall` with a vinOS preset that does the
disk / bootloader / user provisioning, then chroots and runs the
vinOS `install.sh` from the bundled repo — fully offline via the
ISO's package cache.

The disk installer **never** copies the live autologin config: the
installed system uses greetd with a normal password prompt.

## 6. Troubleshooting

- **Black screen after "Booting vinOS"** — try the `safe graphics`
  entry; if that also fails, your GPU probably needs proprietary
  firmware. File an issue with your GPU model.
- **Wifi doesn't work** — check `broadcom-wl` was picked up; some
  cards need proprietary firmware installed post-boot.
- **`dd` finished but PC won't boot from USB** — the BIOS may be
  UEFI-only; boot the "UEFI" USB entry, not the "Legacy" one.
- **flash.sh refuses my USB** — pass `--i-know-what-im-doing` if
  you're sure. The refusal usually means the USB shows as `sata`
  through a docking station.
