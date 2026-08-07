#!/usr/bin/env python3
"""vinos-phase-autoexec — autonomous phase execution engine.

Every N hours (systemd timer), analyze the current GSD phase and land ONE
small, safe edit on an autonomous/* branch. Never touches main.

Model routing: LiteLLM proxy at 127.0.0.1:4000, vinos-executor route
(local Ollama qwen3-coder:30b, $0/run).

Hard safety rails:
  * File must match ALLOWED_PATH_PATTERNS and NOT match FORBIDDEN
  * Working tree must be clean (else skip — do not disturb user's WIP)
  * iso/qa/tier1-lint.sh must pass before commit (rollback if not)
  * Commit lands on autonomous/<phase>-<utc-ts> branch, returns to main
  * Max one file per run; content <= MAX_FILE_LINES
  * All events logged to ~/.vinos/routines/state/autoexec/log.jsonl
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO = Path("/data/projects/vinos")
STATE_DIR = Path.home() / ".vinos/routines/state/autoexec"
STATE_DIR.mkdir(parents=True, exist_ok=True)
LOG = STATE_DIR / "log.jsonl"

LITELLM_URL = os.environ.get("VINOS_LITELLM_URL", "http://127.0.0.1:4000/v1/chat/completions")
MODEL = os.environ.get("VINOS_AUTOEXEC_MODEL", "vinos-executor")


def _load_master_key() -> str:
    key = os.environ.get("LITELLM_MASTER_KEY", "")
    if key:
        return key
    secrets = Path.home() / ".vinos-secrets" / "env"
    if secrets.is_file():
        for line in secrets.read_text().splitlines():
            line = line.strip()
            if line.startswith("LITELLM_MASTER_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


LITELLM_KEY = _load_master_key()

MAX_FILE_LINES = 200
MAX_PLAN_CHARS = 2500
MAX_TOKENS = 1500
MODEL_TIMEOUT_S = 900

ALLOWED_PATH_PATTERNS = [
    r"^\.planning/(?!config\.json)",
    r"^docs/",
    r"^SECURITY\.md$",
    r"^README\.md$",
    r"^NOTICES\.md$",
]
FORBIDDEN_PATH_PATTERNS = [
    r"^install/",
    r"^bin/",
    r"^libexec/",
    r"^iso/profile/",
    r"^omarchy/",
    r"^configs/vinos/(default|security|mac|brand|t2|limine|systemd|litellm)/",
    r"\.planning/config\.json$",
]

SYSTEM = """You are the vinOS autonomous phase executor.

Read the current phase's PLAN.md and recent git commits. Propose ONE small, safe edit that advances the phase.

Hard rules:
- Your target MUST be one of the files listed in "Files not yet authored" in the user message. Do not touch anything on the "Already authored" list — that would be a regression.
- Only edit files under .planning/ (except config.json), docs/, or root SECURITY.md / README.md / NOTICES.md.
- NEVER touch install/, bin/, libexec/, iso/profile/, omarchy/, or configs/vinos/{default,security,mac,brand,t2,limine,systemd,litellm}/.
- Prefer additive edits. Total content <= 500 lines.
- If the "Files not yet authored" list is empty, return action=skip with reason="phase targets complete".
- Return ONLY valid JSON — no prose, no code fences.

JSON shape:
{
  "action": "edit" | "create" | "skip",
  "path": "relative/path",
  "content": "full file contents after edit",
  "commit_message": "<=72 char imperative subject",
  "rationale": "one sentence why this advances the phase"
}
"""


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def log(event: str, **fields) -> None:
    fields.update({"ts": now_iso(), "event": event})
    with LOG.open("a") as f:
        f.write(json.dumps(fields) + "\n")
    brief = {k: v for k, v in fields.items() if k not in ("ts", "event")}
    print(f"[autoexec] {event} {json.dumps(brief)[:400]}", file=sys.stderr)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    kwargs.setdefault("cwd", str(REPO))
    kwargs.setdefault("capture_output", True)
    kwargs.setdefault("text", True)
    return subprocess.run(cmd, **kwargs)


def working_tree_clean() -> bool:
    # Untracked files stay put across `git checkout -b`, so we only care about
    # modified or staged tracked files — those would carry onto the branch.
    r = run(["git", "status", "--porcelain", "--untracked-files=no"])
    return r.returncode == 0 and r.stdout.strip() == ""


def current_branch() -> str:
    return run(["git", "rev-parse", "--abbrev-ref", "HEAD"]).stdout.strip()


def latest_phase_dir() -> str | None:
    phases = REPO / ".planning" / "phases"
    if not phases.is_dir():
        return None
    dirs = sorted(p.name for p in phases.iterdir() if p.is_dir())
    # Highest-numbered phase directory with a PLAN.md is our active target
    for name in reversed(dirs):
        if (phases / name / "PLAN.md").is_file():
            return name
    return None


def recent_commits(n: int = 15) -> str:
    return run(["git", "log", f"-{n}", "--oneline", "--no-merges"]).stdout


def existing_proposals(limit: int = 10) -> str:
    """Compact list of autonomous/* branches already proposed, to steer the
    model away from repeating itself."""
    r = run(["git", "branch", "--list", "autonomous/*", "--format=%(refname:short)"])
    branches = [b.strip() for b in r.stdout.splitlines() if b.strip()]
    if not branches:
        return "(none yet — this is the first proposal)"
    lines = []
    for b in branches[-limit:]:
        subj = run(["git", "log", "-1", "--format=%s", b]).stdout.strip()
        files = run(["git", "log", "-1", "--name-only", "--format=", b]).stdout.strip().splitlines()
        files = [f for f in files if f]
        lines.append(f"- {b} · {subj} · touched: {', '.join(files) or '(none)'}")
    return "\n".join(lines)


def path_allowed(path: str) -> bool:
    if any(re.search(p, path) for p in FORBIDDEN_PATH_PATTERNS):
        return False
    return any(re.match(p, path) for p in ALLOWED_PATH_PATTERNS)


DONE_MIN_LINES = 20


def phase_targets(phase_dir: str) -> tuple[list[str], list[str]]:
    """Parse the phase PLAN.md frontmatter files_modified list and split it
    into (done, todo) based on which target files already have substantive
    content. Filters out any path autoexec is not allowed to touch anyway.

    A file counts as "done" if it exists AND has >= DONE_MIN_LINES lines —
    otherwise it's a stub or missing and belongs on the todo list.
    """
    plan_path = REPO / ".planning/phases" / phase_dir / "PLAN.md"
    if not plan_path.is_file():
        return [], []
    plan = plan_path.read_text()

    m = re.search(r"<frontmatter>(.*?)</frontmatter>", plan, re.DOTALL)
    if not m:
        return [], []
    fm = m.group(1)

    fstart = fm.find("files_modified:")
    if fstart < 0:
        return [], []

    targets: list[str] = []
    for line in fm[fstart:].splitlines()[1:]:
        stripped = line.strip()
        if stripped.startswith("- "):
            targets.append(stripped[2:].strip())
        elif stripped and not line.startswith(" "):
            break

    done: list[str] = []
    todo: list[str] = []
    for t in targets:
        if not path_allowed(t):
            continue
        p = REPO / t
        if p.is_file() and len(p.read_text().splitlines()) >= DONE_MIN_LINES:
            done.append(t)
        else:
            todo.append(t)
    return done, todo


def call_model(system: str, user: str) -> str:
    body = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "max_tokens": MAX_TOKENS,
        "temperature": 0.2,
    }
    headers = {"Content-Type": "application/json"}
    if LITELLM_KEY:
        headers["Authorization"] = f"Bearer {LITELLM_KEY}"
    req = urllib.request.Request(
        LITELLM_URL, data=json.dumps(body).encode(), headers=headers
    )
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=MODEL_TIMEOUT_S) as resp:
        data = json.loads(resp.read())
    log("model_ok", elapsed_s=round(time.time() - t0, 1),
        prompt_tokens=data.get("usage", {}).get("prompt_tokens"),
        completion_tokens=data.get("usage", {}).get("completion_tokens"))
    return data["choices"][0]["message"]["content"]


def parse_json(text: str) -> dict:
    m = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
    if m:
        return json.loads(m.group(1))
    m = re.search(r"\{.*\}", text, re.DOTALL)
    if m:
        return json.loads(m.group(0))
    raise ValueError("no JSON in model response")


def tier1_lint(cwd: Path) -> tuple[int, str]:
    r = subprocess.run(
        [str(cwd / "iso/qa/tier1-lint.sh")],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )
    return r.returncode, (r.stdout + r.stderr)[-2000:]


def main() -> int:
    started = time.time()
    log("start", model=MODEL, url=LITELLM_URL)

    if current_branch() != "main":
        log("skipped", reason=f"not on main (on {current_branch()})")
        return 0
    if not working_tree_clean():
        log("skipped", reason="working tree dirty — user WIP present")
        return 0

    phase_dir = latest_phase_dir()
    if not phase_dir:
        log("skipped", reason="no phase dir with PLAN.md found")
        return 0
    done, todo = phase_targets(phase_dir)
    if not todo:
        log("skipped", reason=f"phase {phase_dir} targets complete", done=len(done))
        return 0

    plan_full = (REPO / ".planning/phases" / phase_dir / "PLAN.md").read_text()
    tasks_start = plan_full.find("## Tasks")
    plan = plan_full[tasks_start:tasks_start + MAX_PLAN_CHARS] if tasks_start >= 0 else plan_full[:MAX_PLAN_CHARS]
    commits = recent_commits()
    proposals = existing_proposals()

    todo_str = "\n".join(f"- {t}" for t in todo)
    done_str = "\n".join(f"- {t}" for t in done[:10]) or "(nothing yet)"

    user_msg = (
        f"Active phase directory: {phase_dir}\n\n"
        f"Files not yet authored — pick ONE of these:\n{todo_str}\n\n"
        f"Already authored (do NOT touch — that's a regression):\n{done_str}\n\n"
        f"Autonomous branches already proposed:\n{proposals}\n\n"
        f"Recent commits (newest first):\n{commits}\n\n"
        f"PLAN.md tasks section (for context):\n{plan}\n\n"
        "Return your JSON proposal now — nothing else."
    )

    try:
        raw = call_model(SYSTEM, user_msg)
    except Exception as e:
        log("model_error", err=str(e))
        return 2

    try:
        proposal = parse_json(raw)
    except Exception as e:
        log("parse_error", err=str(e), raw_head=raw[:400])
        return 2

    action = proposal.get("action")
    if action == "skip":
        log("skipped_by_model", reason=proposal.get("reason") or proposal.get("rationale", ""))
        return 0
    if action not in ("edit", "create"):
        log("bad_action", action=str(action))
        return 2

    path = (proposal.get("path") or "").strip()
    if not path or ".." in path or path.startswith("/"):
        log("bad_path", path=path)
        return 2
    if not path_allowed(path):
        log("path_denied", path=path)
        return 2
    if path not in todo:
        log("path_not_in_todo", path=path, todo=todo)
        return 2

    content = proposal.get("content", "")
    if not isinstance(content, str) or not content.strip():
        log("empty_content", path=path)
        return 2
    if content.count("\n") > MAX_FILE_LINES:
        log("too_large", lines=content.count("\n"), path=path)
        return 2

    # Full isolation: work in a temporary git worktree, so no failure path
    # can leak state to the main working tree. On any exit, the worktree is
    # removed. The branch survives only if a commit landed on it.
    ts = datetime.now().strftime("%Y%m%d-%H%M")
    branch = f"autonomous/{phase_dir}-{ts}"
    wt = Path(f"/tmp/vinos-autoexec-{ts}")

    r = run(["git", "worktree", "add", "-B", branch, str(wt), "main"])
    if r.returncode != 0:
        log("worktree_failed", err=(r.stdout + r.stderr)[-400:])
        return 3

    commit_landed = False
    try:
        target = wt / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

        rc, lint_out = tier1_lint(wt)
        if rc != 0:
            log("lint_failed", rc=rc, tail=lint_out[-800:], path=path)
            return 4

        subprocess.run(["git", "add", path], cwd=str(wt), check=False)
        subject = (proposal.get("commit_message") or "update").strip().splitlines()[0][:72]
        body = f"\n\nautoexec: {proposal.get('rationale','')}\nphase: {phase_dir}\nmodel: {MODEL}\n"
        r = subprocess.run(
            ["git", "commit", "-m", f"autoexec: {subject}{body}"],
            cwd=str(wt), capture_output=True, text=True,
        )
        if r.returncode != 0:
            log("commit_failed", err=(r.stdout + r.stderr)[-500:])
            return 5

        commit_landed = True
        elapsed = int(time.time() - started)
        log(
            "committed",
            branch=branch,
            path=path,
            rationale=proposal.get("rationale", ""),
            subject=subject,
            duration_s=elapsed,
        )
        print(f"[autoexec] SUCCESS branch={branch} path={path} ({elapsed}s)")
        return 0
    finally:
        # Always tear down the worktree. Delete the branch if no commit landed.
        run(["git", "worktree", "remove", "--force", str(wt)])
        if not commit_landed:
            run(["git", "branch", "-D", branch])


if __name__ == "__main__":
    sys.exit(main())
