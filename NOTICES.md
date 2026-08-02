# vinOS — Attribution & Third-Party Notices

vinOS is an **official upstream-tracked fork of [Omarchy](https://omarchy.org)** — the MIT-licensed Hyprland desktop by David Heinemeier Hansson (Basecamp). On top of Omarchy's polished desktop foundation, vinOS adds an agent-native OS layer for founders, engineers, and teams running AI agents at scale.

This file is the canonical credit registry. It exists to satisfy attribution requirements and to publicly acknowledge every upstream project vinOS depends on.

For the license governing vinOS's own overlay code, see [LICENSE](LICENSE).

---

## vinOS overlay — our original work

- **Copyright:** © 2026 Vin Patel
- **License:** MIT (see `LICENSE`)
- **Scope:** every file in this repository **outside the `omarchy/` subtree**, including:
  - `bin/vinos-*` — vinOS agent CLI suite (`vinos-ai`, `vinos-routine`, `vinos-brief`, `vinos-menu`, `vinos-focus`, `vinos-install-disk`, `vinos-install-k8s`, `vinos-flow`, `vinos-waybar-ai`, `vinos-lockscreen-glance`, and ~50 more)
  - `configs/vinos/*` — vinOS branding overlay (accent colors, custom themes, AI pill wiring, LUKS setup, hardening configs)
  - `install/*.sh` — build assembler scripts (`01-base.sh` through `06-hardware.sh`, plus `install/first-run/*.sh`)
  - `iso/*` — archiso profile, package lists, QA harness (`iso/qa/verify-shipped-iso.sh`, `iso/qa/oneshot.sh`), build scripts
  - `docs/*` — documentation, roadmap, per-feature specs
  - `site/*` — [vinos.computer](https://vinos.computer) source
  - Every T2 Mac hardware support fix (wifi recipe v2, brcmfmac firmware symlinks, `linux-t2` kernel integration, keyboard/trackpad/audio patches)
  - Every kernel hardening, sysctl pin, module blacklist, and regression-harness check

**These are the parts of vinOS you may freely fork, use, modify, distribute, and sell under MIT terms.**

---

## Primary upstream — Omarchy

- **Project:** [Omarchy](https://omarchy.org) · [GitHub](https://github.com/basecamp/omarchy)
- **Author:** David Heinemeier Hansson ([@dhh](https://github.com/dhh))
- **Publisher:** Basecamp (37signals)
- **License:** MIT
- **vinOS pins:** Omarchy `3.8.4` (see `omarchy/version`)
- **Location in this repo:** `omarchy/` (added via `git subtree` — upstream refresh via `git subtree pull --prefix=omarchy https://github.com/basecamp/omarchy master --squash`)

**Omarchy provides to vinOS Desktop:**
Hyprland compositor + Walker launcher + Waybar + Mako + Hyprlock + Alacritty/Foot terminals + 19 themes with cross-app styling + Limine bootloader with snapshot rollback + LUKS full-disk encryption on install + first-boot configuration flow + 283 `omarchy-*` utility binaries + first-boot scripts + preflight hardware detection.

Files inside `omarchy/` remain © David Heinemeier Hansson under MIT. Full license text at [`omarchy/LICENSE`](omarchy/LICENSE) and reproduced below.

### Omarchy MIT License (full text)

```
Copyright (c) David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

---

## Base operating system — Arch Linux

- **Project:** [Arch Linux](https://archlinux.org)
- **archiso profile:** [archlinux/archiso](https://gitlab.archlinux.org/archlinux/archiso), GPL-3.0. vinOS's archiso profile modifications are retained under the same license.
- **Package licenses:** Individual Arch packages ship with their own licenses (predominantly GPL, LGPL, MIT, BSD, Apache 2.0). Per-package license text is available on the running system at `/usr/share/licenses/`.
- **vinOS relationship:** vinOS ships as an `archiso`-built ISO. Every Arch package's license accompanies its files on the installed system per Arch conventions. vinOS does not modify Arch upstream package sources.

---

## Kernels shipped

- **linux-cachyos** (BORE scheduler, LLVM-optimized) — GPL-2.0. Upstream: [CachyOS/linux-cachyos](https://github.com/CachyOS/linux-cachyos). Default boot entry for performance.
- **linux-hardened** (KSPP-adjacent hardening, KASLR max, SLUB hardening) — GPL-2.0. Arch-community-maintained. Second boot entry for security posture.
- **linux-t2** (Apple T2 hardware patches) — GPL-2.0. Upstream: [t2linux/linux-t2](https://github.com/t2linux/linux-t2). Third boot entry for T2 MacBooks (2018–2020).

---

## Companion product (same maintainer) — AgenticFlow

- **Project:** [AgenticFlow](https://agenticflow.do)
- **Author:** Vin Patel
- **License:** MIT
- **vinOS relationship:** AgenticFlow is the agent-orchestration platform vinOS is designed to run natively. Deep integration surfaces (waybar module, walker rows, mako channel, MCP local bridge) ship in Phase C releases (v2.2.x). See `docs/ROADMAP.md`.

---

## Cloud model provider

- **Provider:** [Anthropic](https://anthropic.com) — Claude via the Anthropic API
- **License terms:** Anthropic API Terms of Service (proprietary service, accessed by user credentials). vinOS ships no proprietary Anthropic code; the `vinos-ai` CLI is a client that calls the public Anthropic SDK.

---

## Major bundled components (partial list — see `/usr/share/licenses/` on a booted system for exhaustive per-package licenses)

- Hyprland (BSD-3-Clause) · Waybar (MIT) · Walker (MIT) · Foot (MIT) · Mako (MIT) · Hyprlock (BSD-3-Clause) · Hypridle (BSD-3-Clause) · Alacritty (Apache-2.0) · Neovim (Apache-2.0) · Chromium (BSD-3-Clause) · Docker (Apache-2.0) · containerd (Apache-2.0) · systemd (LGPL-2.1+) · pipewire (MIT) · Bluez (GPL-2.0) · iwd (LGPL-2.1)
- `linux-firmware` — mixed (varies per firmware blob per upstream `WHENCE` file); redistributable in binary form
- Broadcom brcmfmac firmware — redistributed under Broadcom's binary firmware terms for compatibility with Apple T2 hardware
- `[arch-mact2]` repository (Apple T2 hardware support) — mixed BSD/MIT/GPL per individual package
- Bibata cursor theme (GPL-3.0)
- sound-theme-freedesktop (LGPL-2.1)
- starship prompt (ISC)

---

## Trademarks

vinOS is **not affiliated with, endorsed by, or sponsored by** Apple Inc., 37signals, Basecamp, the Arch Linux project, the T2 Linux project, Anthropic, or CachyOS.

- "vinOS" is a project name of Vin Patel. Trademark registration pending.
- "Omarchy" is a project of David Heinemeier Hansson and Basecamp. Used nominally to identify our upstream — no endorsement claimed.
- "Apple", "Mac", "MacBook", "iMac", and "T2" are trademarks of Apple Inc. Used nominally — vinOS runs on Apple hardware.
- "Arch Linux" and the Arch Linux logo are trademarks of the Arch Linux team.
- "Linux" is a registered trademark of Linus Torvalds.
- "Claude" and "Anthropic" are trademarks of Anthropic PBC.
- "AgenticFlow" is a project name of Vin Patel.
- All other trademarks are property of their respective owners.

---

## How to keep vinOS synced with Omarchy upstream

vinOS tracks Omarchy as a git subtree. Anyone can pull the latest Omarchy release into a vinOS working tree with:

```bash
git subtree pull --prefix=omarchy https://github.com/basecamp/omarchy master --squash
```

This is the fork-of-Omarchy commitment — vinOS stays continuously in sync with DHH's work while adding its own agent-native layer above.

Contributions from vinOS that benefit Omarchy directly (e.g., T2 Mac hardware fixes) are submitted upstream via pull request whenever appropriate.

---

**Questions or concerns about attribution?** Open an issue at [github.com/vinpatel/vinos](https://github.com/vinpatel/vinos) or reach out to `vinpatel.pro@gmail.com`.
