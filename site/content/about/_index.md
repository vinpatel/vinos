---
title: "About vinOS"
description: "Positioning, heritage, sponsors. vinOS is the agentic startup OS — real Claude/Ollama-powered agents on a schedule, 80% local, 20% premium, and a small, readable overlay on stock Arch."
url: "/about/"
type: "for"
---

<section class="audience-hero">
  <span class="audience-eyebrow">about <span class="accent">vinOS</span></span>
  <h1>An operating system for people who <span class="accent">build things.</span></h1>
  <p class="audience-lede">
    vinOS is the first Linux distribution where autonomous agents run on a
    schedule as first-class citizens — not cron jobs, not Zapier flows, but
    real Claude- and Ollama-powered agents with tools, memory, verification,
    and per-run budgets, running in the background while you work. 80% of
    that work runs on local models on your own hardware; the hard 20%
    escalates to a premium API. The stack is a thin, readable layer over
    stock Arch Linux — you can leave any time and nothing follows you.
  </p>
</section>

<section class="audience-section">
  <h2>What we're building</h2>
  <div class="prose measure">
    <p>
      Everyone else has agents you <em>talk to</em>. vinOS has agents that
      <em>run without you</em> — briefing you at 6&nbsp;am, reviewing your
      PRs at 1&nbsp;pm, closing your day at 6&nbsp;pm — and stay quiet when
      they have nothing to say. The primitive is a
      <a href="/routines/">routine</a>: one declarative TOML file, one
      systemd timer, whitelist-enforced tools inside a bwrap sandbox, and
      a SQLite ledger that meters every token. You commit the routines
      next to your code (<code>.vinos/routines.yaml</code>) and your
      teammates inherit the same agents on clone.
    </p>
    <p>
      That's the whole thesis. Everything else — the Hyprland desktop, the
      88 <code>vinos-*</code> utilities, the T2 Mac support, the 5 shipped
      themes — exists to make sure the primitive works on the machine you
      already own, without a setup weekend.
    </p>
  </div>
</section>

<section class="audience-section" id="heritage">
  <h2>What vinOS is built on</h2>
  <div class="prose measure">
    <p>
      vinOS is a Linux distribution. Like every Linux distribution, it
      composes open-source components with our own work. The small print:
    </p>
    <ul class="small-print" style="line-height: 1.7;">
      <li><strong>Arch Linux</strong> — vinOS is built from the archiso profile published by the Arch Linux project. Modifications retained under the same GPL-3.0 terms. vinOS is not affiliated with or endorsed by the Arch Linux project.</li>
      <li><strong>Omarchy</strong> (MIT) — vendored verbatim as the desktop configuration layer. Upstream: <a href="https://github.com/basecamp/omarchy" target="_blank" rel="noopener">basecamp/omarchy</a>. vinOS extends it with the routine runtime and the <code>vinos-*</code> utility set.</li>
      <li><strong>linux-t2</strong> (GPL-2.0) — the T2-patched kernel from <a href="https://github.com/t2linux/linux-t2" target="_blank" rel="noopener">t2linux/linux-t2</a> ships as vinOS's primary kernel so Apple T2 hardware works from first boot.</li>
      <li><strong>Broadcom firmware</strong> — redistributed under Broadcom's binary firmware terms for Wi-Fi compatibility on T2 hardware.</li>
      <li><strong>Wallpaper photographers</strong> — every shipped theme uses a wallpaper from a working photographer on <a href="https://unsplash.com/license" target="_blank" rel="noopener">Unsplash</a>. Attribution appreciated but not legally required; we credit them anyway because they earned it. Full list in the theme <a href="https://github.com/vinpatel/vinos/blob/main/configs/vinos/brand/themes/ATTRIBUTION.md" target="_blank" rel="noopener">ATTRIBUTION.md</a>.</li>
    </ul>
    <p class="small-print">
      Full third-party notices:
      <a href="https://github.com/vinpatel/vinos/blob/main/NOTICES.md" target="_blank" rel="noopener">NOTICES.md</a>.
      Trademarks — Apple, Mac, MacBook, T2, and Arch Linux are trademarks of
      their respective owners; their use in vinOS is nominative. vinOS is
      not affiliated with, endorsed by, or sponsored by any of them.
    </p>
    <p class="small-print">
      Our own code is under
      <a href="https://github.com/vinpatel/vinos/blob/main/LICENSE" target="_blank" rel="noopener">LICENSE</a>.
    </p>
  </div>
</section>

<section class="audience-section" id="sponsors">
  <h2>Sponsors</h2>
  <div class="prose measure">
    <p>
      vinOS is developed in public by one person and funded by people who
      find it useful. Every sponsor dollar goes to (in order) hosting the
      ISO on a mirror, buying the T2 Macs and NVIDIA rigs the release cycle
      needs to test on, and time — the release cadence is proportional to
      how much time the project can afford. There are no VCs, no exit path,
      no telemetry.
    </p>
    <div class="hero-actions" style="justify-content: flex-start;">
      <a href="https://github.com/sponsors/vinpatel" class="btn-primary" target="_blank" rel="noopener">
        <span style="margin-right: 0.4em;">♥</span> Sponsor on GitHub
      </a>
      <a href="https://opencollective.com/vinos" class="link-ghost" target="_blank" rel="noopener">Open Collective →</a>
      <a href="https://github.com/vinpatel/vinos/discussions" class="link-ghost" target="_blank" rel="noopener">Community discussions →</a>
    </div>
  </div>
</section>
