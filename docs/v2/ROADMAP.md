# vinOS roadmap

Public, best-effort. Shipping order not fixed — priority follows what
sponsors and users tell us matters. See individual specs under
`docs/v2/` for detail.

## Shipped

- **v2.0.3** — theme picker fix (lowercase-at-install + pre-warm cache)
- **v2.0.4** — 10 rebuilt themes (Unsplash HD wallpapers + battle-tested
  palettes), Docker + dua-cli for agentic flows, cosmos as default
- **v2.0.5** — tool-enabled routines with bwrap sandbox, five signature
  vinos-* utilities (standup, commit, focus, fix, explain), portable
  `.vinos/routines.yaml` project spec + loader, wallpaper watermark
  position fix

## In flight

- **v2.0.6** — 80/20 auto-router, cron-string → OnCalendar translator,
  routine memory (persistent/shared), `vinos-*` wrapper set to hide
  omarchy-* commands from user-facing surfaces
- **v2.0.7** — routine gallery on vinos.computer with community
  submission flow, `vinos-routine install <slug>` command, per-routine
  waybar widget

## Site — near-term

- End-to-end install video (~2-3 min MP4) captured from QEMU. Embedded
  at the top of the homepage and `/docs/getting-started/download-and-flash/`.
  Shows: boot menu → live desktop → `vinos-install-disk` → reboot →
  first-boot. Needs non-interactive install flow or scripted keypresses
  via QEMU monitor.
- 24 UI screenshots from booted v2.0.5 to replace `SCREENSHOTS_NEEDED.md`
  placeholders across `/docs/`.
- CDN + `dl.vinos.computer` custom domain per Cloudflare R2 setup.

## v2.1 — vinOS Cloud (headless trim-down)

The runtime — MINUS Hyprland, Waybar, walker, themes, Plymouth —
packaged for cloud execution. Same `.vinos/routines.yaml` runs on the
laptop AND on a $5/mo Hetzner VPS 24/7 without the laptop being on.
Unlocks the "agents that run without you" story completely — currently
agents pause when the laptop sleeps.

Ship targets:

- `ghcr.io/vinpatel/vinos-cloud` — Docker image (~200 MB, Alpine or
  minimal Arch base). Contains `vinos-routine` CLI + libexec + Ollama
  client + sqlite. Mount `.vinos/routines.yaml` as config.
- Systemd Nspawn image for bare-metal ops shops.
- Kubernetes Helm chart — `helm install vinos-agents vinos/agents` —
  CronJobs per routine, PVC for state/ledger, Secret for API keys.
- Fly.io / Cloud Run / Hetzner-Cloud one-clicks for founders who want
  zero infra.

The runtime is already Python + bash + SQLite + optional Ollama HTTP
client — extremely portable. Only vinOS-specific coupling: systemd
user timers (replace with cron in containers) + mako notifications
(replace with webhook POSTs to Slack/Discord/email).

Positioning vs pure-hosted alternatives (Zapier, n8n Cloud): vinOS
Cloud runs on YOUR cloud, YOUR data, YOUR keys.

Blocked on: v2.0.6 (auto-router + loader stabilization).

## v2.2 — team-shared routines

Multi-tenant vinos-routine: many `.vinos/routines.yaml` bundles from
different repos running against one shared Ollama + one shared ledger
+ per-repo API keys. Aimed at engineering teams who want a shared
agent pool without each engineer running their own instance.

## v2.3+ — long-tail directions

Not committed, listed for signal:

- Delta ISO updates via zsync (users pay only bytes-that-changed)
- Encrypted `vinos-persist` LUKS partition by default when
  `--with-persistence` is set on flash
- Rootless Docker as default (avoid the `vinos in docker group` =
  effective root path)
- macOS-style menubar integration (via waybar-menu-plugin)
- Voice-triggered routine invocation (whisper.cpp local)
- Ollama model mirror on dl.vinos.computer for offline installs

## Not doing

Explicit non-goals — flagged so contributors don't waste time:

- Reimplementing QuickShell (Omarchy's QML overlay). Too much code
  for zero product upside. Users don't care whose QML renders their
  volume OSD.
- Forking Omarchy. Contribute the foot.ini per-theme generator fix
  upstream if the maintainers want it; keep the routine framework
  proprietary to vinOS.
- Rewriting the 367 Omarchy bash scripts. Rebrand user-visible ones
  via `vinos-*` wrappers; leave everything else alone.
- Adding CachyOS repos. One upstream simpler; the "free wins"
  (hardened kernel, BTRFS+Snapper) are achievable with our own overlay.

## How to add to this roadmap

Every entry needs (a) a target version, (b) a shipping trigger — what
needs to be true before we start — (c) an honest one-line description
of the user-visible outcome. Vaporware entries get flagged with `??`.
