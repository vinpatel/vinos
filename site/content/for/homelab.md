---
title: "vinOS for homelabs"
description: "Turn the box in your closet into an agentic AI node. Local LLMs on your metal. Offline-capable. Runs on hardware you already own."
url: "/for/homelab/"
---

<section class="audience-hero">
  <span class="audience-eyebrow">for <span class="accent">homelab</span></span>
  <h1>Turn the box in your closet into an <span class="accent">AI node.</span></h1>
  <p class="audience-lede">
    That off-lease Dell, the tower gathering dust, the old ThinkPad, the
    2019 MacBook Apple stopped supporting — each of them is <em>one flash
    away</em> from being a private AI node that pays for itself in canceled
    cloud subscriptions.
  </p>
</section>

<section class="audience-section">
  <h2>Why homelabs and agentic AI belong together.</h2>
  <ul class="audience-pain">
    <li>
      <h3>Cloud AI is a subscription tax.</h3>
      <p>Every seat, every prompt, every context window — priced by the month or the token. Your homelab already has idle CPU + RAM you're paying electricity on.</p>
    </li>
    <li>
      <h3>Old hardware is capable, not obsolete.</h3>
      <p>16 GB of RAM runs a 7B model comfortably. A used GPU or a fat server runs 30B. The bottleneck for agentic workflows isn't compute — it's how fast you can spin one up.</p>
    </li>
    <li>
      <h3>The setup keeps you off the bench.</h3>
      <p>Arch + Hyprland + Ollama + Wayland desktop + hardware quirks — that's a Saturday. A Sunday if your target box is a 2018 MacBook.</p>
    </li>
  </ul>
</section>

<section class="audience-section">
  <h2>What vinOS turns your closet <span class="accent">into.</span></h2>
  <ul class="audience-solutions">
    <li>
      <h3>One ISO, any x86_64.</h3>
      <p>Flash to USB, boot, install. Same fifteen-minute experience on a Framework, a Dell PowerEdge, or a 2019 MacBook. <code>linux-t2</code> baked in — T2 Intel Macs work on first boot.</p>
    </li>
    <li>
      <h3>Ollama, ready.</h3>
      <p>Install the <code>ai</code> bundle once. Every model you pull lives on <em>your</em> disk, serves on <em>your</em> LAN, answers to <em>your</em> agents. Kill the internet — it still works.</p>
    </li>
    <li>
      <h3>Fleet-shaped from day one.</h3>
      <p>Every node runs the same overlay. Deploy vinOS on the laptop as your cockpit, on the tower as a compute node, on the Dell as a headless model server. Same commands everywhere.</p>
    </li>
    <li>
      <h3>Yours to keep.</h3>
      <p>MIT licensed. Zero telemetry. Every driver decision, every service, every keybinding — a shell script you can read. Leave any time; nothing follows you.</p>
    </li>
  </ul>
</section>

<section class="audience-proof">
  <figure>
    <img src="/img/for/homelab-btop.png" alt="btop terminal showing 12-core CPU + memory + processes"
         onerror="this.onerror=null;this.src='/img/screenshots/01-desktop.png';">
    <figcaption>Boot the ISO on a decade-old workstation. 12 cores, 32 GB RAM, three local models loaded, <code>vinos-doctor</code> green across the board.</figcaption>
  </figure>
</section>

<section class="audience-cta">
  <h2>Bring the box back to <span class="accent">life.</span></h2>
  <p class="audience-cta-note">
    Free, MIT-licensed, offline-capable. Flash a USB, boot the target, tell us what worked and what didn't — every hardware report widens the compatibility matrix.
  </p>
  <div class="hero-actions">
    <a href="{{< param isoURL >}}" class="btn-primary" target="_blank" rel="noopener">Download vinOS v{{< param version >}}</a>
    <a href="https://github.com/vinpatel/vinos/issues/new?template=hardware-report.yml" class="link-ghost" target="_blank" rel="noopener">Report your hardware →</a>
    <a href="https://opencollective.com/vinos" class="link-ghost" target="_blank" rel="noopener">Sponsor the work</a>
  </div>
</section>
