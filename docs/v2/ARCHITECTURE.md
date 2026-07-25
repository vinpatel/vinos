# vinOS 2.0 architecture

_Developer-facing. For end-user product description, see the vinos.computer site._

vinOS 2.0 is a Linux distribution assembled from four discrete layers:

```
Custom archiso ISO           (single-boot install, T2-tuned)
  └─ vinOS layer             (T2 live-env + security + Mac muscle-memory + brand)
      └─ Omarchy configs     (vendored 1:1 from upstream, applied by their installer)
          └─ Arch Linux base
```

The 1.1.0 line was self-built. The 2.0 line rebases on Omarchy 4.x for the
desktop layer while keeping vinOS's original work — T2 support, hardening,
Mac migration ergonomics, brand — as thin overlays on top.

## Layers

### 1. Arch Linux base

`iso/v2/profile/` is an archiso profile derived from the 1.1.0 T2-verified
profile. Same base tooling, same T2-boot proofs. Its `pacman.conf` includes
the `[arch-mact2]` third-party repo where `linux-t2` and Apple firmware
packages live.

Packages: `iso/v2/profile/packages.x86_64` — the union of the archiso
releng set and vinOS's live additions. **No AUR** — the v2 build script
does not build a local `[vinos-aur]` repo. Post-install applications are
Omarchy's responsibility.

### 2. Omarchy configs

Vendored verbatim at `configs/omarchy/`. Never edited inline. Updates
mechanical via `git subtree pull` (or the manual `rsync` procedure in
`configs/omarchy/UPSTREAM.md`).

At ISO build time the whole tree is copied into the live env at
`/root/omarchy/`. The vinOS installer wrapper (`vinos-install`) invokes
Omarchy's own installer from there.

### 3. vinOS layer

Four scoped sub-overlays at `configs/vinos/`:

- **`t2/`** — Only for the *live ISO environment*. The installed system's
  T2 setup is Omarchy's `install/hardware/apple/fix-t2.sh`, which installs
  `linux-t2`, `apple-bcm-firmware`, `t2fanrd`, `tiny-dfr` and configures
  initramfs modules. We don't duplicate; we make sure Wi-Fi and keyboard
  work while someone is *installing*.
- **`security/`** — Frame.work-critique response: ufw enabled, sshd not
  exposed and hardened via drop-in, faillock restored to Arch defaults,
  linux-hardened shipped as optional boot kernel.
- **`mac/`** — kanata-driven Cmd→Ctrl remap, natural scroll, Cmd+Shift+4
  screenshot, Cmd+Space launcher. Applied post-install via a Hyprland
  fragment sourced from Omarchy's `hyprland.conf`.
- **`brand/`** — vinOS palette (extends existing teal + cool-charcoal),
  original SVG wallpaper, open-source fonts only (SIL OFL / Apache).
  No third-party aesthetic borrowing.

Each of `security/`, `mac/`, `brand/` has an `install.sh` invoked by
`vinos-install` inside the target chroot.

### 4. Custom archiso ISO

`iso/v2/build.sh` orchestrates a `docker run --privileged` mkarchiso build.
Steps:

1. Stage a fresh copy of `iso/v2/profile/`
2. Layer `configs/omarchy/` into `airootfs/root/omarchy/`
3. Layer `configs/vinos/{security,mac,brand}/` into `airootfs/usr/share/vinos/`
4. Merge `configs/vinos/t2/airootfs/` on top of the profile's airootfs
5. Install the `vinos-install` wrapper at `/usr/local/bin/`
6. Write `/etc/vinos-release` with build metadata
7. `mkarchiso -v -w $WORK -o $OUT $STAGED_PROFILE`
8. Update `iso/out/sha256sums.txt`, preserving the v1.1.0 entry

Output: `iso/out/vinos-<version>-x86_64.iso`. **`vinos-1.1.0-x86_64.iso`
is never touched** — it is the archival gold copy per the 1.1.0
preservation rule.

## Live boot flow

1. User boots the ISO on an Apple T2 Mac.
2. archiso auto-logs in as root, sources `/root/.zlogin`.
3. Kernel is `linux-t2`; `brcmfmac`, `apple-bce`, `hid_apple` load per the
   T2 recipe (`configs/vinos/t2/airootfs/etc/modprobe.d/vinos-brcmfmac.conf`
   plus initramfs modules).
4. User runs `vinos-install`.
5. The wrapper invokes Omarchy's installer, which handles disk selection,
   partitioning (BTRFS + Snapper defaults), and the installed-system base
   including its own `fix-t2.sh` pass.
6. After Omarchy finishes, `vinos-install` rsyncs `/usr/share/vinos/`
   into the target and invokes `security/install.sh`, `mac/install.sh`,
   `brand/install.sh` inside the target chroot.
7. Target is stamped with `/etc/vinos-release`. Reboot.

## Version rules

- **v1.1.0** — permanent archival gold copy. Never overwrite/rebuild/delete.
- **v2.0.0** — the four-layer stack above, minimum shippable.
- **v2.x.x** — feature releases on top of v2.0. Semver.
- Never a "v1.2" — v1 line is closed.

## Files of interest

| Path | Purpose |
|---|---|
| `iso/v2/build.sh` | Build orchestrator |
| `iso/v2/vinos-install` | Live-env installer wrapper |
| `iso/v2/profile/profiledef.sh` | archiso profile identity |
| `iso/v2/profile/packages.x86_64` | Live package set (union of releng+live) |
| `iso/v2/qa/oneshot.sh` | Pre-flash verifier |
| `configs/omarchy/` | Vendored Omarchy upstream (do not edit inline) |
| `configs/vinos/{t2,security,mac,brand}/` | The four scoped overlays |
| `iso/out/vinos-1.1.0-x86_64.iso` | Archival gold copy — never touched |
| `iso/out/vinos-2.0.0-x86_64.iso` | Current v2 build output |
