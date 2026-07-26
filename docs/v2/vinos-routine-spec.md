# vinos-routine — scheduled autonomous agents

**Status:** draft (2026-07-25) · **Target:** v2.0.6

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
# Either syntax accepted. On `enable`, cron is translated to OnCalendar.
# If both are set, oncalendar wins with a WARN.
cron       = "0 6 * * *"            # standard 5-field cron (v2.0.6)
# oncalendar = "*-*-* 06:00:00"     # or systemd-native
timezone   = "America/New_York"
jitter     = "5m"                   # random ±5m to spread load / avoid rate limits

[agent]
route          = "auto"             # anthropic | ollama | auto (v2.0.6)
local_model    = "llama3.1:8b"      # first-pass model when route=auto
premium_model  = "claude-sonnet-4-6" # escalation target when route=auto
# Legacy: `model = "..."` still works when route ∈ {anthropic, ollama}.
system = """
You are the user's morning briefing agent. Concise, action-oriented,
skip filler. Format: markdown, ≤500 words.
"""
tools = [
  "read:~/inbox/*",
  "shell:gh api /notifications",
  "shell:gcalcli agenda today",
]
memory = "persistent"        # session | persistent | shared  (v2.0.6)
tags   = ["reasoning"]       # if present, biases the router toward premium
local_context_tokens = 4096  # hint used for context_overflow detection

[agent.escalation]           # only meaningful when route = "auto" (v2.0.6)
on_low_confidence       = true
on_reasoning_task       = true
on_context_overflow     = true
on_malformed_tool_json  = true
max_escalations_per_run = 3

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

## Scheduling (v2.0.6)

`[schedule]` accepts either:

- `oncalendar = "..."` — passed through to systemd verbatim (see
  `man systemd.time`).
- `cron = "0 6 * * *"` — standard 5-field cron; on `vinos-routine enable`,
  the CLI translates this to OnCalendar and writes the systemd drop-in.

Both may be set — `oncalendar` wins, and the CLI logs a WARN. The translator
lives in `libexec/vinos_routine_cron.py` (stdlib only). See the coverage
matrix at the bottom of this doc.

## Auto-router (v2.0.6)

`route = "auto"` runs a cheap local Ollama model first, then applies four
heuristics to decide whether to escalate the *same turn* to a premium
Anthropic model:

| Trigger | Fires when… | Toggle |
|---|---|---|
| `low_confidence` | reply contains a hedge phrase ("I don't know", "not sure", "unable to", …), OR reply is < 40 whitespace tokens | `on_low_confidence` |
| `reasoning_task` | system prompt / user turn matches `\b(reasoning\|prove\|derive\|chain of thought\|step by step\|deduce\|explain why)\b`, OR `[agent].tags` contains `"reasoning"` | `on_reasoning_task` |
| `context_overflow` | local reply is empty AND Ollama's `prompt_eval_count` was ≥ 90% of `local_context_tokens` | `on_context_overflow` |
| `malformed_tool_json` | during the tool-use loop, Ollama returned `tool_calls` whose arguments failed `json.loads()` | `on_malformed_tool_json` |

`max_escalations_per_run` caps how many times a single run may escalate.
Today a run does one turn, so the effective cap is 0 or ≥ 1 — but the field
is honoured for future multi-turn routines.

The ledger records both attempts on an escalated run:

- `route = "local->premium"` (as opposed to `"local"` for a happy local run,
  or `"anthropic"` / `"ollama"` when the routine hard-picked a route)
- `escalated = 1`, `escalated_reason` = one of the four trigger names
- `input_tokens` / `output_tokens` = the *premium* attempt (what actually cost
  money); `local_input_tokens` / `local_output_tokens` = the local attempt
  we paid for in electricity only

## Memory (v2.0.6)

`[agent].memory` chooses how state carries across runs:

- `"session"` (default) — each run is a blank slate. Backwards-compatible
  with v2.0.5 routines that omit the field.
- `"persistent"` — the runtime reads
  `~/.vinos/routines/state/<name>/memory.md` (capped at ~4 KB), prepends it
  to the user turn as "Prior context from earlier runs", and after the run
  appends a concise 2-3 sentence summary. The summary comes from one extra
  cheap Ollama call (~200 tokens; local, no API cost). If Ollama is
  unreachable, the memory update is skipped with a WARN and the run still
  succeeds.
- `"shared"` — same shape, but reads/writes
  `~/.vinos/routines/state/shared/memory.md`. All routines see and contribute
  to a single cross-routine journal ("what the user has been doing lately").

The memory file is plain markdown — the user can `cat`, edit, or delete it.
When appending would push past 4 KB, the runtime trims the oldest ~500 chars
and realigns to the next newline boundary.

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

## Tools (v2.0.5)

The runtime exposes two tools to the agent, both **whitelist-enforced by the
runtime, not the model**. The routine declares what's available; the model
picks from that list; the runtime refuses anything undeclared.

### Declaring tools

```toml
[agent]
tools = [
  "read:~/inbox/*.eml",                    # glob (supports ~ + **/ + *)
  "read:~/.vinos/routines/state/*/*.md",
  "shell:gh api /notifications --paginate",
  "shell:gcalcli agenda today",
]
network             = false   # default false — shell tools have no network
shell_timeout_sec   = 30      # per-shell-call timeout, default 30s
```

Each entry is prefixed:

- **`read:<glob>`** — declares a filesystem glob the agent may read via the
  `read_files(glob)` tool. The `glob` argument the model passes MUST equal one
  of the declared patterns verbatim — the model cannot invent new patterns.
  Content per call is capped at ~500 KB total across all matched files (later
  files truncated with `"truncated": true`).
- **`shell:<cmd>`** — declares a shell command the agent may run via
  `run_shell(command)`. The `command` argument MUST equal one of the declared
  strings verbatim; the model cannot vary flags, add pipes, or rewrite args.

### Sandbox — mandatory

Every `shell:` call runs inside **`bwrap`** (bubblewrap) with:

- Read-only bind: `/usr`, `/etc`, `/bin`, `/lib`, `/lib64`, `/sbin`, `$HOME`
- `tmpfs` at `/tmp` (writable scratch, discarded per invocation)
- `--unshare-pid`, `--unshare-ipc`, `--unshare-uts`, `--die-with-parent`
- **No network** unless `[agent].network = true` (`--unshare-net` otherwise)
- `--clearenv` — only `HOME`, `PATH`, `TERM`, `LANG` propagate;
  `ANTHROPIC_API_KEY` is deliberately withheld unless `network = true`
- Wall-clock timeout via `timeout <N>s` outside the sandbox

**Fail-closed:** if `bwrap` is not installed on the host, the runtime logs a
`WARN` and every `run_shell` call returns an error result. The runtime never
executes shell commands without a sandbox. Package requirement: `bubblewrap`.

### Loop

The runtime drives a bounded tool-use loop (max **10 iterations** per run):

1. Send messages + tool schemas → provider (Anthropic or Ollama)
2. If the response has no tool calls → capture text, exit loop
3. For each tool call: whitelist-check, execute, capture result
4. Append `tool_result` blocks (Anthropic) or `role:"tool"` messages (Ollama)
5. Loop

For Ollama, the runtime uses the `/api/chat` `tools` field. If the local
model doesn't support tools (older Llama, Gemma, etc.) it will return text
with no `tool_calls` on the first turn — the runtime logs a WARN and returns
the raw text response, so routines still produce output on tool-less models.

### Ledger columns

The ledger schema evolves via backwards-compatible `ALTER TABLE` on every
runtime startup — older rows keep their `NULL` defaults, so ledgers written
by v2.0.4/v2.0.5 open cleanly under v2.0.6.

**v2 (v2.0.5):** added tool tracking.

- `tool_calls` — integer count of tool invocations for the run
- `tools_used` — JSON list of tool names invoked (e.g. `["read_files","run_shell"]`)

**v3 (v2.0.6):** added auto-router accounting.

- `escalated` — `1` if the auto-router escalated this run to premium, else `0`
- `escalated_reason` — one of `low_confidence` | `reasoning_task` |
  `context_overflow` | `malformed_tool_json` | `""` (empty when not escalated)
- `local_input_tokens` — tokens consumed by the local first-pass (auto only)
- `local_output_tokens` — tokens generated by the local first-pass (auto only)

For an escalated run, the top-level `input_tokens`/`output_tokens` reflect the
*premium* attempt (the one that costs money); the `local_*_tokens` columns
show what the local first-pass consumed for free.

Route labels the runtime writes:

- `anthropic` — routine hard-picked Anthropic
- `ollama` — routine hard-picked Ollama
- `local` — auto route ran local only (no escalation)
- `local->premium` — auto route escalated

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
- ~~bwrap sandbox for tools~~ — **shipped in v2.0.5** (see Tools section above)

## Open questions

- **Ollama model choice** — `llama3.2:3b` is 2 GB, `qwen2.5:7b` is 4.5 GB but
  handles tool use better. Bundle 3b (fast, small ISO delta) or 7b (better
  routines, ISO grows to 7 GB+)?
- **Anthropic key onboarding** — first-boot prompt in `vinos-welcome`? Or
  purely env-based (BYO key)?
- **Ledger currency** — assume USD, or per-user? Localized display?
- **Routine sharing format** — plain TOML in a git repo per author, or a
  bundled `.vinos-routine` archive with system prompt + tool defs baked in?

## Cron translator coverage (v2.0.6)

`libexec/vinos_routine_cron.py` maps standard 5-field cron expressions to
systemd OnCalendar strings. Supported:

| Cron | Translated OnCalendar |
|---|---|
| `0 6 * * *` | `*-*-* 06:00:00` |
| `*/30 * * * *` | `*-*-* *:*/30:00` |
| `0 6 * * MON-FRI` | `Mon..Fri *-*-* 06:00:00` |
| `@hourly` | `hourly` |
| `@daily` | `daily` |
| `@midnight` | `daily` |
| `@weekly` | `weekly` |
| `@monthly` | `monthly` |
| `@yearly` / `@annually` | `yearly` |
| `0 0 1 * *` | `*-*-01 00:00:00` |
| `15 3 * * 0` (Sunday) | `Sun *-*-* 03:15:00` |
| `15 3 * * 7` (also Sunday) | `Sun *-*-* 03:15:00` |
| `0 9,17 * * 1-5` | `Mon..Fri *-*-* 09,17:00:00` |
| `0 */6 * * *` | `*-*-* */6:00:00` |
| `0 12 1 JAN *` | `*-01-01 12:00:00` |
| `0 12 1 1,7 *` | `*-01,07-01 12:00:00` |
| `0 6,18 * * mon,wed,fri` | `Mon,Wed,Fri *-*-* 06,18:00:00` |

Explicitly refused (DIE with a clear error pointing to `oncalendar`):

- Jenkins-style random tokens (`H`, `H/5`)
- Quartz extensions (`?`, `L`, `W`, `#`, `15W`, `MON#2`)
- 6- or 7-field cron (seconds prefix, year suffix)
- Out-of-range values (`60 * * * *`, `0-99 * * * *`)
- Unknown shortcuts (`@reboot`, `@rand`)
- Empty / mangled expressions

For anything not on the supported list, write `[schedule].oncalendar` by hand.
