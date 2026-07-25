---
title: "Project routines"
description: "Commit .vinos/routines.yaml next to your code. Teammates run vinos-routine load . after clone and inherit the same agent set."
weight: 30
---

The way `.github/workflows/` gave every repo the same CI, `.vinos/
routines.yaml` gives every clone the same routines. One file, one
command, same agents everywhere.

## The manifest

Drop this at the repo root as `.vinos/routines.yaml`:

```yaml
# .vinos/routines.yaml
version: 1
project: acme-monorepo

routines:
  - name: pr-review
    file: .vinos/routines/pr-review.toml
    require: [gh]

  - name: nightly-security-scan
    file: .vinos/routines/nightly-security-scan.toml
    require: [semgrep, trivy]

  - name: release-notes-draft
    file: .vinos/routines/release-notes-draft.toml
    when: tag  # only enabled on tag pushes
```

Then each referenced TOML lives at the path given — same schema as any
other routine (see [writing your own](/docs/agents/writing-your-own/)).

## Load

From inside the repo, one command installs every routine into a
project-scoped subdir under `~/.vinos/routines/<project>/`:

```
$ cd ~/code/acme-monorepo
$ vinos-routine load .
→ read .vinos/routines.yaml (3 routines)
→ verified deps: gh ✓  semgrep ✓  trivy ✓
→ installed:
    pr-review               → ~/.vinos/routines/acme-monorepo/pr-review.toml
    nightly-security-scan   → ~/.vinos/routines/acme-monorepo/nightly-security-scan.toml
    release-notes-draft     → ~/.vinos/routines/acme-monorepo/release-notes-draft.toml
→ enable individually with: vinos-routine enable <name>
```

`--dry-run` inspects without writing. `--scope=user` (default is
`project`) installs into your top-level `~/.vinos/routines/` instead of
a subdir — useful when you're the only user.

## Unload

Reverses a load. Only removes what this YAML installed:

```
$ vinos-routine unload .
→ read .vinos/routines.yaml
→ disabled + removed 3 routines
```

## Precedence

When two routines share a name across scopes, the closer one wins:

```
1. ~/.vinos/routines/<project>/*.toml   (project-scoped, from `load`)
2. ~/.vinos/routines/*.toml              (user, hand-authored)
3. /etc/vinos/routines/*.toml           (system defaults, shipped in ISO)
```

Full spec: [`vinos-routines-yaml-spec.md`](https://github.com/vinpatel/vinos/blob/main/docs/v2/vinos-routines-yaml-spec.md).

{{% callout kind="tip" %}}
**Commit the YAML and the TOMLs, gitignore the state.** Teammates get
the same agents; nobody leaks a run of `pr-review` on your fork into
their history.
{{% /callout %}}

Next: [tools and the sandbox](/docs/agents/tools-and-sandbox/).
