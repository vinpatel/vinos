---
title: "vinOS for researchers — local models, your papers stay yours"
description: "vinOS runs open-source LLMs on your GPU via Ollama. No paper uploaded to a server. No prompt logged by a third party. Reproducible: pin the model, pin the routine, share the .vinos/routines.yaml alongside your paper."
url: "/for/researchers/"
type: "for"
layout: "persona"
---

<section class="persona-hero">
  <span class="eyebrow">for researchers</span>
  <h1>Local models. Your <span class="accent">papers</span> stay yours.</h1>
  <p class="persona-lede">
    vinOS runs open-source LLMs on your GPU via Ollama. No paper
    uploaded to a server. No prompt logged by a third party.
    <em>Reproducible</em>: pin the model, pin the routine, share the
    <code>.vinos/routines.yaml</code> alongside your paper.
  </p>
  <div class="persona-cta-row">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="#proof" class="btn link">See the recap routine →</a>
  </div>
</section>

<section class="persona-section">
  <h2>Three outcomes for the research workflow.</h2>
  <p class="persona-section-lede">
    Sovereignty, reproducibility, ambient synthesis. Your reading pile
    turns into notes overnight — on your hardware, with a model you
    control.
  </p>

  <div class="outcomes">
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M16 4l10 4v8c0 6-4 10-10 12-6-2-10-6-10-12V8z"/>
          <path d="M12 16l3 3 6-6"/>
        </svg>
      </div>
      <h3>Sovereignty — <span class="accent">no paper text</span> leaves your machine.</h3>
      <p class="outcome-sub">Every routine that touches <code>~/Reading</code> or your bib runs against a local Ollama model. Escalation to a frontier API is disabled by default for research routines.</p>
      <div class="outcome-tool"><code>route = "ollama"</code> · <span class="dim">enforced</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M8 6h16v20H8z"/><path d="M8 12h16"/>
          <path d="M12 18h8M12 22h5"/>
        </svg>
      </div>
      <h3>Reproducibility — <span class="accent">pin model + routine</span> in git.</h3>
      <p class="outcome-sub">Model tag and routine TOML pinned by SHA. <code>vinos-routine run</code> prints the exact model version, quantization, and seed on every invocation.</p>
      <div class="outcome-tool"><code>model = "qwen2.5:32b-instruct-q4_K_M"</code> · <span class="dim">pinned</span></div>
    </article>
    <article class="outcome">
      <div class="outcome-icon" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M6 10l4-4h12l4 4v16H6z"/>
          <path d="M10 14h12M10 18h12M10 22h8"/>
        </svg>
      </div>
      <h3>Nightly recap reads <span class="accent"><code>~/Reading</code></span> for you.</h3>
      <p class="outcome-sub">Long-context local model summarizes new PDFs, cross-links to your bib, and emits spaced-repetition cards. Wakes you up with the synthesis, not the pile.</p>
      <div class="outcome-tool"><code>research-recap</code> · <span class="dim">22:00 nightly</span></div>
    </article>
  </div>
</section>

<section class="persona-section" id="proof">
  <h2>The proof — <span class="accent">a routine + a model pull.</span></h2>
  <p class="persona-section-lede">
    Two files. The routine (versioned in your paper's repo) and the
    exact <code>ollama pull</code> to reproduce the model behind it.
  </p>

{{< code file=".vinos/routines/research-recap.toml" lang="toml" >}}
[routine]
name        = "research-recap"
schedule    = "0 22 * * *"                # nightly · 22:00 local
agent       = "recap"
route       = "ollama"                    # local only · never escalates

[model]
local       = "qwen2.5:32b-instruct-q4_K_M"   # 32B · 128k ctx · pinned
seed        = 42                              # for reproducibility

[tools]
allow       = ["read:~/Reading", "read:~/Zotero", "shell:pandoc"]

[prompt]
system      = """You synthesize the night's reading.
For each new PDF in ~/Reading since last run:
  1. Two-paragraph summary.
  2. Cross-links to prior papers in ~/Zotero (by DOI).
  3. Three spaced-repetition Q/A pairs.
Cite the model version and today's date at the bottom."""

[out]
render      = "markdown"
sink        = "~/Notes/recap-{{date}}.md"
open_on_login = true

[budget]
max_tokens  = 32000
max_dollars = 0.00                        # local · no dollar cost
{{< /code >}}

{{< code file="~ · foot" lang="bash" >}}
# One-time: pull the 32B long-context local model.
$ ollama pull qwen2.5:32b-instruct-q4_K_M
pulling manifest ... 100%
digest: sha256:6c5f... · size: 19 GB

# Enable the routine.
$ vinos-routine enable research-recap
enabled · timer armed · next run: 22:00 today

# Verify what will run.
$ vinos-routine explain research-recap
routine: research-recap
model:   qwen2.5:32b-instruct-q4_K_M (local · sha256:6c5f...)
route:   ollama (frontier escalation disabled)
tools:   read:~/Reading, read:~/Zotero, shell:pandoc
budget:  32000 tokens · $0.00 · local-only
{{< /code >}}

  <p style="margin-top: var(--sp-4); color: var(--fg-2); font-family: var(--font-mono); font-size: var(--fs-xs);">
    GPU + RAM sizing for local models: <a href="/models/">/models/</a>.
    qwen2.5:32b at Q4 needs ~24 GB VRAM (or CPU + 32 GB system RAM at
    ~2 tok/s).
  </p>
</section>

<section class="persona-section">
  <h2>Questions researchers ask.</h2>

  <div class="persona-faq">
    <details>
      <summary>Can I cite the model version in my paper?</summary>
      <div class="faq-body">
        Yes — the model tag is pinned in the routine TOML
        (<code>qwen2.5:32b-instruct-q4_K_M</code>) and the SHA-256 of
        the manifest is printed on every run. Cite the tag, the SHA, and
        the routine's git commit; anyone with the same three can reproduce
        your synthesis bit-for-bit given the same input files.
      </div>
    </details>
    <details>
      <summary>Does this work with LaTeX / pandoc / bib tooling?</summary>
      <div class="faq-body">
        Yes. TeX Live, pandoc, biber, and Zotero (via
        <code>zotero-cli</code>) are in the standard bundle. Routines
        can invoke any of them as a <code>shell:</code> tool — the recap
        routine above uses pandoc to normalize PDFs before feeding them
        to the model.
      </div>
    </details>
    <details>
      <summary>GPU requirements for the big models?</summary>
      <div class="faq-body">
        Rough guide (full table on <a href="/models/">/models/</a>):
        7-8B quantized runs on 8 GB VRAM; 13B on 12 GB;
        32B at Q4 needs ~24 GB (RTX 3090 / 4090 / A5000); 70B needs
        48 GB+. CPU-only works for all sizes at reduced tok/s — fine
        for overnight routines, painful for interactive.
      </div>
    </details>
    <details>
      <summary>Can I share routines with collaborators?</summary>
      <div class="faq-body">
        Yes — drop <code>.vinos/routines.yaml</code> in your paper's
        repo and commit. Any collaborator who's booted vinOS runs
        <code>vinos-routine load .</code> to install the same set. Pair
        that with an <code>ollama-models.lock</code> file (list of tags
        + SHAs) for full reproducibility across machines.
      </div>
    </details>
    <details>
      <summary>How is this different from Elicit / Consensus / ResearchGPT?</summary>
      <div class="faq-body">
        Those are SaaS — you upload papers to their servers, they run
        their model, they log your prompts. vinOS is on your machine:
        your GPU, your model, your keys, your data. Cheaper long-term
        (no per-query fee), reproducible (pinned model version), and
        stays working if the vendor pivots or shuts down.
      </div>
    </details>
    <details>
      <summary>IRB / privacy-review implications?</summary>
      <div class="faq-body">
        Local-first materially simplifies most reviews — no third-party
        processor to disclose, no data-transfer agreement required, no
        subject-data leaving your machine. Print the routine TOML and
        the <code>vinos-routine explain</code> output as evidence of
        the pipeline.
      </div>
    </details>
  </div>
</section>

<section class="persona-cta-final">
  <h2>Overnight synthesis, <span class="accent">on your hardware.</span></h2>
  <p>Flash a USB, pull a model, enable the recap. Tomorrow morning the pile is a page of notes.</p>
  <div class="actions">
    <a href="{{< param isoURL >}}" class="btn primary" target="_blank" rel="noopener">Download vinOS {{< param version >}}</a>
    <a href="/models/" class="btn link">Local model picker →</a>
  </div>
  <div class="cta-note">Uninstall: <code>pacman -Rns vinos-*</code>. No lock-in. MIT-licensed.</div>
</section>
