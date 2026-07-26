#!/usr/bin/env python3
"""vinos_routine_cron — translate standard cron strings to systemd OnCalendar.

Public entry points:
  * cron_to_oncalendar(expr: str) -> str
      Raises ValueError on unsupported expressions (with a message pointing
      the user to write [schedule].oncalendar directly).

Also usable as a CLI:
  $ python3 -m vinos_routine_cron '0 6 * * *'
  *-*-* 06:00:00

The translator is intentionally conservative — it handles the common subset
that maps cleanly to OnCalendar. Weird cron features (`?`, `L`, `W`, `#`,
year field, seconds field, timezone prefixes) are refused loudly.

Grammar supported (5-field standard cron):

    minute  hour  day-of-month  month  day-of-week

Each field may be:
  * a single value       (e.g. `0`, `MON`)
  * a wildcard           (`*`)
  * a list of values     (e.g. `0,15,30`)
  * an inclusive range   (e.g. `1-5`, `MON-FRI`)
  * a step               (`*/N`, `A-B/N`)
  * for day-of-week: names (SUN|MON|TUE|WED|THU|FRI|SAT), any case;
    0 and 7 both mean Sunday, matching Vixie/systemd conventions.
  * for month: names (JAN..DEC), any case, or 1..12.

Shortcuts supported (return OnCalendar keyword directly where possible):
  @hourly  @daily  @midnight  @weekly  @monthly  @yearly / @annually

Explicitly unsupported (DIE with a clear message):
  * `H` / random tokens (Jenkins-style)
  * `?`, `L`, `W`, `#` (Quartz)
  * 6- or 7-field cron (seconds or year)
  * mixed alphanumeric list items in numeric fields
"""
from __future__ import annotations

import sys
from typing import Iterable

# ---------------------------------------------------------------------------
# constants
# ---------------------------------------------------------------------------

_MONTHS = {
    "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
    "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
}

# systemd DayOfWeek uses "Mon..Sun". Cron uses 0-6 (Sun-Sat) or names.
_DOW_NUM_TO_SYSTEMD = {
    0: "Sun", 1: "Mon", 2: "Tue", 3: "Wed",
    4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun",
}
_DOW_NAMES = {
    "SUN": 0, "MON": 1, "TUE": 2, "WED": 3,
    "THU": 4, "FRI": 5, "SAT": 6,
}

# OnCalendar shortcut keywords that systemd already understands verbatim.
_KEYWORDS = {
    "@hourly":   "hourly",
    "@daily":    "daily",
    "@midnight": "daily",
    "@weekly":   "weekly",
    "@monthly":  "monthly",
    "@yearly":   "yearly",
    "@annually": "yearly",
}

# Jenkins/Quartz extensions we refuse. These are detected as *atoms* after
# splitting the field on `,` / `-` / `/`, not as substrings — otherwise a
# valid `WED` would trip the `W` check.
_BAD_ATOMS = {"H", "?", "L", "W", "LW"}
_BAD_ATOM_SUFFIX = ("L", "W")  # e.g. `15W`, `1L`
_BAD_ATOM_SUBSTRING = ("#",)   # e.g. `MON#2` (nth-weekday-of-month)


# ---------------------------------------------------------------------------
# errors
# ---------------------------------------------------------------------------

class CronTranslateError(ValueError):
    """Raised when a cron expression can't be translated to OnCalendar."""


def _die(msg: str) -> None:
    raise CronTranslateError(
        f"{msg}\n"
        "  hint: write [schedule].oncalendar directly using systemd "
        "OnCalendar syntax (see `man systemd.time`)."
    )


# ---------------------------------------------------------------------------
# field parsing
# ---------------------------------------------------------------------------

def _reject_bad_atom(atom: str, original: str) -> None:
    """Refuse Quartz/Jenkins tokens that we can't map to OnCalendar."""
    up = atom.upper()
    # Peel off any step suffix (`H/5` → `H`) before checking bare-token match.
    bare = up.split("/", 1)[0].split("-", 1)[0]
    if bare in _BAD_ATOMS:
        _die(f"unsupported cron token {bare!r} in field {original!r}")
    if bare.endswith(_BAD_ATOM_SUFFIX) and bare not in ("MON", "TUE", "WED",
                                                        "THU", "FRI", "SAT",
                                                        "SUN"):
        # e.g. `15W` (nearest weekday to 15th) or `1L` (last day)
        # Careful: none of our valid day-name atoms end in L/W, but be explicit.
        _die(f"unsupported cron token {bare!r} in field {original!r}")
    for sub in _BAD_ATOM_SUBSTRING:
        if sub in up:
            _die(f"unsupported cron token containing {sub!r} in field {original!r}")


def _parse_field(
    field: str,
    lo: int,
    hi: int,
    names: dict[str, int] | None = None,
) -> list[int] | None:
    """Return a sorted list of ints for the field, or None for a wildcard.

    A step expression `*/N` returns a synthesised list [lo, lo+N, ...] up to hi.
    A step on a range `A-B/N` steps within that range.
    """
    field = field.strip()
    if not field:
        _die("empty cron field")

    if field == "*":
        return None

    # Split on commas — each part parsed independently, results unioned.
    values: set[int] = set()
    for part in field.split(","):
        part = part.strip()
        if not part:
            _die(f"empty comma-list entry in field {field!r}")
        _reject_bad_atom(part, field)
        values.update(_parse_atom(part, lo, hi, names, original=field))

    return sorted(values)


def _parse_atom(
    atom: str,
    lo: int,
    hi: int,
    names: dict[str, int] | None,
    original: str,
) -> Iterable[int]:
    """Parse a single atom: `A`, `A-B`, `*/N`, `A-B/N`."""
    step = 1
    if "/" in atom:
        base, _, step_s = atom.partition("/")
        try:
            step = int(step_s)
        except ValueError:
            _die(f"non-integer step in field {original!r}")
        if step <= 0:
            _die(f"step must be >0 in field {original!r}")
        atom = base

    if atom == "*" or atom == "":
        start, end = lo, hi
    elif "-" in atom:
        a, _, b = atom.partition("-")
        start = _resolve_name(a, lo, hi, names, original)
        end   = _resolve_name(b, lo, hi, names, original)
        if start > end:
            _die(f"range start > end in field {original!r}")
    else:
        v = _resolve_name(atom, lo, hi, names, original)
        if step != 1:
            # `5/10` doesn't have a widely-agreed cron meaning — refuse.
            _die(f"step without range or wildcard in field {original!r}")
        return [v]

    return range(start, end + 1, step)


def _resolve_name(tok: str, lo: int, hi: int, names: dict[str, int] | None,
                  original: str) -> int:
    tok = tok.strip()
    if not tok:
        _die(f"empty token in field {original!r}")
    if names and tok.upper() in names:
        v = names[tok.upper()]
    else:
        try:
            v = int(tok)
        except ValueError:
            _die(f"unrecognised token {tok!r} in field {original!r}")
    if v < lo or v > hi:
        # Allow DoW 7 (= Sunday) through even though hi=6 normally.
        if not (names is _DOW_NAMES and v == 7):
            _die(f"value {tok!r} out of range [{lo}..{hi}] in field {original!r}")
    return v


# ---------------------------------------------------------------------------
# OnCalendar assembly
# ---------------------------------------------------------------------------

def _fmt_list(vals: list[int] | None, width: int = 2, wildcard: str = "*") -> str:
    """Format an int-list as a comma-joined zero-padded string, or wildcard."""
    if vals is None:
        return wildcard
    return ",".join(f"{v:0{width}d}" for v in vals)


def _fmt_step(vals: list[int] | None, lo: int, hi: int, width: int = 2) -> str:
    """Try to render as `*/N` if the list is an arithmetic progression from
    lo covering the full range at step N; otherwise fall back to a plain list.
    """
    if vals is None:
        return "*"
    if len(vals) < 2:
        return _fmt_list(vals, width)
    step = vals[1] - vals[0]
    if step <= 0:
        return _fmt_list(vals, width)
    expected = list(range(lo, hi + 1, step))
    if vals == expected:
        # Prefer step form only when it starts at lo and covers full range.
        return f"*/{step}"
    return _fmt_list(vals, width)


def _fmt_dow(vals: list[int] | None) -> str | None:
    """Format day-of-week for the OnCalendar prefix, or None for wildcard."""
    if vals is None:
        return None
    # Normalise 7 → 0 (both = Sunday), dedupe.
    norm = sorted({0 if v == 7 else v for v in vals})
    if norm == list(range(0, 7)):
        return None  # all days == wildcard
    # Try to express as a contiguous range `Mon..Fri` if possible.
    if len(norm) >= 2 and norm == list(range(norm[0], norm[-1] + 1)):
        return f"{_DOW_NUM_TO_SYSTEMD[norm[0]]}..{_DOW_NUM_TO_SYSTEMD[norm[-1]]}"
    return ",".join(_DOW_NUM_TO_SYSTEMD[v] for v in norm)


# ---------------------------------------------------------------------------
# public entry point
# ---------------------------------------------------------------------------

def cron_to_oncalendar(expr: str) -> str:
    """Translate a cron expression to a systemd OnCalendar string.

    Raises CronTranslateError (subclass of ValueError) on unsupported input.
    """
    if expr is None:
        _die("cron expression is None")
    s = expr.strip()
    if not s:
        _die("empty cron expression")

    # Shortcuts first.
    if s.lower() in _KEYWORDS:
        return _KEYWORDS[s.lower()]
    if s.startswith("@"):
        _die(f"unsupported cron shortcut {s!r}")

    fields = s.split()
    if len(fields) == 6:
        _die("6-field cron (leading seconds) is not supported")
    if len(fields) == 7:
        _die("7-field cron (Quartz-style with year) is not supported")
    if len(fields) != 5:
        _die(f"expected 5 fields, got {len(fields)}")

    minute_f, hour_f, dom_f, month_f, dow_f = fields

    minute = _parse_field(minute_f, 0, 59)
    hour   = _parse_field(hour_f,   0, 23)
    dom    = _parse_field(dom_f,    1, 31)
    month  = _parse_field(month_f,  1, 12, names=_MONTHS)
    dow    = _parse_field(dow_f,    0, 6,  names=_DOW_NAMES)

    # Assemble date piece: [DayOfWeek ]Year-Month-DayOfMonth
    dow_str = _fmt_dow(dow)
    month_str = _fmt_list(month, 2)
    dom_str = _fmt_list(dom, 2)

    date_part = f"*-{month_str}-{dom_str}"

    # Assemble time piece: Hour:Minute:Second — try step form for minute/hour.
    minute_str = _fmt_step(minute, 0, 59)
    hour_str = _fmt_step(hour, 0, 23)
    time_part = f"{hour_str}:{minute_str}:00"

    if dow_str:
        return f"{dow_str} {date_part} {time_part}"
    return f"{date_part} {time_part}"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python3 -m vinos_routine_cron '<cron expression>'",
              file=sys.stderr)
        return 2
    try:
        print(cron_to_oncalendar(argv[0]))
        return 0
    except CronTranslateError as e:
        print(f"vinos-routine-cron: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
