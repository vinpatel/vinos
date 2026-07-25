---
title: "Writing your own routine"
description: "Full anatomy of a routine TOML file — schedule, agent, tools, output, budget. Copy from the shipped day-brief and mutate."
weight: 20
---

Every routine is one TOML file, ≤50 lines. The runtime parses five
tables: `[routine]`, `[schedule]`, `[agent]`, `[output]`, `[budget]`.
Nothing else is read; unknown keys are ignored. The full schema lives
in [`vinos-routine-spec.md`](https://github.com/vinpatel/vinos/blob/main/docs/v2/vinos-routine-spec.md).

## Scaffold

```
$ vinos-routine edit weekly-review
→ new routine, scaffolding at ~/.vinos/routines/weekly-review.toml
→ opening in $EDITOR
```

The scaffold ships pre-filled defaults so you only edit what matters.

## The shipped day-brief, annotated

This is the exact file at `/etc/vinos/routines/day-brief.toml`:

```toml
# day-brief — first thing to greet you in the morning.
# Shipped disabled. Enable: `vinos-routine enable day-brief`
[routine]
name = "day-brief"
description = "Morning brief: top 3 priorities, signals, one reflection"
enabled = false

[schedule]
oncalendar = "*-*-* 06:00:00"
timezone = "local"
jitter   = "5m"

[agent]
route = "anthropic"
model = "claude-sonnet-4-6"
system = """
You are the user's morning briefing agent. The user is a founder building
vinOS (an agentic Linux distro). Be concise and action-oriented; skip filler,
disclaimers, and hedges.

Return markdown with exactly three sections:

## Top 3 for today
Numbered list. Each item ≤ 15 words, concrete, verb-first.

## Signals
2-4 bullets. Tech / AI / OS-space news the user should be aware of.

## One reflection
A single short paragraph — a founder-relevant question or observation.

Total ≤ 400 words. No preamble, no summary, no sign-off.
"""
tools = [
  "read:~/Notes/today.md",
  "read:~/.vinos/routines/state/day-brief/*.md",
  "shell:gh api /notifications --paginate 2>/dev/null | head -c 8000",
  "shell:test -x /usr/bin/gcalcli && gcalcli agenda today || echo 'gcalcli not installed'",
]
shell_timeout_sec = 20
network = false

[output]
type  = "brief"
title = "Today · {{date}}"
open_on_login = true
notify        = true

[budget]
max_tokens_per_run = 4000
max_dollars_per_day = 0.20
on_exceed = "skip"
```

## The five tables

### `[routine]`

- **`name`** — the filename stem. Referenced by `vinos-routine <verb> <name>`.
- **`description`** — one line shown in `list` and `brief`.
- **`enabled`** — a hint only. `vinos-routine enable/disable` toggles the
  systemd timer separately.

### `[schedule]`

- **`oncalendar`** — a systemd OnCalendar spec. `*-*-* 06:00:00` (daily
  6am), `Mon..Fri 09:00`, `hourly`, `*-*-* 09,13,17:00:00` (three
  times a day), etc.
- **`timezone`** — `local` or an IANA zone (e.g. `America/New_York`).
- **`jitter`** — random ±N to spread load and avoid rate limits.

### `[agent]`

- **`route`** — `anthropic` | `ollama` | `auto` (80/20 router).
- **`model`** — provider-specific string. Any Claude model or any
  installed Ollama tag.
- **`system`** — the system prompt. Multiline triple-quoted string.
- **`tools`** — whitelist array. See [tools and sandbox](/docs/agents/tools-and-sandbox/).
- **`shell_timeout_sec`** — per-shell-tool timeout. Default 30.
- **`network`** — bwrap sandbox: allow network access from shell tools?
  Default `false`.

### `[output]`

- **`type`** — `brief` (markdown file + `vinos-brief` visibility),
  `notification` (mako toast), `file` (write only), `webhook` (POST).
- **`title`** — template. `{{date}}`, `{{time}}`, `{{routine}}` interpolate.
- **`open_on_login`** — surface next time the user logs in.
- **`notify`** — also fire a mako toast when done.

### `[budget]`

- **`max_tokens_per_run`** — hard cap; run stops if exceeded.
- **`max_dollars_per_day`** — sums across every run of every routine
  under this dollar-day ledger.
- **`on_exceed`** — `skip` (silent), `degrade-to-local` (rerun with
  ollama), `notify` (fire a mako toast and stop).

## Save. Enable. Watch it run.

```
$ vinos-routine enable weekly-review
✓ enabled weekly-review.timer
  next run  Mon 2026-07-28 09:00:05 EDT

$ vinos-routine run weekly-review    # verify without waiting for Monday
...
```

Next: [share routines across a team](/docs/agents/project-routines/).
