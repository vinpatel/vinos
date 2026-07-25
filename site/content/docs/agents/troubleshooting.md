---
title: "Troubleshooting routines"
description: "API key not found, Ollama unreachable, sandbox refusal, budget exceeded — every failure the runtime knows about, and its fix."
weight: 60
---

## API key not found

The runtime looked in both places and got nothing.

```
[day-brief] fatal: no Anthropic key
  looked in $ANTHROPIC_API_KEY (unset)
  looked in ~/.vinos/secrets/anthropic-key (missing)
  fix: see /docs/getting-started/set-your-api-keys/
```

Fix by dropping your key into `~/.vinos/secrets/anthropic-key` with mode
`0600`. See [set your API keys](/docs/getting-started/set-your-api-keys/).

## Ollama unreachable

The routine wants to talk to Ollama but the server isn't running.

```
[research-recap] fatal: ollama server not reachable at http://localhost:11434
  fix: vinos-ai serve
```

Two-line fix:

```
$ vinos-ai serve
$ vinos-ai status
ollama:  running  (systemd user unit ollama.service active)
models:  llama3.2 · qwen2.5:7b
```

If `vinos-ai serve` fails, install the AI bundle first:

```
$ vinos-install-ai
```

## Sandbox refused a tool call

The model tried to call a tool that isn't on the whitelist.

```
[day-brief] refused tool call: shell:cat ~/.ssh/id_ed25519
  reason: string not in [agent].tools whitelist
```

This is working as designed — [tools and sandbox](/docs/agents/tools-and-sandbox/)
explains why. If the refused command is legitimate, add its **exact
string** to the routine's `tools` array and re-run.

## Budget exceeded

The `[budget].max_dollars_per_day` cap tripped.

```
[day-brief] budget exceeded: today $0.2043 > cap $0.2000
  action: skip  (per [budget].on_exceed)
  next attempt: 2026-07-27 06:00:00
```

Options:
- Raise the cap in the routine's `[budget]` table.
- Switch `route = "auto"` so future runs go local when the budget is thin.
- Set `on_exceed = "degrade-to-local"` so it downshifts instead of skipping.

## Auto-disable after 3 failures

If a routine fails 3 times in a row, the runtime disables its timer and
fires a mako notification. This stops runaway API spend if you push a
broken routine.

```
$ vinos-routine list
NAME              ENABLED   LAST RUN              STATUS
day-brief         no        2026-07-25 06:00:05   auto-disabled (3 fails)
```

Fix the routine, then re-enable:

```
$ vinos-routine edit day-brief
$ vinos-routine run day-brief          # verify it passes once ad-hoc
$ vinos-routine enable day-brief
```

## Timer scheduled but never fires

Systemd user timers only run while your user has an active login. If
you SSH in and out constantly, or the machine sleeps aggressively,
timers can be missed.

Check the timer directly:

```
$ systemctl --user list-timers vinos-routine-*
NEXT                          LEFT       LAST                          PASSED       UNIT
Sat 2026-07-26 06:00:00 EDT   6h 40min   Fri 2026-07-25 06:00:03 EDT   17h ago      vinos-routine-day-brief.timer
```

If `LAST` is stale, enable lingering so systemd runs your units even
when you're logged out:

```
$ sudo loginctl enable-linger $USER
```

## Nothing helped

Grab the last run's full trace and file an issue:

```
$ vinos-routine logs day-brief --tail --lines=200 > /tmp/day-brief.log
$ vinos-doctor > /tmp/doctor.log
```

Attach both to a report at [github.com/vinpatel/vinos/issues](https://github.com/vinpatel/vinos/issues/new).
