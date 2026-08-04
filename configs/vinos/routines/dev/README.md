# vinOS 24x7 Dev Flow — Routines

The routines here are the **self-hosting development pipeline**: vinOS builds vinOS.

Model routing:
- **Local (~80%)**: Qwen3-Coder 30B + Kimi-Linear 48B-A3B via Ollama
- **Cloud (~20%)**: Claude Sonnet 4.6 / Opus 4.7 via Anthropic API
- **All routed through LiteLLM proxy on `localhost:4000`** (config: `configs/vinos/litellm/proxy.yaml`)

## Routine catalog

| Routine | Trigger | Model role | Human ACK? |
|---|---|---|---|
| `vinos-dev-lint` | pre-commit git hook | `vinos-executor` (local) | No |
| `vinos-dev-test` | pre-push git hook | `vinos-executor` | No |
| `vinos-dev-code-review` | PR opened / updated | `vinos-reviewer` (Claude Sonnet) | Yes (merge) |
| `vinos-dev-arch-review` | changes under `install/` or `iso/profile/` | `vinos-architect` (Claude Opus) | Yes (merge) |
| `vinos-dev-security-review` | changes to `SECURITY.md`, `install/`, `iso/`, `bin/vinos-*` | `vinos-architect` | Yes (merge) |
| `vinos-dev-docs-sync` | merge to `main` | `vinos-executor` | No (auto-commit) |
| `vinos-dev-changelog` | version tag | `vinos-executor` + `vinos-reviewer` | Yes (final edit) |
| `vinos-dev-release-notes` | version tag | `vinos-reviewer` | Yes (polish) |
| `vinos-dev-qa-nightly` | systemd timer @ 03:00 | `vinos-executor` + `vinos-checker` | Only on failure |
| `vinos-dev-triage` | systemd timer @ 08:00 | `vinos-reviewer` | Yes (issue triage) |

## Budget

Global caps (also enforced by LiteLLM proxy):
- Per run: $0.50 (typical), $2.00 (architecture/security escalations)
- Per day: $20.00 hard cap
- On exceed: `notify` — never silent-skip

Local model runs are $0.00 marginal. The cap only bites on Claude escalations.

## Ledger

`~/.vinos/dev-flow-ledger.sqlite` — schema:

```sql
CREATE TABLE run (
  run_id           TEXT PRIMARY KEY,
  routine          TEXT NOT NULL,
  triggered_by     TEXT NOT NULL,     -- git-hook | timer | github | manual
  started_at       TIMESTAMP NOT NULL,
  finished_at      TIMESTAMP,
  model            TEXT NOT NULL,
  prompt_tokens    INTEGER,
  completion_tokens INTEGER,
  cost_usd         REAL,
  escalated        INTEGER DEFAULT 0, -- 1 if routed to Claude
  human_ack        TEXT,              -- ISO timestamp of ACK, if any
  result           TEXT NOT NULL,     -- pass | fail | blocked | acked
  notes            TEXT
);
CREATE INDEX idx_run_routine_time ON run(routine, started_at);
CREATE INDEX idx_run_ack ON run(human_ack) WHERE human_ack IS NOT NULL;
```

## Human checkpoint contract

For any routine with `human_ack_required = true`, the runtime:
1. Writes result + reasoning to `~/.vinos/routines/state/<routine>/YYYY-MM-DD-HHMM.md`
2. Notifies via mako (desktop) OR Discord webhook (headless)
3. **Blocks forward progress** until an ACK arrives (via `vinos-routine ack <run_id>` or Discord reaction)
4. Records the ACK timestamp in the ledger

**Never bypass the ACK.** If a routine passes without human ACK when one was required, that's a P0 bug in the runtime.

## Adding a routine

1. Copy `vinos-dev-lint.toml` as template
2. Set `name`, `description`, `[trigger]`, `[model]`, `[budget]`
3. Define steps in `[[step]]` blocks
4. Set `[human_checkpoint].required` if the routine's output affects one of the 8 change classes (see PLAN §5.3)
5. Test with `vinos-routine run <name> --dry-run`
6. Commit to `configs/vinos/routines/dev/`

## Deploying to system

Copied to `/etc/vinos/routines/dev/` at install time by `install/03-configs.sh`. Users can add their own routines to `~/.vinos/routines/`.

## What Phase 02 delivers autonomously

Only `vinos-dev-lint.toml` is authored by hand (this repo). The other 9 routines will be authored by the **autonomous flow itself** as its first proof-of-work — Kimi drafts each TOML, Claude reviews, Vin ACKs before merge. That's the training run.

If the autonomous flow can't produce 9 routine TOMLs correctly, Phase 03 (v1.0.19 ship via autonomous flow) shouldn't proceed. This is the go/no-go gate.
