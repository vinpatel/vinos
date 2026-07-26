---
title: "vinOS for founders — get your Sunday back"
description: "vinOS runs the busywork that eats your weekend. Inbox triage, PR review, day-brief, evening recap. Agents run 24/7 on your laptop. 80% on a local model."
url: "/for/founders/"
type: "for"
layout: "persona"
---

<section class="persona-hero">
  <span class="eyebrow">for founders</span>
  <h1>Get your <span class="accent">Sunday</span> back.</h1>
  <p class="persona-lede">
    vinOS runs the busywork that eats your weekend — inbox triage, PR
    review, morning brief, evening recap. Agents run 24/7 on your
    laptop. <em>80% on a local model. Free.</em>
  </p>
  <div class="persona-cta-row">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="#proof" class="btn link">See a routine →</a>
  </div>
</section>

<section class="persona-section">
  <h2>Three things that ship <span class="accent">the day you install it.</span></h2>
  <p class="persona-section-lede">
    Outcome first. Not features. Every one of these is a shipping routine
    in v{{< param version >}} — disabled by default, one <code>vinos-routine enable</code> away.
  </p>

  <div class="outcomes">
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <rect x="4" y="7" width="24" height="20" rx="2"/>
          <path d="M4 13h24"/><path d="M10 4v6"/><path d="M22 4v6"/>
          <path d="M9 18h8"/><path d="M9 22h5"/>
        </svg>
      </div>
      <h3>A brief on your login screen <span class="accent">every morning.</span></h3>
      <p class="outcome-sub">Reads your inbox, calendar, and GitHub the moment you wake the laptop. Local model. Costs a penny.</p>
      <div class="outcome-tool"><code>day-brief</code> · <span class="dim">llama3.1:8b · 06:00</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M6 10l6 6-6 6"/><path d="M14 22h12"/>
          <circle cx="24" cy="8" r="4"/><path d="M20 8h8"/>
        </svg>
      </div>
      <h3>PR reviews <span class="accent">while you're in a meeting.</span></h3>
      <p class="outcome-sub">Every 30 minutes. Local model triages, Claude only when a diff warrants judgment.</p>
      <div class="outcome-tool"><code>github-review</code> · <span class="dim">route = "auto"</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="16" cy="16" r="10"/>
          <path d="M16 10v6l4 3"/>
        </svg>
      </div>
      <h3>An hour of focus with <span class="accent">everything muted.</span></h3>
      <p class="outcome-sub"><kbd>Super</kbd>+<kbd>F</kbd> → DND on, notifications silenced, 25-minute timer visible.</p>
      <div class="outcome-tool"><code>focus-mode</code> · <span class="dim">Super+F</span></div>
    </article>
  </div>
</section>

<section class="persona-section" id="proof">
  <h2>The proof — <span class="accent">a routine you can read.</span></h2>
  <p class="persona-section-lede">
    Every routine is a TOML file. No YAML DSL. No dashboard. Read it in a
    minute, edit it in five, share it with your team by committing it.
  </p>

{{< code file=".vinos/routines/day-brief.toml" lang="toml" >}}
[routine]
name        = "day-brief"
schedule    = "0 6 * * *"      # daily · 06:00 local
agent       = "brief"
route       = "auto"           # 80% local · escalate on complexity

[model]
local       = "llama3.1:8b"    # ollama · default
premium     = "claude-3-5-sonnet"

[tools]
allow       = ["calendar", "inbox", "github", "weather"]

[out]
render      = "markdown"
sink        = "~/.local/state/vinos/brief.md"
open_on_login = true

[budget]
max_tokens  = 8000
max_dollars = 0.10             # per run · hard cap
{{< /code >}}
</section>

<section class="persona-section">
  <h2>Questions founders actually ask.</h2>

  <div class="persona-faq">
    <details>
      <summary>How much time back?</summary>
      <div class="faq-body">
        Depends how much of your Sunday is currently spent doing what a
        routine can do. If your Sundays look like inbox → PR review →
        weekly recap → planning for Monday, the shipping starter set
        covers all four. Expect the first month to be tuning schedules
        and prompts; steady state after that.
      </div>
    </details>
    <details>
      <summary>What if my API bill blows up?</summary>
      <div class="faq-body">
        Every routine has a <code>[budget]</code> block —
        <code>max_dollars</code> per run, <code>max_dollars_per_day</code>
        across the routine set. Exceed the cap and the runtime skips the
        call (behavior configurable: <code>skip</code>, <code>degrade</code>,
        or <code>local_only</code>). Hard-enforced by the runtime, not the
        model. The default starter set caps you at ~$3/day.
      </div>
    </details>
    <details>
      <summary>Do I need to be technical?</summary>
      <div class="faq-body">
        Yes, but not sysadmin-level. If you can flash a USB, edit a TOML
        file, and read a shell command's output, you're set. The starter
        routines ship <em>enabled-but-idle</em>: turn them on one at a
        time with <code>vinos-routine enable day-brief</code>.
      </div>
    </details>
    <details>
      <summary>Can my team share my routines?</summary>
      <div class="faq-body">
        Yes — routines are portable. Drop a
        <code>.vinos/routines.yaml</code> in your repo, commit it, and
        anyone on your team who's booted vinOS runs
        <code>vinos-routine load .</code> to install the same set on their
        machine. Versioned in git, reviewed in PR.
      </div>
    </details>
    <details>
      <summary>What about privacy?</summary>
      <div class="faq-body">
        Local-first. The default route sends most calls to a local Ollama
        model — your inbox contents, calendar events, and repo diffs
        never leave the machine unless a routine explicitly escalates to
        a frontier API (and even then, only the specific prompt is sent,
        not the full context). Set <code>route = "ollama"</code> on any
        routine to force local-only.
      </div>
    </details>
  </div>
</section>

<section class="persona-cta-final">
  <h2>Boot into <span class="accent">your agents.</span></h2>
  <p>Flash a USB. Boot any x86_64 machine. In fifteen minutes your first routine is running.</p>
  <div class="actions">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="/routines/" class="btn link">Browse routines →</a>
  </div>
  <div class="cta-note">Uninstall: <code>pacman -Rns vinos-*</code>. No lock-in. MIT-licensed.</div>
</section>
