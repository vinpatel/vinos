---
title: "vinOS for platform teams — runs on your laptop, ships to your cluster"
description: "Same .vinos/routines.yaml runs on the engineer's MacBook AND on your Kubernetes cluster via ghcr.io/vinpatel/vinos-cloud (v2.1). Systemd timers on the box, CronJobs in the cluster. One spec, two runtimes."
url: "/for/platform/"
type: "for"
layout: "persona"
---

<section class="persona-hero">
  <span class="eyebrow">for platform teams</span>
  <h1>Runs on your laptop. Ships to your <span class="accent">cluster.</span></h1>
  <p class="persona-lede">
    Same <code>.vinos/routines.yaml</code> runs on the engineer's
    MacBook <em>and</em> on your Kubernetes cluster via
    <code>ghcr.io/vinpatel/vinos-cloud</code> (v2.1). Systemd timers on
    the box, CronJobs in the cluster. One spec, two runtimes.
  </p>
  <div class="persona-cta-row">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="#proof" class="btn link">See the export →</a>
  </div>
</section>

<section class="persona-section">
  <h2>Three outcomes when the same spec targets both runtimes.</h2>
  <p class="persona-section-lede">
    Portability, symmetry, cost. Laptop-first for iteration, cluster for
    the always-on runtime — with no two-tool split-brain.
  </p>

  <div class="outcomes">
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M6 6h20v14H6z"/><path d="M4 22h24"/><path d="M14 26h4"/>
          <path d="M20 12l4-4M20 12l4 4"/>
        </svg>
      </div>
      <h3>Portable spec — <span class="accent">yaml → CronJob.</span></h3>
      <p class="outcome-sub"><code>vinos-routine export --k8s</code> will emit a K8s CronJob per routine — schedules translated, secrets referenced, state bound to a PVC. The <code>.vinos/routines.yaml</code> spec ships today (v2.0.5); the exporter + Helm chart land in v2.1.</p>
      <div class="outcome-tool"><code>vinos-routine export --k8s</code> · <span class="dim">coming v2.1</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="16" cy="16" r="4"/>
          <circle cx="16" cy="16" r="10" opacity="0.5"/>
          <circle cx="16" cy="16" r="14" opacity="0.25"/>
        </svg>
      </div>
      <h3>Same runtime, <span class="accent">laptop or cloud.</span></h3>
      <p class="outcome-sub">Python + bash + SQLite + optional Ollama HTTP client. The Docker image is the same binary as the laptop package — minus Hyprland and friends.</p>
      <div class="outcome-tool"><code>ghcr.io/vinpatel/vinos-cloud:2.1</code> · <span class="dim">~200 MB</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <rect x="4" y="8" width="24" height="16" rx="2"/>
          <path d="M4 14h24"/>
          <circle cx="8" cy="11" r="1" fill="currentColor"/>
        </svg>
      </div>
      <h3>$5/mo Hetzner runs your agents <span class="accent">24/7.</span></h3>
      <p class="outcome-sub">When the laptop sleeps, cluster or VPS picks up the schedule. State converges through the shared ledger.</p>
      <div class="outcome-tool"><code>helm install vinos vinos/agents</code> · <span class="dim">v2.1</span></div>
    </article>
  </div>
</section>

<section class="persona-section" id="proof">
  <h2>The proof — <span class="accent">one spec, two manifests.</span></h2>
  <p class="persona-section-lede">
    Left: what your engineer commits. Right: what the exporter emits for
    your cluster.
  </p>

  <div class="cluster-splits">
    {{< code file=".vinos/routines.yaml" lang="yaml" >}}
apiVersion: vinos.computer/v1
kind: RoutineSet
metadata:
  project: startup-inc

defaults:
  agent:
    route: auto
    model: llama3.1:8b
    escalate_to: claude-sonnet-4-6
  budget:
    max_dollars_per_day: 0.50
    on_exceed: skip

routines:
  - name: pr-review
    schedule:
      oncalendar: "*-*-* 09,13,17:00:00"
      timezone: America/New_York
{{< /code >}}

    {{< code file="k8s/pr-review-cronjob.yaml   ·   generated" lang="yaml" >}}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pr-review
  namespace: vinos-agents
spec:
  schedule: "0 9,13,17 * * *"   # from oncalendar
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: routine
              image: ghcr.io/vinpatel/vinos-cloud:2.1
              args: ["run", "pr-review"]
              envFrom:
                - secretRef: { name: vinos-api-keys }
              volumeMounts:
                - { name: state, mountPath: /var/lib/vinos }
          volumes:
            - name: state
              persistentVolumeClaim: { claimName: vinos-ledger }
{{< /code >}}
  </div>

  <p style="margin-top: var(--sp-4); color: var(--fg-2); font-family: var(--font-mono); font-size: var(--fs-xs);">
    Cloud runtime and Helm chart target v2.1 — see
    <a href="/docs/v2/roadmap/">the roadmap</a>. Today the exporter emits
    CronJob YAML; the Helm chart, PVC scheme, and Secret conventions are
    specced in that doc.
  </p>
</section>

<section class="persona-section">
  <h2>Questions platform teams ask.</h2>

  <div class="persona-faq">
    <details>
      <summary>Helm chart?</summary>
      <div class="faq-body">
        Targeted for v2.1 — <code>helm install vinos-agents vinos/agents</code>.
        Design intent: one CronJob per routine, one PVC for the shared
        ledger, one Secret for API keys, one optional Deployment for a
        cluster-local Ollama sidecar. Chart values will mirror
        RoutineSet <code>defaults</code>. Not yet published — see the
        <a href="https://github.com/vinpatel/vinos/blob/main/docs/v2/ROADMAP.md">v2.1
        roadmap</a> for shipping trigger.
      </div>
    </details>
    <details>
      <summary>Where does state live in the cluster?</summary>
      <div class="faq-body">
        A single PVC mounted at <code>/var/lib/vinos</code> across all
        CronJob pods (RWX StorageClass required for cluster-wide shared
        ledger; RWO with a per-routine subdirectory works for isolated
        runs). Ledger is SQLite; concurrent writes serialized by WAL
        mode plus a routine-name advisory lock.
      </div>
    </details>
    <details>
      <summary>Secrets management?</summary>
      <div class="faq-body">
        API keys live in a K8s <code>Secret</code>
        (<code>vinos-api-keys</code> by default), mounted via
        <code>envFrom</code>. External Secrets Operator, sealed-secrets,
        SOPS — all work; the container only needs the env vars at run
        time. Key names match the laptop config
        (<code>ANTHROPIC_API_KEY</code>, <code>OPENAI_API_KEY</code>).
      </div>
    </details>
    <details>
      <summary>Multi-tenant?</summary>
      <div class="faq-body">
        v2.2. One shared Ollama, per-repo RoutineSets, per-tenant API
        keys, per-tenant budget caps, tenant-scoped ledger view. Aimed
        at internal-platform teams running agents for multiple product
        teams on one pool. Today: one namespace per tenant works as a
        stopgap.
      </div>
    </details>
    <details>
      <summary>Observability?</summary>
      <div class="faq-body">
        SQLite ledger today — <code>vinos-ledger tail</code> streams
        events, and <code>vinos-ledger export --prometheus</code> is
        planned to emit a scrape-friendly text format. OpenTelemetry
        traces per routine run are on the v2.2 wishlist; happy to
        prioritize if a sponsor asks for it.
      </div>
    </details>
    <details>
      <summary>GPU nodes for local Ollama?</summary>
      <div class="faq-body">
        Optional. If you deploy the Ollama sidecar with the NVIDIA
        device plugin, the routine runtime uses the cluster's GPU for
        the local route. If not, all routines fall back to
        <code>escalate_to</code> — cost caps still enforced.
      </div>
    </details>
  </div>
</section>

<section class="persona-cta-final">
  <h2>Try it on your laptop <span class="accent">first.</span></h2>
  <p>Same spec ships to the cluster in v2.1. Start local, migrate when the runtime lands.</p>
  <div class="actions">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="/docs/v2/roadmap/" class="btn link">v2.1 Cloud roadmap →</a>
  </div>
  <div class="cta-note">Uninstall: <code>pacman -Rns vinos-*</code>. No lock-in. MIT-licensed.</div>
</section>
