# Phase 03 — v1.0.19: Docs + Backup Discipline (PLAN)

<frontmatter>
wave: 1
depends_on: [02]
files_modified:
  - docs/v2/ARCHITECTURE.md
  - docs/v2/BACKUP.md
  - docs/v2/TESTING.md
  - docs/v2/ROADMAP.md
  - SECURITY.md
  - site/content/_index.md
  - iso/qa/verify-baseline.sh
  - iso/qa/tier1-lint.sh
  - iso/qa/tier2-container.sh
autonomous: partial
autonomous_split_target: 80/20
executor_model: qwen3-coder:30b (via LiteLLM @ http://localhost:4000)
checker_model: qwen2.5-coder:7b
reviewer_model: anthropic/claude-sonnet-4-6
</frontmatter>

## Requirements
Satisfies: **R1** (baseline immovability — QA harness extension), **R5** (full attribution — grep gate), **R8** (backup discipline — `docs/v2/BACKUP.md` + `verify-baseline.sh`), **R17** (security disclosure — `SECURITY.md`), **R19** (GSD-driven ships — this plan is the ship record).

## Must-haves (goal-backward verification)

truths:
  - "File `docs/v2/ARCHITECTURE.md` exists, ≥800 words, contains sections: Four-Layer Stack, Fork Policies, Kernel Strategy"
  - "File `docs/v2/BACKUP.md` exists, ≥600 words, contains sections: What is backed up, Rollback contracts, DR drill"
  - "File `docs/v2/TESTING.md` exists, ≥600 words, enumerates all 17 QA gates plus QA-A1"
  - "File `SECURITY.md` exists at repo root, ≥400 words, contains: Threat model (A1–A5), Mitigations by phase, Disclosure (vin@mindtrades.com), 90-day CVE SLA"
  - "File `docs/v2/ROADMAP.md` is a ≤40-line stub whose body redirects to `docs/v2/PLAN-2026-08-03.md` and `.planning/ROADMAP.md`"
  - "File `iso/qa/verify-baseline.sh` exists, is executable (mode 0755), exits 0 on the current tree, asserts: git tags `v1.0.18` + `v1.1.0` present; branches `experiments/2.1.0-2026-08-03` + `archive/pre-gsd-2026-08-03` present; no ISOs left in `iso/out/` for versions <1.0.19 (except 1.1.0); `.planning/` structure intact"
  - "File `iso/qa/tier1-lint.sh` exists, executable, supports `--only shellcheck|--only structured|--only attribution|--all` flags, exits 0 on the tree, runs in <30s wall-clock"
  - "File `iso/qa/tier2-container.sh` exists, executable, spawns `archlinux:latest` docker container, runs `install/01-base.sh` + `install/03-configs.sh`, exits 0 in <5min"
  - "File `site/content/_index.md` includes a line linking to `SECURITY.md` and one linking to `docs/v2/PLAN-2026-08-03.md`, without altering the Hallmark theme frontmatter"
  - "Grep `grep -rIn --exclude-dir={omarchy,.git,site/public} 'Omarchy' configs/ bin/ iso/ install/ docs/v2/ site/content/ | grep -v -E 'NOTICES\\.md|about/_index\\.md|ARCHITECTURE\\.md|BACKUP\\.md'` returns 0 lines"
  - "Built `iso/out/vinos-1.0.19-x86_64.iso` sha256 recorded in `iso/out/sha256sums.txt` and reproducibly emitted on a second machine run (QA-1)"
  - "Command `bash iso/qa/verify-shipped-iso.sh iso/out/vinos-1.0.19-x86_64.iso` returns 0 (QA-2)"
  - "Command `bash iso/qa/oneshot.sh iso/out/vinos-1.0.19-x86_64.iso` returns 0 (QA-6)"
  - "Git tag `v1.0.19` created ONLY after human ACK recorded in ledger"
  - {statement: "No file under install/, bin/, configs/vinos/{default,security,mac,brand,t2,limine,systemd,litellm}/, iso/profile/, libexec/ has content changes between v1.0.18 and v1.0.19 commit (diff shows only doc/qa additions)", verification: backstop}
  - {statement: "Live ISO boots to greetd in QEMU + on T2 Mac", verification: backstop}
  - {statement: "Ledger `~/.vinos/dev-flow-ledger.sqlite` records this phase's routine invocations with ≥80% local-model resolution", verification: backstop}

prohibitions:
  - {statement: "No new package added to `iso/profile/packages.x86_64`", status: locked, verification: source}
  - {statement: "No modification to `omarchy/` subtree (stays at 3.8.4)", status: locked, verification: source}
  - {statement: "No modification to `install/`, `bin/`, `libexec/`, `iso/profile/`", status: locked, verification: source}
  - {statement: "No modification to `configs/vinos/` EXCEPT adding new routine TOMLs (none in this phase)", status: locked, verification: source}
  - {statement: "No kernel `.config` change, no `linux-vinos` build in this phase", status: locked, verification: source}
  - {statement: "No `git push --force` to `main`", status: locked, verification: source}
  - {statement: "No Omarchy subtree pull", status: locked, verification: source}
  - {statement: "No autonomous merge of any PR that touches `SECURITY.md`, `install/`, or the v1.0.19 tag — all require human ACK per R15", status: locked, verification: source}

## Artifacts this phase produces

**New files:**
- `/data/projects/vinos/docs/v2/ARCHITECTURE.md`
- `/data/projects/vinos/docs/v2/BACKUP.md`
- `/data/projects/vinos/docs/v2/TESTING.md`
- `/data/projects/vinos/SECURITY.md`
- `/data/projects/vinos/iso/qa/verify-baseline.sh`
- `/data/projects/vinos/iso/qa/tier1-lint.sh`
- `/data/projects/vinos/iso/qa/tier2-container.sh`

**Rewritten files:**
- `/data/projects/vinos/docs/v2/ROADMAP.md` (stub)
- `/data/projects/vinos/site/content/_index.md` (copy-only update)

**Build artifacts (not committed):**
- `/data/projects/vinos/iso/out/vinos-1.0.19-x86_64.iso`
- `/data/projects/vinos/iso/out/sha256sums.txt` (appended)

**Published artifacts (post-tag, human-gated):**
- `dl.vinos.computer/releases/v1.0.19/vinos-1.0.19-x86_64.iso`
- `dl.vinos.computer/releases/v1.0.19/sha256sums.txt`

**Git artifacts:**
- Tag `v1.0.19` (annotated, human ACK required)

---

## Tasks

### Task 1 — Author `docs/v2/ARCHITECTURE.md` (rewrite from scratch)

<task>
  <name>architecture-doc</name>
  <type>tracer</type>
  <wave>1</wave>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>anthropic/claude-sonnet-4-6</reviewer>
  <human_ack>required (public-facing doc)</human_ack>
  <read_first>
    - /data/projects/vinos/docs/v2/PLAN-2026-08-03.md (§2 vision, §10 fork strategy)
    - /data/projects/vinos/docs/v2/KERNEL.md (all 5 tiers)
    - /data/projects/vinos/docs/v2/ARCHITECTURE.md (existing — capture what to preserve and rewrite)
    - /data/projects/vinos/configs/vinos/README.md
    - /data/projects/vinos/omarchy/README.md (first 100 lines only)
    - /data/projects/vinos/.planning/STATE.md
    - /data/projects/vinos/NOTICES.md
  </read_first>
  <action>
    Overwrite /data/projects/vinos/docs/v2/ARCHITECTURE.md with a fresh document describing the CURRENT four-layer stack for the v1.0.x line:

    1. **Header:** Title "vinOS Architecture", subtitle "The four-layer stack — as of v1.0.19", authored-by-vinOS attribution line.
    2. **## Four-Layer Stack** section with an ASCII diagram of the four layers:
       ```
       Layer 4 · ISO composition           (archiso profile → mkarchiso)
       Layer 3 · vinOS overlay             (configs/vinos/, overlays/, bin/vinos-*, install/)
       Layer 2 · Omarchy subtree 3.8.4     (omarchy/, vendored 1:1, never inline-edited)
       Layer 1 · Arch Linux base           (snapshot-pinned per ISO)
       ```
       Follow with 2–4 paragraphs explaining data flow (build-time and runtime) between the layers.
    3. **## Layer 1 — Arch base** subsection: snapshot pinning contract, retention (12 months on R2), where the snapshot URL is stamped (`/etc/vinos-release`).
    4. **## Layer 2 — Omarchy 3.8.4 subtree** subsection: git subtree at `omarchy/`, quarterly bump discipline, LKG tag policy, HARD RULE "no inline edits". Reference R10.
    5. **## Layer 3 — vinOS overlay** subsection: enumerate the sub-overlays under `configs/vinos/` (default, security, t2, mac, brand, limine, systemd, litellm, routines), describe `install/*.sh` numbered pipeline, describe `bin/vinos-*` wrappers (130+ commands), describe `libexec/` (routine runner + ledger).
    6. **## Layer 4 — ISO composition** subsection: archiso profile at `iso/profile/`, `mkarchiso` invocation, `iso/qa/oneshot.sh` gate.
    7. **## Fork Policies** section: two subsections — "Omarchy fork" (quarterly bump, LKG discipline, MIT compliance) and "Arch snapshot" (not forked; pinned; retained). Reference R10, R11.
    8. **## Kernel Strategy** section: 1-paragraph summary + explicit "see docs/v2/KERNEL.md for the 5-tier control model" link. Note: `linux-cachyos` default, `linux-t2` on Mac, `linux-hardened` opt-in.
    9. **## Two Editions From One Tree** section: developer ISO vs headless container (Phase 10), split by profile not by fork. Reference R2.
    10. **## Related Documents** table: pointers to KERNEL.md, DEV-LOOP.md, BACKUP.md, TESTING.md, PLAN-2026-08-03.md, .planning/ROADMAP.md.

    Word count target: 1200–2000. No unattributed "Omarchy" outside the explicit Layer-2 discussion. Preserve the existing v2.0 archival note as a footer (2 lines: "The v1.0.x line is the shipping active line; the pre-2026-08-03 v2.0 experimental content lives in the git tag v2.1.0 and in experiments/2.1.0-2026-08-03.").
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/docs/v2/ARCHITECTURE.md
    - Word count between 800 and 2500 (measured via `wc -w`)
    - `grep -c "^## " docs/v2/ARCHITECTURE.md` returns ≥ 5
    - Contains all 5 required top-level sections: "Four-Layer Stack", "Fork Policies", "Kernel Strategy", "Two Editions From One Tree", "Related Documents"
    - Contains the ASCII diagram with the string "Layer 4 · ISO composition"
    - `grep -c "KERNEL.md" docs/v2/ARCHITECTURE.md` returns ≥ 1
    - `grep -c "R10\|R11\|R2" docs/v2/ARCHITECTURE.md` returns ≥ 3
    - No occurrence of "Omarchy" outside a section titled Layer 2 or Fork Policies (verified by hand-review by Claude Sonnet)
  </acceptance_criteria>
  <verify>
    wc -w /data/projects/vinos/docs/v2/ARCHITECTURE.md | awk '{if ($1 >= 800 && $1 <= 2500) print "OK"; else exit 1}'
    grep -c "^## " /data/projects/vinos/docs/v2/ARCHITECTURE.md | awk '{if ($1 >= 5) print "OK"; else exit 1}'
    grep -q "Four-Layer Stack" /data/projects/vinos/docs/v2/ARCHITECTURE.md && echo OK
    grep -q "Fork Policies" /data/projects/vinos/docs/v2/ARCHITECTURE.md && echo OK
    grep -q "KERNEL.md" /data/projects/vinos/docs/v2/ARCHITECTURE.md && echo OK
  </verify>
  <reversibility>reversible (git revert of single-file commit)</reversibility>
</task>

---

### Task 2 — Author `docs/v2/BACKUP.md`

<task>
  <name>backup-doc</name>
  <type>tracer</type>
  <wave>1</wave>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>anthropic/claude-sonnet-4-6</reviewer>
  <human_ack>required (public-facing doc, refs R8/R9)</human_ack>
  <read_first>
    - /data/projects/vinos/docs/v2/PLAN-2026-08-03.md (§8 backup+rollback)
    - /data/projects/vinos/.planning/REQUIREMENTS.md (R8, R9)
    - /data/projects/vinos/.planning/STATE.md
  </read_first>
  <action>
    Create /data/projects/vinos/docs/v2/BACKUP.md capturing the §8 preview from PLAN-2026-08-03.md, expanded to full document form:

    1. **Header:** "vinOS Backup & Rollback Discipline" + subtitle "Every ship is preserved; every install is recoverable."
    2. **## What is backed up** section: reproduce and expand the 6-row table from PLAN §8 (Git, Memory/refs, ISOs, Build logs, Site, User ledger). For each: source path, destination (R2 + NAS + external), frequency, retention. Add a 7th row for the `.planning/` phase artifacts (retention: forever, source of truth for GSD workflow).
    3. **## Rollback contracts** section: enumerate the 5 rollback paths (ISO re-flash, BTRFS snapper, multi-kernel Limine, Omarchy LKG, Arch snapshot pin). One paragraph per path with the exact command a user runs.
    4. **## Retention policy** subsection: forever for tagged releases; last 2 built + 1.1.0 for local dev iterations (from memory `feedback_iso_retention_policy`); 12 months for Arch snapshots; forever for LKG Omarchy tags.
    5. **## Disaster recovery drill (quarterly)** section: 6-step procedure from PLAN §8.
    6. **## What's not backed up** section: user LLM API keys (BYO — never leave user's machine); ephemeral routine invocation payloads; per-boot BTRFS scratch subvolumes.
    7. **## References** section: pointers to R8, R9, `iso/qa/verify-baseline.sh`, DR drill log location `docs/v2/disaster-recovery-log.md`.

    Word count target: 600–1500. Do not invent new backup destinations beyond the ones in PLAN §8; if a decision is missing, leave a TODO tag `<!-- decision-pending: N -->` and record it in the phase notes.
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/docs/v2/BACKUP.md
    - Word count between 600 and 1500
    - Contains all 5 required sections: "What is backed up", "Rollback contracts", "Retention policy", "Disaster recovery drill (quarterly)", "What's not backed up"
    - Contains a markdown table with ≥7 rows describing backed-up assets
    - Contains ≥5 rollback paths (grep for "snapper|Limine|LKG|R2|re-flash")
    - References R8 and R9 explicitly
  </acceptance_criteria>
  <verify>
    wc -w /data/projects/vinos/docs/v2/BACKUP.md | awk '{if ($1 >= 600 && $1 <= 1500) print "OK"; else exit 1}'
    for h in "What is backed up" "Rollback contracts" "Retention policy" "Disaster recovery drill" "What's not backed up"; do grep -q "$h" /data/projects/vinos/docs/v2/BACKUP.md || exit 1; done
    grep -cE "^\|" /data/projects/vinos/docs/v2/BACKUP.md | awk '{if ($1 >= 9) print "OK"; else exit 1}'
    grep -q "R8" /data/projects/vinos/docs/v2/BACKUP.md && grep -q "R9" /data/projects/vinos/docs/v2/BACKUP.md && echo OK
  </verify>
  <reversibility>reversible</reversibility>
</task>

---

### Task 3 — Author `docs/v2/TESTING.md`

<task>
  <name>testing-doc</name>
  <type>tracer</type>
  <wave>1</wave>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>anthropic/claude-sonnet-4-6</reviewer>
  <human_ack>required (public-facing doc, defines ship gates)</human_ack>
  <read_first>
    - /data/projects/vinos/docs/v2/PLAN-2026-08-03.md (§7 testing)
    - /data/projects/vinos/docs/v2/DEV-LOOP.md (iteration pyramid — this doc is complementary, don't duplicate)
    - /data/projects/vinos/iso/qa/oneshot.sh (first 60 lines to describe structure)
    - /data/projects/vinos/iso/qa/verify-shipped-iso.sh (first 60 lines to describe assertion pattern)
    - /data/projects/vinos/.planning/ROADMAP.md (§Ship-gate quick reference)
  </read_first>
  <action>
    Create /data/projects/vinos/docs/v2/TESTING.md — the QA framework document:

    1. **Header:** "vinOS Testing Framework — 17 gates, one harness"
    2. **## Philosophy** section: 2 paragraphs — "every gate is a shell assertion, every assertion cites a memory/req, no gate is skipped, promotion rule from DEV-LOOP (never skip tiers)".
    3. **## Ship-gate matrix** section: reproduce the QA-1 through QA-17 + QA-A1 table from ROADMAP.md `Ship-gate quick reference`, one row per gate, columns: ID, Name, Introduced-at-phase, Enforced-by-script, Foundation/Feature/Headless/Agentic.
    4. **## Gate descriptions** section: one subsection per gate (QA-1 through QA-17 + QA-A1), each with: What it asserts, How it's tested, Pass criterion, Failure remediation.
    5. **## Harness structure** section: describe the 3 files:
       - `iso/qa/oneshot.sh` — 3-layer verifier (static + container + QEMU screendumps)
       - `iso/qa/verify-shipped-iso.sh` — regression harness; extracts airootfs.sfs and asserts every past fix
       - `iso/qa/verify-baseline.sh` — NEW in Phase 03; asserts backup discipline
       Plus the tier scripts from DEV-LOOP: `tier1-lint.sh`, `tier2-container.sh`, plus placeholders for `tier4-qemu-persistent.sh` (Phase 04).
    6. **## Hardware matrix reference** section: 1 paragraph pointing to `iso/qa/hardware-matrix.md` (Phase 06 deliverable) with the current single-row T2 Mac baseline.
    7. **## Continuous testing** section: `vinos-dev-qa-nightly` routine (03:00 daily on `main`), notification path (Discord webhook), failure escalation (15-min human notify).
    8. **## Adding a new gate** section: 4-step process — write the assertion, add to `verify-shipped-iso.sh`, cite the memory/req in the failure message, update this doc.

    Word count target: 800–1800. This is a reference doc; be enumerable and grep-able (each QA-N has its own H3).
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/docs/v2/TESTING.md
    - Word count between 800 and 1800
    - Contains one H3 (### QA-N) for each of: QA-1, QA-2, QA-3, QA-4, QA-5, QA-6, QA-7, QA-8, QA-9, QA-10, QA-11, QA-12, QA-13, QA-14, QA-15, QA-16, QA-17, QA-A1 (18 gates total)
    - Contains all 6 required sections: "Philosophy", "Ship-gate matrix", "Gate descriptions", "Harness structure", "Continuous testing", "Adding a new gate"
    - Ship-gate matrix table has 18 data rows
    - References DEV-LOOP.md (no duplication)
  </acceptance_criteria>
  <verify>
    wc -w /data/projects/vinos/docs/v2/TESTING.md | awk '{if ($1 >= 800 && $1 <= 1800) print "OK"; else exit 1}'
    for g in QA-1 QA-2 QA-3 QA-4 QA-5 QA-6 QA-7 QA-8 QA-9 QA-10 QA-11 QA-12 QA-13 QA-14 QA-15 QA-16 QA-17 QA-A1; do grep -qE "^### ${g}(\b|$| )" /data/projects/vinos/docs/v2/TESTING.md || { echo "missing $g" >&2; exit 1; }; done
    grep -q "DEV-LOOP.md" /data/projects/vinos/docs/v2/TESTING.md && echo OK
  </verify>
  <reversibility>reversible</reversibility>
</task>

---

### Task 4 — Author `SECURITY.md` at repo root

<task>
  <name>security-doc</name>
  <type>tracer</type>
  <wave>1</wave>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>anthropic/claude-sonnet-4-6 → escalate to claude-opus-4-7 (per R15 change class 3)</reviewer>
  <human_ack>MANDATORY (R15 class 3: SECURITY.md changes)</human_ack>
  <read_first>
    - /data/projects/vinos/docs/v2/PLAN-2026-08-03.md (§9 security)
    - /data/projects/vinos/.planning/REQUIREMENTS.md (R13, R17)
    - Look for existing SECURITY.md — should not exist; if it does, abort and flag
    - /data/projects/vinos/NOTICES.md
  </read_first>
  <action>
    Create /data/projects/vinos/SECURITY.md — repo-root file, GitHub auto-detects:

    1. **Header:** "vinOS Security Policy"
    2. **## Supported versions** section: table with columns Version / Supported. Rows: 1.0.x = ✅, 1.1.0 = archival-only (no fixes, use 1.0.x), 2.1.0 = ❌ experimental, older = ❌.
    3. **## Reporting a vulnerability** section: email vin@mindtrades.com; response SLA — acknowledgment within 72h, triage within 7 days, fix within 90 days (R17 CVE SLA). PGP key TBD (leave placeholder). No public disclosure until coordinated release.
    4. **## Threat model** section: adversary catalog A1–A5 (verbatim structure from PLAN §9, expanded to 2–3 sentences each):
       - A1: Malicious routine (compromised community submission) — mitigated by bwrap sandbox + human ACK gate
       - A2: Commercial LLM API hijack — mitigated by BYO keys + per-repo scoping
       - A3: Physical theft with unlocked LUKS — mitigated by LUKS default (v1.0.20+) + TPM2 opt-in
       - A4: Supply chain (Arch mirror or Omarchy upstream) — mitigated by Arch snapshot pinning + Omarchy LKG tag
       - A5: Local network attacker (evil twin wifi) — mitigated by ufw deny-in + ed25519 SSH only
    5. **## Mitigations by phase** section: reproduce the table from PLAN §9 (Phase 1.0.18 → 1.0.28, adversary, mitigation).
    6. **## Sandboxing** section: describe R13 — agent tools run via bwrap, whitelist-only file access, network gated. Reference `iso/qa/adversarial-tests/` (Phase 07 deliverable).
    7. **## Disclosure log** section: empty placeholder table (Date / CVE / Severity / Status), 0 rows on ship.
    8. **## References** section: R13, R17, related docs (BACKUP.md, ARCHITECTURE.md).

    Word count target: 400–1200. Do NOT commit vin@mindtrades.com in cleartext IF phase policy is "obfuscate email" — check `.planning/config.json`; if no such policy present, plain address is OK (memory says this is public repo).
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/SECURITY.md
    - Word count between 400 and 1200
    - Contains all 6 required sections: "Supported versions", "Reporting a vulnerability", "Threat model", "Mitigations by phase", "Sandboxing", "Disclosure log"
    - Contains exactly 5 adversary IDs A1, A2, A3, A4, A5 (grep "^- A[1-5]:" returns 5)
    - Contains string "vin@mindtrades.com"
    - Contains string "90-day" or "90 days" (CVE SLA)
    - References R13 and R17
  </acceptance_criteria>
  <verify>
    test -f /data/projects/vinos/SECURITY.md && echo OK
    wc -w /data/projects/vinos/SECURITY.md | awk '{if ($1 >= 400 && $1 <= 1200) print "OK"; else exit 1}'
    for h in "Supported versions" "Reporting a vulnerability" "Threat model" "Mitigations by phase" "Sandboxing" "Disclosure log"; do grep -q "$h" /data/projects/vinos/SECURITY.md || exit 1; done
    grep -c "^- A[1-5]:" /data/projects/vinos/SECURITY.md | awk '{if ($1 == 5) print "OK"; else exit 1}'
    grep -q "vin@mindtrades.com" /data/projects/vinos/SECURITY.md && echo OK
    grep -qE "90[- ]day" /data/projects/vinos/SECURITY.md && echo OK
  </verify>
  <reversibility>reversible</reversibility>
</task>

---

### Task 5 — Rewrite `docs/v2/ROADMAP.md` as stub redirect

<task>
  <name>roadmap-stub</name>
  <type>micro</type>
  <wave>1</wave>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>checker:qwen2.5-coder:7b (deterministic diff — no Claude escalation needed)</reviewer>
  <human_ack>not required</human_ack>
  <read_first>
    - /data/projects/vinos/docs/v2/ROADMAP.md (existing — preserve nothing, replace)
    - /data/projects/vinos/.planning/ROADMAP.md (this is now source of truth)
    - /data/projects/vinos/docs/v2/PLAN-2026-08-03.md (this is now master plan)
  </read_first>
  <action>
    Overwrite /data/projects/vinos/docs/v2/ROADMAP.md with a stub (≤40 lines) whose body:

    ```markdown
    # vinOS Roadmap

    **Status:** This file is a stub. The authoritative sources are:

    - **Master plan:** [docs/v2/PLAN-2026-08-03.md](./PLAN-2026-08-03.md) — Vin's ship-queue plan through v1.0.28 dual-edition GA
    - **GSD roadmap:** [.planning/ROADMAP.md](../../.planning/ROADMAP.md) — the phase-by-phase queue that `/gsd-execute-phase` consumes
    - **GSD state:** [.planning/STATE.md](../../.planning/STATE.md) — current baseline and in-flight version

    The pre-2026-08-03 v2.0 roadmap content has been superseded. It lives in git history at commit `<TBD-fill-at-commit-time>` and in the archive branch `archive/pre-gsd-2026-08-03`.

    ## Quick summary (see PLAN for details)

    - v1.0.18 — baseline (shipped, Phase A closed)
    - v1.0.19 — docs freeze + backup discipline (this release, Phase 03)
    - v1.0.20 — LUKS default (Phase 04)
    - v1.0.21 — attribution audit (Phase 05)
    - v1.0.22 — hardware certification (Phase 06)
    - v1.0.23 — developer edition polish (Phase 07)
    - v1.0.24 — routine gallery (Phase 08)
    - v1.0.25 — site + docs + video (Phase 09)
    - v1.0.26 — headless edition (Phase 10)
    - v1.0.27 — team-shared routines (Phase 11)
    - v1.0.28 — dual-edition GA (Phase 12)
    ```
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/docs/v2/ROADMAP.md
    - Line count ≤ 40 (measured via `wc -l`)
    - Contains links to both `docs/v2/PLAN-2026-08-03.md` and `.planning/ROADMAP.md`
    - Contains string "This file is a stub"
    - Enumerates v1.0.19 through v1.0.28
  </acceptance_criteria>
  <verify>
    wc -l /data/projects/vinos/docs/v2/ROADMAP.md | awk '{if ($1 <= 40) print "OK"; else exit 1}'
    grep -q "PLAN-2026-08-03.md" /data/projects/vinos/docs/v2/ROADMAP.md && grep -q ".planning/ROADMAP.md" /data/projects/vinos/docs/v2/ROADMAP.md && echo OK
    grep -q "This file is a stub" /data/projects/vinos/docs/v2/ROADMAP.md && echo OK
    for v in v1.0.19 v1.0.20 v1.0.21 v1.0.22 v1.0.23 v1.0.24 v1.0.25 v1.0.26 v1.0.27 v1.0.28; do grep -q "$v" /data/projects/vinos/docs/v2/ROADMAP.md || exit 1; done
  </verify>
  <reversibility>reversible (previous content preserved in git)</reversibility>
</task>

---

### Task 6 — Copy-only update to `site/content/_index.md`

<task>
  <name>site-landing-update</name>
  <type>micro</type>
  <wave>1</wave>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>anthropic/claude-sonnet-4-6</reviewer>
  <human_ack>required (R15 class 5: public-facing copy)</human_ack>
  <read_first>
    - /data/projects/vinos/site/content/_index.md (current — only 4 lines of frontmatter)
    - /data/projects/vinos/site/content/about (peek at existing tone)
  </read_first>
  <action>
    Update /data/projects/vinos/site/content/_index.md to add TWO reference links inline BELOW the existing frontmatter, without altering the Hallmark theme frontmatter block.

    New content (append after the closing `---` of frontmatter):

    ```markdown

    vinOS is an agent-native Linux for developers building with LLMs. It ships with Claude Code, local Qwen/Kimi models via Ollama, and a routine system that runs your agents while you sleep.

    - [Security policy](https://github.com/vinpatel/vinos/blob/main/SECURITY.md) — threat model + disclosure
    - [Ship plan](https://github.com/vinpatel/vinos/blob/main/docs/v2/PLAN-2026-08-03.md) — the v1.0.19 → v1.0.28 queue
    - [Install guide](/install/)
    ```

    DO NOT touch:
    - The Hallmark theme frontmatter (`title`, `description`) — keep verbatim
    - Any other file in `site/`
    - The Hallmark stylesheet, layout, or components

    This is copy-only. If the Hallmark theme requires a specific frontmatter key for the landing hero, ADD it but do not change existing keys.
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/site/content/_index.md
    - Frontmatter block (delimited by `---`) unchanged from prior — verify `title: "vinOS"` line intact
    - Contains link to SECURITY.md
    - Contains link to docs/v2/PLAN-2026-08-03.md
    - Line count ≤ 20
    - No other file under site/ modified (verified via `git diff --name-only site/` returning only `site/content/_index.md`)
  </acceptance_criteria>
  <verify>
    grep -q 'title: "vinOS"' /data/projects/vinos/site/content/_index.md && echo OK
    grep -q "SECURITY.md" /data/projects/vinos/site/content/_index.md && echo OK
    grep -q "PLAN-2026-08-03.md" /data/projects/vinos/site/content/_index.md && echo OK
    wc -l /data/projects/vinos/site/content/_index.md | awk '{if ($1 <= 20) print "OK"; else exit 1}'
  </verify>
  <reversibility>reversible</reversibility>
</task>

---

### Task 7 — Author `iso/qa/tier1-lint.sh`

<task>
  <name>tier1-lint-harness</name>
  <type>vertical</type>
  <wave>2</wave>
  <depends_on>[none — parallel with tasks 1–6]</depends_on>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>checker:qwen2.5-coder:7b</reviewer>
  <human_ack>not required (deterministic tooling; not user-facing)</human_ack>
  <read_first>
    - /data/projects/vinos/docs/v2/DEV-LOOP.md (Tier 1 section, lines 34–60)
    - /data/projects/vinos/configs/vinos/routines/dev/vinos-dev-lint.toml (defines the --only flags this script must support)
    - /data/projects/vinos/iso/qa/verify-shipped-iso.sh (first 40 lines — copy the color/ok/fail helper style for consistency)
  </read_first>
  <action>
    Create /data/projects/vinos/iso/qa/tier1-lint.sh, executable (mode 0755). Bash strict-mode script. Supports these CLI flags (mutually exclusive):

    - `--only shellcheck` — run only shellcheck across `install/`, `bin/`, `iso/qa/`, and the new `iso/qa/tier*.sh` and `verify-baseline.sh` scripts
    - `--only structured` — validate JSON files under `configs/`, `.planning/`; validate YAML under `configs/`; validate TOML under `configs/`
    - `--only attribution` — grep for "Omarchy" outside allowed files (NOTICES.md, site/content/about/_index.md, docs/v2/ARCHITECTURE.md § Layer 2, docs/v2/BACKUP.md if it references LKG tag)
    - `--all` (default if no flag) — run all three in sequence
    - `-h|--help` — print usage

    Behaviour:
    - Set `-euo pipefail`
    - Colored `ok`/`fail` helpers copied from `verify-shipped-iso.sh`
    - `shellcheck` mode: `find install/ bin/ iso/qa/ -type f -name "*.sh" -exec shellcheck -x {} +`. Exit non-zero on any shellcheck warning severity ≥ error. Warnings-only mode logs but exits 0.
    - `structured` mode:
        - JSON: `find configs/ .planning/ -name "*.json" -not -path "*/node_modules/*" -exec jq -e . {} +` (jq exits nonzero on invalid JSON)
        - YAML: `find configs/ -name "*.yaml" -exec python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" {} \;`
        - TOML: `find configs/ -name "*.toml" -exec python3 -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" {} \;`
    - `attribution` mode: `grep -rIn --exclude-dir={omarchy,.git,site/public,node_modules} "Omarchy" configs/ bin/ iso/ install/ docs/v2/ site/content/ 2>/dev/null | grep -v -E "NOTICES\\.md|about/_index\\.md|ARCHITECTURE\\.md#.*Layer 2|BACKUP\\.md.*LKG|ROADMAP\\.md.*archive|PLAN-2026-08-03\\.md"`. If output is non-empty, fail.
    - Wall-clock target: <30 seconds. Add a `time` self-timer that logs at the end.
    - Exit code: 0 if all checks pass; 1 if any check fails; 2 on usage error.
    - Cwd-independent: script uses `cd "$(dirname "$(realpath "$0")")/../.."` to anchor at repo root.
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/iso/qa/tier1-lint.sh with mode 0755
    - `bash iso/qa/tier1-lint.sh -h` prints usage and exits 0
    - `bash iso/qa/tier1-lint.sh --only shellcheck` exits 0 on the current tree (baseline is clean; if not, fix the tree)
    - `bash iso/qa/tier1-lint.sh --only structured` exits 0
    - `bash iso/qa/tier1-lint.sh --only attribution` exits 0
    - `bash iso/qa/tier1-lint.sh --all` exits 0 in ≤30 seconds (measured with `time`)
    - `bash iso/qa/tier1-lint.sh --only bogus` exits 2 (usage error)
    - Script passes shellcheck itself (`shellcheck iso/qa/tier1-lint.sh` returns 0)
  </acceptance_criteria>
  <verify>
    test -x /data/projects/vinos/iso/qa/tier1-lint.sh && echo OK
    bash /data/projects/vinos/iso/qa/tier1-lint.sh -h >/dev/null && echo OK
    shellcheck /data/projects/vinos/iso/qa/tier1-lint.sh && echo OK
    time bash /data/projects/vinos/iso/qa/tier1-lint.sh --all
    bash /data/projects/vinos/iso/qa/tier1-lint.sh --only bogus; test $? -eq 2 && echo OK
  </verify>
  <reversibility>reversible</reversibility>
</task>

---

### Task 8 — Author `iso/qa/tier2-container.sh`

<task>
  <name>tier2-container-harness</name>
  <type>vertical</type>
  <wave>2</wave>
  <depends_on>[7]</depends_on>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>checker:qwen2.5-coder:7b</reviewer>
  <human_ack>not required</human_ack>
  <read_first>
    - /data/projects/vinos/docs/v2/DEV-LOOP.md (Tier 2 section, lines 62–102)
    - /data/projects/vinos/install/ (list what scripts exist — likely 01-base.sh through 06-hardware.sh)
    - /data/projects/vinos/iso/qa/verify-shipped-iso.sh (helper style)
  </read_first>
  <action>
    Create /data/projects/vinos/iso/qa/tier2-container.sh, executable. Bash strict-mode script that:

    1. Verifies `docker` is available (`command -v docker` — else fail with clear message).
    2. Verifies `/var/run/docker.sock` or user in `docker` group.
    3. Spawns a fresh `archlinux:latest` container:
       - `--rm` (auto-cleanup)
       - `--privileged` (needed for loop devices / systemd if invoked)
       - `-v "$REPO:/vinos:ro"` (mount repo read-only — install scripts should not mutate source)
       - `-v "$WORKDIR:/work"` (writable scratch)
       - `-w /work`
    4. Inside the container:
       - `pacman -Sy --noconfirm base-devel git rsync` (bootstrap)
       - Copy `/vinos/install/` into `/work/install/`
       - Run `bash /work/install/01-base.sh --dry-run` (if `--dry-run` unsupported by any of the install scripts, log clearly and skip that step — DON'T fail; note the gap for Phase 04)
       - Run `bash /work/install/03-configs.sh --dry-run` (same policy)
       - Assert exit codes 0
       - Print `PASS` / `FAIL` summary
    5. Wall-clock target: <5 minutes. Add `time` self-timer.
    6. Handle absent docker gracefully — exit 0 with warning if run on a machine without docker (so `oneshot.sh` doesn't break on light-weight dev machines); this can be overridden with `--strict` which exits 1 if docker absent.
    7. Exit codes: 0 = pass (or docker absent without --strict); 1 = install script failure; 2 = docker/container setup failure.

    NOTE: If `install/01-base.sh` or `install/03-configs.sh` does NOT accept a `--dry-run` flag today (very likely — this is Phase 03, no code changes to `install/`), the script MUST run them in a mode that doesn't actually pacstrap the host. Use `arch-chroot` inside a mkarchroot dir OR simply `bash -n <script>` to syntax-check, and add a TODO comment: `# TODO Phase-04: add --dry-run to install scripts; today we only syntax-check`. The primary value of this harness in Phase 03 is that IT EXISTS and IS SHIPPED, so Phase 04 has a stable target to extend.
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/iso/qa/tier2-container.sh with mode 0755
    - `bash iso/qa/tier2-container.sh -h` prints usage
    - Script passes shellcheck (`shellcheck iso/qa/tier2-container.sh` returns 0)
    - On a machine WITH docker + running daemon: script exits 0 in ≤5 minutes
    - On a machine WITHOUT docker: script exits 0 with a warning line "SKIP: docker not available"
    - With `--strict` and no docker: exits 2
    - Script contains explicit TODO for Phase 04 --dry-run support
  </acceptance_criteria>
  <verify>
    test -x /data/projects/vinos/iso/qa/tier2-container.sh && echo OK
    shellcheck /data/projects/vinos/iso/qa/tier2-container.sh && echo OK
    bash /data/projects/vinos/iso/qa/tier2-container.sh -h >/dev/null && echo OK
    grep -q "TODO Phase-04" /data/projects/vinos/iso/qa/tier2-container.sh && echo OK
    # If docker is running on the dev machine, this exits 0 in <5min:
    if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
      time bash /data/projects/vinos/iso/qa/tier2-container.sh
    else
      echo "SKIP: docker not present on this dev machine"
    fi
  </verify>
  <reversibility>reversible</reversibility>
</task>

---

### Task 9 — Author `iso/qa/verify-baseline.sh`

<task>
  <name>verify-baseline-harness</name>
  <type>vertical</type>
  <wave>2</wave>
  <depends_on>[none — parallel with 7,8]</depends_on>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>anthropic/claude-sonnet-4-6 (enforces R8/R1)</reviewer>
  <human_ack>not required (deterministic)</human_ack>
  <read_first>
    - /data/projects/vinos/.planning/REQUIREMENTS.md (R1, R8, R9)
    - /data/projects/vinos/.planning/STATE.md (which tags/branches must exist)
    - /data/projects/vinos/iso/qa/verify-shipped-iso.sh (helper style, exit-code semantics)
    - Memory `feedback_iso_retention_policy` (last 2 built + 1.1.0)
  </read_first>
  <action>
    Create /data/projects/vinos/iso/qa/verify-baseline.sh, executable, that asserts backup discipline (R8) and baseline immovability (R1). Runs in the REPO context (not against an ISO).

    Assertions (each with ok/fail like verify-shipped-iso.sh):

    1. **Git tag `v1.0.18` exists** — `git rev-parse --verify v1.0.18` returns 0
    2. **Git tag `v1.1.0` exists** — same
    3. **Git tag `v1.0.19` present ONLY if we're post-tag** — soft check; log its presence
    4. **Branch `experiments/2.1.0-2026-08-03` exists** (local OR remote — try both) — required by R8/STATE.md
    5. **Branch `archive/pre-gsd-2026-08-03` exists** — same
    6. **`.planning/` structure intact:** files `STATE.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `config.json` all present
    7. **`.planning/phases/03-v1-0-19-docs/SPEC.md` exists** (this phase's spec)
    8. **`.planning/phases/03-v1-0-19-docs/PLAN.md` exists** (this file)
    9. **`omarchy/` subtree still pinned at 3.8.4** — heuristic check: `omarchy/VERSION` or `omarchy/CHANGELOG.md` contains "3.8.4"; if neither exists, `git log --format=%s omarchy/ | head -1` referenced 3.8.4 in past 5 subtree commits. Fail with "Omarchy subtree drift — see R10" if not.
    10. **`iso/out/` retention policy honored** — enumerate ISOs; there must be:
        - `vinos-1.1.0-x86_64.iso` present (archival — never delete)
        - AT MOST 2 other ISOs beyond 1.1.0 (per `feedback_iso_retention_policy`)
        - Warn (not fail) if older ISOs are still present — this is a cleanup hint, not a regression
    11. **`SECURITY.md` present at repo root** — R17
    12. **`docs/v2/BACKUP.md` present** — R8
    13. **`docs/v2/PLAN-2026-08-03.md` present** — this is the master plan
    14. **`docs/v2/DEV-LOOP.md` present** — Phase 03 references it
    15. **`docs/v2/KERNEL.md` present** — Phase 07 refers here
    16. **NOTICES.md present** — R5/R10

    Behaviour:
    - Set `-euo pipefail`
    - Same ok/fail helper style as verify-shipped-iso.sh
    - Runs from anywhere: `cd "$(dirname "$(realpath "$0")")/../.."`
    - Prints summary: `<N passes>, <M fails>, <K warnings>`
    - Exit 0 if all pass; 1 on any fail

    Wall-clock target: <5 seconds. This is pure filesystem + git queries.
  </action>
  <acceptance_criteria>
    - File exists at /data/projects/vinos/iso/qa/verify-baseline.sh with mode 0755
    - Script passes shellcheck
    - `bash iso/qa/verify-baseline.sh` runs in ≤5 seconds
    - `bash iso/qa/verify-baseline.sh` exits 0 on the current tree (all backup discipline items intact)
    - Manually break one assertion (e.g., temporarily rename `docs/v2/BACKUP.md`) — script exits 1 and prints which check failed
    - Contains explicit references to R1, R8, R9, R10, R17 in comments
  </acceptance_criteria>
  <verify>
    test -x /data/projects/vinos/iso/qa/verify-baseline.sh && echo OK
    shellcheck /data/projects/vinos/iso/qa/verify-baseline.sh && echo OK
    time bash /data/projects/vinos/iso/qa/verify-baseline.sh
    # Break check test:
    mv /data/projects/vinos/docs/v2/BACKUP.md /tmp/BACKUP.md.bak
    bash /data/projects/vinos/iso/qa/verify-baseline.sh; test $? -eq 1 && echo "OK: fails when expected"
    mv /tmp/BACKUP.md.bak /data/projects/vinos/docs/v2/BACKUP.md
    bash /data/projects/vinos/iso/qa/verify-baseline.sh && echo "OK: passes when restored"
  </verify>
  <reversibility>reversible</reversibility>
</task>

---

### Task 10 — Extend `verify-shipped-iso.sh` with docs-freeze assertions

<task>
  <name>harness-extension</name>
  <type>micro</type>
  <wave>2</wave>
  <depends_on>[1, 2, 3, 4, 9]</depends_on>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>anthropic/claude-sonnet-4-6</reviewer>
  <human_ack>not required (harness is not user-facing; edits to iso/qa/ are Phase-03 explicitly allowed)</human_ack>
  <read_first>
    - /data/projects/vinos/iso/qa/verify-shipped-iso.sh (understand extension pattern — same ok/fail helpers)
  </read_first>
  <action>
    Append a new section to /data/projects/vinos/iso/qa/verify-shipped-iso.sh titled "docs-freeze (Phase 03 / v1.0.19)":

    Add exactly 6 new assertions:
    1. `/etc/vinos-release` in airootfs contains `VERSION=1.0.19`
    2. `docs/v2/ARCHITECTURE.md` shipped inside the ISO OR referenced (checked via repo-side existence — this doc lives in git, not necessarily in airootfs)
    3. `docs/v2/BACKUP.md` present in repo (verify against $REPO not $ROOT)
    4. `docs/v2/TESTING.md` present in repo
    5. `SECURITY.md` present in repo
    6. Grep pass: no unattributed "Omarchy" in shipped user-facing surfaces (`$ROOT/etc/motd`, `$ROOT/etc/os-release`, `$ROOT/usr/share/vinos/`) — verified by `grep -r Omarchy $ROOT/etc/motd $ROOT/etc/os-release $ROOT/usr/share/vinos/ 2>/dev/null | grep -v NOTICES.md | wc -l` returns 0

    Insert this section BEFORE the existing final-summary block, using the same `say` / `ok` / `fail` helpers already defined in the file.

    Do NOT restructure existing assertions. Additive only. Every new assertion cites its memory/req in the failure message.
  </action>
  <acceptance_criteria>
    - Existing assertions in verify-shipped-iso.sh unchanged (verify via `git diff --stat` showing only additions)
    - New section header "docs-freeze (Phase 03 / v1.0.19)" present
    - 6 new `ok`/`fail` calls added
    - Script still exits 0 on the current tree (once v1.0.19 ISO built)
    - Script passes shellcheck
  </acceptance_criteria>
  <verify>
    shellcheck /data/projects/vinos/iso/qa/verify-shipped-iso.sh && echo OK
    grep -q "docs-freeze (Phase 03 / v1.0.19)" /data/projects/vinos/iso/qa/verify-shipped-iso.sh && echo OK
    # Count assertions added (should be 6 new):
    grep -c "docs-freeze\|VERSION=1.0.19\|ARCHITECTURE.md\|BACKUP.md\|TESTING.md\|SECURITY.md" /data/projects/vinos/iso/qa/verify-shipped-iso.sh | awk '{if ($1 >= 6) print "OK"; else exit 1}'
  </verify>
  <reversibility>reversible (single-file additive change)</reversibility>
</task>

---

### Task 11 — Build v1.0.19 ISO from current tree (no code changes)

<task>
  <name>build-iso</name>
  <type>vertical</type>
  <wave>3</wave>
  <depends_on>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]</depends_on>
  <owner>executor:qwen3-coder:30b (drives the build script; no code changes required)</owner>
  <reviewer>checker:qwen2.5-coder:7b (verifies sha256 + build log)</reviewer>
  <human_ack>not required for build; required for tag/publish (Task 12/13)</human_ack>
  <read_first>
    - /data/projects/vinos/iso/build.sh (or iso/v2/build.sh — whichever exists in the v1.0.x tree)
    - /data/projects/vinos/iso/qa/oneshot.sh (the ship-gate)
    - /data/projects/vinos/.planning/STATE.md (baseline immovability)
  </read_first>
  <action>
    Build vinos-1.0.19-x86_64.iso using the SAME build script + SAME sources as v1.0.18. Only new files present since v1.0.18 are:
    - The 9 doc/qa files from Tasks 1–10
    - This PLAN.md and the phase directory

    NONE of those files ship into the airootfs (`iso/profile/` is untouched — docs live in git, not on the ISO). The ISO is therefore functionally identical to 1.0.18; only `/etc/vinos-release`'s VERSION= line changes.

    Steps:
    1. Bump version constant. Find where "1.0.18" lives as the build version — likely `iso/build.sh`, `iso/profile/profiledef.sh`, or `iso/version.env`. Change ONLY the version stamp. If multiple places, change all consistently. Log every file changed for the audit trail.
    2. Run the build: whatever the current invocation is (`bash iso/build.sh` OR `bash iso/v2/build.sh` — pick whichever exists and matches how v1.0.18 was built).
    3. Verify output: `iso/out/vinos-1.0.19-x86_64.iso` exists, size within ±100 MB of v1.0.18 size.
    4. Compute sha256, append to `iso/out/sha256sums.txt` (preserving v1.1.0 entry per memory).
    5. Prune older ISOs per retention policy: keep last 2 + 1.1.0. Move anything older to `iso/archive/` (do NOT delete).
    6. Log the build to `iso/out/build-1.0.19-$(date -u +%Y%m%dT%H%M%SZ).log`.
    7. Save the build log path in the ledger for reproducibility check (QA-1 on second machine).

    IF the build script fails (e.g., missing pacman keyring, network dropped): abort, log the failure, notify human. Do NOT retry more than 2× — this is a signal that something upstream drifted (Arch mirror, Omarchy subtree), which is a Phase 03 out-of-scope investigation.
  </action>
  <acceptance_criteria>
    - `iso/out/vinos-1.0.19-x86_64.iso` exists
    - `iso/out/sha256sums.txt` contains a line for `vinos-1.0.19-x86_64.iso` with a 64-hex-char digest
    - `iso/out/sha256sums.txt` still contains the v1.1.0 entry (untouched — verify via diff)
    - ISO size within [3.5 GB, 5.5 GB]
    - Build log written to `iso/out/build-1.0.19-*.log`
    - Only 2 non-1.1.0 ISOs in `iso/out/` (retention policy)
  </acceptance_criteria>
  <verify>
    test -f /data/projects/vinos/iso/out/vinos-1.0.19-x86_64.iso && echo OK
    grep -q "vinos-1.0.19-x86_64.iso" /data/projects/vinos/iso/out/sha256sums.txt && echo OK
    grep -q "vinos-1.1.0-x86_64.iso" /data/projects/vinos/iso/out/sha256sums.txt && echo "OK: 1.1.0 entry preserved"
    ls -la /data/projects/vinos/iso/out/*.iso | wc -l | awk '{if ($1 <= 3) print "OK"; else exit 1}'
    size=$(stat -c%s /data/projects/vinos/iso/out/vinos-1.0.19-x86_64.iso); if [ "$size" -ge 3758096384 ] && [ "$size" -le 5905580032 ]; then echo OK; fi
  </verify>
  <reversibility>partial — ISO can be deleted; the version bump is git-revertable pre-tag</reversibility>
</task>

---

### Task 12 — Run full ship-gate (oneshot + verify-shipped-iso + verify-baseline) and record

<task>
  <name>ship-gate</name>
  <type>vertical</type>
  <wave>3</wave>
  <depends_on>[11]</depends_on>
  <owner>executor:qwen3-coder:30b</owner>
  <reviewer>anthropic/claude-sonnet-4-6 (reads screendumps + logs)</reviewer>
  <human_ack>MANDATORY before Task 13 (tag creation) — R15 class 1</human_ack>
  <read_first>
    - /data/projects/vinos/iso/qa/oneshot.sh
    - /data/projects/vinos/iso/qa/verify-shipped-iso.sh
    - /data/projects/vinos/iso/qa/verify-baseline.sh
  </read_first>
  <action>
    Execute the full ship-gate sequence and record every result in the ledger:

    1. `bash iso/qa/verify-baseline.sh` — exits 0 (R8/R1 discipline)
    2. `bash iso/qa/tier1-lint.sh --all` — exits 0
    3. `bash iso/qa/tier2-container.sh` — exits 0 (or skip if no docker; log clearly)
    4. `bash iso/qa/oneshot.sh iso/out/vinos-1.0.19-x86_64.iso` — exits 0 (QA-6; includes QEMU screendumps → QA-3 non-Mac coverage)
    5. `bash iso/qa/verify-shipped-iso.sh iso/out/vinos-1.0.19-x86_64.iso` — exits 0 (QA-2)
    6. Grep pass (QA-5): `grep -rIn --exclude-dir={omarchy,.git,site/public} "Omarchy" configs/ bin/ iso/ install/ docs/v2/ site/content/ | grep -v -E "NOTICES\\.md|about/_index\\.md|ARCHITECTURE\\.md|BACKUP\\.md|PLAN-2026-08-03\\.md|ROADMAP\\.md.*archive"` returns 0 lines
    7. Reproducibility check (QA-1): re-run the build on a second machine or in a fresh workdir with same inputs → sha256 matches Task 11's digest. If only one build machine available, note as "QA-1 deferred to Phase 12" and log — this is an accepted concession for docs-only releases.
    8. Human hardware test (QA-3 T2): human ACK checkpoint — Vin boots the ISO on his T2 MacBook, confirms greetd + desktop + wifi + no red banners. Records ACK in ledger with timestamp and photo of screen.

    Every gate result goes into `~/.vinos/dev-flow-ledger.sqlite` with:
    - phase: 03
    - version: 1.0.19
    - gate: QA-N
    - status: pass|fail|skipped
    - timestamp
    - artifact_ref (log path or screendump path)

    IF ANY gate fails: PAUSE. Do not proceed to Task 13. Report to human immediately with the specific failing assertion and the memory/req it cites.
  </action>
  <acceptance_criteria>
    - All 6 automated gates return 0
    - Ledger contains 6 rows for phase 03 / version 1.0.19 with status="pass"
    - Human ACK row present for QA-3 T2 (or explicit "deferred" if hardware unavailable during phase execution — must be logged before tag)
    - QA-1 status is either "pass" (reproducibility verified) or "deferred to Phase 12" (accepted concession)
  </acceptance_criteria>
  <verify>
    bash /data/projects/vinos/iso/qa/verify-baseline.sh && echo "QA-baseline OK"
    bash /data/projects/vinos/iso/qa/tier1-lint.sh --all && echo "Tier1 OK"
    bash /data/projects/vinos/iso/qa/verify-shipped-iso.sh /data/projects/vinos/iso/out/vinos-1.0.19-x86_64.iso && echo "QA-2 OK"
    bash /data/projects/vinos/iso/qa/oneshot.sh /data/projects/vinos/iso/out/vinos-1.0.19-x86_64.iso && echo "QA-6 OK"
    # QA-5 grep
    if grep -rIn --exclude-dir={omarchy,.git,site/public} "Omarchy" /data/projects/vinos/configs/ /data/projects/vinos/bin/ /data/projects/vinos/iso/ /data/projects/vinos/install/ /data/projects/vinos/docs/v2/ /data/projects/vinos/site/content/ 2>/dev/null | grep -v -E "NOTICES\\.md|about/_index\\.md|ARCHITECTURE\\.md|BACKUP\\.md|PLAN-2026-08-03\\.md|ROADMAP\\.md.*archive" | grep .; then echo "QA-5 FAIL"; exit 1; else echo "QA-5 OK"; fi
  </verify>
  <reversibility>N/A (verification only, no state change beyond ledger writes)</reversibility>
</task>

---

### Task 13 — Tag `v1.0.19` and publish

<task>
  <name>tag-and-publish</name>
  <type>vertical</type>
  <wave>4</wave>
  <depends_on>[12]</depends_on>
  <owner>anthropic/claude-sonnet-4-6 (drafts the tag message; commits require human)</owner>
  <reviewer>human (Vin)</reviewer>
  <human_ack>MANDATORY — R15 class 1 (version tag), class 3 (SECURITY.md changes), class 8 (model swap — first fully autonomous phase completion)</human_ack>
  <read_first>
    - /data/projects/vinos/.planning/STATE.md (baseline references)
    - /data/projects/vinos/docs/v2/PLAN-2026-08-03.md (release notes template)
    - The ledger rows recorded in Task 12
  </read_first>
  <action>
    ONLY after human ACK is recorded from Task 12:

    1. **Commit the docs freeze:** create a git commit containing all 9 new/modified files (Tasks 1–10), authored as Vin (never Claude co-author per memory `feedback_no_claude_trailer`). Commit message drafted by Claude, polished by Vin. Ships as one atomic docs-freeze commit.
    2. **Create annotated tag:**
       ```
       git tag -a v1.0.19 <commit-sha> -m "vinOS 1.0.19 — Docs freeze + backup discipline

       Docs-only release. Functionally identical to v1.0.18. First autonomous ship
       through the 24x7 dev flow.

       New:
       - docs/v2/ARCHITECTURE.md    (four-layer stack)
       - docs/v2/BACKUP.md          (R8/R9 discipline)
       - docs/v2/TESTING.md         (17 QA gates enumerated)
       - SECURITY.md                (R17 threat model, disclosure)
       - iso/qa/verify-baseline.sh  (R1/R8 automated guard)
       - iso/qa/tier1-lint.sh       (DEV-LOOP.md Tier 1)
       - iso/qa/tier2-container.sh  (DEV-LOOP.md Tier 2)

       Rewritten:
       - docs/v2/ROADMAP.md → stub → PLAN + .planning/ROADMAP
       - site/content/_index.md → refs SECURITY.md + PLAN

       Ship gates: QA-1 QA-2 QA-3 QA-5 QA-6 all green.
       Baseline QA harness: verify-shipped-iso.sh + verify-baseline.sh pass.
       Autonomous flow ledger: <ROWS> rows, 80/20 split confirmed.
       "
       ```
    3. **Push tag** ONLY after human confirms tag message: `git push origin v1.0.19`
    4. **Publish ISO + sha256sums** to dl.vinos.computer/releases/v1.0.19/ — via existing publish tooling. Verify with a curl HEAD against the URL that returns 200.
    5. **Draft release notes** via `vinos-dev-release-notes` routine (Claude Sonnet drafts, Vin polishes). Publish to GitHub Releases.
    6. **Update `.planning/STATE.md`** — bump `Baseline` line to `v1.0.19` (fresh floor) and note `v1.0.18` as archived-baseline.
    7. **Kick off Phase 04** — `/gsd-next` will route to Phase 04 (LUKS) since Phase 03 is closed.

    Every step is human-ACK-gated. If Vin does not respond within 24h, PAUSE — do not force a tag creation autonomously.
  </action>
  <acceptance_criteria>
    - Git tag `v1.0.19` exists locally: `git rev-parse --verify v1.0.19` returns 0
    - Tag is annotated: `git cat-file -t v1.0.19` returns `tag`
    - Tag pushed to origin: `git ls-remote --tags origin v1.0.19` returns a ref
    - `dl.vinos.computer/releases/v1.0.19/vinos-1.0.19-x86_64.iso` returns 200 on HEAD
    - `dl.vinos.computer/releases/v1.0.19/sha256sums.txt` returns 200 and matches local
    - GitHub Release created with notes
    - `.planning/STATE.md` updated (v1.0.19 baseline noted)
    - Ledger row exists showing human ACK from Vin with timestamp
  </acceptance_criteria>
  <verify>
    git -C /data/projects/vinos rev-parse --verify v1.0.19 && echo OK
    git -C /data/projects/vinos cat-file -t v1.0.19 | grep -q "^tag$" && echo OK
    git -C /data/projects/vinos ls-remote --tags origin v1.0.19 | grep -q v1.0.19 && echo OK
    curl -sI https://dl.vinos.computer/releases/v1.0.19/vinos-1.0.19-x86_64.iso | head -1 | grep -q "200" && echo OK
    grep -q "v1.0.19" /data/projects/vinos/.planning/STATE.md && echo OK
  </verify>
  <reversibility>ONE-WAY after `git push origin v1.0.19`. Reversal requires force-push + tag deletion (destructive) + retraction announcement. Do NOT undo without a documented incident.</reversibility>
</task>

---

## Wave map & parallelization

```
Wave 1 (parallel, 5 authors × 1 doc each):
  Task 1: ARCHITECTURE.md
  Task 2: BACKUP.md
  Task 3: TESTING.md
  Task 4: SECURITY.md
  Task 5: ROADMAP.md stub
  Task 6: site/_index.md

Wave 2 (parallel with Wave 1 for 7 & 9; task 8 after 7; task 10 after 1–4):
  Task 7: tier1-lint.sh
  Task 8: tier2-container.sh   (depends on 7 for helper conventions)
  Task 9: verify-baseline.sh
  Task 10: harness extension    (depends on 1–4, 9 for the files it asserts on)

Wave 3 (serial):
  Task 11: build ISO           (after all Wave 1 + Wave 2)
  Task 12: ship gate           (after 11)

Wave 4 (human-serial):
  Task 13: tag + publish       (after 12 + human ACK)
```

Wave 1 (6 tasks) and Wave 2 tasks 7/9 can run in parallel across 8 executor threads. Wall-clock: Wave 1+2 ≈ 6 hours end-to-end assuming Qwen3-Coder throughput of ~1000 tokens/min per task and 2-round Claude review per doc.

---

## Verification

<threat_model>

Adversaries recognized in Phase 03 (per SECURITY.md draft):

- **A1** Malicious routine — no new routines added this phase; existing bwrap sandbox unchanged.
- **A2** Commercial LLM API hijack — Claude Sonnet usage stays under $5 budget cap (14 doc reviews × ~$0.30 = ~$4.20 projected).
- **A3** Physical theft with unlocked LUKS — no LUKS work this phase; posture unchanged from v1.0.18.
- **A4** Supply chain — Arch snapshot + Omarchy subtree both frozen this phase; verify-baseline.sh asserts pinning.
- **A5** Local network attacker — no network config change.

**Phase 03 impact on threat model:** `SECURITY.md` becomes PUBLIC. This transparently discloses our threat model and disclosure process. **No new attack surface introduced** — this is a docs-only release. The publication itself is defensive: it invites coordinated disclosure and sets the 90-day SLA clock.

**Residual risks flagged for downstream phases:**
- Making the threat model public raises the bar for Phase 04 (LUKS): once we've written down A3, we're contractually on the hook to ship LUKS by v1.0.20.
- `verify-baseline.sh` now enforces branch/tag preservation — if a future rebase deletes `archive/pre-gsd-2026-08-03`, the harness will fail. This is intended.

</threat_model>

### Verification loop (pre-ship)

For each wave completion, the executor's checker (qwen2.5-coder:7b) runs the `<verify>` block of every task in that wave. If any verify fails, the task is re-run (max 2 retries) before escalating to Claude Sonnet for diagnosis. After ≥2 Claude escalations on the same task, PAUSE and notify human.

The **plan-drift precheck** (per `.planning/config.json`) runs before each wave: has any file outside `files_modified` changed? If yes, halt and diagnose — this phase forbids scope creep.

### Verification loop (post-ship)

After Task 13, Phase 03 closes with:
- `/gsd-audit-uat` — confirms every UAT item in this PLAN's `truths` list is satisfied
- `/gsd-extract-learnings` — captures what worked/didn't in the first autonomous ship, feeds Phase 04 planning
- Ledger export → `~/.vinos/phase-03-ledger-export.json` for the 80/20 split audit

## Ship gate

**Ship gates required (from SPEC):**
- **QA-1** Reproducible build — sha256 across 2 machines. If only 1 machine available, accepted as "deferred to Phase 12". Task 11 / Task 12 gate.
- **QA-2** Regression harness clean — `verify-shipped-iso.sh` exit 0. Task 12 gate.
- **QA-3** Boots on verified hw — T2 Mac + QEMU (non-Mac coverage via oneshot.sh screendumps). Task 12 gate. Human ACK required for T2 Mac.
- **QA-5** No unattributed strings — grep pass. Task 12 gate.
- **QA-6** Oneshot verifier — 3-layer pass. Task 12 gate.

**Additional Phase 03 gates (beyond SPEC minimum):**
- QA-baseline — `verify-baseline.sh` exit 0. Task 9 output feeds here.
- Autonomous 80/20 — ledger shows ≥80% ±5% local resolution. Task 12 records; validated at Task 13 pre-tag.
- Budget — cumulative Claude cost ≤$5 for the phase. Ledger enforces per-run and per-day caps ($0.50, $20/day).

## Duration estimate

**5 days total** (matches SPEC):

- **Day 1:** Wave 1 kicks off — Tasks 1–6 (6 docs) authored in parallel by Qwen3-Coder. Claude Sonnet review round 1 arrives EOD.
- **Day 2:** Claude review round 2 + human ACK on Tasks 1–4 (public-facing docs). Wave 2 Tasks 7 + 9 kick off in parallel.
- **Day 3:** Task 8 (tier2-container) authored + verified. Task 10 (harness extension) added. Human ACK on site landing (Task 6).
- **Day 4:** Task 11 build ISO. Task 12 full ship-gate. Human boots ISO on T2 Mac for QA-3 ACK.
- **Day 5:** Task 13 tag + publish. GitHub release drafted + polished + posted. Phase 03 closes. `/gsd-next` routes to Phase 04.

**Autonomous / human split target:** 80% local (Qwen3-Coder does all authoring + all verification runs); 20% cloud (Claude Sonnet does reviews of all 4 public-facing docs + release notes polish; Claude Opus escalated only for `SECURITY.md` per R15). Projected Claude budget: **~$4.20** — well under $5 ceiling.

**Buffer:** 1 day of slack absorbed inside Day 3–4 for review round-trips. If any wave slips >4 hours, notify human immediately per DEV-LOOP escalation policy.
