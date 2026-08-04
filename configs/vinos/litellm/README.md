# vinOS LiteLLM proxy

Uniform API for the 24x7 dev flow. Routes:

- **`vinos-executor`** → local Ollama (`qwen3-coder:30b`) — 80% of GSD executor work
- **`vinos-checker`**  → local Ollama (`qwen2.5-coder:7b`)
- **`vinos-researcher`** → local Ollama (`qwen3-coder:30b`)
- **`vinos-planner`**  → Anthropic Claude Sonnet 4.6
- **`vinos-reviewer`** → Anthropic Claude Sonnet 4.6
- **`vinos-architect`** → Anthropic Claude Opus 4.7
- **`vinos-kimi`** → OpenRouter Kimi K2 (opt-in escalation)

## First-time setup on the server

```bash
# 1) Symlink config into place
ln -sf /data/projects/vinos/configs/vinos/litellm/proxy.yaml ~/.litellm/config.yaml

# 2) Drop secrets (mode 0600)
mkdir -p ~/.vinos-secrets
cat > ~/.vinos-secrets/env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
OPENROUTER_API_KEY=sk-or-...   # optional, only for Kimi
LITELLM_MASTER_KEY=<random 32 chars>
EOF
chmod 600 ~/.vinos-secrets/env

# 3) Start proxy (foreground for first test)
source ~/.vinos-venv/bin/activate
set -a; source ~/.vinos-secrets/env; set +a
litellm --config ~/.litellm/config.yaml --port 4000
```

## Verify with curl

```bash
export MK="$LITELLM_MASTER_KEY"

# Executor (local Qwen)
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $MK" -H "Content-Type: application/json" \
  -d '{"model":"vinos-executor","messages":[{"role":"user","content":"Write a bash oneliner that prints the current date in ISO-8601."}]}' | jq -r .choices[0].message.content

# Planner (Claude)
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $MK" -H "Content-Type: application/json" \
  -d '{"model":"vinos-planner","messages":[{"role":"user","content":"Two sentences: what does the vinos-routine spec look like?"}]}' | jq -r .choices[0].message.content
```

## Run as a systemd user service

Once smoke tests pass:
```bash
# See configs/vinos/systemd/vinos-litellm.service — shipped in Phase 03
systemctl --user enable --now vinos-litellm.service
```

## Point GSD at the proxy

In `.planning/config.json` (Phase 0):
```json
{
  "models": {
    "planner_model": "vinos-planner",
    "researcher_model": "vinos-researcher",
    "executor_model": "vinos-executor",
    "checker_model": "vinos-checker",
    "reviewer_model": "vinos-reviewer"
  },
  "api_base": "http://localhost:4000",
  "api_key": "env:LITELLM_MASTER_KEY"
}
```

## Cost model

- Local models: $0.00 marginal
- Claude Sonnet: ~$3/M input, $15/M output (with prompt caching, ~50% off on cached hits)
- Kimi K2 via OpenRouter: ~$0.15/M input, $2.50/M output
- Hard daily cap: $20 (set in `general_settings.max_budget`)
