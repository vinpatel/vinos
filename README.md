# vinOS — an agentic OS for founders, innovators, and thinkers

**Boot to a working Claude Code + local LLM setup in 90 seconds.**

vinOS is an open-source agentic Arch Linux layer by Vin Patel — the desktop
Arch experience with Claude Code, Ollama, and a curated Hyprland
config already wired up. `Super+A` opens a local LLM. `Super+Shift+A`
opens Claude Code. Runs on any x86_64 machine.

## 💛 Sponsor this project

vinOS is solo-maintained and MIT licensed. If it saves you a subscription
fee or a weekend of setup, please consider supporting the work:

- **[GitHub Sponsors →](https://github.com/sponsors/vinpatel)** — recurring, 0% platform fee
- **[OpenCollective →](https://opencollective.com/vinos)** — transparent, corporate-friendly, 10% platform fee
- **[Website →](https://vinos.computer)** — download the ISO, read the story

Sponsors fund real-hardware verification (Framework · StarLabs · older ThinkPads
· MacBooks), infrastructure (archive.org hosting, CI runners), and roadmap
work (fleet management, agent snapshots, safety layers). Every dollar routes
to making vinOS work on more hardware for more people.

**For OEMs and enterprise deployments:** `hello@vinos.computer`.

---

## Install

**One-liner**, on any fresh Arch (including T2 Macs installed via
[t2linux](https://wiki.t2linux.org)):

```bash
curl -fsSL https://raw.githubusercontent.com/vinpatel/vinos/main/boot.sh | bash
```

That clones this repo to `~/.local/share/vinos` and runs `install.sh`.
Full details: [docs/INSTALL.md](docs/INSTALL.md) — including the
T2-Mac path and how bundles work.

## What you get

- **Hyprland** desktop, Wayland-native, with the tokyo-night beauty
  pass out of the box.
- **AI-first**: `Super+A` opens `vinos-ai chat` (ollama), `Super+Shift+A`
  opens Claude Code. Install with `vinos-install-ai`.
- **5 themes** switchable at runtime via `vinos-theme <name>`:
  tokyo-night · catppuccin-mocha · rose-pine · everforest · gruvbox-dark.
- **Nerd Font waybar** with pill-island modules, semantic colors,
  network/audio/cpu/mem/battery/tray.
- **Walker** launcher (`Super+Space`), **hyprlock** with big
  JetBrainsMono clock, **hypridle**, **hyprsunset**, **swayosd**, **satty**.
- **iwd + impala** for wifi (`Super+Ctrl+W`).
- **Bibata cursor** + Kvantum + qt6ct + GTK3/4 all coordinated.
- **`vinos-menu`** (`Super+Ctrl+O`) — one entrypoint for bundles,
  theme switching, doctor, wifi, lock.
- **First-boot notification** points at the menu; nothing gets pushed
  onto you.

## The Three Rules

1. Only `install/02-desktop.sh` touches anything graphical — every
   other script works headless.
2. Base owns `install/01..09`; forks own `10..99`. Overlays add and
   shadow, never edit. All scripts idempotent.
3. Only `install/05-branding.sh` touches identity (os-release,
   wallpaper, `vinos-*` bins).

Details in [VINOS_SPEC.md](VINOS_SPEC.md). Design decisions live in
[DECISIONS.md](DECISIONS.md).

## Docs

- [docs/INSTALL.md](docs/INSTALL.md) — install, T2 Mac path, uninstall.
- [docs/QUICKSTART.md](docs/QUICKSTART.md) — first-boot walkthrough.
- [docs/BUNDLES.md](docs/BUNDLES.md) — every opt-in bundle + size.
- [docs/HARDWARE.md](docs/HARDWARE.md) — verified-hardware matrix.
- [docs/KEYBINDINGS.txt](docs/KEYBINDINGS.txt) — what `Super+K` shows.
- [docs/USB.md](docs/USB.md) — live USB flashing.
- [overlays/README.md](overlays/README.md) — persona forks (education,
  health).
- [iso/README.md](iso/README.md) — the secondary live-ISO path.
- [ATTRIBUTIONS.md](ATTRIBUTIONS.md) — prior-art credits.

## Development

Every script is Bash, shellcheck-clean, under ~80 lines. Config lives
in `config/` and gets rsync'd to `~/.config/`. See `VINOS_SPEC.md` and
`CLAUDE.md`.

## License

MIT © Vin Patel. See [LICENSE](LICENSE) and
[ATTRIBUTIONS.md](ATTRIBUTIONS.md).
