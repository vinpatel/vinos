---
title: "Running a routine"
description: "List, enable, run, log, and inspect cost for routines. Every command with real captured output."
weight: 10
---

## The 30-second tour

Every routine command starts with `vinos-routine`. Its help text is
the source of truth:

```
$ vinos-routine --help
vinos-routine — scheduled autonomous agents

Usage:
  vinos-routine list [--scope=project|user]
                                        List routines with enabled + schedule status
  vinos-routine run <name>              Run a routine now (ad-hoc)
  vinos-routine enable <name>           Enable systemd user timer
  vinos-routine disable <name>          Disable systemd user timer
  vinos-routine logs <name> [--tail]    Show routine execution logs
  vinos-routine cost                    Recent runs + token usage (last 20)
  vinos-routine edit <name>             Open TOML in $EDITOR (scaffolds if new)
  vinos-routine load <path> [--dry-run --scope=project|user --force]
                                        Install routines from .vinos/routines.yaml
  vinos-routine unload <path> [--scope=project|user]
                                        Remove routines this YAML installed
  vinos-routine help                    This message

Routines:
  ~/.vinos/routines/*.toml            (user, hand-authored)
  ~/.vinos/routines/&lt;project&gt;/*.toml  (project-scoped, from `load`)
  /etc/vinos/routines/*.toml          (system defaults, shipped in ISO)

Outputs → ~/.vinos/routines/state/&lt;name&gt;/YYYY-MM-DD-HHMM.md
Ledger  → ~/.vinos/routines/state/ledger.db
```

## List

```
$ vinos-routine list
NAME                           ENABLED    LAST RUN                 SCHEDULE
day-brief                      no         never                    *-*-* 06:00:00
evening-shutdown               no         never                    *-*-* 18:00:00
```

<figure class="doc-shot doc-shot-pending" id="shot-23">
  <div class="doc-shot-slot">Screenshot pending: foot terminal after `vinos-routine list`</div>
  <figcaption>vinos-routine list — see SCREENSHOTS_NEEDED.md #shot-23.</figcaption>
</figure>

Everything shipped is **disabled by default**. The first-boot flow
asks which you want on; you can always change your mind with
`enable` / `disable`.

## Enable

Turns on the systemd user timer. From then on, the routine runs on
its schedule until you disable it.

```
$ vinos-routine enable day-brief
✓ enabled day-brief.timer
  next run  Sat 2026-07-26 06:00:05 EDT  (in 6h 42m)
```

## Run once, ad hoc

Skips the schedule and streams to stdout. Useful when you're editing a
routine and want fast feedback.

```
$ vinos-routine run day-brief
→ routine    day-brief
→ schedule   *-*-* 06:00:00
→ model      claude-sonnet-4-6           (anthropic)
→ tools      2 read-globs, 2 shell cmds

✓ context assembled       (3 sources · 412 tokens)
✓ agent step 1/3          claude-sonnet-4-6 · 1.4s
✓ agent step 2/3          claude-sonnet-4-6 · 2.1s
✓ agent step 3/3          claude-sonnet-4-6 · 0.9s
✓ rendered brief          → ~/.vinos/routines/state/day-brief/2026-07-26-0812.md
  cost   $0.0038  (2,847 in / 691 out)
```

<figure class="doc-shot doc-shot-pending" id="shot-24">
  <div class="doc-shot-slot">Screenshot pending: foot terminal in the middle of `vinos-routine run day-brief`</div>
  <figcaption>Ad-hoc routine run — see SCREENSHOTS_NEEDED.md #shot-24.</figcaption>
</figure>

## Logs

Journal-backed. `--tail` follows in real time.

```
$ vinos-routine logs day-brief --tail
2026-07-26 06:00:05 [day-brief] starting scheduled run
2026-07-26 06:00:05 [day-brief] resolved route=anthropic model=claude-sonnet-4-6
2026-07-26 06:00:06 [day-brief] tool read:~/Notes/today.md → 4 bytes
2026-07-26 06:00:07 [day-brief] tool shell:gh api /notifications → 6.3 KB (0 exit)
2026-07-26 06:00:11 [day-brief] wrote 2026-07-26-0600.md (871 bytes)
2026-07-26 06:00:11 [day-brief] ledger: 2847 in, 691 out, $0.0038, exit=0
```

## Cost

The ledger is a SQLite file at `~/.vinos/routines/state/ledger.db`.
`vinos-routine cost` renders the last 20 rows and a running total.

```
$ vinos-routine cost
LAST 20 RUNS
DATE        ROUTINE            MODEL                  IN     OUT    $
2026-07-26  day-brief          claude-sonnet-4-6      2847   691    0.0038
2026-07-26  evening-shutdown   claude-sonnet-4-6      1284   402    0.0021
2026-07-25  day-brief          claude-sonnet-4-6      3011   612    0.0039
2026-07-25  research-recap     llama3.2 (ollama)      8412  1204    0.0000
...

DAILY TOTAL   $0.0098   (of $0.20 cap)
WEEKLY TOTAL  $0.0483
```

<figure class="doc-shot doc-shot-pending" id="shot-25">
  <div class="doc-shot-slot">Screenshot pending: foot terminal after `vinos-routine cost` — sqlite ledger dump</div>
  <figcaption>Cost ledger — see SCREENSHOTS_NEEDED.md #shot-25.</figcaption>
</figure>

Local Ollama routes always cost `$0.0000` — the ledger still records
in/out tokens so you can see where your context is going.

## Where the output goes

Every run writes a markdown file to
`~/.vinos/routines/state/<name>/YYYY-MM-DD-HHMM.md`. Open the whole
day at once with:

```
$ vinos-brief
```

<figure class="doc-shot" id="shot-20">
  <img src="/img/screenshots/vinos-brief-panel.png" alt="vinos-brief walker panel with today's day-brief" width="1280" height="800" loading="lazy">
  <figcaption>vinos-brief showing today's outputs — see SCREENSHOTS_NEEDED.md #shot-20.</figcaption>
</figure>

Or scope to one routine:

```
$ vinos-brief day-brief
```

<figure class="doc-shot doc-shot-pending" id="shot-26">
  <div class="doc-shot-slot">Screenshot pending: vinos-brief markdown output in a foot terminal</div>
  <figcaption>vinos-brief in a terminal — see SCREENSHOTS_NEEDED.md #shot-26.</figcaption>
</figure>

Next: [write your own routine](/docs/agents/writing-your-own/).
