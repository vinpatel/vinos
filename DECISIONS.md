# vinOS decisions log

Ambiguity resolutions recorded here per CLAUDE.md workflow.

## M1 — Skeleton
- Individual install scripts (`install/01..05-*.sh`) ship as loggable stubs so
  the orchestrator can enumerate them for `--dry-run`. Real bodies land in
  their owning milestones (M2/M3/M5).
- `--skip NN` accepts the two-digit prefix (e.g. `--skip 02`); the spec
  mentions `--resume` as an acceptable alternative — deferred until needed.
- Overlay shadowing is applied by *basename match* on the numbered filename,
  which naturally handles the sanctioned 02/05 shadow points without a
  hardcoded allowlist.
- `bin/vinos-version` reads `VERSION` from repo, `~/.local/share/vinos`, or
  `/usr/share/vinos` (in that order) so it works both pre- and post-install.

## M2 — Base install
- AUR bootstrap uses **`yay-bin`** (prebuilt binary PKGBUILD) rather than
  compiling `yay` from source. Spec is silent on which; `yay-bin` is faster
  and preserves the "same yay CLI" contract for 01-base.
- Container/no-systemd hosts: added `systemctl_enable` helper in
  `lib/common.sh` that skips enable when `/run/systemd/system` is missing
  and warns (not fails) on enable errors. Keeps 04-services idempotent on
  both real Arch and Docker.
- UFW `enable` warn-and-continue is exercised by the container test — inside
  a default Docker container the iptables/nftables call fails with
  `Permission denied` and the test still exits 0, matching the CLAUDE.md
  UFW quirk.
- `tests/test.sh` M2 scope: static Rule 1 / Rule 2 grep guardrails, the
  three dry-run plans, then a docker `archlinux:latest` run that executes
  `install.sh --skip 02` twice (idempotency). Overlay assertion and
  `vinos-doctor` PASS check deferred to their owning milestones (M4/M3) so
  we do not gate M2 on their still-stub scripts.

## M3 — Branding
- `/etc/os-release` rewrite preserves every original key except the five
  vinOS overrides (NAME, PRETTY_NAME, ID, ID_LIKE, VERSION_ID); backup to
  `/etc/os-release.arch.bak` happens exactly once, so re-runs regenerate
  from the pristine Arch original rather than compounding on prior output.
- `bin/vinos-*` land under **`/usr/share/vinos/bin/`** and are symlinked
  into `/usr/local/bin`. Spec text says "symlink `bin/vinos-*` →
  `/usr/local/bin/`"; installing the shared copy first avoids the fragile
  case of `/usr/local/bin/vinos-doctor` pointing into a per-user
  `~/.local/share/vinos/bin/` that other users can't read. `VERSION` is
  copied alongside so `vinos-version`'s existing probe hits it.
- `default/wallpaper.png` is a **generated composite**: `vinos-512.png`
  (from the locked `assets/logo/`) centered on a 1920x1080 `#1a1b26`
  background, produced once via ImageMagick. `assets/logo/` is not
  modified — the composite is a derived artifact committed under
  `default/` where the spec expects it.
- `vinos-doctor` reports **PASS / FAIL / SKIP**; only FAIL causes a
  non-zero exit. Service checks SKIP when `/run/systemd/system` is
  absent, mirroring the `systemctl_enable` container semantics.
- Test.sh runs `git add -A && git commit -m "test snapshot"` inside the
  container after `cp -a` so the copy looks like a clean deployed clone;
  otherwise `vinos-doctor`'s "repo clean" check would FAIL on any
  session that runs the test before final commit.

### Open items carried into later milestones
- **M4:** convert `overlays/example/install/10-hello.sh` from log-only into a
  real `cowsay` install and add the §6 overlay-marker assertion to test.sh.
- **M5:** implement `02-desktop.sh` (Hyprland stack + greetd config) and
  populate `config/hypr/…`, `config/waybar/…`, `config/alacritty/…`.
- **Deferred:** `--resume NN` alias for `--skip NN`; only add if a real user
  hits the resume ergonomics gap.
- **Env quirk (from CLAUDE.md):** UFW/nftables sync failure — `04-services.sh`
  must `warn-and-continue`, never hard-fail. Enforce with a test in M2.
