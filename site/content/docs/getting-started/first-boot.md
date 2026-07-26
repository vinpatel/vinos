---
title: "First boot"
description: "Boot the ISO on generic x86 or a T2 MacBook Pro, complete first-run, and get onto Wi-Fi."
weight: 20
---

## Booting

Plug the USB in, hold your boot-menu key (`F12` on most Dells,
`F9` on HP, `Option` on Intel Macs), pick the vinOS entry.

<figure class="doc-shot doc-shot-pending" id="shot-01">
  <div class="doc-shot-slot">Screenshot pending: Plymouth splash mid-boot with brand caret</div>
  <figcaption>Plymouth boot splash — see SCREENSHOTS_NEEDED.md #shot-01.</figcaption>
</figure>

A few seconds later the console-mode greeter appears while greetd
resolves the autologin. You'll blink past it — it's here for
completeness so you know what's normal.

<figure class="doc-shot doc-shot-pending" id="shot-05">
  <div class="doc-shot-slot">Screenshot pending: greetd / tuigreet on the TTY before autologin</div>
  <figcaption>Console greeter, pre-autologin — see SCREENSHOTS_NEEDED.md #shot-05.</figcaption>
</figure>

On a **T2 MacBook Pro** (2018/2019/2020 Intel), the internal keyboard
and trackpad work out of the box thanks to the shipped `linux-t2`
kernel. Wi-Fi comes up after a firmware warm-up — expect 15–40 seconds
on first boot. See [T2 wifi troubleshooting](/docs/troubleshooting/wifi-t2/)
if it doesn't.

On generic x86_64, everything except NVIDIA optimus laptops "just works".
NVIDIA users may need to add `nomodeset` to the boot line the first
time; once installed, `vinos-install-common` handles the driver setup.

Once autologin fires you land on the default cosmos desktop — waybar
across the top, walker dormant, cosmos wallpaper filling the screen.

<figure class="doc-shot doc-shot-pending" id="shot-06">
  <div class="doc-shot-slot">Screenshot pending: clean cosmos desktop after autologin</div>
  <figcaption>First desktop — cosmos, no overlays. See SCREENSHOTS_NEEDED.md #shot-06.</figcaption>
</figure>

## First-run flow

The first login autostarts `vinos-welcome` in a floating foot window.
It's a walker-dmenu picker with these tasks:

<figure class="doc-shot" id="shot-03">
  <img src="/img/screenshots/welcome-dmenu.png" alt="vinos-welcome walker-dmenu picker" width="1280" height="800" loading="lazy">
  <figcaption>vinos-welcome on first login — see SCREENSHOTS_NEEDED.md #shot-03.</figcaption>
</figure>

<figure class="doc-shot doc-shot-pending" id="shot-07">
  <div class="doc-shot-slot">Screenshot pending: vinos-welcome checklist view (walker overlay)</div>
  <figcaption>Welcome checklist — see SCREENSHOTS_NEEDED.md #shot-07.</figcaption>
</figure>

- **Connect Wi-Fi** — opens the `impala` TUI (Super+Ctrl+W later).
- **Pick a theme** — cycles the 10 shipped themes; default is *cosmos*.
- **Install AI bundle** — pulls Ollama, aichat, claude-code (~2 GB).
- **Install dev bundle** — postgres, docker, mise, common language runtimes.
- **Set your keys** — walks you through Anthropic + optional local model choice.
- **Enable routines** — pick which of the 5 starter routines to activate.

Skip any of them. Rerun the whole flow any time:

```
$ vinos-welcome
```

## Wi-Fi if welcome bugs out

If the picker died before you got online, hop into `impala` directly:

```
$ vinos-launch-wifi
```

Or the keybinding <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>W</kbd>. The
TUI is arrow-driven — highlight an SSID, hit Return, type the password.
iwd stores the credential; next boot reconnects automatically.

## Verifying the install

Once online, run the built-in health check:

```
$ vinos-doctor
```

Expect a mix of PASS / FAIL / SKIP lines grouped by section. FAILs
are the actionable ones — each names the exact thing missing:

```
os-release identity
  PASS NAME=vinOS
  PASS ID=vinos
  PASS ID_LIKE=arch

base packages
  PASS base-devel
  PASS git
  PASS curl
  PASS wget
  PASS rsync
  PASS openssh
  ...

summary: PASS=27 FAIL=0 SKIP=2
```

A green run means you're on the happy path. If FAIL rows appear, jump
to [troubleshooting](/docs/troubleshooting/) and use the FAIL row as
your search term.

Next: [set your API keys](/docs/getting-started/set-your-api-keys/).
