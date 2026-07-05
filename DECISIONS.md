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

### Open items carried into later milestones
- **M3:** implement `05-branding.sh` (os-release override, wallpaper, logo,
  `vinos-*` symlinks) and finish `bin/vinos-doctor` PASS/FAIL checks. Add
  a `vinos-doctor` invocation to `tests/test.sh` once it can pass.
- **M4:** convert `overlays/example/install/10-hello.sh` from log-only into a
  real `cowsay` install and add the §6 overlay-marker assertion to test.sh.
- **M5:** implement `02-desktop.sh` (Hyprland stack + greetd config) and
  populate `config/hypr/…`, `config/waybar/…`, `config/alacritty/…`.
- **Deferred:** `--resume NN` alias for `--skip NN`; only add if a real user
  hits the resume ergonomics gap.
- **Env quirk (from CLAUDE.md):** UFW/nftables sync failure — `04-services.sh`
  must `warn-and-continue`, never hard-fail. Enforce with a test in M2.
