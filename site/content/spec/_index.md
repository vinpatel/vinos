---
title: "The vinOS routine specs"
description: "Index of the two source-of-truth specs behind vinOS routines — vinos-routine-spec.md (single-file TOML the runtime consumes) and vinos-routines-yaml-spec.md (project-scoped YAML you commit next to your code)."
url: "/spec/"
type: "for"
---

<section class="audience-hero">
  <span class="audience-eyebrow">the <span class="accent">spec</span></span>
  <h1>Two files. <span class="accent">Both short.</span> Both authoritative.</h1>
  <p class="audience-lede">
    vinOS routines are defined by two specs. The <strong>routine spec</strong>
    is the single-file TOML the runtime consumes. The
    <strong>routines.yaml spec</strong> is the project-scoped bundle you
    commit next to your code — the way <code>.github/workflows/</code>
    became the standard for CI. Both are drafted against v2.0.5 and live
    in the repo, in <code>docs/v2/</code>. Read them there so you always
    get the latest revision.
  </p>
</section>

<section class="audience-section">
  <h2>The two specs</h2>

  <div class="spec-grid">
    <div class="spec-block">
      <h3>vinos-routine-spec.md</h3>
      <p>
        The single-file TOML schema the runtime reads from
        <code>/etc/vinos/routines/</code> and <code>~/.vinos/routines/</code>.
        Covers <code>[routine]</code>, <code>[schedule]</code>,
        <code>[agent]</code>, <code>[output]</code>, <code>[budget]</code>,
        the tool whitelist, the bwrap sandbox rules, the ledger schema,
        and the systemd timer lifecycle.
      </p>
      <p class="small-print">
        <a href="https://github.com/vinpatel/vinos/blob/main/docs/v2/vinos-routine-spec.md" target="_blank" rel="noopener">Read on GitHub →</a><br>
        <a href="https://raw.githubusercontent.com/vinpatel/vinos/main/docs/v2/vinos-routine-spec.md" target="_blank" rel="noopener">Raw markdown →</a>
      </p>
    </div>

    <div class="spec-block">
      <h3>vinos-routines-yaml-spec.md</h3>
      <p>
        The project-scoped YAML bundle you commit at
        <code>.vinos/routines.yaml</code>. Supports multiple routines per
        file, a deep-merged <code>defaults:</code> block, template
        variables (<code>{{project}}</code>, <code>{{git_root}}</code>,
        <code>{{home}}</code>), and the <code>vinos-routine load</code>
        install flow. Converts to TOML at load time.
      </p>
      <p class="small-print">
        <a href="https://github.com/vinpatel/vinos/blob/main/docs/v2/vinos-routines-yaml-spec.md" target="_blank" rel="noopener">Read on GitHub →</a><br>
        <a href="https://raw.githubusercontent.com/vinpatel/vinos/main/docs/v2/vinos-routines-yaml-spec.md" target="_blank" rel="noopener">Raw markdown →</a>
      </p>
    </div>
  </div>
</section>

<section class="audience-section">
  <h2>Related</h2>
  <div class="model-usage">
    <div class="model-usage-row">
      <span class="model-usage-cmd">/docs/v2/ARCHITECTURE.md</span>
      <span class="model-usage-desc">
        <a href="https://github.com/vinpatel/vinos/blob/main/docs/v2/ARCHITECTURE.md" target="_blank" rel="noopener">v2 architecture overview</a>
        — how the pieces fit together
      </span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">/configs/vinos/routines/*.toml</span>
      <span class="model-usage-desc">
        <a href="https://github.com/vinpatel/vinos/tree/main/configs/vinos/routines" target="_blank" rel="noopener">Starter routine TOMLs</a>
        that ship in the ISO
      </span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">/routines/</span>
      <span class="model-usage-desc">
        <a href="/routines/">Human-readable walkthrough</a>
        of what a routine is, how to install one, and the shipped starters
      </span>
    </div>
  </div>
</section>

<section class="audience-section">
  <div class="prose measure">
    <p class="small-print">
      Both specs are marked <em>draft</em> until v2.0.5 ships. Behavior may
      shift in the last mile. Watch
      <a href="https://github.com/vinpatel/vinos/commits/main/docs/v2" target="_blank" rel="noopener">commits/main/docs/v2</a>
      for changes; every material revision gets a note in the release notes.
    </p>
  </div>
</section>
