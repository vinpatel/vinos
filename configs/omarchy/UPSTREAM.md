# Omarchy — vendored upstream

Vendored from https://github.com/basecamp/omarchy at commit `e294d8278f890cd5912321cc9d7d18ac56ef4d40` (v4.0.0.alpha).
Fetched: 2026-07-23T01:40:02Z.

Licensed under Omarchy's MIT License (see LICENSE in this directory).

## Update procedure

    cd /tmp && rm -rf omarchy-vendor && git clone --depth=1 https://github.com/basecamp/omarchy.git omarchy-vendor
    cd omarchy-vendor && rsync -a --delete <same excludes> ./ /data/projects/vinos/configs/omarchy/
    # then update this file with new commit hash

## What we excluded and why

- `.git*`, `.editorconfig`, `.luarc.json` — repo hygiene, not runtime
- `README.md`, `docs/` — Omarchy's own docs; vinOS has its own
- `icon.png`, `logo.svg`, `icon.txt`, `logo.txt` — Omarchy branding; vinOS uses its own
- `AGENTS.md` — Omarchy contributor guide

## What lives here

Everything else 1:1 from upstream: `bin/`, `config/`, `default/`, `etc/`,
`install/`, `themes/`, `migrations/`, `shell/`, `applications/`, `test/`, `version`.
Do NOT edit these files inline — vinOS deltas belong in `configs/vinos/` overlays,
applied after these. See docs/v2/ARCHITECTURE.md.
