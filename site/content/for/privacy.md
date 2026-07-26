---
title: "vinOS for privacy-first work"
description: "An agentic OS for the world of uncertainty. Your prompts, files, and keys stay on your hardware. Local models by default. Zero telemetry. MIT licensed."
url: "/for/privacy/"
---

<section class="audience-hero">
  <span class="audience-eyebrow">for <span class="accent">privacy-first work</span></span>
  <h1>Your prompts. Your files. <span class="accent">Your keys.</span></h1>
  <p class="audience-lede">
    Every prompt you send to a cloud LLM is a file leaving your machine. For
    public work that's fine. For a client's codebase, an unreleased contract,
    a journalist's source, an M&amp;A doc — <em>fine becomes not-fine
    instantly.</em> vinOS is agentic AI with the default flipped: local first,
    yours by construction.
  </p>
</section>

<section class="audience-section">
  <h2>What you're actually opting into with cloud-only AI.</h2>
  <ul class="audience-pain">
    <li>
      <h3>Every prompt is a data export.</h3>
      <p>The moment you paste a file, a repo excerpt, an internal spec — it's on someone else's server. Their retention policy, their subpoena risk, their next breach.</p>
    </li>
    <li>
      <h3>Zero-trust doesn't extend to your dev laptop.</h3>
      <p>Your SSO is locked down. Your VPN is enforced. Your AI IDE integration sends codebase context to a third party in the clear. The perimeter has a hole.</p>
    </li>
    <li>
      <h3>Compliance keeps saying no.</h3>
      <p>HIPAA, GDPR, SOX, ITAR, client MSAs — every one has clauses about where regulated data lives. "The AI tool sends it to us-east-1" is not an answer that survives audit.</p>
    </li>
  </ul>
</section>

<section class="audience-section">
  <h2>What vinOS <span class="accent">flips.</span></h2>
  <ul class="audience-solutions">
    <li>
      <h3>Local by default.</h3>
      <p>Ollama is the primary path. <kbd>Super</kbd>+<kbd>A</kbd> opens a local LLM. Every prompt, every file, every code excerpt processed on your GPU. Nothing leaves the machine unless <em>you</em> route it out.</p>
    </li>
    <li>
      <h3>Frontier is opt-in and visible.</h3>
      <p>Claude Code is available under <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd>. You know when you're calling it. Your API key lives in your shell, not stored anywhere else. Reserve the API for the calls that need frontier reasoning.</p>
    </li>
    <li>
      <h3>Zero telemetry.</h3>
      <p>vinOS never phones home. No usage stats, no crash reports, no update pings you didn't invoke. What's installed is what's installed; what runs is what runs. Verify with <code>ss -ptn</code> — nothing you didn't start.</p>
    </li>
    <li>
      <h3>Every decision is readable code.</h3>
      <p>MIT licensed. 88 <code>vinos-*</code> scripts you can <code>cat</code>. No hidden binaries, no compiled agents, no proprietary layer. Audit the source in an afternoon.</p>
    </li>
  </ul>
</section>

<section class="audience-proof">
  <figure>
    <img src="/img/for/privacy-monitor.png" alt="Agents monitor panel showing local Ollama models and privacy status"
         onerror="this.onerror=null;this.src='/img/screenshots/01-desktop.png';">
    <figcaption>Live agents monitor: <code>ollama · local · 3 models</code> · <code>claude · opt-in only</code> · <code>outbound: claude only ✓</code> · <code>telemetry: none</code>.</figcaption>
  </figure>
</section>

<section class="audience-cta">
  <h2>Take the agents. <span class="accent">Keep the sovereignty.</span></h2>
  <p class="audience-cta-note">
    Freelance consultants working across client codebases. Journalists protecting sources. Legal teams reviewing contracts. Researchers with regulated data. Anyone whose "AI stack" needs to survive the next data-privacy conversation.
  </p>
  <div class="hero-actions">
    <a href="{{< param isoURL >}}" class="btn-primary" target="_blank" rel="noopener">Download vinOS v{{< param version >}}</a>
    <a href="/install/" class="link-ghost">Read the install guide →</a>
    <a href="mailto:hello@vinos.computer" class="link-ghost">Talk enterprise / compliance</a>
  </div>
</section>
