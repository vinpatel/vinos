# Contributing to vinOS

Thanks for wanting to help. vinOS is a small project with strong opinions — reading this doc + [VISION.md](VISION.md) + [DECISIONS.md](DECISIONS.md) first will save both of us time.

## Ground rules (read these first)

vinOS's durable rules live in [`../.planning/RULES.md`](../.planning/RULES.md). Every contribution must respect them. Highlights:

- **Baseline:** all new work branches from `v1.1.0`. Do not build on top of `main` if `main` diverges from `v1.1.0` unexpectedly — file an issue instead.
- **No Omarchy code, ever.** Zero Omarchy code, configs, forks, or overlays. Commit messages don't reference the name. If you want a feature Omarchy has, read their public repo for ideas and write our own from scratch.
- **Ship-gate:** never send anyone an ISO that hasn't passed `iso/qa/oneshot.sh`. This is a hard rule ([ADR-001](DECISIONS.md#adr-001)).
- **Preserve `v1.1.0` forever.** Never overwrite, rebuild, or delete the `v1.1.0` ISO or re-point the `v1.1.0` git tag.
- **ISO retention:** keep last 3 built ISOs + `v1.1.0` permanent. Prune older only after new build passes the regression harness.

If a PR seems to require violating a rule, open a discussion first — don't silently break it.

## Getting set up

### Local dev environment

You need:
- A Linux host (any modern distro; macOS/Windows via a Linux VM)
- Docker (or Podman with the docker CLI shim)
- Git
- A text editor
- ~15 GB free disk
- Optionally `/dev/kvm` for fast QEMU testing

```bash
git clone git@github.com:vinpatel/vinos.git
cd vinos
git checkout v1.1.0     # or the branch you want to base work on
```

Read [BUILDING.md](BUILDING.md) for the full build flow.

### Repo tour

Every top-level directory has a purpose:

| Path | What lives here |
|---|---|
| `iso/` | ISO build system — archiso profile, build.sh, flash.sh, QA harness |
| `install/` | Installer scripts for the install-on-Arch path (Path B) |
| `bin/` | The 88 `vinos-*` helper scripts (menu, doctor, cheatsheet, hyprland-*, hw-*, etc.) |
| `config/` | End-user config installed to `/etc/skel` (hypr, waybar, walker, mako, foot, kitty, ghostty, alacritty) |
| `configs/vinos/` | System config artifacts installed to `/etc/vinos/` (litellm, routines) |
| `docs/` | User + developer documentation (you're reading it) |
| `.planning/` | Active planning + rules (governs future work) |
| `site/` | The vinos.computer website source |
| `assets/` | Logos, wallpapers, screenshots |

### Where to make changes

- **Fix a `vinos-*` script:** edit under `bin/`
- **Change a keybinding or Hyprland behavior:** edit `config/hypr/`
- **Add / drop a package:** edit `iso/packages.live` (live-ISO-specific) or install scripts (installed-system-specific), regenerate via `iso/gen-packages.sh`
- **Fix a boot-menu entry:** edit `iso/profile/efiboot/loader/entries/*.conf` (UEFI) or `iso/profile/syslinux/*.cfg` (BIOS)
- **Change the live-user setup:** edit `iso/airootfs-overlay/etc/systemd/system/vinos-live-init.service`
- **Add a decision doc:** append an ADR to `docs/DECISIONS.md` (top of file; higher numbers first)

## Commit style

- **Present-tense, imperative subject.** "add Hyprland monitor helper", not "added" or "adds".
- **Under 70 characters** for the subject line.
- **Body wrapped at 72 columns**, explains the *why* (the *what* is in the diff).
- **No trailer.** vinOS commits do not include `Co-Authored-By: Claude` or similar — repo is public and sponsor-facing. This is a hard rule.
- **Small, atomic commits.** One logical change per commit. If you find yourself writing "and also" in the body, split.
- **Never** the word "omarchy" in a commit message ([ADR-007](DECISIONS.md#adr-007)).

### Examples of good commits

```
iso: profiledef only sets perms on the real vinos-* files, not the symlinks

mkarchiso's _set_permissions resolves symlinks via realpath, which fails
("Outside of valid path") because the target /usr/share/vinos/... is
absolute and doesn't exist on the build host. Symlinks inherit perms
from their target at access time on Linux, so this is fine.
```

```
config/hypr: switch wallpaper daemon from swaybg to swww

swww supports smooth transitions when vinos-theme swaps wallpapers on
theme change. swaybg has been reliable but is static-only. Rules out
the "flicker on theme switch" UX gap in ADR-011.
```

## PR flow

1. **Fork or branch from `v1.1.0`** (or the current release-target branch if working on a specific milestone).
2. **Make focused commits.** One logical change per commit; use `git commit --patch` liberally.
3. **Run the ship gate locally before opening the PR:**
   ```bash
   bash iso/qa/oneshot.sh
   ```
   If any layer fails, fix the underlying issue — don't skip. (`iso/qa/oneshot.sh` ships in v1.2.0; for v1.1.0-based PRs use `iso/test.sh --mode matrix` instead.)
4. **Open the PR** targeting `main`. In the body, explain:
   - The problem or opportunity motivating the change
   - The approach taken and why
   - How you tested (which layers of the ship gate, plus any manual verification)
   - Any follow-ups you're deliberately leaving for a later PR
5. **Address review comments** with follow-up commits. Squashing happens at merge time — don't force-push during review unless a reviewer asks.
6. **Merge criteria:**
   - All ship-gate layers pass in CI
   - At least one reviewer approves
   - No unresolved review comments
   - `docs/` updated if the change is user-visible
   - `.planning/RULES.md` unchanged unless the PR is explicitly about rule changes

## Testing conventions

vinOS relies on four testing layers:

1. **Unit-level:** bats-lite bash tests for `vinos-*` scripts. Add tests under `tests/` mirroring the `bin/` layout.
2. **Container-level:** `iso/build.sh` runs the whole build in Docker. If it succeeds, the manifest is valid.
3. **QEMU acceptance:** `iso/test.sh --mode matrix` boots the ISO in QEMU and asserts kernel + systemd + login reach a known-good state.
4. **Regression harness:** `iso/qa/verify-shipped-iso.sh` (v1.2.0+) asserts every past fix is still intact.

If you're adding a feature, add a test at whichever layer catches the failure. If you're fixing a bug, add a regression test that fails without your fix.

## Design decisions

Small changes don't need an ADR. Large or opinionated changes do. Rules of thumb:

- **Requires an ADR** — new architecture, new dependency, new distribution target, security posture change, anything reversing a prior ADR
- **Doesn't need an ADR** — bug fixes, doc updates, style/UX polish, adding to an existing pattern

If in doubt, open a discussion first: "I'm thinking about X, does this warrant an ADR?"

Format for a new ADR:
```
## ADR-NNN · Short title

**Date:** YYYY-MM-DD · **Status:** proposed | locked | superseded | permanent

### Context
### Decision
### Rationale
### Consequences
### Supersedes (optional)
```

Copy the template from the bottom of [DECISIONS.md](DECISIONS.md).

## Filing bugs

Good bug reports include:

- **vinOS version.** From `/etc/vinos/VERSION` or the ISO filename.
- **Hardware.** Model + CPU + GPU. On T2 Macs: which year, which model exactly.
- **What you did.** Exact commands or steps.
- **What happened.** Exact output or observed behavior.
- **What you expected.**
- **Screenshots or logs.** `vinos-doctor --json` is a helpful attachment.

File at [github.com/vinpatel/vinos/issues](https://github.com/vinpatel/vinos/issues).

## Filing feature requests

- **Read [ROADMAP.md](../.planning/ROADMAP.md) first.** The feature may already be planned.
- **Read [VISION.md](VISION.md) first.** The feature may be an explicit non-goal.
- **Frame it as a user story.** "As a <role>, I want <capability> so that <outcome>." Not "add support for X."

File at [github.com/vinpatel/vinos/discussions](https://github.com/vinpatel/vinos/discussions) → Ideas category.

## Working with AI collaborators

Because vinOS is developed with Claude Code as the driver, contributors who use Claude Code (or similar tools) should:

- **Point Claude Code at [`../.planning/RULES.md`](../.planning/RULES.md)** — durable rules the AI must honor
- **Point Claude Code at [`VISION.md`](VISION.md) + [`DECISIONS.md`](DECISIONS.md)** — the "why" behind the codebase
- **Point Claude Code at [`ARCHITECTURE-v1.1.0.md`](ARCHITECTURE-v1.1.0.md)** — the frozen baseline it must not regress

AI-assisted PRs are welcome, but the human PR author is responsible for the change — review AI output as carefully as you'd review a colleague's diff.

## Etiquette

- Be direct. State the problem and the proposed fix — no throat-clearing.
- Assume good faith. If a reviewer's comment seems harsh, they're saving both of you time.
- Don't argue in issues. Move complex discussions to Discussions.
- Attribution goes to whoever wrote the code, not to who ran the AI that helped write it.
- Sponsorship isn't required, but it keeps the lights on: [github.com/sponsors/vinpatel](https://github.com/sponsors/vinpatel) or [opencollective.com/vinos](https://opencollective.com/vinos).

## License

vinOS is MIT-licensed. Contributions are accepted under the same MIT license.

---

*Thanks. This project exists because a lot of small contributors improved it. You're one of them now.*
