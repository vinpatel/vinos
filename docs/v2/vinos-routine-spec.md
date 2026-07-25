# vinos-routine — scheduled autonomous agents

**Status:** draft (2026-07-25) · **Target:** v2.0.4

## Positioning

vinOS is the first OS where autonomous agents run on a schedule as first-class
citizens — not cron jobs, not Zapier flows, but real Claude/Ollama-powered
agents with tools, memory, and verification, running in the background while
you sleep.

Everyone else has agents you *talk to*. vinOS has agents that **run without you**,
on your machine, on your terms.

## Core concepts

- **Routine** — declarative TOML file describing an agent, its schedule, its
  tools, its output destination, and its budget.
- **Registry** — `~/.vinos/routines/*.toml` (user) + `/etc/vinos/routines/*.toml`
  (system defaults, shipped in ISO).
- **Runtime** — one systemd user timer + oneshot service generated per routine.
  Triggers `vinos-routine run <name>`.
- **Output store** — `~/.vinos/routines/state/<name>/YYYY-MM-DD-HHMM.md` +
  `last-run.json`. `vinos-brief` opens today's outputs in a walker panel.
- **Ledger** — SQLite at `~/.vinos/routines/state/ledger.db`. Every run logs
  tokens, dollars, duration, exit status. Enforces per-run and per-day caps.

## Routine file format

```toml
# ~/.vinos/routines/day-brief.toml
[routine]
name = "day-brief"
description = "Morning briefing: inbox, calendar, GitHub, top-of-mind"
enabled = true

[schedule]
cron = "0 6 * * *"           # 6am daily (standard cron)
timezone = "America/New_York"
jitter = "5m"                # random ±5m to spread load / avoid rate limits

[agent]
route = "anthropic"          # anthropic | ollama
model = "claude-sonnet-4-6"  # or e.g. "llama3.2:3b" for local
system = """
You are the user's morning briefing agent. Concise, action-oriented,
skip filler. Format: markdown, ≤500 words.
"""
tools = [
  "read:~/inbox/*",
  "shell:gh api /notifications",
  "shell:gcalcli agenda today",
]
memory = "session"           # session | persistent | shared

[output]
type = "brief"               # brief | notification | file | webhook
title = "Today · {{date}}"
open_on_login = true         # surface next time user logs in
notify = true                # also fire a mako notification when done

[budget]
max_tokens_per_run = 20000
max_dollars_per_day = 0.50
on_exceed = "skip"           # skip | degrade-to-local | notify
```

## CLI

```
vinos-routine list                    # all routines + next-run + last status
vinos-routine enable <name>           # activate systemd timer
vinos-routine disable <name>          # deactivate (keeps config)
vinos-routine run <name>              # ad-hoc run, streams to stdout
vinos-routine logs <name> [--tail]    # per-routine execution log
vinos-routine cost [--today|--week]   # ledger summary + top spenders
vinos-routine create <name>           # scaffold new routine from template
vinos-routine install <slug|url>      # install from vinos.computer/routines
vinos-routine edit <name>             # opens $EDITOR on the toml
```

## Waybar module

`vinos-routine-status` — single-line indicator:

```
󰚩 3 routines · next 06:00 · today $0.04
```

- Left click → opens brief panel (walker plugin) with today's outputs
- Right click → menu: enable/disable, view logs, view cost breakdown
- Icon color signals health: green (ok), yellow (budget warning), red (last run failed)

## Starter routines shipped in ISO

Five system-default routines under `/etc/vinos/routines/`, all **disabled** by
default. `vinos-welcome` first-boot flow prompts the user to enable the ones
they want.

| Slug | Schedule | Purpose |
|---|---|---|
| `day-brief` | 6:00 daily | Inbox + calendar + GitHub review, opens on login |
| `inbox-triage` | hourly | Drafts responses to unread emails (marks with tag, **never sends**) |
| `github-review` | 09:00 / 13:00 / 17:00 | Summarizes new PRs across your repos, flags what needs your review |
| `research-recap` | 22:00 nightly | Reads new saved articles/PDFs in `~/Reading`, generates connections + spaced-repetition cards |
| `evening-shutdown` | 18:00 daily | Summarizes what you shipped today, drafts tomorrow's top-3, files a git note |

## System boundaries (hard rules)

1. **Never send outbound comms without explicit user confirmation.** Routines can
   draft emails, PRs, messages — but the runtime enforces `auto_send=false`
   unless the routine is explicitly signed with the user's key.
2. **Sandboxed shell tools.** Only commands declared in `[agent].tools` are
   invocable. Each routine runs under bwrap with a scoped filesystem view.
3. **Rate limits + budgets enforced by the runtime, not the agent.** Agents
   cannot lie their way past the ledger — the runtime intercepts tool calls
   and refuses when budget is exceeded.
4. **All routine outputs are read-only from the routine's perspective** — the
   agent writes to a scratch, the runtime moves to the state store atomically.
5. **Failures never silently drop.** If a routine fails 3 runs in a row, the
   timer auto-disables and mako notifies the user.

## Architecture

```
vinos-routine (CLI + libexec)
├── ~/.vinos/routines/*.toml           # user routines
├── /etc/vinos/routines/*.toml         # system defaults (5 starters)
├── ~/.vinos/routines/state/
│   ├── <name>/YYYY-MM-DD-HHMM.md      # results, human-readable markdown
│   ├── <name>/last-run.json           # metadata: tokens, dollars, duration
│   └── ledger.db                      # SQLite: cost/usage/history
├── /etc/systemd/user/vinos-routine@.service  # oneshot template
├── /etc/systemd/user/vinos-routine@.timer    # timer template
└── ~/.config/systemd/user/vinos-routine@<name>.timer  # generated per routine
```

Runtime lifecycle:
1. `vinos-routine enable <name>` — parses toml, generates systemd timer,
   `systemctl --user enable --now vinos-routine@<name>.timer`
2. Timer fires → oneshot invokes `vinos-routine run <name>`
3. Runtime reads toml, checks budget in ledger, spawns agent (Anthropic SDK or
   Ollama HTTP) with declared tools sandboxed via bwrap
4. Agent streams output → runtime captures to scratch → atomic move to state
   store → updates ledger → fires notification if `[output].notify`

## Sponsor surface

`vinos.computer/routines`:
- Public gallery, one-click install: `vinos-routine install founder-morning`
- Author profiles link to GitHub Sponsors / Open Collective
- **Sponsor a routine tier** ($10/mo): author's routine featured, "Sponsored by
  X" badge, priority in gallery
- **Corporate tier** ($500+): bespoke routine bundle for role (VC-morning,
  PhD-recap, SRE-oncall, etc.), maintained for 12 months

## MVP scope (v2.0.4)

**In:**
- `vinos-routine` CLI: list, enable, disable, run, logs, cost, create, edit
- systemd timer + oneshot template + per-routine generator
- Ledger (SQLite) with per-run token + dollar tracking + daily-cap enforcement
- 3 starter routines: `day-brief`, `github-review`, `evening-shutdown`
- Waybar module (minimal: next run + today's cost, click → brief panel)
- Brief panel (walker plugin reading `state/*/YYYY-MM-DD-*.md`)
- One preloaded Ollama model in ISO (`llama3.2:3b`, ~2 GB) for local route
- Anthropic SDK route (via `ANTHROPIC_API_KEY` env or `~/.vinos/secrets/anthropic-key`)

**Out (deferred):**
- `inbox-triage` and `research-recap` (v2.0.5, need IMAP + PDF/HTML readers)
- Public gallery + `vinos-routine install <slug>` (v2.0.5)
- `auto_send` outbound comms (v2.1, needs gpg opt-in flow)
- Cross-machine sync of routine state (v2.2)
- Web dashboard (v2.2)
- bwrap sandbox for tools (v2.0.5 — MVP runs with `nsjail`-lite or just
  cwd restriction; call this out as known limitation)

## Open questions

- **Ollama model choice** — `llama3.2:3b` is 2 GB, `qwen2.5:7b` is 4.5 GB but
  handles tool use better. Bundle 3b (fast, small ISO delta) or 7b (better
  routines, ISO grows to 7 GB+)?
- **Anthropic key onboarding** — first-boot prompt in `vinos-welcome`? Or
  purely env-based (BYO key)?
- **Ledger currency** — assume USD, or per-user? Localized display?
- **Routine sharing format** — plain TOML in a git repo per author, or a
  bundled `.vinos-routine` archive with system prompt + tool defs baked in?
