---
title: "Agents"
description: "Routines are Claude/Ollama-powered agents that run on a schedule with tools, budgets, and a sandbox. This section is the operator's manual."
weight: 20
---

A **routine** is one TOML file. It names an agent, sets a schedule,
declares the tools the agent may call (read-globs and shell commands,
both whitelist-enforced), points at an output destination, and caps
the budget in tokens per run and dollars per day. `vinos-routine enable
<name>` generates a systemd user timer.

You'll spend most of your time in three commands:

- `vinos-routine list` — see what's registered and when it runs next.
- `vinos-routine run <name>` — fire one ad-hoc.
- `vinos-brief` — open today's outputs in a walker panel.

If you're deep in it, jump to the [routine spec](/spec/) for the
authoritative TOML schema. Everything here is the operator's view.
