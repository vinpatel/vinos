#!/usr/bin/env python3
"""vinos-routine-run — one-shot agent invocation for a routine.

Reads a routine TOML, calls the agent (Anthropic or Ollama), writes markdown
output to $VINOS_ROUTINE_OUTPUT, and logs a row into the SQLite ledger at
$VINOS_ROUTINE_LEDGER.

Invoked by `vinos-routine run <name>` — not intended for direct human use.

Env:
  VINOS_ROUTINE_OUTPUT   destination markdown file (required)
  VINOS_ROUTINE_LEDGER   sqlite ledger path (required)
  ANTHROPIC_API_KEY      or file at ~/.vinos/secrets/anthropic-key
"""
from __future__ import annotations

import json
import os
import sqlite3
import sys
import tomllib
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path


def die(msg: str, code: int = 1):
    print(f"vinos-routine-run: {msg}", file=sys.stderr)
    sys.exit(code)


def load_anthropic_key() -> str | None:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if key:
        return key.strip()
    secrets = Path.home() / ".vinos/secrets/anthropic-key"
    if secrets.is_file():
        return secrets.read_text().strip()
    return None


def call_anthropic(model: str, system: str, prompt: str, max_tokens: int):
    key = load_anthropic_key()
    if not key:
        die("ANTHROPIC_API_KEY not set (env or ~/.vinos/secrets/anthropic-key)")
    payload = {
        "model": model,
        "max_tokens": max_tokens,
        "system": system,
        "messages": [{"role": "user", "content": prompt}],
    }
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode(),
        headers={
            "content-type": "application/json",
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            body = json.loads(r.read())
    except urllib.error.HTTPError as e:
        die(f"Anthropic API {e.code}: {e.read().decode(errors='replace')[:400]}")
    except urllib.error.URLError as e:
        die(f"Anthropic API unreachable: {e}")
    text = "".join(b.get("text", "") for b in body.get("content", []))
    usage = body.get("usage", {})
    return text, usage.get("input_tokens", 0), usage.get("output_tokens", 0)


def call_ollama(model: str, system: str, prompt: str, max_tokens: int):
    payload = {
        "model": model,
        "stream": False,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ],
        "options": {"num_predict": max_tokens},
    }
    req = urllib.request.Request(
        "http://localhost:11434/api/chat",
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            body = json.loads(r.read())
    except urllib.error.URLError as e:
        die(f"Ollama unreachable at localhost:11434 ({e}) — try `vinos-ai serve`")
    text = body.get("message", {}).get("content", "")
    return text, body.get("prompt_eval_count", 0), body.get("eval_count", 0)


def log_ledger(db_path: str, row: dict):
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db_path)
    con.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            ts             TEXT NOT NULL,
            name           TEXT NOT NULL,
            route          TEXT,
            model          TEXT,
            input_tokens   INTEGER,
            output_tokens  INTEGER,
            exit_status    INTEGER DEFAULT 0,
            output_path    TEXT
        )
    """)
    con.execute(
        "INSERT INTO runs (ts, name, route, model, input_tokens, output_tokens, output_path) "
        "VALUES (?,?,?,?,?,?,?)",
        (row["ts"], row["name"], row["route"], row["model"],
         row["input_tokens"], row["output_tokens"], row["output_path"]),
    )
    con.commit()
    con.close()


def render_title(tmpl: str, name: str) -> str:
    return (tmpl
            .replace("{{name}}", name)
            .replace("{{date}}", datetime.now().strftime("%Y-%m-%d")))


def main():
    if len(sys.argv) < 2:
        die("usage: vinos-routine-run <routine.toml>")
    out_path = os.environ.get("VINOS_ROUTINE_OUTPUT") or die("VINOS_ROUTINE_OUTPUT not set")
    ledger  = os.environ.get("VINOS_ROUTINE_LEDGER") or die("VINOS_ROUTINE_LEDGER not set")

    with open(sys.argv[1], "rb") as f:
        cfg = tomllib.load(f)

    routine = cfg.get("routine", {})
    agent   = cfg.get("agent", {})
    output  = cfg.get("output", {})
    budget  = cfg.get("budget", {})

    name       = routine.get("name") or die("routine.name missing")
    route      = agent.get("route", "anthropic")
    model      = agent.get("model", "claude-sonnet-4-6" if route == "anthropic" else "llama3.2")
    system     = (agent.get("system") or "").strip()
    max_tokens = int(budget.get("max_tokens_per_run", 4000))

    prompt = f"Run the routine now. Today is {datetime.now().strftime('%A, %Y-%m-%d')}. Return the requested content."

    if route == "anthropic":
        text, in_tok, out_tok = call_anthropic(model, system, prompt, max_tokens)
    elif route == "ollama":
        text, in_tok, out_tok = call_ollama(model, system, prompt, max_tokens)
    else:
        die(f"unknown route '{route}' (want anthropic | ollama)")

    title = render_title(output.get("title", "{{name}} · {{date}}"), name)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        f.write(f"# {title}\n\n")
        f.write(f"> `{route}/{model}` · in={in_tok} out={out_tok} tokens\n\n")
        f.write(text.strip())
        f.write("\n")

    log_ledger(ledger, {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "name": name,
        "route": route,
        "model": model,
        "input_tokens": in_tok,
        "output_tokens": out_tok,
        "output_path": out_path,
    })


if __name__ == "__main__":
    main()
