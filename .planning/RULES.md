# vinOS project rules

Durable rules that apply across all phases. Any phase plan, execution, or review MUST honor these. If a task appears to require violating one, stop and ask.

## Model policy

**Driver seat is 100% Claude Opus 4.7 (1M context)** until vinOS ships a stable ISO release.

- All planning, execution, research, review, and debug work runs through Claude Opus 4.7 1M.
- No routing of driver-seat work through local Ollama models (Qwen / DeepSeek / Kimi).
- Local models registered in `configs/vinos/litellm/proxy.yaml` are reserved for autonomous background grinding (dev-engine vision), not for the driver.
- Revisit against Sonnet only after a stable release ships.

## Development baseline

**All new work branches from `v1.1.0`.**

- `v1.1.0` = the permanent gold copy, confirmed working on T2 Mac hardware end-to-end.
- Do NOT cherry-pick from `v1.0.19` (parked Omarchy-fork ship) or from any `v2.x` (abandoned).
- The `v1.1.0` git tag anchors the source tree; branch new work from `v1.1.0`, not from any newer commit on `main`.

## No Omarchy — HARD RULE

**vinOS ships zero Omarchy code, configs, forks, or overlays.**

- No `omarchy` package in the ISO.
- No cloning `basecamp/omarchy`, no sourcing their install script, no vendoring their config files.
- If we want feature parity with an Omarchy behavior: read their public repo for ideas, then write our own from scratch in `iso/profile/` or `iso/airootfs-overlay/`.
- Attribution: since we ship none of their code, Omarchy is not listed in `NOTICES.md` or About.

## ISO storage & retention

**All ISOs live in `/data/projects/vinos/iso/out/`.** No separate archive directory.

Retention policy at any point in time:
- Keep the **last 3 successful builds**.
- Keep `vinos-1.1.0-x86_64.iso` **permanently** — never overwrite, rebuild, or delete under any circumstance.
- Prune builds older than the last 3 ONLY after the newest build passes the regression harness (`iso/qa/verify-shipped-iso.sh`).
- Each ISO ships with a sidecar `vinos-<version>-x86_64.iso.sha256`.

Retention supersedes the older "last 2" rule.

## Ship-gate discipline

- Never hand the user an ISO without running `iso/qa/oneshot.sh` first (static + container + QEMU screendumps + regression harness).
- Never burn an ISO to USB via raw `dd`; use `iso/flash.sh` — it enforces USB-transport check + two-typed confirmations.

## Preservation guarantees

- `v1.1.0` ISO: never deleted, ever. Reinforced twice in memory.
- `v1.1.0` git tag: never re-pointed, never deleted.
- `NOTICES.md` compliance content: never removed without user sign-off.

## When to update this file

Any change here requires an explicit user directive. Do not silently loosen a rule to make a task easier — flag the conflict instead.
