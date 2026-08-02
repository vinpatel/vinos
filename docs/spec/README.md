# vinOS Specification System

*The 5-artifact discipline that makes shipping without regressions possible.*

## Why this exists

Between 2026-07 and 2026-08 we shipped v2.0.5 through v2.0.18. Multiple builds regressed fixes we had already made. The user rightly pushed back: "we are not storing all fixes context properly and we keep reiterating the build."

The answer is the 5-artifact discipline. Every feature — new or fix — ships with all 5. If it can't produce all 5, it's not ready. Reading a shipped feature's spec tells you what it does, why we picked this design, how we verify it stays working, and when to reconsider it.

## The 5 artifacts

For every feature, in this order:

### 1. Problem statement
One paragraph. No jargon. Answers: "What breaks or what's missing without this feature?"

### 2. User story
Format: "As a [operator | founder | dev], I want [X], so that [Y]."

X is the concrete behavior. Y is the outcome the operator cares about.

### 3. Behavior spec
Deterministic and testable. Answers: "Given input A, exactly what happens? Given error B, exactly what exit code and message?"

Bad: "The installer should handle missing modules gracefully."
Good: "If `mkinitcpio -p ${KERNEL_NAME}` returns non-zero, the installer logs the failure to `/tmp/vinos-install.log`, retries once without the `vinos-t2.conf` drop-in, and exits 0 if the retry succeeds. If the retry fails, exits with code 6 and prints: `✗ initramfs generation failed for kernel ${KERNEL_NAME}`."

### 4. Harness check
A concrete addition to `iso/qa/verify-shipped-iso.sh` that fails if this feature regresses. Grep-based when possible; extract-and-verify when necessary. The check must:
- Fail on the exact regression the feature protects against
- Link to the memory entry name in its failure message
- Add to the harness count (currently 19 → growing)

### 5. Memory entry
A `.md` file in `~/.claude/projects/-data-projects-vinos/memory/` following the standard pattern (`project-*` or `feedback-*` or `reference-*`). Answers: "Why this design? What did we consider and reject? When should we reconsider?"

## Spec file template

Save as `docs/spec/<phase-letter>-<short-slug>.md`.

```markdown
# <Feature Name>

**Phase:** B | C | D | E
**Version target:** 2.X.Y
**Status:** draft | in-progress | shipped
**Owner:** claude (or agent name / human)
**Memory entry:** [feature-slug](path/to/memory.md)
**Harness check ID:** #NN

## 1. Problem statement

One paragraph.

## 2. User story

As a <role>, I want <X>, so that <Y>.

## 3. Behavior spec

### Inputs

- Input 1: <description>
- Input 2: <description>

### Behavior

Given `<condition>`, exactly `<outcome>` must occur.

If `<error condition>`, exit code `<N>` with message `<exact string>`.

### Non-behavior (explicit non-goals)

- Does NOT handle <X>
- Does NOT touch <Y>

## 4. Harness check

Add to `iso/qa/verify-shipped-iso.sh`:

```bash
# Check #NN — <one-line description>
if <grep or extract-and-verify command>; then
  ok "<pass message>"
else
  fail "<fail message with actionable diagnostic>" \
       "<memory-entry-slug>"
fi
```

## 5. Memory entry

Path: `~/.claude/projects/-data-projects-vinos/memory/<slug>.md`

Content: standard memory template (name, description, metadata, body with **Why** and **How to apply**).

## Implementation

- Files touched: `<list>`
- Package additions: `<list>` (or none)
- Migration notes: `<if any>`

## Testing

Explicit steps to verify manually before running harness:

1. Build the ISO
2. Flash + boot
3. Run `<command>` and verify `<output>`
4. Run `bash iso/qa/verify-shipped-iso.sh iso/out/vinos-X.Y.Z-x86_64.iso` — check #NN must pass
```

## Naming conventions

- Files in `docs/spec/` — `<phase-letter>-<short-slug>.md` (e.g. `b-omarchy-decoupling.md`)
- Memory entries — `project-<slug>.md`, `feedback-<slug>.md`, `reference-<slug>.md`
- Harness checks — numbered sequentially, comment references the spec

## When a spec is complete

- All 5 artifacts exist and reference each other
- Harness runs green with the new check
- Memory entry has been read by the next session (referenced elsewhere)
- The feature is checked in and shipped

## Anti-patterns to avoid

- **"We'll add the harness check later."** — No. Ship blocks.
- **"The memory entry is basically the same as the spec."** — No. Spec is contract; memory is history + reasoning.
- **"The behavior is obvious."** — Then writing it down takes 30 seconds. Do it.
- **"Only humans need specs; agents figure it out."** — Especially for agents. The agent that reads a spec next month is not the agent that wrote it.
