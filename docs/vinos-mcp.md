# `vinos-mcp` — MCP server registry CLI

`vinos-mcp` is the vinOS command for browsing a curated registry of MCP (Model Context Protocol) servers, installing entries into your user config, and removing them. Because MCP is now cross-vendor, one vinOS-managed config feeds every runner (Claude Code, Codex CLI, Aider, etc.) via each runner adapter's `runner_mcp_apply` hook.

## Quick reference

```
vinos-mcp registry              print the curated registry (JSON)
vinos-mcp list                  print the user's installed servers
vinos-mcp show <name>           print one registry entry's details
vinos-mcp add <name>            add a registry entry to your user config
vinos-mcp remove <name>         remove an entry from your user config
```

## What ships in the registry

Six curated servers cover the ~90 % case for developer workflows. All are opt-in — `add` puts them into your config; nothing is auto-enabled.

| Name | What it does | Runtime |
|---|---|---|
| `filesystem` | Read/write local files, scoped by path (defaults to `$HOME`) | Node ≥ 18 via `npx` |
| `github` | Read GitHub repos, issues, PRs, code search (requires `GITHUB_PERSONAL_ACCESS_TOKEN`) | Node ≥ 18 via `npx` |
| `fetch` | Fetch arbitrary URLs and return sanitized content | Node ≥ 18 via `npx` |
| `sequential-thinking` | Structured multi-step reasoning primitive | Node ≥ 18 via `npx` |
| `playwright` | Headless browser automation (navigate, click, extract, screenshot) | Node ≥ 18 + ~500 MB disk for Chromium |
| `sqlite` | Query and mutate a local SQLite database | Python ≥ 3.10 via `uvx` |

Full details for any entry:
```
vinos-mcp show github
```

## Config layout

- **Registry (system):** `/usr/lib/vinos/registry/mcp-servers.json` — read-only, part of the vinOS install
- **User config:** `~/.config/vinos/mcp/servers.json` — created on first `add`, world-unreadable (mode 0600)

The user config shape is the standard MCP `mcpServers` object that Claude Code, Codex, and Aider all understand:

```jsonc
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "$HOME"],
      "env": {}
    }
  }
}
```

Runner adapters copy this file into the runner's own settings on activation (Claude Code merges into `~/.claude.json`; Codex reads it directly).

## Environment overrides

Useful for tests and site-specific overrides:

- `VINOS_MCP_REGISTRY` — override the registry JSON path (default: `/usr/lib/vinos/registry/mcp-servers.json`)
- `VINOS_MCP_USER` — override the user config path (default: `$HOME/.config/vinos/mcp/servers.json`)

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Usage error (unknown verb, missing argument) |
| 2 | Registry entry not found |
| 3 | Runtime dependency missing (`jq`) |

## Extending the registry

- **Personal additions:** drop a JSON snippet into `~/.config/vinos/mcp/servers.json` by hand (any keys under `mcpServers` are honored by every runner). Nothing prevents you from installing servers not in the curated registry.
- **Contributing to the shipped registry:** open a PR against `usr/lib/vinos/registry/mcp-servers.json` in the vinOS repo. Each new entry must specify `command`, `args`, `env`, `requires`, and `docs`.

## Test suite

`tests/vinos-mcp.test.sh` is a bats-lite harness with 7 assertions:

1. `registry` emits valid JSON with all 6 curated servers
2. `list` on a fresh `$HOME` reports the empty state
3. `add filesystem` writes a valid config
4. `add` is idempotent — the second `add` is a no-op with `exit 0`
5. `list` after `add` shows the installed server as valid JSON
6. `remove` wipes the entry
7. `add nonexistent` fails with exit code 2 + error message

Run: `bash tests/vinos-mcp.test.sh`

## What's next

- `vinos-mcp add filesystem --path /custom/dir` (per-add path override)
- Runner-specific `apply` verbs (`vinos-mcp apply --runner claude`) that sync into each runner's own config
- `vinos-mcp search <term>` — fuzzy search against the registry + a community index (v1.4.0)
- Registry v2 — schema for MCP server *capabilities* so runners can filter by needed tool surface
