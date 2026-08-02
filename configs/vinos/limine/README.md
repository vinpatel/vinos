# vinOS Limine overrides

These two files override Omarchy's Limine setup during install:

- `limine.conf` → `/boot/limine.conf` — the actual boot menu display config (branding, colors, timeout, default entry).
- `default.conf` → `/etc/default/limine` — controls how `limine-mkinitcpio-hook` writes kernel entries.

## Install-time contract

`vinos-install-disk` layers these on top of Omarchy's install:

1. Omarchy install runs first, laying down its Limine setup.
2. `install/first-run/limine-brand.sh` copies these two files over the top.
3. `limine-update` regenerates entries from installed kernels (`linux-cachyos`, `linux-hardened`, `linux-t2` if present) — each becomes its own visible menu entry.
4. Snapper snapshots continue to appear at the bottom (BOOT_ORDER preserves them).

## Hardware auto-detect for `default_entry`

`vinos-install-disk` reads `/proc/device-tree` or `dmidecode -s system-product-name` at install time:

- **Apple T2 Mac** (MacBookPro15,x / MacBookPro16,x / iMacPro1,x / Macmini8,x) → linux-t2 as default
- **Anything else** → linux (Arch stock) as default

**2.1.1 roadmap:** swap generic default to `linux-cachyos` (BORE scheduler, ~10-15% perf) once supply-chain research on the cachyos signing key is complete.

The install script edits the `default_entry:` line in the shipped `limine.conf` accordingly.

## What the user sees at boot

```
┌────────────────────────────────────────┐
│         vinOS Bootloader               │
├────────────────────────────────────────┤
│  → Arch Linux (linux-cachyos)          │  ← default on generic hardware
│    Arch Linux (linux-cachyos-fallback) │
│    Arch Linux (linux-hardened)         │
│    Arch Linux (linux-hardened-fallback)│
│  → Arch Linux (linux-t2)               │  ← default on T2 Macs
│    Arch Linux (linux-t2-fallback)      │
│  ▼ Snapshots (roll back if broken)     │
└────────────────────────────────────────┘
      timeout 2s · vinOS #33ccff accent
```

## Refreshing from upstream

If Omarchy updates their Limine defaults meaningfully, we can:

1. Pull Omarchy: `git subtree pull --prefix=omarchy https://github.com/basecamp/omarchy master --squash`
2. Diff `omarchy/default/limine/*.conf` against ours: `diff omarchy/default/limine/limine.conf configs/vinos/limine/limine.conf`
3. Cherry-pick any Omarchy improvements that don't conflict with our branding.
