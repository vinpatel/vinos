---
title: "Bundles"
description: "Optional persona bundles — install what you actually use"
---

Base vinOS is deliberately lean. Persona-specific apps opt in with one command.
Every bundle is idempotent — safe to re-run.

## Catalog

| Bundle | Command | What it installs | Approx. size |
|---|---|---|---|
| **ai** | `vinos-install-ai` | ollama, llama.cpp, huggingface-cli, python-openai/anthropic/torch, docker + nvidia-container-toolkit (on NVIDIA), CUDA/cuDNN (on NVIDIA), claude-code, aichat, open-webui | ~4 GB (CPU) / ~9 GB (NVIDIA) |
| **dev** | `vinos-install-dev` | postgresql, mariadb-libs, redis, kubectl, helm, terraform, jdk, rust, ruby, go, docker, mise | ~2 GB |
| **media** | `vinos-install-media` | mpv, kdenlive, obs-studio, evince, pinta, imv, gpu-screen-recorder, spotify | ~1.5 GB |
| **office** | `vinos-install-office` | libreoffice-fresh, thunderbird | ~800 MB |
| **gaming** | `vinos-install-gaming` | steam, lutris, gamemode, mangohud | ~1 GB + games |
| **productivity** | `vinos-install-productivity` | obsidian, notion-app, typora, 1password + 1password-cli | ~700 MB |
| **comms** | `vinos-install-comms` | signal-desktop, localsend | ~200 MB |
| **browser** | `vinos-install-browser` | chromium, firefox | ~500 MB |

## Non-interactive

Set `VINOS_INSTALL_ASSUME_YES=1` to skip the confirm prompt. Useful for
dotfiles, provisioning tools, CI.

```bash
for b in browser comms ai dev productivity; do
  VINOS_INSTALL_ASSUME_YES=1 vinos-install-$b
done
```

## From the menu

`Super+Ctrl+O` opens `vinos-menu` with every bundle listed. Bundle
installers run inside a floating foot terminal so you see yay's
progress + prompts.

## Adding your own

1. Copy `bin/vinos-install-media` as a template.
2. Fill `bundle_pkg` / `bundle_aur` / `bundle_post` calls.
3. `install/05-branding.sh` picks up new `vinos-*` bins automatically.
