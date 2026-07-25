---
title: "Tools and the sandbox"
description: "read: globs and shell: commands are whitelist-enforced by the runtime — not the model. Every shell tool runs inside bwrap."
weight: 40
---

The runtime never trusts the model. Every tool call the agent tries to
make is checked against the `tools = [...]` array in the routine's TOML.
Anything not on that list is refused — not soft-warned, not logged —
**refused before the tool runs**.

## Two tool kinds

### `read:` — file globs

```toml
tools = [
  "read:~/Notes/today.md",
  "read:~/.vinos/routines/state/day-brief/*.md",
]
```

- Path is expanded (`~` → `$HOME`).
- Glob patterns work (`*`, `?`, `[abc]`).
- Files are read as UTF-8, capped at 256 KB per read, 1 MB per run total.
- Symlinks are followed but the resolved path must also match a whitelist entry.

### `shell:` — command strings

```toml
tools = [
  "shell:gh api /notifications --paginate 2>/dev/null | head -c 8000",
  "shell:test -x /usr/bin/gcalcli && gcalcli agenda today || echo 'gcalcli not installed'",
]
```

- The **entire string** is the whitelist entry. Substring or fuzzy
  matches do not exist. The agent must call the command *verbatim*.
- Runs via `bash -c` inside a bwrap sandbox.
- Timeout: `[agent].shell_timeout_sec`, default 30s.
- Network: `[agent].network`, default `false`.
- Stdout returned to the model, capped at 32 KB per call.

## The bwrap sandbox

Every `shell:` tool runs inside [bubblewrap](https://github.com/containers/bubblewrap)
with a locked-down namespace:

- **Filesystem** — read-only bind of `/usr`, `/etc`, `/lib`. Read-write
  bind of `~/.vinos/routines/state/<routine-name>/` only.
- **Network** — off by default. `[agent].network = true` opts in.
- **Process** — new PID namespace; the shell can't see the host's
  processes.
- **Devices** — `/dev` is a tmpfs with `null`, `zero`, `urandom` only.
- **Users** — the sandbox runs as your UID; no privilege escalation possible.

You can inspect the exact bwrap invocation by adding
`VINOS_ROUTINE_DEBUG=1` to the environment and running `vinos-routine run <name>`
— every argv is printed before the fork.

## Why the runtime, not the model

The security model is deliberate: the *model* is untrusted, so its
declared intent to call a tool is a *request*, not an authorization.
The *runtime* is trusted, and it enforces. A jailbroken model that
tries `shell:rm -rf ~` will find that string isn't on the whitelist
and the request will be refused before bwrap even spins up.

Reading Anthropic's [prompt injection notes](https://www.anthropic.com/news/prompt-injection)
convinced us this is the only workable model.

## Common patterns

**Read a directory of markdown, no shell needed:**
```toml
tools = ["read:~/Reading/*.md"]
```

**Run a single API query, no network required (uses local `gh` cache):**
```toml
tools = ["shell:gh api /user"]
```

**Pull today's calendar plus inbox:**
```toml
tools = [
  "shell:gcalcli agenda today",
  "shell:notmuch search tag:inbox and date:today",
]
```

**Give the agent internet:**
```toml
[agent]
network = true
tools = ["shell:curl -s https://api.github.com/repos/vinpatel/vinos"]
```

## What the runtime refuses

- Substring match: `shell:gh api /notifications` will *not* match if the
  model calls `shell:gh api /notifications | head`. Add the pipe to the
  whitelist explicitly.
- Path outside `read:` glob: `read:~/Notes/today.md` will not permit
  `~/Notes/tomorrow.md`.
- Any tool call the runtime doesn't recognize (typos, imagined new
  tools, etc.).

Refusals log a line like:
```
[day-brief] refused tool call: shell:cat /etc/shadow
```

Next: [the 80/20 router](/docs/agents/the-80-20-router/).
