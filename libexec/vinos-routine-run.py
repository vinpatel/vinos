#!/usr/bin/env python3
"""vinos-routine-run — one-shot agent invocation for a routine.

Reads a routine TOML, calls the agent (Anthropic, Ollama, or auto-routed),
writes markdown output to $VINOS_ROUTINE_OUTPUT, and logs a row into the
SQLite ledger at $VINOS_ROUTINE_LEDGER.

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

Auto-router (v2.0.6, [agent].route = "auto"):
    Runs a local Ollama model first, then applies cheap heuristics to decide
    whether to escalate to a premium Anthropic model:

      * low_confidence      — reply is very short or contains hedge phrases
      * reasoning_task      — prompt or [agent].tags mark it as reasoning-heavy
      * context_overflow    — local reply is empty and prompt filled the ctx
      * malformed_tool_json — local returned tool_calls we couldn't parse

    Escalation is capped by [agent.escalation].max_escalations_per_run (per
    process — currently one turn = one potential escalation).

Memory (v2.0.6, [agent].memory ∈ session|persistent|shared):
    "persistent" reads/writes ~/.vinos/routines/state/<name>/memory.md.
    "shared" reads/writes ~/.vinos/routines/state/shared/memory.md.
    The prior memory is prepended to the user turn; after the run, a fresh
    concise summary (via one small local-model call) is appended, capped at
    ~4 KB by trimming the oldest ~500 chars first.

Env:
  VINOS_ROUTINE_OUTPUT   destination markdown file (required)
  VINOS_ROUTINE_LEDGER   sqlite ledger path (required)
  ANTHROPIC_API_KEY      or file at ~/.vinos/secrets/anthropic-key
  VINOS_ROUTINES_STATE   override state dir (default ~/.vinos/routines/state)
"""
from __future__ import annotations

import glob as _glob
import json
import os
import re
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

# --- auto-router thresholds -------------------------------------------------

# If the local reply has fewer than this many whitespace-separated tokens and
# the prompt wasn't a tiny factual lookup, treat it as low confidence.
LOW_CONF_MIN_TOKENS = 40

# Hedge phrases we treat as "the model bailed". Matched case-insensitively as
# whole phrases anywhere in the reply.
LOW_CONF_HEDGES = (
    "i don't know", "i do not know", "i'm not sure", "i am not sure",
    "not sure", "i cannot", "i can't", "i am unable", "i'm unable",
    "unable to", "as an ai", "i don't have", "unclear",
    "insufficient information", "no information",
)

# Prompt/system-prompt markers that flag a reasoning-heavy task.
REASONING_MARKERS = re.compile(
    r"\b(reasoning|prove|derive|chain[- ]of[- ]thought|step[- ]by[- ]step|"
    r"deduce|explain why)\b",
    re.IGNORECASE,
)

# If prompt_eval_count is within this fraction of the local model's context,
# we treat an empty reply as a context-overflow signal.
CONTEXT_OVERFLOW_FRACTION = 0.9
# Fallback assumption when we don't know the local model's true context size.
DEFAULT_LOCAL_CONTEXT_TOKENS = 4096

# --- memory -----------------------------------------------------------------

MEMORY_MAX_BYTES = 4 * 1024        # cap ~4 KB (~800 words)
MEMORY_TRIM_CHARS = 500            # drop this many oldest chars when over cap
MEMORY_SUMMARY_MAX_TOKENS = 200    # budget for the summarisation Ollama call
MEMORY_SUMMARY_MODEL_FALLBACK = "llama3.2"


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def die(msg: str, code: int = 1):
    print(f"vinos-routine-run: {msg}", file=sys.stderr)
    sys.exit(code)


def warn(msg: str):
    print(f"vinos-routine-run: WARN: {msg}", file=sys.stderr)


def info(msg: str):
    print(f"vinos-routine-run: {msg}", file=sys.stderr)


def load_anthropic_key() -> str | None:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if key:
        return key.strip()
    secrets = Path.home() / ".vinos/secrets/anthropic-key"
    if secrets.is_file():
        return secrets.read_text().strip()
    return None


def state_dir() -> Path:
    return Path(os.environ.get("VINOS_ROUTINES_STATE",
                               str(Path.home() / ".vinos/routines/state")))


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
    """Return (text, in_tok, out_tok, tool_names, extras).

    `extras` is a dict of extra signals: {"prompt_eval_count", "eval_count",
    "malformed_tool_json"} — the auto-router uses these for its heuristics.
    """
    tools_declared = bool(reads or shells)
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": prompt},
    ]
    in_tok = out_tok = 0
    tool_call_names: list[str] = []
    final_text = ""
    warned_no_tools = False
    last_prompt_eval = 0
    malformed_tool_json = False

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
        last_prompt_eval = body.get("prompt_eval_count", last_prompt_eval)

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
                    warn(f"Ollama returned malformed tool JSON: {args[:120]!r}")
                    malformed_tool_json = True
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

    extras = {
        "prompt_eval_count": last_prompt_eval,
        "eval_count": out_tok,
        "malformed_tool_json": malformed_tool_json,
    }
    return final_text, in_tok, out_tok, tool_call_names, extras


# ---------------------------------------------------------------------------
# auto-router heuristics
# ---------------------------------------------------------------------------

def _looks_low_confidence(text: str) -> bool:
    if not text:
        return True
    lower = text.lower()
    if any(h in lower for h in LOW_CONF_HEDGES):
        return True
    token_count = len(text.split())
    if token_count < LOW_CONF_MIN_TOKENS:
        return True
    return False


def _looks_reasoning_task(system: str, prompt: str, tags: list[str]) -> bool:
    if tags:
        for t in tags:
            if isinstance(t, str) and t.strip().lower() == "reasoning":
                return True
    combined = f"{system}\n{prompt}"
    return bool(REASONING_MARKERS.search(combined))


def _looks_context_overflow(text: str, prompt_eval_count: int,
                             local_ctx_hint: int) -> bool:
    if text:
        return False
    if not prompt_eval_count:
        return False
    ctx = local_ctx_hint or DEFAULT_LOCAL_CONTEXT_TOKENS
    return prompt_eval_count >= int(ctx * CONTEXT_OVERFLOW_FRACTION)


def decide_escalation(
    text: str,
    prompt_eval_count: int,
    malformed_tool_json: bool,
    escalation_cfg: dict,
    system: str,
    prompt: str,
    tags: list[str],
    local_ctx_hint: int,
) -> str:
    """Return the escalation-reason string (one of the ledger enum values) or
    '' if we shouldn't escalate. Individual triggers can be disabled via
    [agent.escalation].on_<name> = false.
    """
    if escalation_cfg.get("on_malformed_tool_json", True) and malformed_tool_json:
        return "malformed_tool_json"
    if escalation_cfg.get("on_context_overflow", True) and _looks_context_overflow(
            text, prompt_eval_count, local_ctx_hint):
        return "context_overflow"
    if escalation_cfg.get("on_reasoning_task", True) and _looks_reasoning_task(
            system, prompt, tags):
        return "reasoning_task"
    if escalation_cfg.get("on_low_confidence", True) and _looks_low_confidence(text):
        return "low_confidence"
    return ""


# ---------------------------------------------------------------------------
# memory
# ---------------------------------------------------------------------------

def memory_path_for(mode: str, name: str) -> Path | None:
    """Return the on-disk memory path, or None for session/off."""
    if mode == "persistent":
        return state_dir() / name / "memory.md"
    if mode == "shared":
        return state_dir() / "shared" / "memory.md"
    return None


def read_memory(path: Path | None) -> str:
    if path is None or not path.is_file():
        return ""
    try:
        data = path.read_text(errors="replace")
    except OSError as e:
        warn(f"failed to read memory {path}: {e}")
        return ""
    # If somehow bigger than cap, trim from the front.
    if len(data) > MEMORY_MAX_BYTES:
        data = data[-MEMORY_MAX_BYTES:]
    return data


def summarise_for_memory(local_model: str, name: str, output_text: str) -> str:
    """One cheap Ollama call → ~200-token summary. Failure = no update."""
    if not output_text.strip():
        return ""
    payload = {
        "model": local_model or MEMORY_SUMMARY_MODEL_FALLBACK,
        "stream": False,
        "messages": [
            {"role": "system", "content": (
                "You compress a routine run's output into a 2-3 sentence memo "
                "for future runs. No preamble. State facts and decisions only. "
                "Under 60 words."
            )},
            {"role": "user", "content": (
                f"Routine `{name}` just produced this output:\n\n"
                f"---\n{output_text[:6000]}\n---\n\n"
                "Write the memo now."
            )},
        ],
        "options": {"num_predict": MEMORY_SUMMARY_MAX_TOKENS},
    }
    try:
        body = _ollama_post(payload)
    except SystemExit:
        # _ollama_post calls die() on failure; catch to keep memory non-fatal.
        warn("memory summariser: Ollama unreachable — skipping memory update")
        return ""
    return (body.get("message", {}).get("content", "") or "").strip()


def write_memory(path: Path, existing: str, name: str, summary: str) -> None:
    if not summary:
        return
    ts = datetime.now().strftime("%Y-%m-%d %H:%M")
    entry = f"- {ts} [{name}] {summary}\n"
    combined = (existing.rstrip() + "\n" if existing else "") + entry
    # Trim from the front if over cap.
    while len(combined.encode("utf-8")) > MEMORY_MAX_BYTES:
        combined = combined[MEMORY_TRIM_CHARS:]
        # Realign to the next newline so we don't cut in the middle of a bullet.
        nl = combined.find("\n")
        if nl >= 0:
            combined = combined[nl + 1:]
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(combined)
    tmp.replace(path)


# ---------------------------------------------------------------------------
# ledger
# ---------------------------------------------------------------------------

# All columns for the v3 schema. Anything missing on an older DB gets added
# via ALTER TABLE; older rows keep their NULL defaults, which is fine.
_LEDGER_CREATE = """
    CREATE TABLE IF NOT EXISTS runs (
        ts                 TEXT NOT NULL,
        name               TEXT NOT NULL,
        route              TEXT,
        model              TEXT,
        input_tokens       INTEGER,
        output_tokens      INTEGER,
        exit_status        INTEGER DEFAULT 0,
        output_path        TEXT,
        tool_calls         INTEGER DEFAULT 0,
        tools_used         TEXT,
        escalated          INTEGER DEFAULT 0,
        escalated_reason   TEXT,
        local_input_tokens INTEGER,
        local_output_tokens INTEGER
    )
"""

_LEDGER_ADD_COLUMNS = (
    "tool_calls INTEGER DEFAULT 0",
    "tools_used TEXT",
    "escalated INTEGER DEFAULT 0",
    "escalated_reason TEXT",
    "local_input_tokens INTEGER",
    "local_output_tokens INTEGER",
)


def log_ledger(db_path: str, row: dict):
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db_path)
    con.execute(_LEDGER_CREATE)
    # Backwards compat: ALTER older tables lacking newer columns. sqlite3
    # raises OperationalError if the column already exists — swallow that.
    for col_ddl in _LEDGER_ADD_COLUMNS:
        try:
            con.execute(f"ALTER TABLE runs ADD COLUMN {col_ddl}")
        except sqlite3.OperationalError:
            pass
    con.execute(
        "INSERT INTO runs (ts, name, route, model, input_tokens, output_tokens, "
        "output_path, tool_calls, tools_used, escalated, escalated_reason, "
        "local_input_tokens, local_output_tokens) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (row["ts"], row["name"], row["route"], row["model"],
         row["input_tokens"], row["output_tokens"], row["output_path"],
         row["tool_calls"], row["tools_used"],
         row.get("escalated", 0), row.get("escalated_reason"),
         row.get("local_input_tokens"), row.get("local_output_tokens")),
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
    # Legacy: a single `model` field. New: `local_model` + `premium_model`
    # for the auto-router. Fall back sensibly when only one is provided.
    legacy_model  = agent.get("model")
    local_model   = agent.get("local_model", legacy_model or "llama3.2")
    premium_model = agent.get("premium_model", legacy_model or "claude-sonnet-4-6")
    system     = (agent.get("system") or "").strip()
    max_tokens = int(budget.get("max_tokens_per_run", 4000))
    tags       = agent.get("tags", []) or []
    memory_mode = agent.get("memory", "session")

    if memory_mode not in ("session", "persistent", "shared"):
        warn(f"unknown memory mode {memory_mode!r} — falling back to session")
        memory_mode = "session"

    # Tool config
    reads, shells = parse_tools(agent.get("tools", []))
    network       = bool(agent.get("network", False))
    shell_timeout = int(agent.get("shell_timeout_sec", DEFAULT_SHELL_TIMEOUT_SEC))
    bwrap_available = shutil.which("bwrap") is not None
    if shells and not bwrap_available:
        warn("bwrap not installed — shell: tools will fail-closed "
             "(install `bubblewrap` to enable)")

    # Escalation config (only meaningful for route = auto).
    escalation_cfg = cfg.get("agent", {}).get("escalation", {}) or {}
    max_escalations = int(escalation_cfg.get("max_escalations_per_run", 3))
    local_ctx_hint = int(agent.get("local_context_tokens",
                                    DEFAULT_LOCAL_CONTEXT_TOKENS))

    # Memory: read prior context (persistent/shared only).
    mem_path = memory_path_for(memory_mode, name)
    prior_memory = read_memory(mem_path)

    manifest = build_tool_manifest(reads, shells)
    prompt = (
        f"Run the routine now. Today is {datetime.now().strftime('%A, %Y-%m-%d')}. "
        f"Return the requested content.\n"
    )
    if prior_memory:
        prompt = (
            "Prior context from earlier runs (most recent last):\n"
            f"---\n{prior_memory.strip()}\n---\n\n"
        ) + prompt
    if manifest:
        prompt += "\nAvailable tools (call ONLY with these exact arguments):\n" + manifest + "\n"

    # Ledger row defaults — mutated below per route.
    ledger_row: dict = {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "name": name,
        "route": route,
        "model": None,
        "input_tokens": 0,
        "output_tokens": 0,
        "output_path": out_path,
        "tool_calls": 0,
        "tools_used": None,
        "escalated": 0,
        "escalated_reason": None,
        "local_input_tokens": None,
        "local_output_tokens": None,
    }

    if route == "anthropic":
        text, in_tok, out_tok, tool_names = call_anthropic(
            premium_model, system, prompt, max_tokens,
            reads, shells, network, shell_timeout, bwrap_available)
        model_used = premium_model
        ledger_row.update(model=model_used, input_tokens=in_tok,
                          output_tokens=out_tok, tool_calls=len(tool_names),
                          tools_used=json.dumps(tool_names) if tool_names else None)

    elif route == "ollama":
        text, in_tok, out_tok, tool_names, _extras = call_ollama(
            local_model, system, prompt, max_tokens,
            reads, shells, network, shell_timeout, bwrap_available)
        model_used = local_model
        ledger_row.update(model=model_used, input_tokens=in_tok,
                          output_tokens=out_tok, tool_calls=len(tool_names),
                          tools_used=json.dumps(tool_names) if tool_names else None)

    elif route == "auto":
        # First pass: local Ollama model.
        info(f"auto-route: local first-pass with {local_model!r}")
        (l_text, l_in, l_out, l_tools, l_extras) = call_ollama(
            local_model, system, prompt, max_tokens,
            reads, shells, network, shell_timeout, bwrap_available)

        reason = decide_escalation(
            text=l_text,
            prompt_eval_count=l_extras.get("prompt_eval_count", 0),
            malformed_tool_json=l_extras.get("malformed_tool_json", False),
            escalation_cfg=escalation_cfg,
            system=system,
            prompt=prompt,
            tags=tags,
            local_ctx_hint=local_ctx_hint,
        )

        # max_escalations_per_run currently gates the single potential
        # escalation this run has; the counter is future-proofing for when
        # we support multi-turn interactive routines.
        if reason and max_escalations >= 1:
            info(f"auto-route: escalating (reason={reason}) to {premium_model!r}")
            p_text, p_in, p_out, p_tools = call_anthropic(
                premium_model, system, prompt, max_tokens,
                reads, shells, network, shell_timeout, bwrap_available)
            text = p_text
            model_used = f"{local_model}->{premium_model}"
            ledger_row.update(
                route="local->premium",
                model=model_used,
                input_tokens=p_in,
                output_tokens=p_out,
                tool_calls=len(p_tools),
                tools_used=json.dumps(p_tools) if p_tools else None,
                escalated=1,
                escalated_reason=reason,
                local_input_tokens=l_in,
                local_output_tokens=l_out,
            )
        else:
            if reason and max_escalations < 1:
                info(f"auto-route: would escalate (reason={reason}) but "
                     f"max_escalations_per_run={max_escalations} — keeping local")
            else:
                info("auto-route: local reply passed heuristics — no escalation")
            text = l_text
            model_used = local_model
            ledger_row.update(
                route="local",
                model=model_used,
                input_tokens=l_in,
                output_tokens=l_out,
                tool_calls=len(l_tools),
                tools_used=json.dumps(l_tools) if l_tools else None,
                escalated=0,
                escalated_reason="",
                local_input_tokens=l_in,
                local_output_tokens=l_out,
            )
    else:
        die(f"unknown route '{route}' (want anthropic | ollama | auto)")

    title = render_title(output.get("title", "{{name}} · {{date}}"), name)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        f.write(f"# {title}\n\n")
        f.write(f"> `{ledger_row['route']}/{model_used}` · "
                f"in={ledger_row['input_tokens']} out={ledger_row['output_tokens']} tokens")
        if ledger_row.get("escalated"):
            f.write(f" · escalated: {ledger_row.get('escalated_reason', '')}")
        tools_json = ledger_row.get("tools_used")
        if tools_json:
            names = json.loads(tools_json)
            if names:
                f.write(f" · tools={len(names)} ({', '.join(sorted(set(names)))})")
        f.write("\n\n")
        f.write((text or "").strip())
        f.write("\n")

    log_ledger(ledger, ledger_row)

    # Memory: summarise + append (persistent/shared only, best-effort).
    if mem_path is not None and text:
        summary = summarise_for_memory(local_model, name, text)
        if summary:
            write_memory(mem_path, prior_memory, name, summary)
            info(f"memory: appended {len(summary)}B to {mem_path}")


if __name__ == "__main__":
    main()
