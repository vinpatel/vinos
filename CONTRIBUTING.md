# Contributing to vinOS

vinOS is solo-maintained and community-verified. The single best way to help is to **flash the ISO on a new machine and file a hardware report** — every report widens `docs/HARDWARE.md` and helps the next person's laptop boot cleanly.

## Best first contribution

[**File a hardware report**](https://github.com/vinpatel/vinos/issues/new?template=hardware-report.yml) after flashing the ISO on a machine that isn't yet in the compatibility matrix. Ten minutes of your time, months of saved debugging for someone else.

## Ways to contribute

- **Hardware reports** — see above. Highest signal-to-noise.
- **Fixes for the compatibility matrix** — if your machine works after a small tweak, PR the tweak into `install/`, `iso/`, or the relevant `config/` file.
- **New bundles** — a bundle is a plain list of packages in `install/bundles/`. Keep it under ~15 packages and single-purpose.
- **Docs** — `docs/` is prose, `docs/KEYBINDINGS.txt` is the live source for `Super+K`. Both get outdated fast.
- **Overlays** — persona forks (education, health, kiosk) live in `overlays/`. Fork-friendly by design.
- **Discussions** — [github.com/vinpatel/vinos/discussions](https://github.com/vinpatel/vinos/discussions) for questions, showcase, and ideas.

## Code style

- **Bash everywhere.** Every user-facing script is Bash, shellcheck-clean, and kept under ~80 lines. If it grows past that, split it.
- **Config lives in `config/`** and gets rsync'd to `~/.config/`. Don't touch `~/.config/` directly.
- **No magic.** Bundles are plain package lists. Helpers are readable top-to-bottom.
- **Test on real hardware** if you can. QEMU is fine for smoke tests but hardware reports are what matter.

## PR flow

1. Fork, branch, work, PR against `main`.
2. In the PR body: what changed, why, and what hardware you tested on.
3. Small PRs merge fast. If it touches ISO build (`iso/`), expect more review — the ISO is the shipping surface.

## Reporting security issues

Please **do not** file public issues for security concerns. Email `hello@vinos.computer` instead. See [`SECURITY.md`](SECURITY.md) if present.

## Code of Conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Short version: be kind, assume good faith, disagree with ideas not people.

## License

By contributing you agree your work is released under the [MIT License](LICENSE).
