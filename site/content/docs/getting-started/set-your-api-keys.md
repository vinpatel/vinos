---
title: "Set your API keys"
description: "Anthropic key for Claude Code + routines. Optional local Ollama model. Where they live, what reads them."
weight: 30
---

vinOS agents talk to **Anthropic** (Claude Sonnet / Opus / Haiku),
**local Ollama** (any model you pull), or both via the 80/20 router.
You need at least one working route before routines will run.

## Anthropic (Claude)

Two locations, in priority order:

1. `$ANTHROPIC_API_KEY` environment variable.
2. `~/.vinos/secrets/anthropic-key` — a plain file, mode `0600`, one
   line, no trailing newline (leading `sk-ant-…` is fine).

The secrets file is the recommended path because it survives shell
restarts and works from systemd units without extra `Environment=` lines.

```
$ mkdir -p ~/.vinos/secrets
$ install -m 600 /dev/null ~/.vinos/secrets/anthropic-key
$ $EDITOR ~/.vinos/secrets/anthropic-key
```

Paste your key (get one at [console.anthropic.com](https://console.anthropic.com/settings/keys)),
save, exit. Confirm it works:

```
$ vinos-ai chat "one word: hello"
hello
```

{{% callout kind="warning" %}}
Never commit `~/.vinos/secrets/*` anywhere. It's gitignored in the
default `~/.config` shipped in the ISO, but if you clone your dotfiles
back over the top later, re-verify.
{{% /callout %}}

## Ollama (local)

Install once — the AI bundle handles it — then pull whatever model
you want as the local default:

```
$ vinos-install-ai        # pulls ollama, aichat, claude-code, ~2 GB
$ vinos-ai serve          # start the ollama systemd user unit
$ vinos-ai pull llama3.2  # or qwen2.5:7b, gemma3:4b, mistral:7b, etc.
```

Confirm the model list:

```
$ vinos-ai models
NAME              ID              SIZE      MODIFIED
llama3.2:latest   a80c4f17acd5    2.0 GB    2 minutes ago
qwen2.5:7b        845dbda0ea48    4.7 GB    5 days ago
```

The default local model is set by `$VINOS_AI_DEFAULT_MODEL` (falls back
to `llama3.2`). Override per shell or in `~/.config/vinos/ai.toml`.

## The 80/20 router

If both routes are configured, `route = "auto"` in a routine's TOML
runs local first and escalates to Claude only when the local model's
confidence is low or the task exceeds a token threshold. Full model of
that behavior on [the 80/20 router page](/docs/agents/the-80-20-router/).

```toml
[agent]
route = "auto"   # ollama → escalate to claude-sonnet on confidence < 0.6
```

## Never-set-anything path

If you skip both keys, only routines with `route = "ollama"` and a
tiny model (`gemma3:4b`, `qwen2.5:1.5b`) will run. Claude-routed
routines will refuse to execute and fire a mako notification pointing
back to this page.

Ready to run your first routine? Go to [running a routine](/docs/agents/running-a-routine/).
