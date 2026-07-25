# vinOS security overlay

Answers the 2026-era Frame.work-forum critique of stock Omarchy defaults.
Each file here corresponds to one concern.

## What this overlay changes

| Frame.work concern | File | Change |
|---|---|---|
| Firewall shipped off | `etc/systemd/system/multi-user.target.wants/ufw.service` (symlink at build) + `etc/ufw/vinos.rules` | ufw enabled by default, deny incoming, allow outgoing |
| SSH open + insecure defaults | `etc/ssh/sshd_config.d/00-vinos.conf` | `PasswordAuthentication no`, `PermitRootLogin no`, `KbdInteractiveAuthentication no` — plus we do NOT enable sshd by default |
| No hardened kernel option | (packages list) | `linux-hardened` shipped alongside `linux-t2`, user can pick at boot |
| `curl \| sh` scripts | our installer flow uses signed pacman packages only | (no file — process, not config) |
| Weakened faillock | `etc/security/faillock.conf` | Arch defaults restored: `deny=3`, `unlock_time=600`, `fail_interval=900` |

## What this overlay does NOT do

- Full kernel hardening (SELinux/AppArmor policies) — out of scope for v2.0
- Full disk encryption enforcement — offered in installer, not forced
- Sandbox-per-app (Flatpak/bubblewrap) — Omarchy stack; leave to user
