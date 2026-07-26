---
title: "vinOS for developers"
description: "An agentic dev environment that ships out of the box. 80/20 local + frontier AI. Less config, more shipping."
url: "/for/developers/"
---

<section class="audience-hero">
  <span class="audience-eyebrow">for <span class="accent">developers</span></span>
  <h1>Boot into your workflow, <span class="accent">not your setup weekend.</span></h1>
  <p class="audience-lede">
    Every laptop you own has one weekend of setup blocking it from being a
    working agentic dev machine. vinOS ships that weekend already done —
    Hyprland, Ollama, Claude Code, sensible defaults, and 88 helper commands,
    all wired on first boot. <em>You write code. It handles the rest.</em>
  </p>
</section>

<section class="audience-section">
  <h2>The three things you're paying for right now.</h2>
  <ul class="audience-pain">
    <li>
      <h3>The setup weekend.</h3>
      <p>A functional Wayland desktop is a shopping list: compositor, bar, launcher, terminal, lock screen, notification daemon, clipboard, screenshot pipeline. Then themes. Then keybindings. Then font hinting.</p>
    </li>
    <li>
      <h3>The API bill.</h3>
      <p>You're routing every prompt to a frontier model — including the summarize / refactor / extract grunt work a local 7B can handle for free. Your monthly Claude bill is <em>quietly</em> subsidizing tasks that don't need it.</p>
    </li>
    <li>
      <h3>The data leaving your machine.</h3>
      <p>Every unfamiliar prompt, every codebase excerpt, every internal doc — sent to someone else's servers. Fine for public work. Suddenly not fine when a client hands you a repo.</p>
    </li>
  </ul>
</section>

<section class="audience-section">
  <h2>What vinOS does <span class="accent">instead.</span></h2>
  <ul class="audience-solutions">
    <li>
      <h3>Zero-config, first boot.</h3>
      <p>Hyprland + waybar + walker + foot + hyprlock, tokyo-night themed. Every driver detected, every service tuned. No dotfile chase. No community wiki. <code>vinos-doctor</code> prints green.</p>
    </li>
    <li>
      <h3>Local for the 80%.</h3>
      <p><kbd>Super</kbd>+<kbd>A</kbd> opens Ollama chat with the model you pick. Grunt work — summarize, refactor, extract, draft, test — runs on your GPU for free. Zero API tokens burned.</p>
    </li>
    <li>
      <h3>Frontier for the 20%.</h3>
      <p><kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd> opens Claude Code in your project. Deep reasoning, big context, final polish — over the API, only when it matters. Your bill covers <em>judgment</em>, not busywork.</p>
    </li>
    <li>
      <h3>Every helper is a shell script.</h3>
      <p>88 <code>vinos-*</code> commands, each under 80 lines, every one <code>shellcheck</code>-clean. Read them, fork them, replace them. Nothing hidden.</p>
    </li>
  </ul>
</section>

<section class="audience-proof">
  <figure>
    <img src="/img/for/developers-doctor.png" alt="vinos-doctor terminal — 26 checks passed, 0 failed"
         onerror="this.onerror=null;this.src='/img/screenshots/01-desktop.png';">
    <figcaption>Fresh boot. <code>vinos-doctor</code> → <span style="color:var(--color-ok)">PASS = 26</span> · <span>FAIL = 0</span> · SKIP = 3. Real output from a fresh boot.</figcaption>
  </figure>
</section>

<section class="audience-cta">
  <h2>Ship faster. <span class="accent">Local first.</span></h2>
  <p class="audience-cta-note">
    Flash a USB. Boot. In fifteen minutes, your daily driver runs local LLMs and Claude Code. Every subsequent boot: five seconds to a working workspace.
  </p>
  <div class="hero-actions">
    <a href="{{< param isoURL >}}" class="btn-primary" target="_blank" rel="noopener">Download vinOS v{{< param version >}}</a>
    <a href="/install/" class="link-ghost">Read the install guide →</a>
    <a href="https://github.com/sponsors/vinpatel" class="link-ghost" target="_blank" rel="noopener">Sponsor the work ♥</a>
  </div>
</section>
