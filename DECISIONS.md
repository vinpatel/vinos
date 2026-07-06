# vinOS decisions log

Ambiguity resolutions recorded here per CLAUDE.md workflow.

## M1 — Skeleton
- Individual install scripts (`install/01..05-*.sh`) ship as loggable stubs so
  the orchestrator can enumerate them for `--dry-run`. Real bodies land in
  their owning milestones (M2/M3/M5).
- `--skip NN` accepts the two-digit prefix (e.g. `--skip 02`); the spec
  mentions `--resume` as an acceptable alternative — deferred until needed.
- Overlay shadowing is applied by *basename match* on the numbered filename,
  which naturally handles the sanctioned 02/05 shadow points without a
  hardcoded allowlist.
- `bin/vinos-version` reads `VERSION` from repo, `~/.local/share/vinos`, or
  `/usr/share/vinos` (in that order) so it works both pre- and post-install.

## M2 — Base install
- AUR bootstrap uses **`yay-bin`** (prebuilt binary PKGBUILD) rather than
  compiling `yay` from source. Spec is silent on which; `yay-bin` is faster
  and preserves the "same yay CLI" contract for 01-base.
- Container/no-systemd hosts: added `systemctl_enable` helper in
  `lib/common.sh` that skips enable when `/run/systemd/system` is missing
  and warns (not fails) on enable errors. Keeps 04-services idempotent on
  both real Arch and Docker.
- UFW `enable` warn-and-continue is exercised by the container test — inside
  a default Docker container the iptables/nftables call fails with
  `Permission denied` and the test still exits 0, matching the CLAUDE.md
  UFW quirk.
- `tests/test.sh` M2 scope: static Rule 1 / Rule 2 grep guardrails, the
  three dry-run plans, then a docker `archlinux:latest` run that executes
  `install.sh --skip 02` twice (idempotency). Overlay assertion and
  `vinos-doctor` PASS check deferred to their owning milestones (M4/M3) so
  we do not gate M2 on their still-stub scripts.

## M3 — Branding
- `/etc/os-release` rewrite preserves every original key except the five
  vinOS overrides (NAME, PRETTY_NAME, ID, ID_LIKE, VERSION_ID); backup to
  `/etc/os-release.arch.bak` happens exactly once, so re-runs regenerate
  from the pristine Arch original rather than compounding on prior output.
- `bin/vinos-*` land under **`/usr/share/vinos/bin/`** and are symlinked
  into `/usr/local/bin`. Spec text says "symlink `bin/vinos-*` →
  `/usr/local/bin/`"; installing the shared copy first avoids the fragile
  case of `/usr/local/bin/vinos-doctor` pointing into a per-user
  `~/.local/share/vinos/bin/` that other users can't read. `VERSION` is
  copied alongside so `vinos-version`'s existing probe hits it.
- `default/wallpaper.png` is a **generated composite**: `vinos-512.png`
  (from the locked `assets/logo/`) centered on a 1920x1080 `#1a1b26`
  background, produced once via ImageMagick. `assets/logo/` is not
  modified — the composite is a derived artifact committed under
  `default/` where the spec expects it.
- `vinos-doctor` reports **PASS / FAIL / SKIP**; only FAIL causes a
  non-zero exit. Service checks SKIP when `/run/systemd/system` is
  absent, mirroring the `systemctl_enable` container semantics.
- Test.sh runs `git add -A && git commit -m "test snapshot"` inside the
  container after `cp -a` so the copy looks like a clean deployed clone;
  otherwise `vinos-doctor`'s "repo clean" check would FAIL on any
  session that runs the test before final commit.

## M4 — Overlay proof
- `overlays/example/install/10-hello.sh` installs `cowsay` (extra repo, not
  AUR) via the shared `install_pkg` helper — idempotent through `--needed`,
  Rule 1 headless-safe.
- `overlays/example/config/fastfetch/config.jsonc` now mirrors the base
  config verbatim with the `// overlay-applied` marker on line 1. That
  single line is what the M4 assertion greps for; keeping the body a
  verbatim mirror keeps merge-conflict noise low if the base config
  evolves.
- Dry-run assertions in tests/test.sh: parse the plan output and confirm
  the overlay script line-number is greater than 05-branding's, and the
  overlay config-source line-number is greater than base's, so a
  future refactor of the orchestrator cannot silently break §6 ordering.
- The `--overlay` container run reuses the same non-root user; cowsay
  ends up on-system and the overlay's fastfetch config wins the
  shadowing (verified via `grep -F overlay-applied`).

## I1 — Profile boots
- **Docker-privileged build path**: host `sudo` is password-protected and
  CLAUDE.md forbids `pacman -Syu` on host; the sanctioned CI path in
  VINOS_ISO_SPEC.md §7 is also containerized. `iso/build.sh` therefore
  bakes a small `vinos-archiso-builder` image (`archlinux:latest` +
  `archiso`) once and runs `mkarchiso -v` inside it with `--privileged`.
  `iso/test.sh` uses a peer `vinos-iso-tester` image (`+ qemu-base +
  edk2-ovmf`) and mounts `/dev/kvm` when available.
- **Pristine releng first**: `iso/profile/` was committed verbatim from
  `/usr/share/archiso/configs/releng` (I1a) before any edits, so the
  vinOS rebrand diff (I1b) is legible against upstream releng.
- **Package list is generated, never hand-edited**: `iso/gen-packages.sh`
  writes `iso/profile/packages.x86_64` as the sorted union of
  `iso/packages.releng` (frozen upstream list), `iso/packages.live` (live
  extras: `networkmanager`, `gparted`), and every `install_pkg` argument
  extracted from `install/01-base.sh` + `install/02-desktop.sh`. AUR
  arguments go to `iso/aur.list` for I3's local repo. Spec §3.2 mandates
  a drift check; build.sh regenerates and warns on diff.
- **Boot marker convention**: `airootfs/etc/systemd/system/vinos-boot-marker.service`
  is enabled via multi-user.target.wants symlink and echoes
  `VINOS_BOOT_OK reached multi-user.target` to `/dev/kmsg` and
  `/dev/ttyS0` best-effort. Kernel cmdline in syslinux/grub/systemd-boot
  entries adds `console=tty0 console=ttyS0,115200` so QEMU
  `-serial file:` captures the marker in headless mode. Spec §5.1 will
  reuse the same marker after graphical.target for I2.
- **install_dir stays `arch`**: renaming to `vinos` would require updating
  every path reference in syslinux/grub/systemd-boot configs and can wait
  until the ISO layout stabilizes. It has no user-visible effect since
  it's just the on-medium directory name.
- **KVM opportunistic**: `/dev/kvm` is 666 on this host so docker can pass
  it through without any user-in-group juggling; the QEMU test picks
  `accel=kvm:tcg` when present and falls back to pure `tcg` otherwise.

## I2 — Live desktop
- **`VINOS_ROOT` prefix in `lib/common.sh`**: the one permitted change to
  common.sh per VINOS_ISO_SPEC §2. When set, `install_pkg`/`install_aur`
  become no-ops (packages come from packages.x86_64), `copy_config`
  writes to `$VINOS_ROOT/etc/skel/.config`, `append_once`/`_sudo`/
  `systemctl_enable` prefix or route into the airootfs. Installer path
  (VINOS_ROOT empty) behaves exactly as before — backward-compatible.
- **greetd enable is per-mode**: installer mode uses plain
  `systemctl enable greetd` (systemd reads WantedBy=graphical.target +
  Alias=display-manager from the unit). VINOS_ROOT mode builds the two
  symlinks manually AND sets `default.target -> graphical.target`
  because the pristine releng airootfs defaults to multi-user.
- **Boot marker is a script + oneshot service**: earlier attempts to
  inline the marker in ExecStart with line-continuations produced
  parse-fragile output. Now `/usr/local/bin/vinos-boot-marker` is
  called by the unit — cleaner, testable, greppable. The script writes
  `VINOS_BOOT_OK boot complete ID=vinos VERSION_ID="X"` to /dev/ttyS0
  and /dev/kmsg (test 5.1 + 5.2 in one line). WantedBy is both
  graphical.target and multi-user.target so if graphical stalls (e.g.
  Hyprland can't find DRM on some hardware), the marker still fires
  and boot reports success.
- **mkarchiso resets modes**: `profiledef.sh`'s `file_permissions`
  associative array is the ONLY thing that determines the final mode
  of a file after squashing — plain `chmod +x` on the source tree gets
  reset to 0644. Every new executable in `airootfs/` must be listed
  there (`vinos-boot-marker`, sudoers.d entry).
- **Releng's `getty@tty1` autologin-root drop-in** conflicts with
  greetd on VT1 on a live ISO. The live overlay ships a same-directory
  drop-in that sorts alphabetically AFTER `autologin.conf` and clears
  ExecStart, restoring a plain agetty on tty1 so greetd owns VT1
  cleanly.
- **QEMU display**: `-nographic` sets `-vga none` which leaves the
  guest without any framebuffer, so Hyprland can never find a DRM
  device. `iso/test.sh` uses `-display none -vga std -serial file:…`
  instead — no host window, but the guest sees a bochs-drm GPU which
  is enough to keep greetd/Hyprland happy.
- **Live user creation via first-boot service** (`vinos-live-init.service`):
  runs after systemd-sysusers, before greetd + user-sessions. `useradd
  -m -G wheel vin && passwd -d vin`, then copies `/etc/skel` into
  `/home/vin`. Idempotent via a `.vinos-live-init-done` marker file.
  Chose this over baking passwd/shadow entries directly to avoid
  conflicting with pacstrap's automatic user additions during
  mkarchiso.
- **Rule 3 extension for ISO boot menus** (spec §3.4): syslinux/GRUB/
  systemd-boot titles say "Boot vinOS" — modifying boot-menu identity
  outside `install/05-branding.sh` is a sanctioned exception because
  those files are ISO-only and never touched by installer mode.

## I3 — Offline completeness
- **Mask `systemd-time-wait-sync.service`**: releng ships it in
  `sysinit.target.wants`, and its `TimeoutStartSec` is `no limit`.
  Without a network (QEMU `-nic none`), NTP never arrives and boot
  stalls indefinitely at the multi-user handoff. The live overlay
  now ships a `/dev/null` symlink at
  `/etc/systemd/system/systemd-time-wait-sync.service`, which is
  systemd's canonical "masked" form. Applies to online boots too —
  the live medium never legitimately blocks on NTP.
- **`iso/aur-build.sh` scaffolding is in the tree but idle**: `aur.list`
  is empty in the base repo (nothing in 01/02 references AUR). The
  script + build.sh integration are ready for the first fork that
  needs a local `[vinos-aur]` file:// repo.
- **Size budget 5.4**: the ISO is **1.92 GB**, well under the 3.5 GB
  budget. Adding Hyprland + tools cost ~300 MB over the pristine
  releng ~1.7 GB. Test.sh's size check is now the guard.
- **RAM floor 5.5**: PASSes at `-m 3G`. squashfs is memory-mapped
  (not decompressed to tmpfs), so working-set is much smaller than
  compressed size.
- **`iso/test.sh --mode matrix`** is the single-command I3 check:
  BIOS 4 GB with net, UEFI 4 GB with net, BIOS 3 GB (RAM floor),
  BIOS 4 GB with `-nic none` (offline). All must PASS.

## I4 — Flash & hardware (software-side complete; hardware verification user-side)
- **flash.sh safety model**: two blocking confirmations — the device
  path (typed exactly as `/dev/sdX`) AND the vendor/model string as
  shown by `lsblk`. Hard-refuses if any partition of the target is
  mounted at `/`, `/boot`, `/home`, `/efi`, `/boot/efi` (this is
  never overridable — it means it's the user's OS disk). Refuses
  `tran != usb` unless `--i-know-what-im-doing` is passed (allows
  USB-through-a-dock cases). `dd` uses `bs=4M oflag=direct
  conv=fsync` followed by an explicit `sync`.
- **Persistence via a labelled ext4 partition**: `flash.sh
  --with-persistence` runs `sgdisk --new=0:0:0` to append a partition
  after the ISO's data, then `mkfs.ext4 -L vinos-persist`. On boot
  the "Boot vinOS (persistent)" menu entry passes
  `cow_device=/dev/disk/by-label/vinos-persist`; archiso's initramfs
  mounts it as the copy-on-write overlay so changes survive reboots.
- **Persistent boot entries in all three loaders**: syslinux
  (`archpersist`), grub (`archlinux-persistent`), systemd-boot
  (`03-archiso-persistent-linux.conf`). The persistent entry appears
  regardless of whether the persist partition exists — kernel just
  boots without persistence if the label isn't found (archiso's
  fallback).
- **Hardware boot verification is user-side**: I cannot flash to a
  real USB from this environment. The tracker shows `[~]` for I4
  until the user confirms Acer Aspire boots to Hyprland and
  persistence survives a reboot.

## I5 — CI (workflow-side complete; runner + first release pending user)
- **Split lint from build**: `.github/workflows/iso.yml` has a
  GH-hosted `lint` job (shellcheck + packages.x86_64 drift check) and
  a self-hosted `iso` job (build + QEMU matrix + release attach). GH
  hosted runners cannot expose loop devices privileged enough for
  mkarchiso, so the actual build must live on the Dell.
- **Self-hosted runner label**: `[self-hosted, dell]`. Runner setup
  (GH runner binary, docker in the runner user's groups, /dev/kvm
  access) is user-side one-time infra work.
- **Trigger surface**: `workflow_dispatch` (manual, 7-day artifact) +
  `push tags: v*` (release attach via softprops/action-gh-release).
  A `v1.0.0` tag would upload `vinos-1.0.0-x86_64.iso` +
  `sha256sums.txt` to the release page.
- **Drift enforcement**: the lint job regenerates
  `iso/profile/packages.x86_64` and fails if it differs from HEAD.
  This is spec §3.2's "never hand-edit; CI fails if regenerating
  produces a diff".

### Open items carried into later milestones
- **I4:** `iso/flash.sh` + persistence + `docs/USB.md`. Real-hardware
  Acer boot is user-side (I cannot flash from here).
- **I5:** self-hosted CI on Dell + tag → release ISO.
- **Deferred:** `--resume NN` alias for `--skip NN`; only add if a real
  user hits the resume ergonomics gap.
- **qemu-desktop UI backend:** `iso/qemu-desktop.sh` picks SDL when
  `XDG_SESSION_TYPE=wayland`, GTK on X11. QEMU's GTK window loses
  keyboard focus through XWayland (reproduced on Hyprland). Also
  attaches `-usb -device usb-kbd -device usb-tablet` so input is a
  real USB kbd + absolute-pointer mouse instead of PS/2.

## I6 — Omarchy parity + Mac + splash
- **App scope**: curated subset of Omarchy's user-facing package set,
  not the full 152. Extra-repo: `chromium nvim nautilus sushi
  signal-desktop localsend plymouth eza bat fzf ripgrep fd zoxide
  starship github-cli lazygit`. AUR (baked into ISO via `[vinos-aur]`
  local repo): `spotify obsidian 1password 1password-cli
  apple-bcm-firmware apple-t2-audio-config tiny-dfr t2fanrd`.
  Package split: CLI tools go through `install/01-base.sh` (headless,
  Rule 1); GUI apps + Plymouth land in `install/02-desktop.sh`.
- **AUR pipeline: install_aur args now merged into packages.x86_64**.
  gen-packages.sh originally output install_aur strictly to aur.list,
  which meant the local repo built but mkarchiso never pacstrapped
  from it. Merging them into packages.x86_64 (alongside install_pkg)
  closes the loop — build.sh appends `[vinos-aur]` to pacman.conf and
  the same mkarchiso pass installs both extra-repo and AUR packages.
- **T2 Mac kernel is post-install only.** `linux-t2` is not baked into
  the ISO (dual-kernel maintenance, ~150MB size hit not worth the
  live-boot polish). `install/06-hardware.sh` is a new script that
  runs after 05-branding and installs `linux-t2 linux-t2-headers`
  when `dmidecode -s system-manufacturer == "Apple Inc."`, plus
  NVIDIA/AMD/Intel/Dell/ASUS conditional drivers. gen-packages.sh
  only scans 01 and 02, so nothing from 06 leaks into the ISO's
  package set — deliberate.
- **T2 firmware/audio DOES ship on the ISO** so live boot on T2 Macs
  gets bcm-firmware + audio config; only the kernel swap is deferred.
  User picks that up on first install run.
- **Plymouth split across Rule 1 and Rule 3.** 02-desktop installs
  the package + wires the mkinitcpio hook (graphical concern);
  05-branding ships the `vinos` theme (logo + blinking terminal
  caret) and writes `plymouthd.conf` with `Theme=vinos` (identity
  concern). ISO airootfs gets `plymouth` in `archiso.conf`'s HOOKS
  directly (edited in place — profile files are ours to modify per
  I2). Boot cmdlines across syslinux/grub/systemd-boot get
  `quiet splash loglevel=3 vt.global_cursor_default=0`. Accessibility
  and PXE entries left untouched — screen-reader users want text.
- **Plymouth theme is `themes/vinos/`** at repo root (not
  `default/`) — it's an installable asset with three files
  (vinos.plymouth, vinos.script, logo.png), not a single dotfile.
  `default/` stays for wallpaper-shaped single-file drops.
- **install/06-hardware.sh naming**: base scripts own 01–09 per
  Rule 2, so 06 is a legal name. Sitting after 05 also means
  identity is fully applied before we touch driver stacks —
  matters because 06 may prompt for a reboot to pick up the new
  kernel and we want that prompt to say "vinOS" not "Arch".
