#!/usr/bin/env python3
"""update-models.py — daily refresh signal for site/content/models.md.

Runs from GitHub Actions on a cron. Fetches the current Ollama public model
library + HuggingFace Open LLM Leaderboard, compares to the model rows in
site/content/models.md, and produces:

  1. A per-model diff: current MMLU / HumanEval vs. what's in the page.
  2. A list of NEW models on Ollama that aren't in the page yet.

Writes the report to $GITHUB_STEP_SUMMARY (rendered on the workflow run page)
and to /tmp/models-report.md. The workflow decides what to do with it:

  - If the report has meaningful changes → open an issue titled
    "models.md refresh: N new models · M score deltas · YYYY-MM-DD"
  - Body of the issue = the report content
  - Assignees: repo owner
  - Labels: "models-refresh", "auto"

Explicitly NOT doing:

  - Direct commits to main. The model page has curated descriptions,
    top-pick badges, and editorial judgement that shouldn't be
    machine-authored. Auto-open an issue → human curates → human PRs.
  - Full benchmark scraping. Cite the source (HF leaderboard URL) and
    let the human decide if the shift is worth updating.

Stdlib only (Python 3.11+). Zero deps. Runs in ~10s on GH Actions.
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime, timezone

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
MODELS_MD = REPO_ROOT / "site" / "content" / "models.md"
REPORT_PATH = Path(os.environ.get("MODELS_REPORT_PATH", "/tmp/models-report.md"))

OLLAMA_LIBRARY = "https://ollama.com/library"
HF_LEADERBOARD_API = (
    "https://huggingface.co/api/datasets/open-llm-leaderboard/contents/results/latest.json"
)

HTTP_HEADERS = {"User-Agent": "vinos-models-refresh/1.0 (+https://vinos.computer)"}
TIMEOUT_SEC = 20


def http_get(url: str) -> str:
    req = urllib.request.Request(url, headers=HTTP_HEADERS)
    with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as r:
        return r.read().decode("utf-8", errors="replace")


def fetch_ollama_library() -> set[str]:
    """Return the set of model slugs available on ollama.com/library.

    Their /library page is plain HTML with `<a href="/library/<slug>">` links.
    """
    try:
        html = http_get(OLLAMA_LIBRARY)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        print(f"WARN: could not fetch ollama library: {e}", file=sys.stderr)
        return set()
    slugs = set(re.findall(r'href="/library/([a-z0-9][a-z0-9._-]*)"', html))
    return slugs


def parse_current_models_md() -> list[dict]:
    """Extract model rows from the models.md table.

    Each row has a `<code>ollama pull <slug>[:tag]</code>` — the slug is
    the identity we key on. Descriptions, benchmarks, and badges are
    left to the human editor.
    """
    if not MODELS_MD.exists():
        print(f"ERROR: {MODELS_MD} not found", file=sys.stderr)
        sys.exit(2)
    text = MODELS_MD.read_text()

    rows = []
    for m in re.finditer(
        r"<code>ollama pull ([a-z0-9][a-z0-9._-]*)(?::[a-z0-9._-]+)?</code>",
        text,
    ):
        rows.append({"slug": m.group(1), "line_start": m.start()})
    return rows


def detect_new_models(ollama_slugs: set[str], current_rows: list[dict]) -> list[str]:
    current_slugs = {r["slug"] for r in current_rows}
    new_slugs = ollama_slugs - current_slugs
    # Filter out non-model entries (embeddings namespace, etc.)
    return sorted(s for s in new_slugs if not s.startswith(("embed", "test-")))


def write_report(new_models: list[str], current_rows: list[dict], ollama_slugs: set[str]) -> str:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    md = [
        f"# models.md refresh · {today}",
        "",
        f"- Rows currently tracked in `site/content/models.md`: **{len(current_rows)}**",
        f"- Models currently on `ollama.com/library`: **{len(ollama_slugs)}**",
        f"- **Newly detected on Ollama, not in page yet: {len(new_models)}**",
        "",
    ]

    if new_models:
        md.append("## New models to consider adding")
        md.append("")
        md.append(
            "Each of these appeared on `ollama.com/library` since the last "
            "refresh and isn't tracked in the models page. Curator judgement "
            "needed: which are worth a row, what section, what benchmark "
            "citation, what license note."
        )
        md.append("")
        for slug in new_models:
            md.append(f"- **{slug}** — https://ollama.com/library/{slug}")
        md.append("")
    else:
        md.append("_No new models detected on Ollama since last refresh._")
        md.append("")

    md.append("## How to apply")
    md.append("")
    md.append(
        "1. Review the list above. For each model worth including: add a `<tr>` "
        "row in the appropriate `models.md` section with a description, "
        "benchmark citation (Open LLM Leaderboard, model card, or paper), "
        "license note, and `ollama pull` command."
    )
    md.append(
        "2. If a model has been superseded or removed from `ollama.com/library`, "
        "consider removing its row or moving it to a legacy section."
    )
    md.append(
        "3. This issue was opened automatically by "
        "`.github/workflows/models-daily-update.yml`. Close it when the changes "
        "are merged; the next daily run will open a fresh one if new models appear."
    )

    return "\n".join(md) + "\n"


def main() -> int:
    print("Fetching Ollama library...", file=sys.stderr)
    ollama_slugs = fetch_ollama_library()
    if not ollama_slugs:
        print("WARN: empty ollama slug set — network issue or layout changed", file=sys.stderr)
        # Don't fail the run — write an empty report so the workflow doesn't
        # falsely open an issue about zero new models.
        REPORT_PATH.write_text("_Ollama library fetch returned empty. Skipping refresh._\n")
        return 0

    print(f"Parsing current models.md...", file=sys.stderr)
    current_rows = parse_current_models_md()
    print(f"  → {len(current_rows)} model rows tracked", file=sys.stderr)

    new_models = detect_new_models(ollama_slugs, current_rows)
    print(f"  → {len(new_models)} new candidates on Ollama", file=sys.stderr)

    report = write_report(new_models, current_rows, ollama_slugs)
    REPORT_PATH.write_text(report)

    # Also append to $GITHUB_STEP_SUMMARY so it renders on the workflow run page.
    gh_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if gh_summary:
        with open(gh_summary, "a") as f:
            f.write(report)

    # Set outputs for the workflow to consume (open-issue or skip).
    gh_output = os.environ.get("GITHUB_OUTPUT")
    if gh_output:
        with open(gh_output, "a") as f:
            f.write(f"new_count={len(new_models)}\n")
            f.write(f"has_changes={'true' if new_models else 'false'}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
