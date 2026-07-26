---
title: "Download and flash"
description: "Grab the latest ISO, verify sha256, and write it to a USB drive with dd."
weight: 10
---

## 1. Download

Latest builds land on GitHub Releases and are mirrored to Archive.org.
The Archive.org mirror is what the homepage links to because it's
free forever and torrentable.

- **GitHub Releases (current)** — [github.com/vinpatel/vinos/releases/latest](https://github.com/vinpatel/vinos/releases/latest)
- **Archive.org (v1.1.0 archival only)** — [archive.org/details/vinos-1.1.0-x86_64](https://archive.org/details/vinos-1.1.0-x86_64) · permanent gold-copy mirror of the v1 line

Files you want:

```
vinos-2.0.5-x86_64.iso            ~4.4 GB
vinos-2.0.5-x86_64.iso.sha256     73 B
vinos-2.0.5-x86_64.iso.sig        (optional, GPG-signed sha256)
```

## 2. Verify

Never flash an unverified ISO. From the directory holding both files:

```
$ sha256sum -c vinos-2.0.5-x86_64.iso.sha256
vinos-2.0.5-x86_64.iso: OK
```

If you have the maintainer's key (`gpg --recv-keys 0xVINPATEL`),
verify the signature on the checksum file too:

```
$ gpg --verify vinos-2.0.5-x86_64.iso.sig vinos-2.0.5-x86_64.iso.sha256
gpg: Good signature from "Vin Patel <vin@mindtrades.com>"
```

{{% callout kind="warning" %}}
**One archival build is exempt from every rule.** `vinos-1.1.0-x86_64.iso`
is a permanent gold copy — never overwritten, never rebuilt. Newer
releases live under versioned filenames alongside it. If you're
downloading `1.1.0`, expect the older signing key.
{{% /callout %}}

## 3. Flash to USB

You need an **8 GB or larger USB stick**. Its contents will be destroyed.
Confirm the target device path before flashing — writing to the wrong
disk will wipe your system.

Find the device:

```
$ lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS
sda      500G  disk
├─sda1   512M  part /boot
└─sda2 499.5G  part /
sdb     14.6G  disk                    ← your USB stick
```

Flash it (this is Linux; macOS uses `diskutil` first to unmount, then
`sudo dd of=/dev/rdiskN`):

```
$ sudo dd if=vinos-2.0.5-x86_64.iso of=/dev/sdb bs=4M status=progress oflag=sync
4508876800 bytes (4.5 GB, 4.2 GiB) copied, 148 s, 30.5 MB/s
1075+1 records in
1075+1 records out
```

{{% callout kind="tip" %}}
If `dd` feels risky, `gnome-disks` and [BalenaEtcher](https://etcher.balena.io/)
both work. They handle the unmount/flush dance for you.
{{% /callout %}}

Eject cleanly:

```
$ sync && sudo eject /dev/sdb
```

Once you boot from the stick, the first thing you'll see is the
syslinux menu — pick "vinOS live" (highlighted by default) and press
Return.

<figure class="doc-shot doc-shot-pending" id="shot-04">
  <div class="doc-shot-slot">Screenshot pending: syslinux boot menu with "vinOS live" highlighted</div>
  <figcaption>Boot menu — see SCREENSHOTS_NEEDED.md #shot-04.</figcaption>
</figure>

You're ready for [first boot](/docs/getting-started/first-boot/).
