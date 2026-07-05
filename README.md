# vinOS — starter bundle

Everything needed to begin. Extract this into your project directory on the Dell.

## Contents
- `CLAUDE.md` — project instructions Claude Code reads every session
- `VINOS_SPEC.md` — base system spec (Milestones M1–M4)
- `VINOS_ISO_SPEC.md` — live ISO/USB spec (Milestones I1–I5)
- `assets/logo/` — locked logo (Prompt V): SVGs, mono variants, animated SVG + GIF, PNG 16–512

## Kickoff (on the Dell)

```bash
cd ~/vinos                 # this extracted folder
git init && git add -A && git commit -m "M0: specs, project instructions, logo assets"
gh repo create vinos --private --source=. --push

docker run --rm archlinux:latest echo ok    # verify Docker works

claude
```

First prompt to Claude Code:

> Read CLAUDE.md and VINOS_SPEC.md. Execute Milestone M1 only. Stop when its
> DONE WHEN criterion passes (./install.sh --dry-run prints the full ordered
> plan). Run the test and show me the output before claiming done. Then update
> the status tracker in CLAUDE.md and commit as "M1: <description>".

Then one session per milestone: M2 → M3 → M4, then switch to VINOS_ISO_SPEC.md
for I1 → I4 (I5/CI deferred per the 3-day plan). Never let a session start the
next milestone.
