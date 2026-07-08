# CLAUDE.md — vinOS project instructions

## What this project is
vinOS: an opinionated Arch Linux layer by Vin Patel — stock Arch + curated packages + configs + idempotent install scripts. Two specs govern everything:
- `VINOS_SPEC.md` — base system, Milestones M1–M4
- `VINOS_ISO_SPEC.md` — live ISO/USB, Milestones I1–I5

Read the relevant spec before writing any code. The specs win over your own preferences.

## The Three Rules (never violate — tests enforce them)
1. Only `install/02-desktop.sh` may touch anything graphical. All other scripts must work headless.
2. Forks overlay, never edit: base owns 01–09, forks own 10–99, forks shadow files. Every script idempotent (safe to re-run).
3. Only `install/05-branding.sh` touches identity (os-release, wallpaper, logos, vinos-* bins).

## Workflow discipline
- Work on ONE milestone per session. Stop when its DONE WHEN criterion passes. Do not start the next milestone.
- Before claiming a milestone done, actually run its test (tests/test.sh in Docker for M-milestones; iso/test.sh QEMU for I-milestones) and show the output.
- Commit format: `M1: <what>` / `I2: <what>`. Commit at logical checkpoints, not one giant commit.
- Bash only in the install path. shellcheck-clean. Scripts under ~80 lines; shared logic in lib/common.sh.
- Never run destructive commands (dd, mkfs, partitioning, pacman -Syu) on this host. All install testing happens in `docker run --rm archlinux:latest` containers. ISO builds use a dedicated workdir under /tmp.
- Never hand-edit generated files (iso/profile/packages.x86_64) — fix the generator.
- If something in the spec is ambiguous, pick the simplest option that preserves the Three Rules and note the decision in a `DECISIONS.md` line. Don't stop to ask.

## Environment
- This machine runs Arch. Docker available. archiso will be installed for I-milestones.
- Known quirk: UFW's nftables backend can fail to sync on this setup — install scripts must warn-and-continue on ufw errors, never hard-fail.
- Logo assets are pre-made in assets/logo/ — never regenerate or modify them.

## Status tracker (update after each session)
- [x] M1 skeleton   - [x] M2 base install   - [x] M3 branding   - [x] M4 overlay proof
- [x] I1 profile boots   - [x] I2 live desktop   - [x] I3 offline complete   - [~] I4 flash+persistence (Acer hardware boot pending user verification)   - [~] I5 CI workflow (self-hosted runner setup + first tag push pending user)
- [~] I6 curated app parity — chromium/nvim/nautilus/comms + CLI tools + AUR pipeline live, Plymouth splash wired, install/06-hardware.sh for T2/NVIDIA/etc. Build verification pending.
- [~] I6.1 Plymouth animation + I/O errors — floppy blacklist ships and boot is clean. ISO built (2.2 GB) and Plymouth splash renders correctly in QEMU (visually verified via screendump PNG); refresh_cb doesn't tick under QEMU headless so caret animation not observable. Real-hardware KMS test pending.
- [x] I7 Network ergonomics — iwd + impala + rfkill, NetworkManager out, systemd-networkd-wait-online masked. Super+Ctrl+W → vinos-launch-wifi.
- [x] I8 UI/UX polish + walker adoption — walker (replaces wofi), hypridle, hyprlock, hyprpicker, hyprsunset, swayosd, satty, kvantum, gtk4-layer-shell, yaru-icon-theme. Ships opinionated configs (foot, walker+theme, swayosd, mako) matching tokyo-night. themes/ system (tokyo-night + gruvbox-dark) + bin/vinos-theme runtime switcher. Verified via iso/test-desktop.sh — Hyprland + waybar render cleanly in QEMU.
- [x] I9 NVIDIA support — nvidia-open-dkms + env drop-ins + Hyprland snippet + KMS via mkinitcpio+modprobe.d.
- [~] I10 hardware verification matrix — docs/HARDWARE.md scaffold with 5 target machines. Real-hardware boots pending user.
- [x] I11 THE PIVOT — lean base + 8 opt-in bundles (ai/dev/media/office/gaming/productivity/comms/browser). vinos-menu (Super+Ctrl+O), vinos-install-once first-boot notifier, gum-based confirm UX. **ISO 2.33 GB (was 2.9 GB pre-I11), well under the 3 GB budget.** Matrix pass: 5.1+5.2+5.4+5.5+offline all green. Kvantum+qt6ct+GTK-3/4 themes, waybar semantic-color styling, Noto CJK+emoji fonts, docs/{BUNDLES,QUICKSTART}.md.
- [x] post-I11 — overlays/education + overlays/health persona forks with first-boot.d/*.list preselection contract.
