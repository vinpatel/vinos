# vinOS Security Posture

**vinOS is a hardened agentic operating system.** Security is a first-class concern, not an add-on.

- **Report vulnerabilities to:** vinpatel.pro@gmail.com (PGP fingerprint published on request)
- **CVE patch SLA:** 90 days from public disclosure
- **Advisories:** published on GitHub at https://github.com/vinpatel/vinos/security/advisories

## Supported versions

| Version | Support status |
|---|---|
| v1.0.18 (baseline) | Full support · immovable QA floor |
| v1.0.19+ | Full support · latest release |
| v1.1.0 | Archival · security-critical patches only |
| Pre-v1.1.0 (v1.0.x historical) | Unsupported |
| v2.x experimental branch | Unsupported · reference only |

## Threat model

vinOS defends against five primary adversary classes:

### A1 · Malicious routine
**Threat:** User installs a compromised community routine from the gallery (or authors one that inadvertently misbehaves).

**Mitigation:**
- **bwrap sandbox** — every routine executes in a bubble-wrap namespace with:
  - Whitelist-only file access (`configs/vinos/default/etc/vinos-routine-sandbox.conf` per Phase 02+)
  - Network egress gated by explicit `[tools.allow]` in routine TOML
  - No `/etc` write, no PID namespace crossover, no `--privileged` capabilities
- **Firejail** on the AI shell + browser (Phase 07 deliverable)
- **Budget caps** — per-run + per-day USD ceilings in `~/.vinos/dev-flow-ledger.sqlite`; `on_exceed: notify` never silent-skips
- **Ledger audit trail** — every routine action recorded with run_id, model, tokens, cost, human_ack
- **Routine signatures** — from v1.0.24 (Phase 08), routines pulled via `vinos-routine install <slug>` are signed against `configs/vinos/keys/routines-signing.pub`
- **QA-14** — adversarial suite denies rm -rf, sudo, curl attacker.com, secrets read

### A2 · Commercial LLM API hijack
**Threat:** User's Anthropic / OpenAI / OpenRouter account is compromised; attacker uses the key to run arbitrary agent workloads via user's vinOS.

**Mitigation:**
- **BYOK model** — users bring their own keys, no vinOS-side storage
- **Local key file** — `~/.vinos/secrets/env` mode 0600, never in git
- **Budget caps** at the runtime layer — even a stolen key can't exceed `per_day_usd` before `on_exceed: notify` fires
- **Key rotation policy** — documented in `docs/v2/PLAN-2026-08-03.md` §9; annual rotation recommended
- **`vinos-secrets rotate` command** (Phase 12 deliverable) — rotate keys across all configured providers with one command

### A3 · Physical theft with unlocked LUKS
**Threat:** Laptop stolen, disk not encrypted or unlocked at time of theft.

**Mitigation:**
- **LUKS default recommendation** from v1.0.20 (Phase 04) — installer prompt defaults to enabling LUKS on laptop hardware detection
- **TPM2 auto-unlock** opt-in via `--luks-tpm2` (LUKS+TPM = fewer prompts, still resistant to disk theft alone)
- **Lock on suspend** — Hyprland default, ships in Omarchy 3.8.4
- **`vinos-persist` LUKS partition** (Phase 12+) — encrypted state for live-USB workflows
- **SecureBoot signing** (Phase 12, contingent on key acquisition) — prevents boot-time evil-maid attacks
- **No password auth on SSH** — ed25519 keys only from Phase 07

### A4 · Supply chain (Arch mirror or Omarchy upstream)
**Threat:** Arch mirror or Omarchy repo compromised; malicious package or config injected upstream.

**Mitigation:**
- **Arch snapshot pinning** — every ISO built against a specific mirror snapshot URL, retained on R2 12 months. Users don't `pacman -Syu` directly; they use `vinos-update` between blessed snapshots (Phase 06 deliverable).
- **Omarchy LKG tag** — `omarchy-lkg-<date>` on last-known-good version. Rollback = `git subtree pull` to LKG.
- **Diff-before-merge** discipline — every Omarchy bump reviewed + full harness must pass.
- **No custom repos** — one upstream (Arch official). Nothing from CachyOS, chaotic-aur-headers, or private mirrors.
- **hardened_malloc** system-wide from Phase 07 — reduces exploitability of common memory corruption bugs
- **linux-hardened** default kernel on Headless from Phase 10
- **`linux-vinos` custom kernel** from Phase 07 — signed, in-repo `.config`, per-flag rationale in `configs/vinos/kernel/RATIONALE.md`
- **Attribution audit** — `iso/qa/tier1-lint.sh --only attribution` catches unattributed insertions in every PR (Phase 05 CI gate)

### A5 · Local network attacker
**Threat:** Evil-twin wifi, ARP poisoning, coffee-shop MITM.

**Mitigation:**
- **ufw / nftables deny-in default** from Phase 07
- **SSH ed25519-only, no password auth, no root** from Phase 07
- **T2 wifi hardening** — MAC randomization off (per iwd + brcmfmac config), ANQP off, wifi powersave off — reduces attack surface and improves reliability (see `iso/qa/verify-shipped-iso.sh` T2 wifi assertions)
- **DoH / DoT** — from Phase 08+, `systemd-resolved` configured to encrypt DNS by default
- **VPN-ready** — WireGuard client shipped, one-command setup docs in Phase 09

## Mitigations by release phase

| Phase | Ship version | Adversaries mitigated | New security controls |
|---|---|---|---|
| 01 Capture | tag v1.0.18 | — | Baseline preserved; immovable floor |
| 02 Dev flow | routines | A1 | bwrap sandbox contract, budget caps in ledger |
| **03 v1.0.19** | ISO | A2, A4 (partial) | **This SECURITY.md published;** BYOK model documented; attribution grep in CI |
| 04 v1.0.20 | ISO | A3 | **LUKS default** + TPM2 opt-in |
| 05 v1.0.21 | ISO | A4 | Attribution audit + legal review complete; CI enforcement |
| 06 v1.0.22 | ISO | A3 (extended) | Multi-hardware verified; per-board hardening tweaks |
| 07 v1.0.23 | ISO | A1, A4, A5 | **linux-hardened + linux-vinos + Firejail + hardened_malloc + ufw** |
| 08 v1.0.24 | ISO | A1 | Routine signature scheme |
| 09 v1.0.25 | ISO | — (docs) | Security disclosure page on site |
| 10 v1.0.26 | Docker + Helm | A1, A4 | **Headless hardened profile** — readonly rootfs, apparmor enforcing, nftables deny-in, no-SSH-root, kernel cmdline hardening |
| 11 v1.0.27 | ISO + Cloud | — | Team-shared secrets discipline |
| 12 v1.0.28 GA | ISO + Cloud | A3, A4 | **SecureBoot signing** (contingent on key), reproducible builds, external counsel audit |

## Security tests (QA gates)

Per `docs/v2/TESTING.md`:

- **QA-13** — Budget enforcement ±$0.01 accuracy
- **QA-14** — Sandbox escape resistance (adversarial suite)
- **QA-15** — Human checkpoint honored — `human_checkpoint: true` blocks without ACK
- **QA-H1** — Hardened profile assertions (apparmor + hardened_malloc + nftables) — Headless only
- **QA-H2** — Adversarial hardening test — Headless only
- **QA-17** — No CVE unpatched > 90 days — continuous

## Human checkpoints (mandatory for autonomous flow)

The 24x7 development flow requires human ACK for these change classes (per `docs/v2/PLAN-2026-08-03.md` §5.3 and REQUIREMENTS R15):

1. Version tag creation (one-way)
2. `main` force-push (destructive)
3. Any change to `SECURITY.md` (security-affecting)
4. Any change to `install/` or `iso/profile/` (architecture-affecting)
5. Public-facing copy (site, README, release notes)
6. Sponsor commits, licensing changes (legal)
7. Budget cap changes (cost impact)
8. Model swaps (reproducibility)

Never bypass a checkpoint. If a routine passes without human ACK when one was required, that's a P0 bug in the runtime.

## Attribution & licensing

- **vinOS overlay (own work):** © 2026 Vin Patel · MIT · covers `configs/vinos/`, `overlays/`, `bin/vinos-*`, `install/`, `iso/` (profile + QA), `libexec/`, `docs/`, `site/`
- **Omarchy 3.8.4 (vendored):** © David Heinemeier Hansson / Basecamp · MIT · covers `omarchy/` subtree · full text in `NOTICES.md`
- **Arch Linux archiso profile:** © Arch Linux community · GPL-3.0 · per-package licenses on installed systems at `/usr/share/licenses/`
- **Kernels:** `linux-cachyos`, `linux-hardened`, `linux-t2` — all GPL-2.0

Full attribution registry in `NOTICES.md`. Attribution-clean CI gate lands in v1.0.21 (Phase 05).

## Reporting a vulnerability

1. **Do NOT open a public GitHub issue** for security vulnerabilities.
2. **Email vinpatel.pro@gmail.com** with:
   - Description of the vulnerability
   - Reproduction steps
   - Affected vinOS versions
   - Suggested fix (optional)
3. **PGP key** — available on request.
4. **Response time:** initial acknowledgment within 72 hours, triage decision within 7 days.
5. **90-day disclosure window** — we ship a fix within 90 days of report, then publish an advisory. If we can't ship in 90 days, we coordinate an extension with you.
6. **Credit** — reporters credited in the advisory unless they request anonymity.

## Out of scope

- Attacks requiring physical root access to an already-unlocked machine
- DoS via unlimited compute consumption on user's own laptop (budget caps limit spend, not local resource use)
- Social engineering not involving vinOS code
- Third-party services (Anthropic, OpenRouter, GitHub) — report those directly to those vendors
- Vulnerabilities in Omarchy 3.8.4 — report to https://github.com/basecamp/omarchy/security (we track and pull fixes on the quarterly bump schedule; critical CVEs get out-of-band bumps)

## Related

- `docs/v2/PLAN-2026-08-03.md` §9 — security posture rationale
- `docs/v2/ARCHITECTURE.md` — layers being secured
- `docs/v2/BACKUP.md` — includes A4 supply-chain mitigations
- `docs/v2/TESTING.md` — security-specific QA gates
- `docs/v2/KERNEL.md` — kernel hardening tiers
- `NOTICES.md` — attribution registry
