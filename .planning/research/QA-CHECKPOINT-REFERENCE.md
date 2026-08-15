# QA & Checkpoint Reference — structural takeaways

**Filed:** 2026-08-15
**Motivating incident:** v1.2.5 shipped a "polished waybar" that never rendered. Waybar aborted on `style.css:11` — `font-feature-settings` is web CSS, not GTK CSS — and on `style.css:161` — `@keyframes` block with `inset` box-shadow. Wallpaper showed; bar did not. Neither `iso/qa/config-lint.sh` nor `iso/test-desktop.sh` (idle screendump) caught it. The bug was found only after the QEMU swap, live, by running `waybar` in a foot terminal.

**Rule reminder:** `feedback_no_omarchy_ever_2026_08_08` — zero Omarchy code/configs/overlay ever ships in vinOS. This doc is a **structural** reference only. We inspected `github.com/basecamp/omarchy` for organization patterns; we copy no code, no configs, no themes, no scripts.

---

## What we looked at

Top-level layout of `basecamp/omarchy`:

```
agents/skills           — agent capabilities
applications            — .desktop-tier config
bin                     — executables (self-describing via metadata comments)
config                  — config trees
default                 — shipped defaults
docs                    — dev docs
etc                     — system files
install                 — staged install (subdirs below)
manual                  — authoritative user manual
migrations              — version-upgrade scripts
shell                   — shell configs
test                    — single test harness
themes                  — visual themes
AGENTS.md, CLAUDE.md    — agent contracts at repo root
version                 — one-line version file
```

`install/` is staged with named subdirectories: `preflight/`, `config/`, `login/`, `packaging/`, `post-install/`, `first-run/`, `helpers/`. Package lists are top-level: `omarchy-base.packages`, `omarchy-other.packages`.

`test/` is a single script (`omarchy-cli-test.sh`) that exercises the CLI dispatch layer:

- helper primitives (`pass`, `fail`, `assert_output_contains`)
- self-describing binary metadata validation (every `bin/` script has header comments the harness parses)
- command discovery, JSON output contract, group help
- edge cases via temp binaries (malformed metadata, partial fields, out-of-order comments)
- end-to-end dispatch with timeout guards

## Structural takeaways for vinOS

Adopt selectively, on top of what we already have. No code/config copy.

1. **`preflight/` as a first-class install stage.** Currently our `install/` is flat (`02-desktop.sh`, `05-branding.sh`, …). A named `preflight/` step communicates intent: "run these checks before touching the target." Not a rename yet — a directory added in front, invoked by `install/00-preflight.sh`.

2. **Self-describing `bin/` scripts + a validator.** Their harness parses metadata comments from every `bin/` script. We already do this weakly — `bin/vinos-toggle-enabled` has `# vinos:summary=…` and `# vinos:args=…` headers. Formalize the convention, then wire a validator that fails the build if a shipped `bin/` script is missing headers or has malformed ones.

3. **Single-file authoritative doc.** They keep `manual/` as the source of truth. We have `.planning/TESTING.md` for QA and `.planning/ROADMAP.md` for direction — analogous. Do NOT add more doc silos.

4. **`test/` is one harness, not many.** They have one script that covers dispatch + metadata + edge cases. Our surface is bigger (ISO + configs + CLI + AI runtime), so one file doesn't work — but the principle does: **one entrypoint that fans out**. Today we have `iso/test-desktop.sh`, `iso/test-plymouth.sh`, `iso/test-super-return.sh`, `iso/qa/config-lint.sh` — four independent scripts, no single invocation. Add `iso/qa/checkpoint.sh` as the single entrypoint that runs every gate in order and fails loud on any miss.

5. **Version file at repo root.** They ship `version`; we ship `VERSION`. Same pattern, keep it.

## What we already have (do not rebuild)

- `iso/qa/config-lint.sh` — static Hyprland/autostart lint (Q1)
- `iso/qa/hmp.sh`, `iso/qa/keepalive.sh`, `iso/qemu-desktop.sh` — QEMU harness (Q2/Q3)
- `iso/test-super-return.sh` — Tier 2 keybinding gate (Q4)
- `iso/qa/loop.sh` — Tier 3 hot-reload (Q5 — landed 2026-08-14, sshd overlay still pending)
- `bin/vinos-toggle-enabled`-style metadata headers on a handful of `bin/` scripts

## What is missing (v1.2.5 regression proves)

**A pre-ship checkpoint that runs every user-facing config through its own parser.** `iso/qa/config-lint.sh` does static grep-level checks; it does not invoke `waybar`, `mako`, `hyprctl`, `swaybg`, `fcitx5`, `walker`, or `elephant` against their own configs. That gap is exactly where the v1.2.5 CSS bug slipped through.

## Proposed follow-on: `iso/qa/checkpoint.sh`

Design captured in task #2 (`gsd-task` — Design v1.2.6 checkpoint gate). Summary:

- `.planning/SHIP-MANIFEST.md` — declared inventory of what ships (packages, `bin/*` scripts, configs, AI/agent scripts, features). One-line per entry, machine-parseable.
- `iso/qa/checkpoint.sh` — single ship-gate entrypoint. Fans out to:
  1. `config-lint.sh` (Q1, static)
  2. Parser-validation of every declared config against its own binary (waybar, hyprctl, mako, swaybg, fcitx5, walker)
  3. Manifest coverage: every SHIP-MANIFEST item must resolve to a real file / installed binary / test
  4. `test-super-return.sh` and other Tier-2 gates
- Mandatory: `iso/build.sh` refuses to write `iso/out/vinos-*.iso` unless `checkpoint.sh` returns 0.

This is the fix for the class of bug v1.2.5 revealed, not just v1.2.5's specific bug.

---

**Related memory:**
- `feedback_no_omarchy_ever_2026_08_08` — hard rule this doc honors
- `project_track_q_qa_harness_2026_08_14` — existing harness scope
- `feedback_oneshot_before_ship` — never hand ISO without gate (violated by v1.2.5)
- `feedback_research_before_commit` — reason we inspected the reference first
