# Pilot 4 — Hyprland ecosystem evaluation for v1.2.0 / v1.3.0

**Date:** 2026-08-09 · **Author:** Vin Patel + Claude Opus 4.7 (1M) collaborator · **Target compositor:** Hyprland **0.55.2** (currently shipped on this host)

## Method

Verification is per-source-repo, not directory-page. For each candidate I checked:
- **License** — must pass gate 1 (MIT / BSD / Apache-2 / MPL-2) for the shipped default set. GPL-licensed plugins are documented for the *user-installable* opt-in set but not bundled.
- **Last-commit signal** — active in 2026 counts as "green," 6-12 month gap "yellow," > 12 month gap "red."
- **Open-issue count** — a rough support signal.
- **Hyprland-version target** — README's compatibility statement.

## Candidate matrix

| Plugin | Upstream | License | Open issues | Version signal | Effort | Verdict |
|---|---|---|---|---|---|---|
| **borders-plus-plus** | hyprwm/hyprland-plugins | BSD-3-Clause ✓ | shared | tracks upstream | **S** | ✅ default |
| **hyprbars** | hyprwm/hyprland-plugins | BSD-3-Clause ✓ | shared | tracks upstream | **S** | ✅ default |
| **hyprfocus** | hyprwm/hyprland-plugins | BSD-3-Clause ✓ | shared | tracks upstream | **S** | ✅ default |
| **hyprexpo** | hyprwm/hyprland-plugins (subdir; not in current README but referenced by many downstream configs) | BSD-3-Clause ✓ | shared | tracks upstream — the community treats it as a first-party plugin, but the top-level README dropped its mention. Verify subdir presence before v1.2.0 ship. | **S** | ✅ default (pending README/subdir re-verification) |
| **hyprtrails** | hyprwm/hyprland-plugins (subdir; same status as hyprexpo — mentioned by downstream but not in current README) | BSD-3-Clause ✓ | shared | tracks upstream | **S** | 🔶 opt-in (v1.3.0 — verify subdir presence) |
| **hyprwinwrap** | hyprwm/hyprland-plugins (referenced from vinOS's own plugins.conf; needs subdir verification) | BSD-3-Clause ✓ | shared | tracks upstream | **M** — needs an app that draws to XWayland with `--x11-name=vinos-live-wallpaper` | 🔶 opt-in (v1.3.0) |
| **pyprland** | hyprland-community/pyprland | MIT ✓ | 2 open | Requires ≥ 2.4.4 for Hyprland 0.48+; 3.4.x is latest stable — 0.55.2 falls in the "> 0.48" range so 3.4.x supports it | **M** — Python framework; extends possibilities but is not "install and use" — configs required | ✅ default (framework only; wire specific pypr plugins in v1.3.0) |
| **hyprgrass** | horriblename/hyprgrass | BSD-3-Clause + Apache-2.0 ✓ | 17 open | Alpha stage; maintainer warns "earlier versions had bugs potentially rendering touch devices unusable until unloaded" | **M** — T2 touchpad users want it; ship *disabled by default*, opt-in via `vinos-menu → System → T2 gestures` | ✅ default (staged; enable only on T2 hardware detected by dmi) |
| **hy3** | outfoxxed/hy3 | **GPL-3.0** ✗ | 70 open | Actively tagged per Hyprland release; `hl0.55.x` tag expected | **L** — swapping layout engine is a serious UX shift, dwindle stays default | ❌ **not bundled** — license fails gate 1. Document for users to install via `hyprpm` themselves. |
| **Hyprspace** | KZDKM/Hyprspace | **GPL-2.0** ✗ | 77 open | Maintainer notes limited availability for issues; "uses latest Hyprland" | **L** | ❌ **not bundled** — license fails gate 1. Users can `hyprpm add`. |
| **hypr-dynamic-cursors** | VirtCode/hypr-dynamic-cursors | MIT ✓ | 17 open | Requires ≥ 0.41.2 — 0.55.2 works | **S** — plug-and-play cursor physics | 🔶 opt-in (v1.3.0 polish set — pretty but non-essential) |
| **hypr-kinetic-scroll** | not found in a canonical source repo during this pilot; needs a follow-up locate | — | — | — | — | ⏭ defer to v1.3.0 investigation |

## Recommended default install set (baked into vinOS v1.2.0 A2 landing)

Small, license-clean, upstream-tracked. All ship pre-enabled with a `plugins.conf` block that becomes active when `hyprpm add https://github.com/hyprwm/hyprland-plugins` + `hyprpm enable <name>` runs at first-boot (already wired in the current `install/06-hardware.sh` post-boot path — extending to hyprpm is a small addition to that script).

1. **borders-plus-plus** — layered borders with vinOS accent gradient (config uses `col.border_1 = rgba(33ccff33)` — already in the shipped `config/hypr/plugins.conf`)
2. **hyprbars** — title bars for floating windows, styled to the vinOS palette
3. **hyprfocus** — flashfocus visual cue on window activation (subtle, cohesive with theme)
4. **hyprexpo** — Mission-Control-style workspace overview via Super+Tab (already bound in the shipped `plugins.conf`; verify subdir exists at hyprwm/hyprland-plugins before ship)
5. **pyprland** (framework only) — enables advanced `vinos-*` scripts to talk to Hyprland IPC directly; no user-visible plugins wired yet at v1.2.0

**Estimated ISO delta:** ~4 MB total binaries + 1 systemd user unit for pyprland. First-run hyprpm dance takes ~30 s (fetched from GitHub).

## Recommended opt-in set (v1.3.0 via `vinos-menu → System → Extra Hyprland plugins`)

- **hyprgrass** — enable on Apple T2 hardware only (dmi-detected). Alpha; opt-in explicit.
- **hyprtrails** — animated cursor/window trails; fun but power-hungry on integrated GPU.
- **hyprwinwrap** — live wallpaper via any XWayland app.
- **hypr-dynamic-cursors** — cursor physics + shake-to-find.

## Rejected (with reasons — users can still `hyprpm add` themselves)

- **hy3** — GPL-3.0 fails gate 1 for bundling. Excellent i3-style layout; document as "install-it-yourself" in `docs/hyprland-plugins.md`.
- **Hyprspace** — GPL-2.0 fails gate 1 for bundling. Similar overview functionality to hyprexpo which is BSD-3 — cover the use case there.
- **csgo-vulkan-fix** — CS:GO-specific, no vinOS relevance.

## Hall-of-fame use rules honored

- **NEVER copy a config wholesale** — every borrowed pattern must be re-authored in vinOS palette and iconography.
- Any pattern lifted from a hall-of-fame post must credit its author in `NOTICES.md` if the source repo requires attribution (MIT/BSD `Redistribution ... reproduce the copyright notice` clauses do).
- Ecosystem themes remain OUT — ADR-012 unchanged.

## Follow-ups before v1.2.0 A2 ship

1. Confirm hyprwm/hyprland-plugins actually has hyprexpo / hyprtrails / hyprwinwrap as top-level subdirs (READMe's plugin list only names 4; either the README is stale or these plugins moved). If they moved to a separate repo, note the URL.
2. Locate the canonical source repo for `hypr-kinetic-scroll` (deferred).
3. Add a first-boot hyprpm step to `install/06-hardware.sh` that runs `hyprpm add https://github.com/hyprwm/hyprland-plugins && hyprpm enable borders-plus-plus hyprbars hyprfocus hyprexpo && hyprpm reload -n`. Idempotent via `hyprpm list | grep -q <name>` guards.
4. Update `NOTICES.md` with per-plugin attribution before bundling any binary.

## References

- Hyprland core (BSD-3-Clause): https://github.com/hyprwm/Hyprland
- Official plugin repo: https://github.com/hyprwm/hyprland-plugins
- hy3 (GPL-3.0, not bundled): https://github.com/outfoxxed/hy3
- hyprgrass (BSD+Apache dual): https://github.com/horriblename/hyprgrass
- pyprland (MIT): https://github.com/hyprland-community/pyprland
- Hyprspace (GPL-2.0, not bundled): https://github.com/KZDKM/Hyprspace
- hypr-dynamic-cursors (MIT): https://github.com/VirtCode/hypr-dynamic-cursors
- Hall of fame directory: https://hypr.land/hall_of_fame/
- Featured plugins directory: https://hypr.land/plugins
