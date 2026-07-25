# vinOS overlays

Thin overlays applied on top of vendored Omarchy configs (`configs/omarchy/`).
See `docs/v2/ARCHITECTURE.md` for the full picture.

## Directories

- `security/` — Frame.work-critique response: firewall on, SSH not exposed,
  faillock restored to Arch defaults.
- `t2/` — T2 Mac support scoped to the **live ISO environment only**. The
  installed system's T2 setup is handled by Omarchy's
  `install/hardware/apple/fix-t2.sh`, which we do not duplicate.
- `mac/` — Mac muscle-memory: Cmd remap, natural scroll, Cmd+Shift+4 screenshot.
  Applied post-install as a Hyprland drop-in.
- `brand/` — vinOS visual identity: original wallpaper, palette, boot splash,
  greetd theme. Open-licensed fonts only.

## Rule

Never edit files under `configs/omarchy/`. Every vinOS delta lives in one of
the four directories above and is layered on top at build time. Upstream
Omarchy updates then merge mechanically.
