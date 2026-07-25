# Third-party notices

vinOS is a Linux distribution. Like every Linux distribution, it composes
open-source components with our own work. This file exists to satisfy
attribution requirements. For the license governing vinOS's own code, see
[LICENSE](LICENSE).

## Upstream projects

- **Linux kernel with T2 patches** — GPL-2.0-only. Upstream:
  [t2linux/linux-t2](https://github.com/t2linux/linux-t2). vinOS ships
  `linux-t2` as its primary kernel to support Apple T2 hardware.
- **Omarchy desktop configuration** — MIT. Upstream:
  [basecamp/omarchy](https://github.com/basecamp/omarchy). vinOS vendors
  Omarchy configuration files verbatim as its desktop layer.
- **Arch Linux** — vinOS is built from the archiso profile published by the
  Arch Linux project ([archlinux/archiso](https://gitlab.archlinux.org/archlinux/archiso),
  GPL-3.0). Modifications to that profile are retained under the same
  license.
- **Broadcom Wi-Fi firmware** — redistributed under Broadcom's binary
  firmware terms for compatibility with Apple T2 hardware.

## Installed packages

The vinOS ISO installs packages from the Arch Linux official repositories
(core, extra, multilib) and the Arch User Repository (AUR). Each package
retains the license and copyright declared by its upstream author. vinOS
makes no additional claim of ownership over redistributed third-party
software. Per-package license text is available on the running system at
`/usr/share/licenses/`.

## Trademarks

vinOS is not affiliated with, endorsed by, or sponsored by Apple Inc.,
37signals, the Arch Linux project, or the T2 Linux project.

- "Apple", "Mac", "MacBook", and "T2" are trademarks of Apple Inc. Their
  use in vinOS is nominative — vinOS runs on Apple hardware.
- "Arch Linux" and the Arch Linux logo are trademarks of the Arch Linux
  team. vinOS does not use the Arch Linux name or logo as part of its
  identity; where the string `arch` appears (e.g. `ID_LIKE=arch` in
  `/etc/os-release`), it is used descriptively in the standard
  Linux-vendor way.
- "Omarchy" is a project by 37signals. vinOS uses Omarchy configuration
  files under MIT terms.
