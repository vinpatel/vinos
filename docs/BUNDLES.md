# vinOS Bundles

Base vinOS is **lean**: Arch + Hyprland + the UX stack. Everything a
persona-specific (AI dev, media editor, gamer, office user) needs is
opt-in via `vinos-install-<bundle>` scripts. First-boot notification
prompts the user to open the menu (Super+Ctrl+O → **Install: ai
bundle**, etc.). Nothing extra is downloaded until asked.

## Bundle catalog

| Bundle | Command | What it installs | Approx. size |
|---|---|---|---|
| **ai** | `vinos-install-ai` | ollama, llama.cpp, huggingface-cli, python-openai/anthropic/torch, docker + nvidia-container-toolkit (on NVIDIA), CUDA/cuDNN (on NVIDIA), claude-code, aichat, open-webui | ~4 GB (CPU) / ~9 GB (NVIDIA) |
| **dev** | `vinos-install-dev` | postgresql, mariadb-libs, redis, kubectl, helm, terraform, jdk, rust, ruby, go, docker, mise | ~2 GB |
| **media** | `vinos-install-media` | mpv, kdenlive, obs-studio, evince, pinta, imv, gpu-screen-recorder, spotify | ~1.5 GB |
| **office** | `vinos-install-office` | libreoffice-fresh, thunderbird | ~800 MB |
| **gaming** | `vinos-install-gaming` | steam, lutris, gamemode, mangohud (needs [multilib] repo enabled) | ~1 GB + games |
| **productivity** | `vinos-install-productivity` | obsidian, notion-app, typora, 1password + 1password-cli | ~700 MB |
| **comms** | `vinos-install-comms` | signal-desktop, localsend | ~200 MB |
| **browser** | `vinos-install-browser` | chromium, firefox | ~500 MB |

Sizes are pacman-reported installed size on a fresh Arch box; on-disk
after compression is ~40 % less. The AI bundle is the outlier —
CUDA/cuDNN dominate on NVIDIA machines.

## Ergonomics

- **Discoverability**: press `Super+Ctrl+O` for `vinos-menu`. It's a
  walker-dmenu picker with every bundle listed, plus wifi, update,
  doctor, and lock.
- **Non-interactive**: set `VINOS_INSTALL_ASSUME_YES=1` in the
  environment before running any `vinos-install-*` script and it skips
  the confirm prompt. Useful for CI, provisioning tools, dotfiles.
- **State**: each successful install appends to
  `~/.local/state/vinos/bundles.log` (ISO-timestamp + bundle name).
  Idempotent — re-running a bundle is a `pacman -S --needed` no-op.
- **First-boot notification**: `vinos-install-once` runs from Hyprland
  `exec-once`, fires one desktop notification pointing at the menu,
  drops a sentinel at `~/.local/state/vinos/install-once.done`, and
  never nags again.

## Why not just ship everything?

The I11 pivot: keep the base ISO ≤ 3 GB. That means chromium, signal,
spotify, obsidian, 1password, localsend all moved out of
`install/02-desktop.sh` into their bundles. The upside: a first-time
user isn't sitting through a 5 GB download to try vinOS on a USB, and
personas get to opt in to only the ~4 GB of AI or ~1 GB of media
tooling they actually want.

If you want the "everything" experience, chain the installers:

```bash
for b in browser comms ai dev productivity media; do
  VINOS_INSTALL_ASSUME_YES=1 vinos-install-$b
done
```

## Adding a bundle

1. Copy `bin/vinos-install-media` as a template.
2. Fill `bundle_pkg` / `bundle_aur` / `bundle_post` calls.
3. Add a row to this doc.
4. Add the bundle name to `BUNDLES=(...)` in `bin/vinos-menu`.
5. `install/05-branding.sh` picks up new `vinos-*` bins automatically
   via its rsync + symlink loop.
