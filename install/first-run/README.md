# First-run scripts

Fire ONCE after `vinos-install-disk` completes, gated by
`~/.local/state/vinos/first-run.mode`. Never fire on live-boot.

Each script MUST be idempotent — first-run can restart mid-way and
re-execute. Every script exits 0 on missing tools / already-configured
state; a failing first-run must never brick a fresh install.
