---
title: "vinOS for IT decision-makers — the agentic OS with guardrails built in"
description: "Local models by default. Sandboxed tools. Auditable ledger. Predictable cost. Sovereign. On-prem. Compares against Copilot Enterprise ($40/seat/mo unpredictable): vinOS routes ~80% locally, hard-caps escalated spend per-user per-day."
url: "/for/enterprise/"
type: "for"
layout: "persona"
---

<section class="persona-hero">
  <span class="eyebrow">for it decision-makers</span>
  <h1>The agentic OS with <span class="accent">guardrails</span> built in.</h1>
  <p class="persona-lede">
    Local models by default. Sandboxed tools. Auditable ledger.
    Predictable cost. Sovereign. On-prem. Compares against Copilot
    Enterprise ($40/seat/mo, unpredictable): vinOS routes <em>~80% of
    calls to a local model</em> and hard-caps escalated spend per-user
    per-day.
  </p>
  <div class="persona-cta-row">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="#compare" class="btn link">See the comparison →</a>
  </div>
</section>

<section class="persona-section">
  <h2>Three outcomes procurement can measure.</h2>
  <p class="persona-section-lede">
    Sovereignty, predictability, auditability. Each backed by a runtime
    primitive — not a policy PDF.
  </p>

  <div class="outcomes">
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M16 4l10 4v8c0 6-4 10-10 12-6-2-10-6-10-12V8z"/>
        </svg>
      </div>
      <h3>Data sovereignty — <span class="accent">80% of AI work</span> never leaves the machine.</h3>
      <p class="outcome-sub">Local Ollama first. Escalation to a frontier API is opt-in per routine and logged with the exact prompt hash.</p>
      <div class="outcome-tool"><code>route = "ollama"</code> · <span class="dim">forces local-only</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="16" cy="16" r="10"/>
          <path d="M16 8v8l5 3"/>
        </svg>
      </div>
      <h3>Cost predictability — <span class="accent">hard-capped</span> at the runtime.</h3>
      <p class="outcome-sub">Per-run and per-day dollar limits declared in each routine. Exceed a cap and the routine skips, degrades, or falls back to local — enforced by the loader, not the model.</p>
      <div class="outcome-tool"><code>max_dollars_per_day</code> · <span class="dim">on_exceed: skip</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M6 6h20v20H6z"/><path d="M6 12h20"/>
          <path d="M10 18h12"/><path d="M10 22h8"/>
        </svg>
      </div>
      <h3>Auditable — every run <span class="accent">in a queryable ledger.</span></h3>
      <p class="outcome-sub">Routines are TOML in git. Every run appends to a per-user SQLite ledger: routine, model, tokens, tool calls, cost, exit code.</p>
      <div class="outcome-tool"><code>~/.vinos/ledger.db</code> · <span class="dim">sqlite3</span></div>
    </article>
  </div>
</section>

<section class="persona-section" id="compare">
  <h2>Where vinOS sits <span class="accent">in the market.</span></h2>
  <p class="persona-section-lede">
    Honest comparison. Unpublished figures are marked as such — we don't
    invent numbers we can't cite.
  </p>

  <div style="overflow-x: auto;">
  <table class="persona-compare">
    <thead>
      <tr>
        <th></th>
        <th class="us">vinOS</th>
        <th>Copilot Enterprise</th>
        <th>Cursor Enterprise</th>
        <th>ChatGPT Team</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <th>Cost model</th>
        <td class="us">Free ISO + your own API keys. ~80% local (free).</td>
        <td>{{< param costMonthlyCopilotEnterprise >}}/seat/month, unpredictable overages</td>
        <td>$40/seat/month + inference passthrough</td>
        <td>$30/seat/month, cap by plan</td>
      </tr>
      <tr>
        <th>Data sovereignty</th>
        <td class="us">Local-first. Frontier only on explicit escalate.</td>
        <td>Prompts to OpenAI / Microsoft servers</td>
        <td>Prompts to Anthropic / OpenAI servers</td>
        <td>Prompts to OpenAI servers</td>
      </tr>
      <tr>
        <th>Deploy target</th>
        <td class="us">Bare metal · VM · Docker · K8s (v2.1)</td>
        <td>SaaS only</td>
        <td>SaaS only</td>
        <td>SaaS only</td>
      </tr>
      <tr>
        <th>Audit log</th>
        <td class="us">Per-user SQLite · routine · model · tokens · cost · tools</td>
        <td>Admin console · unpublished schema</td>
        <td>Admin console · unpublished schema</td>
        <td>Admin console · unpublished schema</td>
      </tr>
      <tr>
        <th>Sandbox model</th>
        <td class="us"><code>bwrap</code> per tool call · explicit fs + net allowlist</td>
        <td>Not applicable (SaaS)</td>
        <td>Not applicable (SaaS)</td>
        <td>Not applicable (SaaS)</td>
      </tr>
      <tr>
        <th>License</th>
        <td class="us">MIT (distribution) · GPL/permissive (components)</td>
        <td>Commercial EULA</td>
        <td>Commercial EULA</td>
        <td>Commercial EULA</td>
      </tr>
      <tr>
        <th>Per-seat lock-in</th>
        <td class="us">None. <code>pacman -Rns vinos-*</code> to remove.</td>
        <td>Annual per-seat commit</td>
        <td>Annual per-seat commit</td>
        <td>Monthly per-seat</td>
      </tr>
    </tbody>
  </table>
  </div>
  <p style="margin-top: var(--sp-3); color: var(--fg-2); font-family: var(--font-mono); font-size: var(--fs-xs);">
    Pricing pulled from public sources on the launch date of this page.
    Corrections welcome via <a href="{{< param github >}}/issues" target="_blank" rel="noopener">GitHub Issues</a>.
  </p>
</section>

<section class="persona-section">
  <h2>Questions procurement asks.</h2>

  <div class="persona-faq">
    <details>
      <summary>SOC 2 / ISO 27001?</summary>
      <div class="faq-body">
        On the roadmap. The primitives auditors care about — immutable
        run ledger, per-tool sandbox, explicit network egress list,
        deterministic routing decisions — exist in v2.0.5 and are
        documented in <a href="/spec/">/spec/</a>. Formal attestation
        pending an enterprise-tier customer sponsoring the audit.
      </div>
    </details>
    <details>
      <summary>GDPR / data residency?</summary>
      <div class="faq-body">
        Local-first is by-design GDPR-compliant for most use cases —
        prompts and outputs stay on the endpoint, no cross-border
        transfer. When a routine escalates to a frontier API, the
        provider's Data Processing Agreement applies (Anthropic and
        OpenAI both offer EU-residency options). Escalation is explicit
        and logged.
      </div>
    </details>
    <details>
      <summary>Air-gap support?</summary>
      <div class="faq-body">
        Yes. Set <code>route = "ollama"</code> at the RoutineSet
        <code>defaults</code> level and no routine can escalate off-box.
        The installer supports offline install from a mirrored USB;
        Ollama models pre-pulled to <code>/var/lib/ollama</code> during
        image build.
      </div>
    </details>
    <details>
      <summary>SSO / LDAP / SCIM?</summary>
      <div class="faq-body">
        vinOS inherits Arch's auth surface — SSSD, realmd, LDAP,
        Kerberos, and PAM modules install from AUR/extras (not
        pre-installed in the base ISO — pull them via
        <code>pacman -S</code> or a post-install profile). Per-user
        routine ledgers are already per-<code>$UID</code>. SCIM
        provisioning is not vinOS's layer — handle it at your identity
        provider.
      </div>
    </details>
    <details>
      <summary>Support / SLA?</summary>
      <div class="faq-body">
        Community support via <a href="{{< param github >}}/discussions" target="_blank" rel="noopener">GitHub Discussions</a>
        today. Enterprise tier with named-contact SLA + private
        vulnerability disclosure is planned — contact
        <a href="mailto:vin@mindtrades.com">vin@mindtrades.com</a>
        directly if you need a quote before the tier is public.
      </div>
    </details>
    <details>
      <summary>Compliance packet for our security review?</summary>
      <div class="faq-body">
        In progress. Today: architecture diagram, threat model, and
        audit-log extraction docs are in <a href="/docs/">/docs/</a>.
        A packaged Trust Center (SBOM, signed release binaries,
        supply-chain provenance) is on the v2.1 roadmap alongside the
        Cloud runtime.
      </div>
    </details>
  </div>
</section>

<section class="persona-cta-final">
  <h2>Pilot it on <span class="accent">one team.</span></h2>
  <p>Free to try — the ISO is the full distribution. Uninstall in one command if it doesn't fit.</p>
  <div class="actions">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="/docs/" class="btn link">Deployment guide →</a>
  </div>
  <div class="cta-note">Uninstall: <code>pacman -Rns vinos-*</code>. No lock-in. MIT-licensed.</div>
</section>
