---
title: "The 80/20 router"
description: "route = auto runs local Ollama first, escalates to Claude only when needed. The cost math and the escalation policy."
weight: 50
---

The 80/20 router is one setting: `route = "auto"`. With it, every
routine call tries a local Ollama model first. If the response passes
the confidence check, the run stops there — zero API cost. If it
doesn't, the router re-runs the same prompt against a Claude model.

Real numbers on a typical founder workload (routines + interactive
`vinos-ai` sessions):

| | All-premium | 80/20 routed | Local only |
|---|---|---|---|
| Monthly cost | {{< param costMonthlyPremium >}} | {{< param costMonthlyRouted >}} | $0 |
| Latency (p50) | 1.4s | 0.6s | 0.4s |
| Quality on complex code | High | High | Mixed |
| Quality on summaries | Overkill | Great | Great |
| Privacy | Anthropic sees prompts | 80% never leave your box | Never leaves your box |

## Configure once

`~/.config/vinos/ai.toml` sets the default router behavior:

```toml
# ~/.config/vinos/ai.toml
[router]
local_model  = "llama3.2"
escalate_to  = "claude-sonnet-4-6"
confidence_min = 0.6      # 0–1; escalate when local self-confidence lower
token_ceiling  = 8000     # escalate for prompts larger than this many tokens

[cost]
daily_cap_dollars = 5.00  # hard stop; log a warning and refuse further Claude calls
```

Per-routine override in the TOML wins:

```toml
[agent]
route = "auto"
model = "llama3.2"                        # local first-attempt
fallback_model = "claude-sonnet-4-6"      # what to escalate to
```

## The escalation policy

1. **Run local.** Local model returns a response plus a self-reported
   confidence score (via a stop-token pattern the runtime parses).
2. **Check confidence.** If `>= confidence_min`, done.
3. **Check size.** If the input tokens exceed `token_ceiling`, skip
   the local attempt entirely — anything that big will just OOM the
   local model.
4. **Escalate.** Re-run with `fallback_model`. This second attempt is
   the one that costs money.
5. **Log both.** The ledger records both runs with a `route:auto:local`
   or `route:auto:escalated` tag so `vinos-routine cost` can tell you
   which one you paid for.

## Which routes what

The 5 shipped routines are already tuned:

- **day-brief** → `anthropic` (needs the reasoning; runs once a day; cheap).
- **evening-shutdown** → `anthropic` (short output, worth the polish).
- **research-recap** → `ollama` (pure summarization; local is great here).
- **inbox-triage** → `auto` (most emails are quick; some drafts need muscle).
- **github-review** → `anthropic` (code diffs are where Claude earns its keep).

## When to override

Use `route = "ollama"` when:
- The output is short + summarization-shaped.
- You need latency under 1 second.
- The data is sensitive and mustn't leave the machine.

Use `route = "anthropic"` when:
- The task is multi-step reasoning across long context.
- You're generating something (code, prose) where fidelity matters.
- You've measured that the local model is failing the confidence check
  every time anyway.

Use `route = "auto"` for everything else. That's the whole point.

Next: [troubleshooting routines](/docs/agents/troubleshooting/).
