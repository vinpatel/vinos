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

### Open items carried into later milestones
- **M2:** flesh out `01-base.sh` (base packages + yay), `04-services.sh`
  (ufw/sshd/greetd enablement, warn-and-continue on ufw), and wire
  `tests/test.sh` to run `install.sh --skip 02` twice in an Arch container
  (idempotency check per §8).
- **M3:** implement `05-branding.sh` (os-release override, wallpaper, logo,
  `vinos-*` symlinks) and finish `bin/vinos-doctor` PASS/FAIL checks.
- **M4:** convert `overlays/example/install/10-hello.sh` from log-only into a
  real `cowsay` install and add the §6 overlay-marker assertion to test.sh.
- **M5:** implement `02-desktop.sh` (Hyprland stack + greetd config) and
  populate `config/hypr/…`, `config/waybar/…`, `config/alacritty/…`.
- **Deferred:** `--resume NN` alias for `--skip NN`; only add if a real user
  hits the resume ergonomics gap.
- **Env quirk (from CLAUDE.md):** UFW/nftables sync failure — `04-services.sh`
  must `warn-and-continue`, never hard-fail. Enforce with a test in M2.
