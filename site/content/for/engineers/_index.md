---
title: "vinOS for engineers — agents that live next to your code"
description: "Drop a .vinos/routines.yaml in any repo. Your team runs the same PR reviewer, the same commit-message writer, the same standup summarizer — locally. Versioned in git. Auditable in PR."
url: "/for/engineers/"
type: "for"
layout: "persona"
---

<section class="persona-hero">
  <span class="eyebrow">for engineers</span>
  <h1>Agents that live <span class="accent">next to your code.</span></h1>
  <p class="persona-lede">
    Drop a <code>.vinos/routines.yaml</code> in any repo. Your team runs
    the same PR reviewer, the same commit-message writer, the same
    standup summarizer — <em>locally, versioned in git, auditable in PR.</em>
  </p>
  <div class="persona-cta-row">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="#proof" class="btn link">See the spec →</a>
  </div>
</section>

<section class="persona-section">
  <h2>Three things you get when you commit the spec.</h2>
  <p class="persona-section-lede">
    Portable, sandboxed, cost-capped. All three enforced by the runtime,
    not by convention. Read them yourself in <code>libexec/vinos-routine</code>.
  </p>

  <div class="outcomes">
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M6 8h20v18H6z"/><path d="M6 14h20"/>
          <circle cx="10" cy="11" r="1" fill="currentColor"/>
          <path d="M10 20l4-4 4 4 4-4"/>
        </svg>
      </div>
      <h3>Portable agents in <span class="accent">a single yaml.</span></h3>
      <p class="outcome-sub"><code>.vinos/routines.yaml</code> in the repo root. <code>vinos-routine load .</code> installs the set under <code>~/.vinos/routines/&lt;project&gt;/</code>. Scoped per repo.</p>
      <div class="outcome-tool"><code>vinos-routine load .</code> · <span class="dim">git-native</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M6 16h6l4-8 4 16 4-8h2"/>
        </svg>
      </div>
      <h3>80/20 router keeps API bills <span class="accent">predictable.</span></h3>
      <p class="outcome-sub"><code>route = "auto"</code>: local Ollama first, escalate to Claude only when the task exceeds what a local can handle. Ledger logs every choice.</p>
      <div class="outcome-tool"><code>vinos-router explain &lt;task&gt;</code> · <span class="dim">SQLite ledger</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M16 4l10 4v8c0 6-4 10-10 12-6-2-10-6-10-12V8z"/>
          <path d="M12 16l3 3 6-6"/>
        </svg>
      </div>
      <h3>Sandbox <span class="accent">by default.</span></h3>
      <p class="outcome-sub">Every tool call goes through <code>bwrap</code> with an explicit filesystem + network allowlist declared in the routine. Nothing implicit.</p>
      <div class="outcome-tool"><code>tools.allow = [ ... ]</code> · <span class="dim">bwrap-enforced</span></div>
    </article>
  </div>
</section>

<section class="persona-section" id="proof">
  <h2>The proof — <span class="accent">the actual repo spec.</span></h2>
  <p class="persona-section-lede">
    This is the file that lives at <code>.vinos/routines.yaml</code> in
    your repo. Committed. Reviewed. Loaded on every engineer's machine
    with one command.
  </p>

{{< code file=".vinos/routines.yaml" lang="yaml" >}}
apiVersion: vinos.computer/v1
kind: RoutineSet

metadata:
  project: startup-inc
  owner: engineering@startup.example

defaults:
  agent:
    route: auto            # 80% local · 20% escalate
    model: llama3.1:8b
    escalate_to: claude-sonnet-4-6
    memory: session
  budget:
    max_tokens_per_run: 8000
    max_dollars_per_day: 0.50
    on_exceed: skip

routines:
  - name: pr-review
    description: Triage new PRs across the org · flag what needs a human.
    schedule:
      oncalendar: "*-*-* 09,13,17:00:00"
      timezone: America/New_York
      jitter: 3m
    agent:
      tools:
        - "shell:gh pr list --state=open --json number,title,repository"
        - "read:{{git_root}}/CODEOWNERS"

  - name: commit-message
    description: Suggest a Conventional-Commits subject line from staged diff.
    schedule: on_demand      # `vinos-routine run commit-message`
    agent:
      route: ollama          # local only · never leaves the box
      tools:
        - "shell:git diff --cached"
{{< /code >}}

  <p style="margin-top: var(--sp-4); color: var(--fg-2); font-family: var(--font-mono); font-size: var(--fs-xs);">
    Full spec: <a href="/spec/">/spec/</a> · loader source:
    <a href="https://github.com/vinpatel/vinos/tree/main/libexec" target="_blank" rel="noopener">libexec/vinos-routine</a>
  </p>
</section>

<section class="persona-section">
  <h2>Questions engineers actually ask.</h2>

  <div class="persona-faq">
    <details>
      <summary>Vendor lock-in?</summary>
      <div class="faq-body">
        None. vinOS is Arch under the hood. The routine spec is versioned
        YAML — you can read it, port it, or export routines to plain
        systemd unit files with <code>vinos-routine export --systemd</code>.
        The whole distribution uninstalls with
        <code>pacman -Rns vinos-*</code>. MIT-licensed. Your
        <code>.vinos/routines.yaml</code> keeps working if you leave.
      </div>
    </details>
    <details>
      <summary>How does the auto-router decide local vs. frontier?</summary>
      <div class="faq-body">
        Three heuristics, in order: context length (if the prompt exceeds
        the local model's window, escalate), tool count (multi-tool
        orchestration escalates), and prior-run classification (if the
        same routine has escalated on similar inputs before, escalate
        immediately). Full decision tree in the
        <a href="/spec/">router spec</a> — deterministic, no LLM in the
        routing loop.
      </div>
    </details>
    <details>
      <summary>Can I write my own tools?</summary>
      <div class="faq-body">
        Yes. A tool is either <code>shell:&lt;command&gt;</code> or
        <code>read:&lt;path&gt;</code>. Both go through
        <code>bwrap</code> with a scoped filesystem view. Custom
        long-running tools can be wrapped as
        <code>shell:vinos-tool my-tool</code> — anything on PATH works.
      </div>
    </details>
    <details>
      <summary>Does it work with our monorepo?</summary>
      <div class="faq-body">
        Yes. Each <code>.vinos/routines.yaml</code> is scoped by its
        directory — the loader keys routines by repo path, so you can
        have per-service routine sets under
        <code>services/foo/.vinos/</code> that only apply when
        <code>{{git_root}}</code> resolves inside that subtree.
      </div>
    </details>
    <details>
      <summary>CI integration?</summary>
      <div class="faq-body">
        Planned for v2.1 (see the <a href="/docs/v2/roadmap/">roadmap</a>) —
        <code>ghcr.io/vinpatel/vinos-cloud</code> Docker image runs the
        same routine set as a GitHub Action or GitLab CI job. Today you
        can wire a routine to a webhook via
        <code>vinos-routine run &lt;name&gt; --json</code> and pipe the
        result into any CI's step outputs.
      </div>
    </details>
    <details>
      <summary>Language / stack requirements?</summary>
      <div class="faq-body">
        Nothing beyond what your repo already needs. The routine runtime
        is Python + bash + SQLite; tools you invoke run in your project's
        environment. If your monorepo has a devcontainer, routines see
        the same shell.
      </div>
    </details>
  </div>
</section>

<section class="persona-cta-final">
  <h2>Commit the spec. <span class="accent">Your team inherits the agents.</span></h2>
  <p>Flash a USB. Boot. Drop <code>.vinos/routines.yaml</code> in your repo. Push.</p>
  <div class="actions">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="/spec/" class="btn link">Read the routine spec →</a>
  </div>
  <div class="cta-note">Uninstall: <code>pacman -Rns vinos-*</code>. No lock-in. MIT-licensed.</div>
</section>
