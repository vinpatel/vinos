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

### Open items carried into later milestones
- **I2:** flesh out `install/02-desktop.sh` (Hyprland stack + greetd
  autologin) and populate `config/hypr/…`, `config/waybar/…`,
  `config/alacritty/…`. Extend `iso/build.sh` to assemble airootfs from
  base + overlays (invoke 03/05 with `VINOS_ROOT` set — the one
  permitted change to `lib/common.sh`). Boot marker moves to
  `graphical.target`.
- **I3:** local `[vinos-aur]` repo, size + RAM budgets, offline boot with
  QEMU `-nic none`.
- **I4:** `iso/flash.sh` + persistence + `docs/USB.md`. Real-hardware
  Acer boot is user-side (I cannot flash from here).
- **I5:** self-hosted CI on Dell + tag → release ISO.
- **Deferred:** `--resume NN` alias for `--skip NN`; only add if a real
  user hits the resume ergonomics gap.
