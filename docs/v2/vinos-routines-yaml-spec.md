# `.vinos/routines.yaml` — project-scoped agents

**Status:** draft (2026-07-25) · **Target:** v2.0.5 · **Companion:** [vinos-routine-spec.md](vinos-routine-spec.md)

## Positioning

`.vinos/routines.yaml` is the "commit your agents next to your code" primitive:
one file, checked into the repo, that any teammate can install with a single
command. It turns vinOS routines from a per-machine thing into a portable,
GitHub-native workflow — the same way `.github/workflows/` did for CI.

Existing single-file TOMLs remain the ground truth for the runtime
(`libexec/vinos-routine-run.py`); YAML is the **authoring + distribution**
surface. The loader converts YAML → TOML at install time.

## Install flow

```
git clone git@github.com:acme/monorepo.git
cd monorepo
vinos-routine load .            # installs everything in .vinos/routines.yaml
vinos-routine list --scope=project
vinos-routine enable pr-review
```

## Schema

```yaml
apiVersion: vinos.computer/v1     # required, currently only v1
kind: RoutineSet                  # required, currently only RoutineSet

metadata:                         # optional
  project: startup-inc            # informational; used for dir prefix
  owner:   founders@acme.example  # informational
  description: >
    Free-form description of this bundle.

defaults:                         # optional; deep-merged into every routine
  agent:
    route: anthropic
    model: claude-sonnet-4-6
    memory: session
  budget:
    max_tokens_per_run: 8000
  output:
    notify: true
  docker: ghcr.io/vinpatel/vinos-routine:latest

routines:                         # required, non-empty list
  - name: pr-review               # required, unique within file
    description: "…"
    enabled: false                # informational; `vinos-routine enable`
                                  # is still the way to activate the timer
    docker: ghcr.io/…             # optional override of defaults.docker

    schedule:
      oncalendar: "*-*-* 09,13,17:00:00"
      timezone: America/New_York
      jitter: 3m

    agent:
      route: anthropic            # anthropic | ollama
      model: claude-sonnet-4-6
      system: |
        Multi-line prompt goes here.
        Template vars work: {{project}}, {{git_root}}, {{home}}.
      tools:
        - "shell:gh pr list --state=open"
        - "read:{{git_root}}/CODEOWNERS"
      memory: session              # session | persistent | shared

    output:
      type: brief                  # brief | notification | file | webhook
      title: "PRs · {{date}}"
      open_on_login: false

    budget:
      max_tokens_per_run: 8000
      max_dollars_per_day: 0.50
      on_exceed: skip              # skip | degrade-to-local | notify
```

### Fields relative to TOML

Every field maps 1:1 to the TOML the runtime consumes (see
`docs/v2/vinos-routine-spec.md`), with two YAML-only affordances:

| YAML-only key      | Where       | Purpose |
|--------------------|-------------|---------|
| `apiVersion`/`kind`| top-level   | Forward-compat marker; parser rejects unknown `kind` |
| `metadata`         | top-level   | Human context + project directory name |
| `defaults`         | top-level   | Deep-merged into each routine before conversion |
| `docker`           | per-routine | Image ref for the future k8s exporter; parked in `[routine].docker` |

Unknown top-level keys under a routine are preserved verbatim under
`[routine]`, so future runtime fields keep working without loader changes.

## Resolution rules

1. **Locate.** `vinos-routine load <path>`:
   - If `<path>` is a `.yaml`/`.yml` file, use it directly.
   - Else if `<path>/.vinos/routines.yaml` exists, use it.
   - Else walk up to git root (`git rev-parse --show-toplevel`, or `.git`
     ancestor) and look there.
   - Else fail with an actionable message.
2. **Parse.** PyYAML preferred (`python-yaml` on Arch). If missing, a
   built-in minimal parser handles the subset above (mappings, lists,
   `|`/`>` block scalars, flow sequences, comments). The loader prints a
   one-line notice recommending PyYAML for anything more exotic.
3. **Merge.** For each routine: `deep_merge(defaults, routine)`. Nested
   dicts merge key-by-key; scalars, lists, and block scalars replace.
4. **Resolve templates.** `{{project}}` → `metadata.project` or the git
   root's directory name. `{{git_root}}` → absolute path to the repo.
   `{{home}}` → `$HOME`. Applied recursively to every string in the
   merged routine (including `agent.system`, `tools`, `output.title`).
   Runtime template vars like `{{date}}` are NOT resolved here — they're
   handled by `vinos-routine-run.py` at execution time.
5. **Convert.** Each routine becomes a TOML file matching the runtime
   schema: `[routine]`, `[schedule]`, `[agent]`, `[output]`, `[budget]`.
6. **Write.**
   - `--scope=project` (default) → `~/.vinos/routines/<project>/<name>.toml`.
   - `--scope=user` → `~/.vinos/routines/<name>.toml` (flat, may collide).
   - Existing files are **never** overwritten silently; pass `--force`.

## CLI surface (extension to `vinos-routine`)

```
vinos-routine load <path>              # install .vinos/routines.yaml
vinos-routine load <path> --dry-run    # show TOML that would be written
vinos-routine load <path> --scope=user # flat install, no project prefix
vinos-routine load <path> --force      # overwrite existing files

vinos-routine unload <path>            # remove routines this YAML installed
vinos-routine list --scope=project     # only project-scoped routines
```

`enable` / `disable` / `run` / `logs` / `cost` are unchanged — they take a
routine name and find it wherever it lives on disk.

## Rationale

- **Multiple routines per file** is the whole point. A repo's agents are a
  cohesive set (PR review + inbox digest + weekly review). Splitting them
  into N single-file TOMLs on disk is a runtime concern; from the author's
  seat it should be one file.
- **`defaults:` block** avoids the copy-paste of `route`, `model`, `budget`
  across every routine — the common failure mode for agent bundles.
- **Template variables** keep the YAML portable across machines: the same
  file resolves to different paths on every clone without any per-user
  edits. They're deliberately load-time (not runtime) so the resulting
  TOML is a fully-resolved snapshot you can inspect with `cat`.
- **`docker:` field is informational for now** because the exporter isn't
  built yet — but declaring it now lets us make it load-bearing later
  without a schema break. Loader parks it under `[routine].docker` where
  it's inert but round-trips.
- **Project scope by default** so `load` never trashes a routine the user
  hand-authored under `~/.vinos/routines/`. Opt into flat installs.

## Non-goals (for this iteration)

- Cross-file inheritance (`extends: base.yaml`). Add if repos start
  wanting shared agent libraries.
- Signed/verified bundles. Comes with the sponsor gallery in v2.0.6.
- Auto-enable on `load`. Deliberate: activating a scheduled agent must be
  an explicit act by the user of the machine.
