# vinOS — QA & test runbook

**Goal:** iterate on ISO fixes from the Mac without burning a USB. Every fix
passes this loop before it goes to real hardware.

Linux dev host: `omarchyserver` (LAN IP `192.168.1.140`, 12 cores, 128 GB RAM,
KVM enabled). Mac lives on the same LAN. All QEMU runs on the Linux host; VNC
surfaces the guest desktop to the Mac.

Four iteration tiers. Pick the one that matches the change.

---

## One-time setup (Linux dev host, one sudo command)

Open port 5900 in ufw, scoped to the home LAN:

```bash
sudo ufw allow from 192.168.1.0/24 to any port 5900 proto tcp comment 'vinOS QEMU VNC — LAN only'
```

Persists across reboots. To revoke:

```bash
sudo ufw delete allow from 192.168.1.0/24 to any port 5900 proto tcp
```

If your LAN uses a different subnet, adjust `192.168.1.0/24` accordingly.

---

## The one command you'll actually type

```bash
iso/qemu-desktop.sh --lan --keepalive --iso iso/out/vinos-<version>-x86_64.iso
```

That single invocation:

- Boots the ISO under QEMU with **4 vCPU / 8 GB / virtio-vga / cpu=host** (KVM accelerated)
- Publishes VNC on `0.0.0.0:5900` with password `vinos`
- Exposes a QEMU HMP monitor at `/tmp/qemu-hmp.sock` (for automation)
- Spawns `iso/qa/keepalive.sh` — sends an invisible Shift press to the guest
  every 45 s so `hypridle` never locks the session (critical for pre-v1.2.3
  ISOs where the live user cannot unlock)
- Prints the exact `vnc://` URL + password to paste into Finder

Add `--hostfwd` (defaults to host port 2222) when you need SSH into the guest for
hot-patch iteration (Tier 3).

---

## Tier 1 — visual test (human presses keys in Screen Sharing)

**Use for:** "did my fix ship?" — the 90 % case.

### On the Mac

Finder → **⌘K** → paste:

```
vnc://192.168.1.140
```

Password prompt → type `vinos`. Check "Remember password in Keychain" so future
connects are one-click.

Screen Sharing → **View → Send Command Key** (or **⌃⌘K**) so macOS stops eating
⌘ shortcuts and passes them through to Hyprland as Super.

### The acid-test checklist

| Test | Press | Should |
|---|---|---|
| Super passthrough | ⌘Space | Walker text launcher appears |
| **Terminal binding** (the v1.2.1/v1.2.2 regression) | **⌘Return** | Foot terminal opens |
| Visual grid launcher | ⌘⌥Space | nwg-drawer full-screen icon grid |
| Keybindings cheat sheet | ⌘K | Overlay with all bindings |
| Close focused window | ⌘Q | Window closes |

### Beauty audit

Look at any window:

- **Gradient border**: 2 px mint→mauve→cyan (45°) on the active window
- **Rounded corners**: ~14 px radius
- **Blur**: drag one window over another — the bottom should show through as soft blur
- **Opacity**: inactive windows dimmer than active
- **Animation**: `⌘` + drag a window — smooth with `easeOutQuint` easing

Any missing → `looknfeel.conf` isn't fully loading. Different bug from the
binding failures.

### Teardown

```bash
pkill -f 'qemu-system-x86_64.*vinos-'
pkill -f keepalive.sh
```

---

## Tier 2 — automated headless regression

**Use for:** wire into the ship gate so silent no-op bugs cannot ship again.
Pure pass/fail, no human.

```bash
iso/test-super-return.sh --iso iso/out/vinos-<version>-x86_64.iso
```

What it does:

1. Boots ISO headless under QEMU with `-vga std`.
2. Waits 150 s (Hyprland settled) — tunable via `--settle SEC`.
3. HMP `screendump before.ppm`.
4. HMP `sendkey meta_l-ret`.
5. HMP `screendump after.ppm` at t+2 s.
6. `imagemagick compare` counts pixels changed with `-fuzz 5%`.
7. **PASS** if ≥ 2 % of pixels changed (a terminal-shaped window painted) —
   tunable via `--threshold PCT`. **FAIL** otherwise, with both frames and
   the diff PNG saved to `iso/out/super-return-*.png`.

To be wired into `iso/test.sh matrix` as Q7 — no ISO ships without this green.

---

## Tier 3 — hot-patch config inside the running QEMU (sub-second)

**Use for:** iterating on config-only fixes (Hyprland bindings, autostart,
looknfeel, walker CSS, waybar). Zero rebuilds.

**Prerequisite:** sshd running in the live overlay (Q6, not yet shipped).

```bash
iso/qemu-desktop.sh --lan --keepalive --hostfwd --iso iso/out/vinos-<version>-x86_64.iso
# in another shell — currently manual, will become iso/qa/loop.sh (Q5)
scp -P 2222 config/hypr/bindings/apps.conf vinos@localhost:/home/vinos/.config/hypr/bindings/apps.conf
ssh -p 2222 vinos@localhost 'hyprctl reload'
# press SUPER+Return in the VNC window
```

Test → observe → edit → reload → test. Seconds per iteration. Only rebuild the
ISO when the config is proven to fire the intended action.

**Fallback when sshd isn't up yet (works today):** open walker (⌘Space) → type
`foot` → Enter → in foot, edit the config and `hyprctl reload` directly. Slower
than SSH but no infra prerequisite.

---

## Tier 4 — HMP-driven automation (for tests + rescue)

**Use for:** driving the guest from outside without any GUI. Powers Tier 2 and
enables scripted rescue when the desktop is inaccessible.

Every helper talks to QEMU through `iso/qa/hmp.sh`:

```bash
iso/qa/hmp.sh status                    # info status
iso/qa/hmp.sh key meta_l-ret            # send SUPER+Return
iso/qa/hmp.sh key meta_l-spc            # send SUPER+Space
iso/qa/hmp.sh type foot                 # type "foot" one keysym at a time
iso/qa/hmp.sh dump /tmp/frame.ppm       # screendump
iso/qa/hmp.sh send 'info block'         # arbitrary HMP command
```

Composable — Tier 2 stitches `key + dump + compare`; keepalive uses `key shift`;
rescue can use `key meta_l-spc + type foot + key ret` to open a terminal when
the SUPER+Return binding is broken.

---

## Bug class → tier matrix

| Bug class | Static gate (`config-lint.sh`) | Tier 1 (visual) | Tier 2 (automated) | Tier 3 (hot-patch) |
|---|---|---|---|---|
| xdg-terminal-exec silent no-op (v1.2.1) | ✅ | ✅ | ✅ | — |
| swaybg per-user path (v1.2.1) | ✅ | ✅ | (add wallpaper diff) | — |
| Wrong keysym case (v1.2.2 `RETURN` vs `Return`) | ❌ | ✅ | ✅ | ✅ |
| `uwsm-app -- foot` runtime fail | ❌ | ✅ | ✅ | ✅ |
| Binding not sourced (source-order) | ❌ | ✅ | ✅ | ✅ |
| foot missing at runtime | ✅ (package list check) | ✅ | ✅ | — |
| looknfeel.conf not loading (beauty missing) | ❌ | ✅ | (add pixel-diff of borders) | ✅ |
| hypridle locking mid-test | N/A (this runbook side-effect) | fixed by --keepalive + v1.2.3 skip | | |
| T2 hardware-only failure | ❌ | ❌ | ❌ | ❌ (needs real T2) |

Tier 1 catches almost everything. Tier 2 makes it non-negotiable at build time.
Tier 3 collapses config iteration from minutes to seconds. Real hardware only
enters the loop after Tiers 1–3 pass.

---

## Ship gate integration (Q7, pending)

Every `iso/build.sh` post-build sequence should run:

1. `iso/qa/config-lint.sh` (static — already wired at gate 0 in build.sh)
2. `iso/test.sh matrix` (bios + uefi + 3G floor + offline + plymouth — already wired)
3. **`iso/test-super-return.sh`** (Tier 2 — NEEDS wiring in build.sh / test.sh)
4. Manual Tier 1: `iso/qemu-desktop.sh --lan --keepalive`, run the acid-test
   checklist, sign off in commit: `verified: SUPER+Return · gradient border ·
   blur · nwg-drawer · walker`

Only when all four pass may the ISO become a candidate for `iso/flash.sh` to
real hardware.

---

## Files that make this work

| Path | Purpose |
|---|---|
| `iso/qemu-desktop.sh` | Entry point. `--lan/--vnc/--keepalive/--monitor/--hostfwd/--password/--mem/--smp/--vga` flags. |
| `iso/qa/config-lint.sh` | Static Hyprland config lint. Runs at build time. |
| `iso/qa/hmp.sh` | HMP client wrapper. Every automation talks through this. |
| `iso/qa/keepalive.sh` | Sends `sendkey shift` every 45 s. Defeats hypridle. |
| `iso/test-super-return.sh` | Tier 2 regression test. Sendkey + pixel-diff. |
| `iso/test.sh` / `iso/test-desktop.sh` | Existing headless boot / screendump matrix. |
| `iso/qa/loop.sh` *(Q5, pending)* | Hot-reload iteration driver. |

## Files that need to land next

- **Q5 `iso/qa/loop.sh`** — inotifywait + scp + hyprctl reload driver.
- **Q6** — enable `sshd.service` in `iso/airootfs-overlay/etc/systemd/system/multi-user.target.wants/` so `--hostfwd` actually reaches a running sshd.
- **Q7** — extend `iso/build.sh` and/or `iso/test.sh matrix` to run `iso/test-super-return.sh` as a mandatory pre-ship gate.
