# Phase 01 — CAPTURE (v1.0.18 baseline lock)

**Type:** infrastructure (no ISO artifact)
**Depends on:** none
**Ships as:** git tag `v1.0.18` + archive branches + `.planning/` initialization + running Hermes/LiteLLM
**Duration:** 3 days
**Requirements satisfied:** R1, R8, R19

## Goal

Everything backed up. Nothing at risk of loss. New work has an immovable floor to build from. GSD infrastructure operational.

## Scope (in)

- Retroactively tag v1.0.18 in git (identify baseline commit from `iso/out/build-v2.0.18-r1.log` timestamp)
- Create `experiments/2.1.0-2026-08-03` branch preserving current `main` state (contains 2.1.0 experimental work)
- Create `archive/pre-gsd-2026-08-03` branch as full snapshot
- Reset `main` to v1.0.18 **LOCALLY ONLY** — do NOT push force until explicit user ACK
- Sync `docs/`, `iso/`, `~/.claude/projects/-data-projects-vinos/memory/` to R2 (`s3://vinos-archive/2026-08-03/`)
- Copy v1.0.18 ISO to `dl.vinos.computer/releases/v1.0.18/` with sha256
- Move `iso/out/build-*.log` to `iso/archive/build-logs/`
- Materialize `.planning/` structure: STATE.md, ROADMAP.md, REQUIREMENTS.md, config.json, per-phase SPECs
- Symlink `~/.hermes/config.json`, `~/.gsd/config.json` to `.planning/config.json`
- Symlink `~/.litellm/config.yaml` to `configs/vinos/litellm/proxy.yaml`
- Install Kimi-Linear-48B-A3B as Ollama model `kimi-code`
- Update `configs/vinos/litellm/proxy.yaml` to include `vinos-kimi-local` → kimi-code
- Start LiteLLM proxy as systemd user service
- Verify GSD can plan Phase 03 via LiteLLM-routed executor

## Scope (out)

- Any functional code change to `install/`, `bin/`, `configs/`, `iso/profile/`
- Merging any 2.1.0 work back into main (parked, not merged)
- Any ISO build
- Any deletion of files or history

## Edge coverage

- **covered:** `v1.0.18` tag exists on origin
- **covered:** `archive/pre-gsd-2026-08-03` and `experiments/2.1.0-2026-08-03` branches exist on origin
- **covered:** `main` reset to v1.0.18 (locally, awaiting user ACK for push)
- **covered:** off-site R2 backup exists — random-file sha256 verify succeeds
- **covered:** `.planning/` directory populated with STATE + ROADMAP + REQUIREMENTS + config.json + phase SPECs
- **covered:** `ollama list` shows `kimi-code`, `qwen3-coder:30b`, `qwen2.5-coder:7b`
- **covered:** `curl http://localhost:4000/v1/models` (LiteLLM proxy) returns `vinos-executor`, `vinos-planner`, `vinos-checker`, `vinos-kimi-local` at minimum
- **backstop:** verify Hermes + GSD read the same config.json (both symlinks resolve to `.planning/config.json`) — check via `readlink -f ~/.hermes/config.json`
- **unresolved:** whether Anthropic + OpenRouter API keys are already set on Vin's server (planner assumption: yes; if not, add step to prompt Vin for keys)

## Human checkpoints

1. **Before `git push --force-with-lease origin main`** — destructive to remote; requires ACK
2. **Before R2 sync destroys old snapshots** — if R2 bucket already has content, confirm overwrite

## Ship gate

- ✅ `git tag v1.0.18` exists on origin
- ✅ Archive + experiments branches on origin
- ✅ R2 backup verified (random-file sha256 match)
- ✅ `.planning/` fully materialized (all files exist and valid JSON/markdown)
- ✅ LiteLLM proxy running on :4000, responds to `/v1/models`
- ✅ `/gsd-plan-phase 3` succeeds — produces `.planning/phases/03-v1-0-19-docs/PLAN.md` via Kimi/Qwen executor

## Deliverables (file list)

- `.git/refs/tags/v1.0.18`
- `.git/refs/heads/archive/pre-gsd-2026-08-03`
- `.git/refs/heads/experiments/2.1.0-2026-08-03`
- `.planning/STATE.md`
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/config.json`
- `.planning/phases/01-capture/SPEC.md` (this file)
- `.planning/phases/02-dev-flow/SPEC.md`
- `.planning/phases/03-v1-0-19-docs/SPEC.md`
- ... (SPECs 04–12 stubbed at minimum)
- `configs/vinos/litellm/proxy.yaml` + `README.md` (already exist)
- `configs/vinos/systemd/vinos-litellm.service` (new: systemd user unit)
- `iso/archive/build-logs/` (moved from `iso/out/`)
- `~/.hermes/config.json` → `.planning/config.json`
- `~/.gsd/config.json` → `.planning/config.json`
- `~/.litellm/config.yaml` → `configs/vinos/litellm/proxy.yaml`
- Ollama registered model: `kimi-code` (from Kimi-Linear-48B-A3B-Instruct GGUF)
