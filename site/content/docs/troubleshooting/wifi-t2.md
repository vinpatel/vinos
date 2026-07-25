---
title: "Wi-Fi on T2 MacBooks"
description: "The 8-item recipe for Broadcom BCM4364/4377 Wi-Fi on Intel-Mac T2 laptops. Verified since the 2026-07-15 baseline ISO."
weight: 10
---

Intel T2 MacBooks (2018/2019/2020 MBP + MBA) ship with a Broadcom
BCM4364 or BCM4377 chip that needs coaxing to associate reliably on
Linux. The vinOS ISO includes every fix below by default — this page
is here for people who are:

- Booting an older ISO that didn't have the full recipe.
- Installing to disk and losing state during the migration.
- Diagnosing a partial regression.

If wifi *just works* on your first boot, skip this page.

## The 8-item recipe

Every fix is baked into the shipped ISO. Together they get the
BCM4364/4377 to associate on the first boot ~99% of the time.

### 1. `wireless-regdb` installed

```
$ pacman -Qi wireless-regdb | head -1
Name : wireless-regdb
```

If missing: `sudo pacman -S wireless-regdb`.

### 2. iwd `Country` set

```
$ cat /etc/iwd/main.conf
[General]
EnableNetworkConfiguration=true
Country=US
```

Match `US` to your ISO country code (`GB`, `DE`, `JP`, etc.).

### 3. systemd-networkd running with DHCP

```
$ cat /etc/systemd/network/25-wireless.network
[Match]
Name=wl*

[Network]
DHCP=yes
IgnoreCarrierLoss=3s
```

And enable: `sudo systemctl enable --now systemd-networkd`.

### 4. brcmfmac `feature_disable` set

```
$ cat /etc/modprobe.d/brcmfmac.conf
options brcmfmac feature_disable=0x82000
```

This disables the Broadcom features that break on non-macOS drivers.

### 5. T2 initramfs modules included

```
$ cat /etc/mkinitcpio.conf | grep MODULES
MODULES=(applespi apple_ibridge apple_ib_tb apple_ib_als brcmfmac brcmutil)
```

Regenerate the initramfs if you changed anything:
`sudo mkinitcpio -P`.

### 6. `cfg80211` on the kernel command line

Check your bootloader config; the line should include:

```
cfg80211.ieee80211_regdom=US
```

Match the same country code as step 2.

### 7. Model-specific firmware symlinks

Different T2 model variants (MacBookPro15,1 vs 16,1 vs 16,4 etc.)
expect slightly different firmware filenames. The `apple-bcm-firmware`
package ships all of them; we symlink the right one at first boot.

```
$ ls -l /lib/firmware/brcm/brcmfmac4364b3-pcie.bin
lrwxrwxrwx 1 root root 46 Jul 15 20:27
  /lib/firmware/brcm/brcmfmac4364b3-pcie.bin ->
  /lib/firmware/brcm/apple/brcmfmac4364b3-pcie.txt
```

If the symlink is missing, `sudo vinos-first-run` will recreate it
based on your detected model.

### 8. `iwd` active

```
$ systemctl is-active iwd
active
```

If not: `sudo systemctl enable --now iwd`.

## Verify the whole stack

The `vinos-doctor` wifi section walks every item above:

```
$ vinos-doctor
...
wifi (T2 Mac + generic)
  PASS wireless-regdb installed
  PASS iwd Country=US
  PASS systemd-networkd active
  PASS brcmfmac feature_disable=0x82000
  PASS T2 initramfs modules present
  PASS cfg80211 regdom on cmdline
  PASS BCM4364 firmware symlink resolved
  PASS iwd active
...
```

## The red text on boot is normal

You'll see `brcmfmac: could not find firmware...` red text scrolling
past during boot. **This is not an error.** The Broadcom driver
probes for several firmware filenames in sequence; the first few
misses are noisy, then it finds the right one and associates. Watch
for `brcmfmac: brcmf_c_process_txcap_blob` (the success message)
somewhere below the red text.

If you never see the success line, then it's real — grab
`journalctl -k | grep brcmfmac` and file an issue.

## Still nothing?

- Reboot once cleanly (not a resume from suspend) — first-boot
  firmware detection sometimes needs a clean power cycle.
- Try `sudo iwctl station wlan0 scan; sleep 3; sudo iwctl station wlan0 get-networks`.
  If you see SSIDs, the hardware is fine and it's an association issue.
- File an issue with `vinos-doctor` + `journalctl -k -b` attached.
