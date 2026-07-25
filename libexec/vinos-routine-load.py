#!/usr/bin/env python3
"""vinos-routine-load — install project-scoped routines from .vinos/routines.yaml.

Called by `vinos-routine load <path>`:

  * Locates .vinos/routines.yaml in <path> (or walks up to git root).
  * Parses YAML (PyYAML if available, else a minimal built-in fallback).
  * Applies top-level `defaults:` merge into each routine.
  * Resolves template vars: {{project}}, {{git_root}}, {{home}}.
  * Emits one TOML file per routine, matching the schema consumed by
    libexec/vinos-routine-run.py.

Scopes:
  --scope=project (default) → ~/.vinos/routines/<project>/<name>.toml
  --scope=user              → ~/.vinos/routines/<name>.toml (flat, may collide)

Overwrite protection: if a target already exists, we refuse and print how to
force. --force overrides.

Spec: docs/v2/vinos-routines-yaml-spec.md
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def die(msg: str, code: int = 1):
    print(f"vinos-routine-load: {msg}", file=sys.stderr)
    sys.exit(code)


def info(msg: str):
    print(f"vinos-routine-load: {msg}")


# ---------------------------------------------------------------------------
# YAML parsing — PyYAML preferred, tiny fallback below.
# ---------------------------------------------------------------------------

def _load_yaml_pyyaml(text: str):
    import yaml  # type: ignore
    return yaml.safe_load(text)


def _load_yaml_fallback(text: str):
    """Minimal YAML subset:
      * mappings + lists of mappings (dash-item)
      * scalars: unquoted, single-quoted, double-quoted, ints, bools, null
      * block scalars: `|` (literal) and `>` (folded), with common indent strip
      * `#` comments (line-start or after whitespace)
      * inline flow sequences: `[a, b, c]` and flow mappings: `{a: b}`
    This is enough for .vinos/routines.yaml. If your file needs more, install
    python-yaml (Arch: pacman -S python-yaml).
    """

    # --- Tokenise into logical lines with indent tracking -------------------
    raw_lines = text.splitlines()
    lines: list[tuple[int, str]] = []  # (indent, content)
    i = 0
    while i < len(raw_lines):
        ln = raw_lines[i].rstrip()
        # strip trailing comments (but not inside quotes — simple pass)
        stripped_ln = _strip_trailing_comment(ln)
        if not stripped_ln.strip():
            i += 1
            continue
        indent = len(stripped_ln) - len(stripped_ln.lstrip(" "))
        lines.append((indent, stripped_ln))
        i += 1

    pos = [0]  # boxed cursor

    def peek():
        return lines[pos[0]] if pos[0] < len(lines) else (None, None)

    def consume():
        cur = lines[pos[0]]
        pos[0] += 1
        return cur

    def parse_block(base_indent: int):
        """Parse mapping or list starting at cursor, at exactly base_indent."""
        indent, line = peek()
        if indent is None:
            return None
        if indent < base_indent:
            return None
        content = line[indent:]
        if content.startswith("- "):
            return parse_list(base_indent)
        return parse_mapping(base_indent)

    def parse_mapping(base_indent: int):
        out: dict = {}
        while True:
            indent, line = peek()
            if indent is None or indent < base_indent:
                break
            if indent > base_indent:
                die(f"YAML parse: unexpected indent at line: {line!r}")
            content = line[indent:]
            if content.startswith("- "):
                # list item at same indent — belongs to parent list, not us
                break
            key, _, rest = content.partition(":")
            if not _:
                die(f"YAML parse: expected 'key:' — got {content!r}")
            key = key.strip()
            rest = rest.strip()
            consume()
            if rest == "":
                # nested block
                nxt_indent, nxt_line = peek()
                if nxt_indent is None or nxt_indent <= base_indent:
                    out[key] = None
                else:
                    out[key] = parse_block(nxt_indent)
            elif rest in ("|", ">") or rest.startswith("|") or rest.startswith(">"):
                out[key] = parse_block_scalar(base_indent, rest[0])
            else:
                out[key] = parse_scalar(rest)
        return out

    def parse_list(base_indent: int):
        out: list = []
        while True:
            indent, line = peek()
            if indent is None or indent != base_indent:
                break
            content = line[indent:]
            if not content.startswith("- "):
                break
            item_content = content[2:]
            consume()
            if not item_content.strip():
                # empty dash → nested block
                nxt_indent, _ = peek()
                if nxt_indent is None or nxt_indent <= base_indent:
                    out.append(None)
                else:
                    out.append(parse_block(nxt_indent))
                continue
            if (":" in item_content
                    and not _looks_like_flow(item_content)
                    and not _looks_like_quoted_scalar(item_content)):
                # inline mapping start under the dash: `- key: value` etc.
                # treat as first entry of a mapping whose subsequent keys are
                # indented base_indent+2
                key, _, rest = item_content.partition(":")
                key = key.strip()
                rest = rest.strip()
                item: dict = {}
                if rest == "":
                    nxt_indent, _ = peek()
                    child_indent = base_indent + 2
                    if nxt_indent is not None and nxt_indent >= child_indent:
                        item[key] = parse_block(nxt_indent)
                    else:
                        item[key] = None
                elif rest in ("|", ">") or rest.startswith("|") or rest.startswith(">"):
                    item[key] = parse_block_scalar(base_indent + 2, rest[0])
                else:
                    item[key] = parse_scalar(rest)
                # consume further sibling keys at indent base_indent+2
                while True:
                    nxt_indent, nxt_line = peek()
                    if nxt_indent is None or nxt_indent <= base_indent:
                        break
                    if nxt_indent != base_indent + 2:
                        # deeper — belongs to a nested key already handled
                        break
                    nxt_content = nxt_line[nxt_indent:]
                    if nxt_content.startswith("- "):
                        break
                    k2, _, r2 = nxt_content.partition(":")
                    k2 = k2.strip()
                    r2 = r2.strip()
                    consume()
                    if r2 == "":
                        deeper_indent, _ = peek()
                        if deeper_indent is not None and deeper_indent > base_indent + 2:
                            item[k2] = parse_block(deeper_indent)
                        else:
                            item[k2] = None
                    elif r2 in ("|", ">") or r2.startswith("|") or r2.startswith(">"):
                        item[k2] = parse_block_scalar(base_indent + 2, r2[0])
                    else:
                        item[k2] = parse_scalar(r2)
                out.append(item)
            else:
                out.append(parse_scalar(item_content))
        return out

    def parse_block_scalar(base_indent: int, kind: str):
        """kind is '|' (literal) or '>' (folded). Consumes indented lines."""
        buf: list[str] = []
        first_indent: int | None = None
        # Use raw_lines directly for block scalar — comments and blanks matter
        # Find current raw position
        current_line_idx = _current_raw_index(raw_lines, lines, pos[0] - 1)
        j = current_line_idx + 1
        while j < len(raw_lines):
            raw = raw_lines[j]
            if raw.strip() == "":
                buf.append("")
                j += 1
                continue
            indent = len(raw) - len(raw.lstrip(" "))
            if indent <= base_indent:
                break
            if first_indent is None:
                first_indent = indent
            if indent < first_indent:
                break
            buf.append(raw[first_indent:])
            j += 1
        # Advance cursor past consumed raw lines by rebuilding logical positions
        while pos[0] < len(lines):
            nxt_indent, nxt_line = lines[pos[0]]
            nxt_raw_idx = _current_raw_index(raw_lines, lines, pos[0])
            if nxt_raw_idx is None or nxt_raw_idx >= j:
                break
            pos[0] += 1
        # trailing empties → single newline
        while buf and buf[-1] == "":
            buf.pop()
        if kind == "|":
            return "\n".join(buf) + "\n"
        # folded: join non-empty runs with space, blank lines → newline
        folded: list[str] = []
        run: list[str] = []
        for line in buf:
            if line == "":
                if run:
                    folded.append(" ".join(run))
                    run = []
                folded.append("")
            else:
                run.append(line.strip())
        if run:
            folded.append(" ".join(run))
        return "\n".join(folded) + "\n"

    def parse_scalar(s: str):
        s = s.strip()
        if not s:
            return None
        if s.startswith("[") and s.endswith("]"):
            inner = s[1:-1].strip()
            if not inner:
                return []
            return [parse_scalar(x) for x in _split_flow(inner)]
        if s.startswith("{") and s.endswith("}"):
            inner = s[1:-1].strip()
            if not inner:
                return {}
            out: dict = {}
            for pair in _split_flow(inner):
                k, _, v = pair.partition(":")
                out[k.strip()] = parse_scalar(v.strip())
            return out
        if len(s) >= 2 and s[0] == s[-1] == '"':
            return _unescape_double(s[1:-1])
        if len(s) >= 2 and s[0] == s[-1] == "'":
            return s[1:-1].replace("''", "'")
        low = s.lower()
        if low in ("true", "yes", "on"):
            return True
        if low in ("false", "no", "off"):
            return False
        if low in ("null", "~", ""):
            return None
        try:
            if "." in s or "e" in s.lower():
                return float(s)
            return int(s)
        except ValueError:
            return s

    top = parse_block(0)
    # anything left over?
    remaining = pos[0] < len(lines)
    if remaining:
        _, rest_line = peek()
        die(f"YAML parse: trailing content not consumed near: {rest_line!r}")
    return top


def _strip_trailing_comment(line: str) -> str:
    out = []
    in_s = False
    in_d = False
    for i, ch in enumerate(line):
        if ch == "'" and not in_d:
            in_s = not in_s
        elif ch == '"' and not in_s:
            in_d = not in_d
        elif ch == "#" and not in_s and not in_d:
            # require preceding whitespace or line start
            if i == 0 or line[i - 1] in (" ", "\t"):
                break
        out.append(ch)
    return "".join(out).rstrip()


def _looks_like_flow(s: str) -> bool:
    return s.lstrip().startswith(("[", "{"))


def _looks_like_quoted_scalar(s: str) -> bool:
    """True if s is entirely wrapped in matched quotes — a scalar, not a key."""
    s = s.strip()
    return len(s) >= 2 and s[0] == s[-1] and s[0] in ('"', "'")


def _split_flow(inner: str) -> list[str]:
    parts: list[str] = []
    depth = 0
    cur: list[str] = []
    in_s = in_d = False
    for ch in inner:
        if ch == "'" and not in_d:
            in_s = not in_s
        elif ch == '"' and not in_s:
            in_d = not in_d
        elif not in_s and not in_d:
            if ch in "[{":
                depth += 1
            elif ch in "]}":
                depth -= 1
            elif ch == "," and depth == 0:
                parts.append("".join(cur).strip())
                cur = []
                continue
        cur.append(ch)
    if cur:
        parts.append("".join(cur).strip())
    return parts


def _unescape_double(s: str) -> str:
    return (s.replace('\\n', '\n').replace('\\t', '\t')
             .replace('\\"', '"').replace('\\\\', '\\'))


def _current_raw_index(raw_lines: list[str], logical: list[tuple[int, str]], logical_idx: int) -> int | None:
    """Map a logical-line index back to the raw-line index. Best-effort match
    on stripped content — good enough for our block-scalar rewinding."""
    if logical_idx < 0 or logical_idx >= len(logical):
        return None
    target = logical[logical_idx][1].strip()
    # count occurrences up to this logical index for tiebreak
    seen = sum(1 for k in range(logical_idx) if logical[k][1].strip() == target)
    found = 0
    for j, raw in enumerate(raw_lines):
        if _strip_trailing_comment(raw).strip() == target:
            if found == seen:
                return j
            found += 1
    return None


def load_yaml(text: str):
    try:
        return _load_yaml_pyyaml(text)
    except ImportError:
        info("PyYAML not installed — using built-in minimal parser. For full "
             "spec support: `sudo pacman -S python-yaml`")
        return _load_yaml_fallback(text)


# ---------------------------------------------------------------------------
# TOML writing — tomli_w preferred, fallback below.
# ---------------------------------------------------------------------------

def dump_toml(data: dict) -> str:
    try:
        import tomli_w  # type: ignore
        return tomli_w.dumps(data)
    except ImportError:
        return _dump_toml_fallback(data)


def _dump_toml_fallback(data: dict) -> str:
    """Render the routine subset of TOML. Handles str/int/float/bool/list-of-str
    and one level of section nesting — matches what routine-run.py consumes."""
    out: list[str] = []
    # Emit top-level scalar keys (none expected for routines, but be safe)
    top_scalars = {k: v for k, v in data.items() if not isinstance(v, dict)}
    for k, v in top_scalars.items():
        out.append(f"{k} = {_toml_value(v)}")
    if top_scalars:
        out.append("")
    # Sections
    for section, body in data.items():
        if not isinstance(body, dict):
            continue
        out.append(f"[{section}]")
        for k, v in body.items():
            if isinstance(v, dict):
                # rare — emit as [section.subsection]
                out.append("")
                out.append(f"[{section}.{k}]")
                for k2, v2 in v.items():
                    out.append(f"{k2} = {_toml_value(v2)}")
                continue
            out.append(f"{k} = {_toml_value(v)}")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def _toml_value(v) -> str:
    if v is None:
        return '""'
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        return "[" + ", ".join(_toml_value(x) for x in v) + "]"
    if isinstance(v, str):
        if "\n" in v:
            # triple-quoted string; escape triple quotes if present
            body = v.replace('"""', '\\"\\"\\"')
            return f'"""\n{body}"""'
        escaped = (v.replace("\\", "\\\\")
                    .replace('"', '\\"')
                    .replace("\n", "\\n")
                    .replace("\t", "\\t"))
        return f'"{escaped}"'
    # dict handled by caller
    return f'"{v}"'


# ---------------------------------------------------------------------------
# Locate + resolve
# ---------------------------------------------------------------------------

def find_git_root(start: Path) -> Path | None:
    try:
        r = subprocess.run(
            ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=False,
        )
        if r.returncode == 0 and r.stdout.strip():
            return Path(r.stdout.strip())
    except FileNotFoundError:
        pass
    # fallback: walk up looking for .git
    p = start.resolve()
    while True:
        if (p / ".git").exists():
            return p
        if p.parent == p:
            return None
        p = p.parent


def locate_yaml(path: Path) -> tuple[Path, Path]:
    """Return (yaml_path, project_root). Search order:
       1. <path>/.vinos/routines.yaml
       2. If <path> is in a git repo → <git_root>/.vinos/routines.yaml
       3. If <path> itself is a .yaml file, use it (project_root = its parent's
          parent when parent is `.vinos`, else parent).
    """
    p = path.resolve()
    if p.is_file() and p.suffix in (".yaml", ".yml"):
        # Handed a direct file — the project root is dir-above-.vinos when
        # the file lives in `.vinos/`, else the file's parent.
        parent = p.parent
        project_root = parent.parent if parent.name == ".vinos" else parent
        return p, project_root
    if p.is_dir():
        candidate = p / ".vinos" / "routines.yaml"
        if candidate.is_file():
            return candidate, p
        gitroot = find_git_root(p)
        if gitroot is not None:
            candidate = gitroot / ".vinos" / "routines.yaml"
            if candidate.is_file():
                return candidate, gitroot
    die(f"no .vinos/routines.yaml found in {path} (or its git root)")


# ---------------------------------------------------------------------------
# Merge + resolve
# ---------------------------------------------------------------------------

def deep_merge(base: dict, override: dict) -> dict:
    out = dict(base)
    for k, v in override.items():
        if k in out and isinstance(out[k], dict) and isinstance(v, dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def resolve_templates(obj, vars: dict):
    if isinstance(obj, str):
        for k, v in vars.items():
            obj = obj.replace("{{" + k + "}}", str(v))
        return obj
    if isinstance(obj, dict):
        return {k: resolve_templates(v, vars) for k, v in obj.items()}
    if isinstance(obj, list):
        return [resolve_templates(x, vars) for x in obj]
    return obj


# ---------------------------------------------------------------------------
# Routine → TOML conversion
# ---------------------------------------------------------------------------

# YAML top-level routine keys that map into a specific TOML section.
# Anything not in this map (e.g. `docker`) is preserved under [routine] as a
# scalar so it round-trips visibly for humans.
_KNOWN_SECTIONS = {
    "schedule": "schedule",
    "agent": "agent",
    "output": "output",
    "budget": "budget",
}

# Fields that belong under [routine] at top level.
_ROUTINE_TOP_FIELDS = ("name", "description", "enabled", "docker")


def routine_yaml_to_toml_dict(r: dict) -> dict:
    """Convert one YAML routine dict to the sectioned TOML dict."""
    if "name" not in r or not r["name"]:
        die("routine missing required `name` field")

    routine_section: dict = {}
    for k in _ROUTINE_TOP_FIELDS:
        if k in r and r[k] is not None:
            routine_section[k] = r[k]

    out: dict = {"routine": routine_section}
    for yaml_key, toml_key in _KNOWN_SECTIONS.items():
        v = r.get(yaml_key)
        if isinstance(v, dict):
            # drop None values so tomllib on the runtime side sees only real keys
            out[toml_key] = {kk: vv for kk, vv in v.items() if vv is not None}

    # Preserve any other unknown top-level scalars under [routine].meta.<key>
    known = set(_ROUTINE_TOP_FIELDS) | set(_KNOWN_SECTIONS.keys())
    extras = {k: v for k, v in r.items() if k not in known}
    if extras:
        # nested-dict extras → own section; scalars → under [routine]
        for k, v in extras.items():
            if isinstance(v, dict):
                out[k] = v
            else:
                out["routine"][k] = v
    return out


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def plan(yaml_path: Path, project_root: Path, scope: str) -> tuple[dict, list[tuple[str, Path, dict]]]:
    """Parse the YAML and compute what would be written.
    Returns (parsed_doc, [(routine_name, target_path, toml_dict), ...])."""
    text = yaml_path.read_text()
    doc = load_yaml(text)
    if not isinstance(doc, dict):
        die("routines.yaml must be a mapping at the top level")

    kind = doc.get("kind")
    if kind and kind != "RoutineSet":
        die(f"unsupported kind: {kind!r} (want 'RoutineSet')")

    metadata = doc.get("metadata") or {}
    project = metadata.get("project") or project_root.name
    defaults = doc.get("defaults") or {}
    routines = doc.get("routines") or []
    if not isinstance(routines, list) or not routines:
        die("routines.yaml: `routines:` must be a non-empty list")

    tmpl_vars = {
        "project": project,
        "git_root": str(project_root),
        "home": str(Path.home()),
    }

    home = Path.home()
    if scope == "project":
        target_dir = home / ".vinos" / "routines" / project
    elif scope == "user":
        target_dir = home / ".vinos" / "routines"
    else:
        die(f"unknown scope: {scope!r} (want project|user)")

    plans: list[tuple[str, Path, dict]] = []
    for r in routines:
        if not isinstance(r, dict):
            die(f"routine entry is not a mapping: {r!r}")
        merged = deep_merge(defaults, r)
        merged = resolve_templates(merged, tmpl_vars)
        toml_dict = routine_yaml_to_toml_dict(merged)
        name = toml_dict["routine"]["name"]
        target = target_dir / f"{name}.toml"
        plans.append((name, target, toml_dict))
    return doc, plans


def cmd_load(argv: list[str]):
    ap = argparse.ArgumentParser(prog="vinos-routine load")
    ap.add_argument("path", nargs="?", default=".", help="repo path or .yaml file")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--scope", choices=("project", "user"), default="project")
    ap.add_argument("--force", action="store_true",
                    help="overwrite existing routine files")
    args = ap.parse_args(argv)

    yaml_path, project_root = locate_yaml(Path(args.path))
    info(f"loading {yaml_path}")
    _doc, plans = plan(yaml_path, project_root, args.scope)

    conflicts = [(n, t) for n, t, _ in plans if t.exists() and not args.force]
    if conflicts and not args.dry_run:
        for n, t in conflicts:
            print(f"  conflict: {t} already exists (routine {n})")
        die("refusing to overwrite — pass --force to replace")

    for name, target, toml_dict in plans:
        rendered = dump_toml(toml_dict)
        if args.dry_run:
            print(f"--- would write: {target} ---")
            print(rendered)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(rendered)
            print(f"  wrote {name} → {target}")

    if args.dry_run:
        info(f"dry-run: {len(plans)} routine(s) would be written under scope={args.scope}")
    else:
        info(f"loaded {len(plans)} routine(s) under scope={args.scope}")


def cmd_unload(argv: list[str]):
    ap = argparse.ArgumentParser(prog="vinos-routine unload")
    ap.add_argument("path", nargs="?", default=".")
    ap.add_argument("--scope", choices=("project", "user"), default="project")
    args = ap.parse_args(argv)

    yaml_path, project_root = locate_yaml(Path(args.path))
    info(f"unloading {yaml_path}")
    _doc, plans = plan(yaml_path, project_root, args.scope)

    removed = 0
    for name, target, _ in plans:
        if target.is_file():
            target.unlink()
            print(f"  removed {name} → {target}")
            removed += 1
        else:
            print(f"  skip {name}: not present at {target}")

    # If scope=project and the project dir is now empty, remove it too.
    if args.scope == "project" and plans:
        parent = plans[0][1].parent
        try:
            if parent.is_dir() and not any(parent.iterdir()):
                parent.rmdir()
                info(f"removed empty {parent}")
        except OSError:
            pass

    info(f"unloaded {removed} routine(s)")


def main():
    if len(sys.argv) < 2:
        die("usage: vinos-routine-load {load|unload} <path> [flags]")
    sub = sys.argv[1]
    if sub == "load":
        cmd_load(sys.argv[2:])
    elif sub == "unload":
        cmd_unload(sys.argv[2:])
    else:
        die(f"unknown subcommand: {sub!r} (want load|unload)")


if __name__ == "__main__":
    main()
