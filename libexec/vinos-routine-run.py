#!/usr/bin/env python3
"""vinos-routine-run — one-shot agent invocation for a routine.

Reads a routine TOML, calls the agent (Anthropic or Ollama), writes markdown
output to $VINOS_ROUTINE_OUTPUT, and logs a row into the SQLite ledger at
$VINOS_ROUTINE_LEDGER.

Invoked by `vinos-routine run <name>` — not intended for direct human use.

Tools (v2.0.5)
    [agent].tools is a list of strings, each prefixed with:
      * read:<glob>   — matches files (globbing incl. ~ expansion), agent
                        calls read_files(glob=<declared-glob>) to fetch content
      * shell:<cmd>   — declares a shell command; agent calls
                        run_shell(command=<declared-cmd>) verbatim

    Whitelist enforcement lives in the runtime: even if the model tries to
    call read_files or run_shell with an undeclared glob/command, the runtime
    refuses. Shell commands run inside a `bwrap` sandbox with read-only
    /usr,/etc,/bin,/lib(64) + read-only $HOME, tmpfs /tmp, and no network
    (unless [agent].network = true). Timeout via [agent].shell_timeout_sec
    (default 30s).

Env:
  VINOS_ROUTINE_OUTPUT   destination markdown file (required)
  VINOS_ROUTINE_LEDGER   sqlite ledger path (required)
  ANTHROPIC_API_KEY      or file at ~/.vinos/secrets/anthropic-key
"""
from __future__ import annotations

import glob as _glob
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tomllib
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# constants
# ---------------------------------------------------------------------------

MAX_TOOL_ITERATIONS = 10
MAX_READ_BYTES_PER_CALL = 500 * 1024  # ~500 KB cap per read_files invocation
DEFAULT_SHELL_TIMEOUT_SEC = 30

READ_PREFIX = "read:"
SHELL_PREFIX = "shell:"


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def die(msg: str, code: int = 1):
    print(f"vinos-routine-run: {msg}", file=sys.stderr)
    sys.exit(code)


def warn(msg: str):
    print(f"vinos-routine-run: WARN: {msg}", file=sys.stderr)


def load_anthropic_key() -> str | None:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if key:
        return key.strip()
    secrets = Path.home() / ".vinos/secrets/anthropic-key"
    if secrets.is_file():
        return secrets.read_text().strip()
    return None


# ---------------------------------------------------------------------------
# tool declarations + whitelist
# ---------------------------------------------------------------------------

def parse_tools(tools_decl: list[str]) -> tuple[list[str], list[str]]:
    """Split declared tool strings into (read_globs, shell_commands)."""
    reads, shells = [], []
    for entry in tools_decl or []:
        if not isinstance(entry, str):
            warn(f"skipping non-string tool entry: {entry!r}")
            continue
        if entry.startswith(READ_PREFIX):
            reads.append(entry[len(READ_PREFIX):].strip())
        elif entry.startswith(SHELL_PREFIX):
            shells.append(entry[len(SHELL_PREFIX):].strip())
        else:
            warn(f"unknown tool prefix (want read:/shell:): {entry!r}")
    return reads, shells


def build_tool_manifest(reads: list[str], shells: list[str]) -> str:
    """Human-readable manifest to help the model pick the right args."""
    lines = []
    if reads:
        lines.append("Declared read globs (call read_files with exactly these):")
        lines.extend(f"  - {g}" for g in reads)
    if shells:
        lines.append("Declared shell commands (call run_shell with exactly these):")
        lines.extend(f"  - {c}" for c in shells)
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# tool implementations
# ---------------------------------------------------------------------------

def _resolve_glob(pattern: str) -> list[Path]:
    expanded = os.path.expanduser(os.path.expandvars(pattern))
    return sorted(Path(p) for p in _glob.glob(expanded, recursive=True))


def tool_read_files(pattern: str, allowed_globs: list[str]) -> dict:
    if pattern not in allowed_globs:
        return {"error": f"glob {pattern!r} not in declared read: whitelist",
                "allowed": allowed_globs}
    matches = _resolve_glob(pattern)
    out, total = [], 0
    truncated = False
    for p in matches:
        if not p.is_file():
            continue
        try:
            data = p.read_bytes()
        except OSError as e:
            out.append({"path": str(p), "error": str(e)})
            continue
        if total + len(data) > MAX_READ_BYTES_PER_CALL:
            remaining = MAX_READ_BYTES_PER_CALL - total
            if remaining > 0:
                out.append({
                    "path": str(p),
                    "content": data[:remaining].decode("utf-8", errors="replace"),
                    "truncated": True,
                })
                total += remaining
            truncated = True
            break
        out.append({"path": str(p), "content": data.decode("utf-8", errors="replace")})
        total += len(data)
    return {"files": out, "bytes_read": total, "truncated": truncated,
            "match_count": len(out)}


def _bwrap_argv(cmd: str, network: bool, timeout_sec: int) -> list[str]:
    """Build the bwrap invocation for a shell command."""
    home = os.path.expanduser("~")
    argv = [
        "bwrap",
        "--ro-bind", "/usr", "/usr",
        "--ro-bind", "/etc", "/etc",
        "--ro-bind", "/bin", "/bin",
        "--ro-bind", "/lib", "/lib",
    ]
    if os.path.isdir("/lib64"):
        argv += ["--ro-bind", "/lib64", "/lib64"]
    if os.path.isdir("/sbin"):
        argv += ["--ro-bind", "/sbin", "/sbin"]
    argv += [
        "--ro-bind", home, home,
        "--tmpfs", "/tmp",
        "--proc", "/proc",
        "--dev", "/dev",
        "--chdir", home,
        "--die-with-parent",
        "--unshare-pid",
        "--unshare-ipc",
        "--unshare-uts",
        "--unshare-cgroup-try",
    ]
    if not network:
        argv += ["--unshare-net"]
    # Preserve minimal env; drop most of the host's.
    argv += [
        "--clearenv",
        "--setenv", "HOME", home,
        "--setenv", "PATH", "/usr/local/bin:/usr/bin:/bin",
        "--setenv", "TERM", os.environ.get("TERM", "dumb"),
        "--setenv", "LANG", os.environ.get("LANG", "C.UTF-8"),
    ]
    # Pass API key through only if the routine opted into network (rare).
    if network and os.environ.get("ANTHROPIC_API_KEY"):
        argv += ["--setenv", "ANTHROPIC_API_KEY", os.environ["ANTHROPIC_API_KEY"]]
    argv += ["timeout", f"{timeout_sec}s", "bash", "-lc", cmd]
    return argv


def tool_run_shell(cmd: str, allowed_cmds: list[str], network: bool,
                   timeout_sec: int, bwrap_available: bool) -> dict:
    if cmd not in allowed_cmds:
        return {"error": f"command {cmd!r} not in declared shell: whitelist",
                "allowed": allowed_cmds, "exit_code": -1, "stdout": "", "stderr": ""}
    if not bwrap_available:
        return {"error": "bwrap not installed on this host — shell tools refused (fail-closed)",
                "exit_code": -1, "stdout": "", "stderr": ""}
    argv = _bwrap_argv(cmd, network=network, timeout_sec=timeout_sec)
    try:
        r = subprocess.run(argv, capture_output=True, text=True,
                           timeout=timeout_sec + 5)
    except subprocess.TimeoutExpired:
        return {"error": f"timed out after {timeout_sec}s",
                "exit_code": 124, "stdout": "", "stderr": ""}
    except FileNotFoundError as e:
        return {"error": f"exec failed: {e}", "exit_code": -1,
                "stdout": "", "stderr": ""}
    # Cap outputs (avoid blowing the context window on a chatty command).
    stdout = r.stdout[:MAX_READ_BYTES_PER_CALL]
    stderr = r.stderr[:16 * 1024]
    return {
        "exit_code": r.returncode,
        "stdout": stdout,
        "stderr": stderr,
        "stdout_truncated": len(r.stdout) > len(stdout),
    }


# ---------------------------------------------------------------------------
# Anthropic tool-use loop
# ---------------------------------------------------------------------------

ANTHROPIC_TOOLS = [
    {
        "name": "read_files",
        "description": (
            "Read files matching a whitelisted glob pattern. The `glob` "
            "argument MUST be one of the patterns declared in the routine's "
            "read: whitelist verbatim — you cannot invent new patterns."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "glob": {"type": "string",
                         "description": "A glob pattern from the read: whitelist."},
            },
            "required": ["glob"],
        },
    },
    {
        "name": "run_shell",
        "description": (
            "Run a whitelisted shell command inside a bwrap sandbox. The "
            "`command` argument MUST be one of the commands declared in the "
            "routine's shell: whitelist verbatim — you cannot invent commands "
            "or vary arguments."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string",
                            "description": "A command from the shell: whitelist."},
            },
            "required": ["command"],
        },
    },
]


def _anthropic_post(payload: dict, key: str) -> dict:
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
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        die(f"Anthropic API {e.code}: {e.read().decode(errors='replace')[:400]}")
    except urllib.error.URLError as e:
        die(f"Anthropic API unreachable: {e}")


def call_anthropic(model, system, prompt, max_tokens,
                   reads, shells, network, shell_timeout, bwrap_available):
    key = load_anthropic_key()
    if not key:
        die("ANTHROPIC_API_KEY not set (env or ~/.vinos/secrets/anthropic-key)")

    tools_declared = bool(reads or shells)
    tools_arg = ANTHROPIC_TOOLS if tools_declared else None

    messages = [{"role": "user", "content": prompt}]
    in_tok = out_tok = 0
    tool_call_names: list[str] = []
    final_text = ""

    for iteration in range(MAX_TOOL_ITERATIONS):
        payload = {
            "model": model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": messages,
        }
        if tools_arg:
            payload["tools"] = tools_arg
        body = _anthropic_post(payload, key)
        usage = body.get("usage", {})
        in_tok += usage.get("input_tokens", 0)
        out_tok += usage.get("output_tokens", 0)

        content = body.get("content", [])
        stop_reason = body.get("stop_reason")

        # Append assistant turn to conversation.
        messages.append({"role": "assistant", "content": content})

        if stop_reason != "tool_use":
            final_text = "".join(b.get("text", "") for b in content if b.get("type") == "text")
            break

        tool_results = []
        for block in content:
            if block.get("type") != "tool_use":
                continue
            name = block.get("name")
            inp = block.get("input", {}) or {}
            tuid = block.get("id")
            tool_call_names.append(name)
            if name == "read_files":
                result = tool_read_files(inp.get("glob", ""), reads)
            elif name == "run_shell":
                result = tool_run_shell(inp.get("command", ""), shells,
                                        network, shell_timeout, bwrap_available)
            else:
                result = {"error": f"unknown tool {name!r}"}
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": tuid,
                "content": json.dumps(result)[:MAX_READ_BYTES_PER_CALL],
                "is_error": "error" in result,
            })
        if not tool_results:
            break
        messages.append({"role": "user", "content": tool_results})
    else:
        warn(f"hit MAX_TOOL_ITERATIONS ({MAX_TOOL_ITERATIONS}); "
             f"returning last assistant text")
        # Try to salvage any text from the last assistant turn.
        for block in reversed(messages):
            if block["role"] == "assistant":
                final_text = "".join(
                    b.get("text", "") for b in block["content"]
                    if isinstance(b, dict) and b.get("type") == "text"
                )
                break

    return final_text, in_tok, out_tok, tool_call_names


# ---------------------------------------------------------------------------
# Ollama tool-use loop
# ---------------------------------------------------------------------------

OLLAMA_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "read_files",
            "description": "Read files matching a whitelisted glob (must be in read: whitelist).",
            "parameters": {
                "type": "object",
                "properties": {"glob": {"type": "string"}},
                "required": ["glob"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_shell",
            "description": "Run a whitelisted shell command in bwrap (must be in shell: whitelist).",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string"}},
                "required": ["command"],
            },
        },
    },
]


def _ollama_post(payload: dict) -> dict:
    req = urllib.request.Request(
        "http://localhost:11434/api/chat",
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.loads(r.read())
    except urllib.error.URLError as e:
        die(f"Ollama unreachable at localhost:11434 ({e}) — try `vinos-ai serve`")


def call_ollama(model, system, prompt, max_tokens,
                reads, shells, network, shell_timeout, bwrap_available):
    tools_declared = bool(reads or shells)
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": prompt},
    ]
    in_tok = out_tok = 0
    tool_call_names: list[str] = []
    final_text = ""
    warned_no_tools = False

    for iteration in range(MAX_TOOL_ITERATIONS):
        payload = {
            "model": model,
            "stream": False,
            "messages": messages,
            "options": {"num_predict": max_tokens},
        }
        if tools_declared:
            payload["tools"] = OLLAMA_TOOLS

        body = _ollama_post(payload)
        in_tok += body.get("prompt_eval_count", 0)
        out_tok += body.get("eval_count", 0)

        msg = body.get("message", {})
        content = msg.get("content", "") or ""
        tool_calls = msg.get("tool_calls") or []

        # Add assistant turn (Ollama expects role="assistant").
        messages.append({"role": "assistant", "content": content,
                         "tool_calls": tool_calls} if tool_calls
                        else {"role": "assistant", "content": content})

        if not tool_calls:
            # If tools were declared but no tool_calls ever came, the model
            # likely doesn't support tools — warn once and return the text.
            if tools_declared and iteration == 0 and not warned_no_tools:
                warn(f"Ollama model {model!r} returned no tool_calls on "
                     f"first turn; model may not support tools — proceeding "
                     f"with raw response")
                warned_no_tools = True
            final_text = content
            break

        for tc in tool_calls:
            fn = tc.get("function", {}) or {}
            name = fn.get("name")
            args = fn.get("arguments", {}) or {}
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except json.JSONDecodeError:
                    args = {}
            tool_call_names.append(name)
            if name == "read_files":
                result = tool_read_files(args.get("glob", ""), reads)
            elif name == "run_shell":
                result = tool_run_shell(args.get("command", ""), shells,
                                        network, shell_timeout, bwrap_available)
            else:
                result = {"error": f"unknown tool {name!r}"}
            messages.append({
                "role": "tool",
                "content": json.dumps(result)[:MAX_READ_BYTES_PER_CALL],
            })
    else:
        warn(f"hit MAX_TOOL_ITERATIONS ({MAX_TOOL_ITERATIONS}) on Ollama loop")

    return final_text, in_tok, out_tok, tool_call_names


# ---------------------------------------------------------------------------
# ledger
# ---------------------------------------------------------------------------

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
            output_path    TEXT,
            tool_calls     INTEGER DEFAULT 0,
            tools_used     TEXT
        )
    """)
    # Backwards compat: ALTER older tables lacking the new columns. sqlite3
    # raises OperationalError if the column already exists — swallow that.
    for col_ddl in ("tool_calls INTEGER DEFAULT 0", "tools_used TEXT"):
        try:
            con.execute(f"ALTER TABLE runs ADD COLUMN {col_ddl}")
        except sqlite3.OperationalError:
            pass
    con.execute(
        "INSERT INTO runs (ts, name, route, model, input_tokens, output_tokens, "
        "output_path, tool_calls, tools_used) "
        "VALUES (?,?,?,?,?,?,?,?,?)",
        (row["ts"], row["name"], row["route"], row["model"],
         row["input_tokens"], row["output_tokens"], row["output_path"],
         row["tool_calls"], row["tools_used"]),
    )
    con.commit()
    con.close()


def render_title(tmpl: str, name: str) -> str:
    return (tmpl
            .replace("{{name}}", name)
            .replace("{{date}}", datetime.now().strftime("%Y-%m-%d")))


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

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

    # Tool config
    reads, shells = parse_tools(agent.get("tools", []))
    network       = bool(agent.get("network", False))
    shell_timeout = int(agent.get("shell_timeout_sec", DEFAULT_SHELL_TIMEOUT_SEC))
    bwrap_available = shutil.which("bwrap") is not None
    if shells and not bwrap_available:
        warn("bwrap not installed — shell: tools will fail-closed "
             "(install `bubblewrap` to enable)")

    manifest = build_tool_manifest(reads, shells)
    prompt = (
        f"Run the routine now. Today is {datetime.now().strftime('%A, %Y-%m-%d')}. "
        f"Return the requested content.\n"
    )
    if manifest:
        prompt += "\nAvailable tools (call ONLY with these exact arguments):\n" + manifest + "\n"

    if route == "anthropic":
        text, in_tok, out_tok, tool_names = call_anthropic(
            model, system, prompt, max_tokens,
            reads, shells, network, shell_timeout, bwrap_available)
    elif route == "ollama":
        text, in_tok, out_tok, tool_names = call_ollama(
            model, system, prompt, max_tokens,
            reads, shells, network, shell_timeout, bwrap_available)
    else:
        die(f"unknown route '{route}' (want anthropic | ollama)")

    title = render_title(output.get("title", "{{name}} · {{date}}"), name)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        f.write(f"# {title}\n\n")
        f.write(f"> `{route}/{model}` · in={in_tok} out={out_tok} tokens")
        if tool_names:
            f.write(f" · tools={len(tool_names)} ({', '.join(sorted(set(tool_names)))})")
        f.write("\n\n")
        f.write((text or "").strip())
        f.write("\n")

    log_ledger(ledger, {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "name": name,
        "route": route,
        "model": model,
        "input_tokens": in_tok,
        "output_tokens": out_tok,
        "output_path": out_path,
        "tool_calls": len(tool_names),
        "tools_used": json.dumps(tool_names) if tool_names else None,
    })


if __name__ == "__main__":
    main()
