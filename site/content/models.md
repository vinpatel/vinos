---
title: "Local models on vinOS"
description: "The comprehensive picker for open-source LLMs on vinOS via Ollama. 50+ models across chat, coding, reasoning, small/edge, vision, embeddings, function-calling, MoE, uncensored, and multilingual. RAM + license + cost delta + ollama pull command per row."
url: "/models/"
type: "for"
---

<section class="audience-hero">
  <span class="audience-eyebrow">local <span class="accent">models</span> + the 80/20 router</span>
  <h1>Pick a model. Copy the command. <span class="accent">You're running.</span></h1>
  <p class="audience-lede">
    vinOS ships Ollama. Every model below is a single <code>ollama pull</code>
    away — no config, no auth, no keys. <em>Runs on your GPU (or CPU).
    Nothing leaves the machine.</em> Marginal cost per prompt: your
    electricity. Routines default to a local pick from this catalog and
    escalate to Claude only when they have to — see the router below.
  </p>
</section>

<section class="audience-section" id="the-80-20-router">
  <h2>The <span class="accent">80/20</span> router</h2>
  <div class="prose measure">
    <p>
      Every vinOS routine picks a model per run. Set <code>route = "auto"</code>
      in the routine's TOML and the runtime tries a <strong>local Ollama
      model</strong> first — for summarization, extraction, drafting,
      classification, small-scale reasoning. Roughly <strong>80% of routine
      work never leaves your machine</strong>. The other 20% — deep reasoning,
      big context, code that must actually be right — escalates to a
      premium API (Claude Sonnet/Opus). Escalation happens when the local
      model returns low confidence, when the task declares itself as
      reasoning-heavy, or when the local model runs out of context.
    </p>
    <p>
      <strong>The math on a typical founder day:</strong> 500 routine
      runs/day (github-review three times × ~30 PRs, inbox-triage hourly
      × ~15 emails, day-brief once, evening-shutdown once, ad-hoc
      <code>vinos-ai</code> calls). <strong>20% escalate to Claude</strong>
      at roughly <strong>$0.03 per premium call</strong> average
      (Sonnet input+output, ~2k in / ~500 out). That's
      <strong>$90/mo</strong> in Claude
      spend. If you routed everything to Claude —
      <strong>$450/mo</strong>.
      <strong class="accent">Saved: ~$360/mo</strong>
      per user, or roughly a MacBook every eighteen months.
    </p>
  </div>
</section>

<section class="audience-section">
  <h2>Configure the router</h2>
  <p style="max-width: 62ch; color: var(--color-ink-2); font-size: var(--text-md); line-height: 1.55; margin-bottom: var(--space-lg);">
    Drop <code>route = "auto"</code> into the routine's <code>[agent]</code>
    block and declare a <code>local_model</code>, a <code>premium_model</code>,
    and an escalation policy. That's it.
  </p>
<pre><code class="language-toml">[agent]
route         = "auto"                # anthropic | ollama | auto
local_model   = "qwen2.5:7b"          # what runs the 80% case
premium_model = "claude-sonnet-4-6"   # what runs the escalated 20%

[agent.escalation]
on_low_confidence   = true      # local returns "unsure" or confidence &lt; threshold
on_reasoning_task   = true      # prompt tagged as reasoning-heavy
on_context_overflow = true      # local hit its context limit
max_escalations_per_run = 3     # cap runaway loops
</code></pre>
  <p class="small-print" style="margin-top: var(--space-md);">
    Set <code>route = "ollama"</code> to force local-only (zero API spend).
    Set <code>route = "anthropic"</code> when the routine's whole reason
    for being is high-stakes judgment. Full field reference:
    <a href="/spec/">routine spec</a>.
  </p>
</section>

<section class="audience-section">
  <h2>Just tell me what to install.</h2>
  <p style="max-width: 60ch; color: var(--color-ink-2); font-size: var(--text-md); line-height: 1.55; margin-bottom: var(--space-lg);">
    Pick the row that matches your machine. Two commands and you're set for daily use — general chat + coding assistant.
  </p>
  <div class="model-quickstart">
    <div class="model-quickstart-row">
      <span class="model-quickstart-tag">4 GB RAM</span>
      <code>ollama pull qwen2.5:1.5b</code>
    </div>
    <div class="model-quickstart-row">
      <span class="model-quickstart-tag">8 GB RAM</span>
      <code>ollama pull llama3.2:3b &amp;&amp; ollama pull qwen2.5-coder:3b</code>
    </div>
    <div class="model-quickstart-row highlight">
      <span class="model-quickstart-tag">16 GB RAM · recommended</span>
      <code>ollama pull llama3.2:8b &amp;&amp; ollama pull qwen2.5-coder:7b</code>
    </div>
    <div class="model-quickstart-row">
      <span class="model-quickstart-tag">32 GB + GPU</span>
      <code>ollama pull qwen2.5:32b &amp;&amp; ollama pull qwen2.5-coder:32b</code>
    </div>
    <div class="model-quickstart-row">
      <span class="model-quickstart-tag">64+ GB · workstation</span>
      <code>ollama pull llama3.3:70b</code>
    </div>
    <div class="model-quickstart-row">
      <span class="model-quickstart-tag">100+ GB · fat server</span>
      <code>ollama pull deepseek-v3</code>
    </div>
  </div>
  <p style="max-width: 60ch; color: var(--color-muted); font-size: var(--text-sm); line-height: 1.55; margin-top: var(--space-md); font-family: var(--font-mono);">
    Then: <kbd>Super</kbd>+<kbd>A</kbd> opens chat with your default model. Or <code>vinos-ai chat</code> in any terminal.
  </p>
</section>

<section class="audience-section">
  <h2>How much are you saving?</h2>
  <p style="max-width: 60ch; color: var(--color-ink-2); font-size: var(--text-md); line-height: 1.55;">
    Local marginal cost per prompt: <strong>$0</strong> (your electricity — call it a rounding error).
    The "cost vs cloud" column on each table below compares against the nearest frontier equivalent — API rates for reference:
  </p>
  <div class="model-usage" style="margin-top: var(--space-md);">
    <div class="model-usage-row">
      <span class="model-usage-cmd">Claude Opus 4.7</span>
      <span class="model-usage-desc">$15/M in · $75/M out — deep reasoning</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">Claude Sonnet 4.6</span>
      <span class="model-usage-desc">$3/M in · $15/M out — general purpose</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">Claude Haiku 4.5</span>
      <span class="model-usage-desc">$1/M in · $5/M out — fast + cheap</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">GPT-4 class</span>
      <span class="model-usage-desc">roughly comparable to Opus</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">text-embedding-3</span>
      <span class="model-usage-desc">$0.02/M — for context vs Ollama's $0</span>
    </div>
  </div>
  <p style="max-width: 60ch; color: var(--color-muted); font-size: var(--text-sm); line-height: 1.55; margin-top: var(--space-md); font-family: var(--font-mono);">
    One heavy user's typical week: <span style="color: var(--color-accent);">~$150/mo saved</span> when 80% of prompts route local.
  </p>
</section>

<nav class="model-catnav" aria-label="Model categories">
  <span class="model-catnav-label">Jump to:</span>
  <a href="#general">General &amp; instruct</a>
  <a href="#coding">Coding</a>
  <a href="#reasoning">Reasoning</a>
  <a href="#small">Small / edge</a>
  <a href="#vision">Vision</a>
  <a href="#embeddings">Embeddings</a>
  <a href="#function-calling">Function-calling</a>
  <a href="#moe">MoE</a>
  <a href="#uncensored">Uncensored</a>
  <a href="#how-to-use">How to use</a>
</nav>

<section class="audience-section" id="general">
  <h2>General chat &amp; instruct</h2>
  <p class="model-cat-lede">Day-to-day <kbd>Super</kbd>+<kbd>A</kbd> chat, drafting, summarizing, extraction, structured tasks.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Sizes</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>Hunyuan Large</strong> · Tencent<br><a href="https://ollama.com/library/hunyuan" target="_blank" rel="noopener">ollama.com</a></td><td>7B · 389B (MoE, ~52B active)<br><span class="model-ctx">256k ctx · Nov 2024</span></td><td class="model-score"><span class="model-score-val">88.4</span><span class="model-score-bench">MMLU · 389B MoE</span></td><td>Tencent's open MoE flagship. Beats Llama 3.3 70B and Claude Sonnet on multiple benches. Massive but only 52B active per token. <span class="model-license-note">Tencent Hunyuan license</span></td><td>52B active → 32 GB · 389B → 220 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.20 / prompt (Opus)</span></td><td><code>ollama pull hunyuan</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>Llama 3.3</strong> · Meta<br><a href="https://ollama.com/library/llama3.3" target="_blank" rel="noopener">ollama.com</a></td><td>70B<br><span class="model-ctx">128k ctx · Dec 2024</span></td><td class="model-score"><span class="model-score-val">86.0</span><span class="model-score-bench">MMLU · 70B</span><span class="model-score-secondary">68.9 MMLU Pro</span></td><td>Top-tier open reasoning. GPT-4-class on many benches. <span class="model-license-note">Llama 3.3 license</span></td><td>70B → 40 GB</td><td>$0 <span class="model-cost-vs">vs ~$1.65 / 100-pg summary (Opus)</span></td><td><code>ollama pull llama3.3</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>Llama 4 Maverick</strong> · Meta<br><a href="https://ollama.com/library/llama4" target="_blank" rel="noopener">ollama.com</a></td><td>400B params · 17B active (MoE)<br><span class="model-ctx">1M ctx · Apr 2026</span></td><td class="model-score"><span class="model-score-val">85.5</span><span class="model-score-bench">MMLU · MoE</span><span class="model-score-secondary">80.5 MMLU Pro</span></td><td>Meta's flagship native-multimodal MoE. Datacenter class. <span class="model-license-note">Llama 4 license</span></td><td>400B → ~200 GB</td><td>$0 <span class="model-cost-vs">vs GPT-4-class API rates</span></td><td><code>ollama pull llama4:maverick</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>Phi 4</strong> · Microsoft<br><a href="https://ollama.com/library/phi4" target="_blank" rel="noopener">ollama.com</a></td><td>14B<br><span class="model-ctx">16k ctx · Dec 2024</span></td><td class="model-score"><span class="model-score-val">84.8</span><span class="model-score-bench">MMLU</span></td><td>Punches above weight class. Reasoning-focused training. <span class="model-license-note">MIT</span></td><td>14B → 10 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.20 / prompt (Opus)</span></td><td><code>ollama pull phi4</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>Mistral Large</strong> · Mistral<br><a href="https://ollama.com/library/mistral-large" target="_blank" rel="noopener">ollama.com</a></td><td>123B<br><span class="model-ctx">128k ctx · Jul 2024</span></td><td class="model-score"><span class="model-score-val">84.0</span><span class="model-score-bench">MMLU</span></td><td>Mistral's flagship. For serious hardware. <span class="model-license-note">Mistral Research (non-commercial)</span></td><td>123B → 68 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.20 / prompt (Opus)</span></td><td><code>ollama pull mistral-large</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>Qwen 3</strong> · Alibaba<br><a href="https://ollama.com/library/qwen3" target="_blank" rel="noopener">ollama.com</a></td><td>0.6B · 1.7B · 4B · 8B · 14B · 30B · 32B · 235B<br><span class="model-ctx">40k–256k ctx · May 2025</span></td><td class="model-score"><span class="model-score-val">83.3</span><span class="model-score-bench">MMLU · 32B</span></td><td>Latest Qwen. Hybrid thinking/non-thinking modes. Widest size range on Ollama. <span class="model-license-note">Apache 2.0</span></td><td>8B → 6 GB · 32B → 20 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.05 / prompt (Sonnet)</span></td><td><code>ollama pull qwen3</code></td></tr>
        <tr><td><span class="model-rank">7</span><strong>Qwen 2.5</strong> · Alibaba<br><a href="https://ollama.com/library/qwen2.5" target="_blank" rel="noopener">ollama.com</a></td><td>0.5B · 1.5B · 3B · 7B · 14B · 32B · 72B<br><span class="model-ctx">128k ctx · Sep 2024</span></td><td class="model-score"><span class="model-score-val">83.3</span><span class="model-score-bench">MMLU · 32B</span></td><td>Sharp on structured output (JSON, tables). Best multilingual. Widest size range. <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB · 32B → 20 GB</td><td>$0 <span class="model-cost-vs">vs ~$1.50 / 500-email extract (Opus)</span></td><td><code>ollama pull qwen2.5:7b</code></td></tr>
        <tr><td><span class="model-rank">8</span><strong>GLM-4</strong> · Zhipu AI<br><a href="https://ollama.com/library/glm4" target="_blank" rel="noopener">ollama.com</a></td><td>9B · 32B · 100B<br><span class="model-ctx">128k ctx · Jun 2024</span></td><td class="model-score"><span class="model-score-val">81.9</span><span class="model-score-bench">MMLU · 32B</span></td><td>Zhipu AI's flagship. Sharp on Chinese + English. Widely deployed in Asia; competitive with Claude Sonnet on multiple benches. <span class="model-license-note">GLM-4 open license</span></td><td>32B → 20 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.05 / prompt (Sonnet)</span></td><td><code>ollama pull glm4</code></td></tr>
        <tr><td><span class="model-rank">9</span><strong>Llama 4 Scout</strong> · Meta<br><a href="https://ollama.com/library/llama4" target="_blank" rel="noopener">ollama.com</a></td><td>109B params · 17B active (MoE)<br><span class="model-ctx">10M ctx · Apr 2026</span></td><td class="model-score"><span class="model-score-val">79.6</span><span class="model-score-bench">MMLU · MoE</span></td><td>Massive-context multimodal at 17B active — accessible for local rigs. <span class="model-license-note">Llama 4 license</span></td><td>109B → ~50 GB (Q4)</td><td>$0 <span class="model-cost-vs">vs long-context Sonnet</span></td><td><code>ollama pull llama4:scout</code></td></tr>
        <tr><td><span class="model-rank">10</span><strong>Gemma 3</strong> · Google<br><a href="https://ollama.com/library/gemma3" target="_blank" rel="noopener">ollama.com</a></td><td>1B · 4B · 12B · 27B<br><span class="model-ctx">128k ctx · Mar 2025</span></td><td class="model-score"><span class="model-score-val">78.6</span><span class="model-score-bench">MMLU · 27B</span></td><td>Newer Gemma. Multimodal-capable at higher sizes. <span class="model-license-note">Gemma terms</span></td><td>12B → 8 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.05 / prompt (Sonnet)</span></td><td><code>ollama pull gemma3</code></td></tr>
        <tr><td><span class="model-rank">11</span><strong>Mixtral 8x22B</strong> · Mistral<br><a href="https://ollama.com/library/mixtral" target="_blank" rel="noopener">ollama.com</a></td><td>141B params · ~39B active<br><span class="model-ctx">64k ctx · Apr 2024</span></td><td class="model-score"><span class="model-score-val">77.3</span><span class="model-score-bench">MMLU</span></td><td>Larger Mixtral MoE. Excellent general purpose for beefy hardware. <span class="model-license-note">Apache 2.0</span></td><td>141B → 80 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.20 / prompt (Opus)</span></td><td><code>ollama pull mixtral:8x22b</code></td></tr>
        <tr><td><span class="model-rank">12</span><strong>Yi</strong> · 01.AI<br><a href="https://ollama.com/library/yi" target="_blank" rel="noopener">ollama.com</a></td><td>6B · 9B · 34B<br><span class="model-ctx">200k ctx · Jan 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">76.3</span><span class="model-score-bench">MMLU · 34B</span></td><td>Chinese-first with strong bilingual EN. <span class="model-license-note">Apache 2.0</span></td><td>9B → 7 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.03 / prompt (Sonnet)</span></td><td><code>ollama pull yi</code></td></tr>
        <tr><td><span class="model-rank">13</span><strong>Command R+</strong> · Cohere<br><a href="https://ollama.com/library/command-r-plus" target="_blank" rel="noopener">ollama.com</a></td><td>104B<br><span class="model-ctx">128k ctx · Aug 2024</span></td><td class="model-score"><span class="model-score-val">75.7</span><span class="model-score-bench">MMLU</span></td><td>Cohere flagship. Enterprise-tuned. <span class="model-license-note">CC-BY-NC 4.0</span></td><td>104B → 60 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.25 / RAG call (Opus)</span></td><td><code>ollama pull command-r-plus</code></td></tr>
        <tr><td><span class="model-rank">14</span><strong>Gemma 2</strong> · Google<br><a href="https://ollama.com/library/gemma2" target="_blank" rel="noopener">ollama.com</a></td><td>2B · 9B · 27B<br><span class="model-ctx">8k ctx · Jun 2024</span></td><td class="model-score"><span class="model-score-val">75.2</span><span class="model-score-bench">MMLU · 27B</span></td><td>Strong reasoning benches per parameter. Google Research lineage. <span class="model-license-note">Gemma terms</span></td><td>27B → 16 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.03 / prompt (Sonnet)</span></td><td><code>ollama pull gemma2:27b</code></td></tr>
        <tr><td><span class="model-rank">15</span><strong>DBRX</strong> · Databricks<br><a href="https://ollama.com/library/dbrx" target="_blank" rel="noopener">ollama.com</a></td><td>132B params · 36B active (MoE)<br><span class="model-ctx">32k ctx · Mar 2024</span></td><td class="model-score"><span class="model-score-val">73.7</span><span class="model-score-bench">MMLU</span></td><td>Databricks fine-grained MoE. Enterprise-grade + Apache-safe. <span class="model-license-note">DBRX Open Model License</span></td><td>132B → 74 GB</td><td>$0 <span class="model-cost-vs">vs enterprise API rates</span></td><td><code>ollama pull dbrx</code></td></tr>
        <tr><td><span class="model-rank">16</span><strong>Falcon 3</strong> · TII<br><a href="https://ollama.com/library/falcon3" target="_blank" rel="noopener">ollama.com</a></td><td>1B · 3B · 7B · 10B<br><span class="model-ctx">32k ctx · Dec 2024</span></td><td class="model-score"><span class="model-score-val">73.1</span><span class="model-score-bench">MMLU · 10B</span></td><td>UAE's Falcon. Sovereign-friendly. 10B leads sub-13B knowledge tasks. <span class="model-license-note">TII Falcon 2.0</span></td><td>10B → 7 GB</td><td>$0 <span class="model-cost-vs">vs cloud</span></td><td><code>ollama pull falcon3</code></td></tr>
        <tr><td><span class="model-rank">17</span><strong>Mistral Small</strong> · Mistral<br><a href="https://ollama.com/library/mistral-small" target="_blank" rel="noopener">ollama.com</a></td><td>22B<br><span class="model-ctx">32k ctx · Sep 2024</span></td><td class="model-score"><span class="model-score-val">72.9</span><span class="model-score-bench">MMLU</span></td><td>Mid-tier from Mistral. Balances speed + quality. <span class="model-license-note">Mistral Research (non-commercial)</span></td><td>22B → 14 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.05 / prompt (Sonnet)</span></td><td><code>ollama pull mistral-small</code></td></tr>
        <tr><td><span class="model-rank">18</span><strong>InternLM 2.5</strong><br><a href="https://ollama.com/library/internlm2" target="_blank" rel="noopener">ollama.com</a></td><td>1.8B · 7B · 20B<br><span class="model-ctx">1M ctx · Jul 2024</span></td><td class="model-score"><span class="model-score-val">72.8</span><span class="model-score-bench">MMLU · 7B</span></td><td>Shanghai AI Lab. Long context (1M tokens at 7B). <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$1+ / 1M-context call (Sonnet)</span></td><td><code>ollama pull internlm2</code></td></tr>
        <tr><td><span class="model-rank">19</span><strong>Gemma 2 9B</strong> · Google<br><a href="https://ollama.com/library/gemma2" target="_blank" rel="noopener">ollama.com</a></td><td>9B<br><span class="model-ctx">8k ctx · Jun 2024</span></td><td class="model-score"><span class="model-score-val">71.3</span><span class="model-score-bench">MMLU · 9B</span></td><td>Sweet-spot Gemma 2 for consumer boxes. <span class="model-license-note">Gemma terms</span></td><td>9B → 7 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.03 / prompt (Sonnet)</span></td><td><code>ollama pull gemma2:9b</code></td></tr>
        <tr><td><span class="model-rank">20</span><strong>Llama 3.1</strong> · Meta<br><a href="https://ollama.com/library/llama3.1" target="_blank" rel="noopener">ollama.com</a></td><td>8B · 70B · 405B<br><span class="model-ctx">128k ctx · Jul 2024</span></td><td class="model-score"><span class="model-score-val">69.4</span><span class="model-score-bench">MMLU · 8B</span></td><td>The 8B daily driver. Still the strongest small default for most users. <span class="model-license-note">Llama 3.1 license</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.20 / refactor (Opus)</span></td><td><code>ollama pull llama3.1:8b</code></td></tr>
        <tr><td><span class="model-rank">21</span><strong>Command R</strong> · Cohere<br><a href="https://ollama.com/library/command-r" target="_blank" rel="noopener">ollama.com</a></td><td>35B · 08-2024<br><span class="model-ctx">128k ctx · Aug 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">68.2</span><span class="model-score-bench">MMLU</span></td><td>Tuned for RAG + tool-use. Long context. <span class="model-license-note">CC-BY-NC 4.0</span></td><td>35B → 22 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.15 / RAG call (Sonnet)</span></td><td><code>ollama pull command-r</code></td></tr>
        <tr><td><span class="model-rank">22</span><strong>Mistral Nemo</strong> · Mistral<br><a href="https://ollama.com/library/mistral-nemo" target="_blank" rel="noopener">ollama.com</a></td><td>12B<br><span class="model-ctx">128k ctx · Jul 2024</span></td><td class="model-score"><span class="model-score-val">68.0</span><span class="model-score-bench">MMLU</span></td><td>128k context window. Long-document work. <span class="model-license-note">Apache 2.0</span></td><td>12B → 8 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.80 / long-context prompt (Sonnet)</span></td><td><code>ollama pull mistral-nemo</code></td></tr>
        <tr><td><span class="model-rank">23</span><strong>Nous Hermes 3</strong><br><a href="https://ollama.com/library/hermes3" target="_blank" rel="noopener">ollama.com</a></td><td>3B · 8B · 70B · 405B<br><span class="model-ctx">128k ctx · Aug 2024</span></td><td class="model-score"><span class="model-score-val">68.0</span><span class="model-score-bench">MMLU · 8B</span></td><td>Nous Research fine-tunes of Llama. Function-calling + reasoning tuned. <span class="model-license-note">Llama 3.x terms</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.10 / tool call (Sonnet)</span></td><td><code>ollama pull hermes3</code></td></tr>
        <tr><td><span class="model-rank">24</span><strong>Solar</strong> · Upstage<br><a href="https://ollama.com/library/solar" target="_blank" rel="noopener">ollama.com</a></td><td>10.7B<br><span class="model-ctx">4k ctx · Feb 2024</span></td><td class="model-score"><span class="model-score-val">65.5</span><span class="model-score-bench">MMLU</span></td><td>Upstage's depth-upscaled Llama. Strong benches for its size. <span class="model-license-note">Apache 2.0</span></td><td>10.7B → 8 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.04 / prompt (Sonnet)</span></td><td><code>ollama pull solar</code></td></tr>
        <tr><td><span class="model-rank">25</span><strong>OpenChat</strong><br><a href="https://ollama.com/library/openchat" target="_blank" rel="noopener">ollama.com</a></td><td>7B<br><span class="model-ctx">8k ctx · Jan 2024</span></td><td class="model-score"><span class="model-score-val">64.5</span><span class="model-score-bench">MMLU</span></td><td>C-RLFT fine-tune. Community-loved conversational quality. <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.02 / prompt (Haiku)</span></td><td><code>ollama pull openchat</code></td></tr>
        <tr><td><span class="model-rank">26</span><strong>Mistral 7B</strong> · Mistral<br><a href="https://ollama.com/library/mistral" target="_blank" rel="noopener">ollama.com</a></td><td>7B<br><span class="model-ctx">32k ctx · May 2024</span></td><td class="model-score"><span class="model-score-val">62.5</span><span class="model-score-bench">MMLU</span></td><td>Classic Mistral. Still a strong lightweight baseline. <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.03 / prompt (Sonnet)</span></td><td><code>ollama pull mistral</code></td></tr>
        <tr><td><span class="model-rank">27</span><strong>Aya Expanse</strong> · Cohere<br><a href="https://ollama.com/library/aya-expanse" target="_blank" rel="noopener">ollama.com</a></td><td>8B · 32B<br><span class="model-ctx">128k ctx · Oct 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">62.2</span><span class="model-score-bench">MMLU · 8B</span></td><td>23 languages. Best truly-multilingual open model. <span class="model-license-note">CC-BY-NC 4.0</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.05 / translation (Sonnet)</span></td><td><code>ollama pull aya-expanse</code></td></tr>
        <tr><td><span class="model-rank">28</span><strong>Zephyr</strong> · HuggingFace<br><a href="https://ollama.com/library/zephyr" target="_blank" rel="noopener">ollama.com</a></td><td>7B · 141B<br><span class="model-ctx">32k ctx · Nov 2023</span></td><td class="model-score"><span class="model-score-val">61.1</span><span class="model-score-bench">MMLU</span></td><td>HuggingFace's Mistral fine-tune. Strong for chat. <span class="model-license-note">MIT</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.02 / prompt (Haiku)</span></td><td><code>ollama pull zephyr</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="coding">
  <h2>Coding assistants</h2>
  <p class="model-cat-lede">Wire into <code>vinos-ai code</code> or your editor. Fill-in-the-middle, refactor, explain.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Sizes</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>Qwen 2.5 Coder</strong> · Alibaba<br><a href="https://ollama.com/library/qwen2.5-coder" target="_blank" rel="noopener">ollama.com</a></td><td>0.5B · 1.5B · 3B · 7B · 14B · 32B<br><span class="model-ctx">128k ctx · Nov 2024</span></td><td class="model-score"><span class="model-score-val">92.7</span><span class="model-score-bench">HumanEval · 32B</span><span class="model-score-secondary">90.2 MBPP</span></td><td>Top open coding model. 32B beats Claude 3.5 Sonnet on HumanEval. Recommended default. <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB · 32B → 20 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.20 / typical refactor (Opus)</span></td><td><code>ollama pull qwen2.5-coder:7b</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>DeepSeek Coder V2</strong><br><a href="https://ollama.com/library/deepseek-coder-v2" target="_blank" rel="noopener">ollama.com</a></td><td>16B (MoE) · 236B<br><span class="model-ctx">128k ctx · Jun 2024</span></td><td class="model-score"><span class="model-score-val">90.2</span><span class="model-score-bench">HumanEval · 236B</span><span class="model-score-secondary">76.2 MBPP</span></td><td>MoE — activates ~2.4B/token (Lite) or ~21B (236B). Great on larger codebases. <span class="model-license-note">DeepSeek license</span></td><td>16B → 10 GB</td><td>$0 <span class="model-cost-vs">vs ~$1+ / complex refactor (Opus)</span></td><td><code>ollama pull deepseek-coder-v2</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>Codestral</strong> · Mistral<br><a href="https://ollama.com/library/codestral" target="_blank" rel="noopener">ollama.com</a></td><td>22B<br><span class="model-ctx">32k ctx · May 2024</span></td><td class="model-score"><span class="model-score-val">81.1</span><span class="model-score-bench">HumanEval</span><span class="model-score-secondary">78.2 MBPP</span></td><td>Solid completion + fill-in-the-middle. 32k context. <span class="model-license-note">Mistral Research (non-commercial)</span></td><td>22B → 14 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.15 / completion (Sonnet)</span></td><td><code>ollama pull codestral</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>DeepSeek Coder</strong><br><a href="https://ollama.com/library/deepseek-coder" target="_blank" rel="noopener">ollama.com</a></td><td>1.3B · 6.7B · 33B<br><span class="model-ctx">16k ctx · Nov 2023</span></td><td class="model-score"><span class="model-score-val">79.3</span><span class="model-score-bench">HumanEval · 33B</span></td><td>Predecessor to V2. Still solid; different license terms. <span class="model-license-note">DeepSeek license</span></td><td>6.7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.15 / refactor (Sonnet)</span></td><td><code>ollama pull deepseek-coder</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>Magicoder</strong><br><a href="https://ollama.com/library/magicoder" target="_blank" rel="noopener">ollama.com</a></td><td>6.7B · 7B<br><span class="model-ctx">4k ctx · Dec 2023</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">76.8</span><span class="model-score-bench">HumanEval</span></td><td>OSS-Instruct fine-tune. Very community-loved. <span class="model-license-note">CC-BY-4.0</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.10 / prompt (Sonnet)</span></td><td><code>ollama pull magicoder</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>Codestral Mamba</strong> · Mistral<br><a href="https://ollama.com/library/codestral-mamba" target="_blank" rel="noopener">ollama.com</a></td><td>7B<br><span class="model-ctx">256k ctx · Jul 2024</span></td><td class="model-score"><span class="model-score-val">75.0</span><span class="model-score-bench">HumanEval</span></td><td>Mamba architecture — infinite context, fast inference. <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.15 / long-file completion (Sonnet)</span></td><td><code>ollama pull codestral-mamba</code></td></tr>
        <tr><td><span class="model-rank">7</span><strong>WizardCoder</strong><br><a href="https://ollama.com/library/wizardcoder" target="_blank" rel="noopener">ollama.com</a></td><td>Python variants: 7B · 13B · 33B<br><span class="model-ctx">16k ctx · Aug 2023</span></td><td class="model-score"><span class="model-score-val">73.2</span><span class="model-score-bench">HumanEval · 34B</span></td><td>Evol-Instruct fine-tune. Historical footprint but still useful. <span class="model-license-note">Llama 2 terms</span></td><td>13B → 9 GB</td><td>$0 <span class="model-cost-vs">vs cloud</span></td><td><code>ollama pull wizardcoder</code></td></tr>
        <tr><td><span class="model-rank">8</span><strong>StarCoder2</strong> · BigCode<br><a href="https://ollama.com/library/starcoder2" target="_blank" rel="noopener">ollama.com</a></td><td>3B · 7B · 15B<br><span class="model-ctx">16k ctx · Feb 2024</span></td><td class="model-score"><span class="model-score-val">72.6</span><span class="model-score-bench">HumanEval · 15B-Instruct</span></td><td>Trained on The Stack v2. Strong on obscure languages. <span class="model-license-note">BigCode OpenRAIL-M</span></td><td>15B → 10 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.10 / language port (Sonnet)</span></td><td><code>ollama pull starcoder2:15b</code></td></tr>
        <tr><td><span class="model-rank">9</span><strong>Granite Code</strong> · IBM<br><a href="https://ollama.com/library/granite-code" target="_blank" rel="noopener">ollama.com</a></td><td>3B · 8B · 20B · 34B<br><span class="model-ctx">128k ctx · May 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">53.0</span><span class="model-score-bench">HumanEval · 8B</span></td><td>IBM's enterprise-grade code model. Apache 2.0 = commercial-safe. <span class="model-license-note">Apache 2.0</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">vs enterprise API rates</span></td><td><code>ollama pull granite-code:8b</code></td></tr>
        <tr><td><span class="model-rank">10</span><strong>CodeLlama</strong> · Meta<br><a href="https://ollama.com/library/codellama" target="_blank" rel="noopener">ollama.com</a></td><td>7B · 13B · 34B · 70B<br><span class="model-ctx">16k ctx · Aug 2023</span></td><td class="model-score"><span class="model-score-val">48.8</span><span class="model-score-bench">HumanEval · 34B</span></td><td>Older but battle-tested. Python-specialized variants exist. <span class="model-license-note">Llama 2 license</span></td><td>13B → 9 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.20 / refactor (Opus)</span></td><td><code>ollama pull codellama:13b</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="reasoning">
  <h2>Reasoning specialists</h2>
  <p class="model-cat-lede">Chain-of-thought native. Slower per token, deeper answers. Great for math, planning, multi-step problems.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Sizes</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>DeepSeek R1</strong><br><a href="https://ollama.com/library/deepseek-r1" target="_blank" rel="noopener">ollama.com</a></td><td>1.5B · 7B · 8B · 14B · 32B · 70B · 671B<br><span class="model-ctx">128k ctx · Jan 2025</span></td><td class="model-score"><span class="model-score-val">97.3</span><span class="model-score-bench">MATH-500 · 671B</span><span class="model-score-secondary">79.8 AIME 2024</span></td><td>DeepSeek's reasoning flagship + distills. Best math/code chain-of-thought open model. <span class="model-license-note">MIT</span></td><td>7B → 5 GB · 671B → 400+ GB</td><td>$0 <span class="model-cost-vs">vs ~$5+ / reasoning task (Opus)</span></td><td><code>ollama pull deepseek-r1:7b</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>DeepSeek R1 Distill Qwen 32B</strong><br><a href="https://ollama.com/library/deepseek-r1" target="_blank" rel="noopener">ollama.com</a></td><td>32B<br><span class="model-ctx">128k ctx · Jan 2025</span></td><td class="model-score"><span class="model-score-val">94.3</span><span class="model-score-bench">MATH-500 · 32B distill</span><span class="model-score-secondary">72.6 AIME 2024</span></td><td>The best reasoning-per-GB ratio. Fits on a single 24GB card. <span class="model-license-note">MIT</span></td><td>32B → 20 GB</td><td>$0 <span class="model-cost-vs">vs ~$5+ / reasoning task (Opus)</span></td><td><code>ollama pull deepseek-r1:32b</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>QwQ</strong> · Alibaba<br><a href="https://ollama.com/library/qwq" target="_blank" rel="noopener">ollama.com</a></td><td>32B<br><span class="model-ctx">32k ctx · Nov 2024</span></td><td class="model-score"><span class="model-score-val">90.6</span><span class="model-score-bench">MATH-500</span><span class="model-score-secondary">50.0 AIME</span></td><td>Qwen's reasoning-tuned variant. Chain-of-thought native. <span class="model-license-note">Apache 2.0</span></td><td>32B → 20 GB</td><td>$0 <span class="model-cost-vs">vs ~$5+ / deep task (Opus)</span></td><td><code>ollama pull qwq</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>DeepSeek V3.1</strong><br><a href="https://ollama.com/library/deepseek-v3.1" target="_blank" rel="noopener">ollama.com</a></td><td>671B (MoE)<br><span class="model-ctx">160k ctx · Aug 2025</span></td><td class="model-score"><span class="model-score-val">90.4</span><span class="model-score-bench">MATH-500</span></td><td>V3 refresh — hybrid thinking/non-thinking mode. Fat-server only. <span class="model-license-note">DeepSeek license</span></td><td>671B → ~400 GB</td><td>$0 <span class="model-cost-vs">vs GPT-4-class API rates</span></td><td><code>ollama pull deepseek-v3.1</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>DeepSeek V3</strong><br><a href="https://ollama.com/library/deepseek-v3" target="_blank" rel="noopener">ollama.com</a></td><td>685B (MoE)<br><span class="model-ctx">128k ctx · Dec 2024</span></td><td class="model-score"><span class="model-score-val">90.2</span><span class="model-score-bench">MATH-500</span></td><td>DeepSeek's MoE. Extremely capable but needs a fat server. <span class="model-license-note">DeepSeek license</span></td><td>685B → ~400 GB (MoE)</td><td>$0 <span class="model-cost-vs">vs GPT-4-class API rates</span></td><td><code>ollama pull deepseek-v3</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>Reflection Llama</strong><br><a href="https://ollama.com/library/reflection" target="_blank" rel="noopener">ollama.com</a></td><td>70B<br><span class="model-ctx">8k ctx · Sep 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">89.9</span><span class="model-score-bench">GSM8K</span></td><td>Self-correcting reflection tokens. Numbers were disputed at launch — treat with caution. <span class="model-license-note">Llama 3.1 terms</span></td><td>70B → 40 GB</td><td>$0 <span class="model-cost-vs">vs ~$5+ / uncertain task (Opus)</span></td><td><code>ollama pull reflection</code></td></tr>
        <tr><td><span class="model-rank">7</span><strong>Marco-o1</strong> · Alibaba<br><a href="https://ollama.com/library/marco-o1" target="_blank" rel="noopener">ollama.com</a></td><td>7B<br><span class="model-ctx">32k ctx · Nov 2024</span></td><td class="model-score"><span class="model-score-val">82.5</span><span class="model-score-bench">MGSM</span></td><td>Alibaba's OpenAI-o1-style reasoning fine-tune. Compact + strong on math. <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$3+ / math problem (Opus)</span></td><td><code>ollama pull marco-o1</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="small">
  <h2>Small / edge (≤ 4B parameters)</h2>
  <p class="model-cat-lede">Old laptops, low-RAM boxes, background daemons, edge devices. Instant streaming, modest capability.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Sizes</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>Phi 3.5 mini</strong></td><td>3.8B<br><span class="model-ctx">128k ctx · Aug 2024</span></td><td class="model-score"><span class="model-score-val">69.0</span><span class="model-score-bench">MMLU</span></td><td>Quality-per-parameter leader. Solid at code + reasoning. <span class="model-license-note">MIT</span></td><td>3.8B → 3 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.005 / prompt (Haiku)</span></td><td><code>ollama pull phi3.5</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>Llama 3.2</strong> · Meta</td><td>1B · 3B<br><span class="model-ctx">128k ctx · Sep 2024</span></td><td class="model-score"><span class="model-score-val">63.4</span><span class="model-score-bench">MMLU · 3B</span></td><td>Instant streaming for autocomplete, short-form chat. <span class="model-license-note">Llama 3.2 license</span></td><td>3B → 3 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.005 / prompt (Haiku)</span></td><td><code>ollama pull llama3.2:3b</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>MiniCPM 3</strong></td><td>4B<br><span class="model-ctx">32k ctx · Sep 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">62.6</span><span class="model-score-bench">MMLU</span></td><td>Runs on mobile. Chinese lightweight lineage, strong at its size. <span class="model-license-note">Apache 2.0</span></td><td>4B → 3 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.005 / prompt (Haiku)</span></td><td><code>ollama pull minicpm3</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>Qwen 2.5 1.5B</strong></td><td>0.5B · 1.5B<br><span class="model-ctx">128k ctx · Sep 2024</span></td><td class="model-score"><span class="model-score-val">60.9</span><span class="model-score-bench">MMLU · 1.5B</span></td><td>Runs on a Raspberry Pi 5 or a 2015 laptop. <span class="model-license-note">Apache 2.0</span></td><td>1.5B → 2 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.005 / prompt (Haiku)</span></td><td><code>ollama pull qwen2.5:1.5b</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>Falcon 3 (small)</strong></td><td>1B · 3B<br><span class="model-ctx">32k ctx · Dec 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">56.0</span><span class="model-score-bench">MMLU · 3B</span></td><td>TII's small Falcons. Sovereign-friendly. <span class="model-license-note">TII Falcon 2.0</span></td><td>3B → 3 GB</td><td>$0 <span class="model-cost-vs">vs cloud</span></td><td><code>ollama pull falcon3:3b</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>Gemma 2 2B</strong></td><td>2B<br><span class="model-ctx">8k ctx · Jun 2024</span></td><td class="model-score"><span class="model-score-val">52.2</span><span class="model-score-bench">MMLU</span></td><td>Efficient, strong per-parameter reasoning. <span class="model-license-note">Gemma terms</span></td><td>2B → 2 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.005 / prompt (Haiku)</span></td><td><code>ollama pull gemma2:2b</code></td></tr>
        <tr><td><span class="model-rank">7</span><strong>SmolLM 2</strong> · HuggingFace<br><a href="https://ollama.com/library/smollm2" target="_blank" rel="noopener">ollama.com</a></td><td>135M · 360M · 1.7B<br><span class="model-ctx">8k ctx · Oct 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">49.8</span><span class="model-score-bench">MMLU · 1.7B</span></td><td>HuggingFace's tiny series. Sub-billion sizes for embedded work. <span class="model-license-note">Apache 2.0</span></td><td>1.7B → 2 GB</td><td>$0 <span class="model-cost-vs">vs edge API rates</span></td><td><code>ollama pull smollm2</code></td></tr>
        <tr><td><span class="model-rank">8</span><strong>Stable LM 2</strong><br><a href="https://ollama.com/library/stablelm2" target="_blank" rel="noopener">ollama.com</a></td><td>1.6B · 12B<br><span class="model-ctx">4k ctx · Feb 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">47.1</span><span class="model-score-bench">MMLU · 1.6B</span></td><td>Stability AI's LM series. 1.6B for edge, 12B for mid-tier. <span class="model-license-note">Stability commercial terms</span></td><td>1.6B → 2 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.005 / prompt (Haiku)</span></td><td><code>ollama pull stablelm2</code></td></tr>
        <tr><td><span class="model-rank">9</span><strong>TinyLlama</strong><br><a href="https://ollama.com/library/tinyllama" target="_blank" rel="noopener">ollama.com</a></td><td>1.1B<br><span class="model-ctx">2k ctx · Jan 2024</span></td><td class="model-score"><span class="model-score-val">25.3</span><span class="model-score-bench">MMLU</span></td><td>Pre-trained on 3T tokens. Tiny but well-trained. <span class="model-license-note">Apache 2.0</span></td><td>1.1B → 2 GB</td><td>$0 <span class="model-cost-vs">vs edge API rates</span></td><td><code>ollama pull tinyllama</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="vision">
  <h2>Vision &amp; multimodal</h2>
  <p class="model-cat-lede">Pass an image (screenshot, chart, document scan) with the prompt.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Sizes</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>Qwen 2.5 VL</strong> · Alibaba<br><a href="https://ollama.com/library/qwen2.5-vl" target="_blank" rel="noopener">ollama.com</a></td><td>3B · 7B · 32B · 72B<br><span class="model-ctx">32k ctx · Jan 2025</span></td><td class="model-score"><span class="model-score-val">70.2</span><span class="model-score-bench">MMMU · 72B</span><span class="model-score-secondary">74.8 MathVista</span></td><td>Sharp on documents + charts + tables + agent screens. 72B ~= GPT-4o. <span class="model-license-note">Apache 2.0</span></td><td>7B → 6 GB · 72B → 45 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.02 / image (Sonnet Vision)</span></td><td><code>ollama pull qwen2.5-vl</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>Llama 3.2 Vision</strong> · Meta<br><a href="https://ollama.com/library/llama3.2-vision" target="_blank" rel="noopener">ollama.com</a></td><td>11B · 90B<br><span class="model-ctx">128k ctx · Sep 2024</span></td><td class="model-score"><span class="model-score-val">60.3</span><span class="model-score-bench">MMMU · 90B</span><span class="model-score-secondary">57.3 MathVista</span></td><td>Meta's multimodal. Charts, screenshots, docs. <span class="model-license-note">Llama 3.2 license</span></td><td>11B → 8 GB · 90B → 55 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.02 / image (Sonnet Vision)</span></td><td><code>ollama pull llama3.2-vision</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>MiniCPM-V</strong><br><a href="https://ollama.com/library/minicpm-v" target="_blank" rel="noopener">ollama.com</a></td><td>8B<br><span class="model-ctx">32k ctx · Jul 2024</span></td><td class="model-score"><span class="model-score-val">49.8</span><span class="model-score-bench">MMMU val</span></td><td>Efficient multimodal for mobile / edge. Strong OCR. <span class="model-license-note">Apache 2.0</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.02 / OCR page</span></td><td><code>ollama pull minicpm-v</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>LLaVA</strong><br><a href="https://ollama.com/library/llava" target="_blank" rel="noopener">ollama.com</a></td><td>7B · 13B · 34B<br><span class="model-ctx">4k ctx · Jan 2024</span></td><td class="model-score"><span class="model-score-val">44.7</span><span class="model-score-bench">MMMU · 34B</span></td><td>Classic community vision assistant. Well-documented. <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.02 / image (Sonnet Vision)</span></td><td><code>ollama pull llava</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>LLaVA-Llama3</strong><br><a href="https://ollama.com/library/llava-llama3" target="_blank" rel="noopener">ollama.com</a></td><td>8B<br><span class="model-ctx">8k ctx · May 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">41.7</span><span class="model-score-bench">MMMU</span></td><td>LLaVA architecture on Llama 3. Faster, sharper than v1 LLaVA. <span class="model-license-note">Llama 3 license</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.02 / image (Sonnet Vision)</span></td><td><code>ollama pull llava-llama3</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>BakLLaVA</strong><br><a href="https://ollama.com/library/bakllava" target="_blank" rel="noopener">ollama.com</a></td><td>7B<br><span class="model-ctx">4k ctx · Oct 2023</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">39.0</span><span class="model-score-bench">MMMU</span></td><td>Mistral-based multimodal. Alternative lineage to LLaVA. <span class="model-license-note">Apache 2.0</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.02 / image</span></td><td><code>ollama pull bakllava</code></td></tr>
        <tr><td><span class="model-rank">7</span><strong>Moondream</strong><br><a href="https://ollama.com/library/moondream" target="_blank" rel="noopener">ollama.com</a></td><td>1.8B<br><span class="model-ctx">2k ctx · Jan 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">—</span><span class="model-score-bench">OCR-focused</span></td><td>Tiny vision model, runs on phones. Real-time edge tasks. <span class="model-license-note">Apache 2.0</span></td><td>1.8B → 2 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.01 / image (Haiku Vision)</span></td><td><code>ollama pull moondream</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="embeddings">
  <h2>Embeddings</h2>
  <p class="model-cat-lede">Text → vectors for search, RAG, semantic dedup. Fast, small, no chat.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Dims</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>BGE-M3</strong> · BAAI<br><a href="https://ollama.com/library/bge-m3" target="_blank" rel="noopener">ollama.com</a></td><td>1024<br><span class="model-ctx">8k ctx · Jan 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">66.9</span><span class="model-score-bench">MTEB mixed</span></td><td>Multilingual, multi-granularity. Dense + sparse + multi-vector in one model. <span class="model-license-note">MIT</span></td><td>2 GB</td><td>$0 <span class="model-cost-vs">vs multi-vector API rates</span></td><td><code>ollama pull bge-m3</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>mxbai-embed-large</strong> · Mixed Bread<br><a href="https://ollama.com/library/mxbai-embed-large" target="_blank" rel="noopener">ollama.com</a></td><td>1024<br><span class="model-ctx">512 ctx · Mar 2024</span></td><td class="model-score"><span class="model-score-val">64.7</span><span class="model-score-bench">MTEB avg</span></td><td>High-quality general-purpose embedder. Strong bench numbers. <span class="model-license-note">Apache 2.0</span></td><td>1 GB</td><td>$0 <span class="model-cost-vs">vs $0.13 / M tokens (Voyage)</span></td><td><code>ollama pull mxbai-embed-large</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>BGE Large EN</strong> · BAAI<br><a href="https://ollama.com/library/bge-large" target="_blank" rel="noopener">ollama.com</a></td><td>1024<br><span class="model-ctx">512 ctx · Oct 2023</span></td><td class="model-score"><span class="model-score-val">64.2</span><span class="model-score-bench">MTEB avg</span></td><td>English-focused. High MTEB scores. <span class="model-license-note">MIT</span></td><td>1 GB</td><td>$0 <span class="model-cost-vs">vs $0.02 / M tokens</span></td><td><code>ollama pull bge-large</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>Granite Embedding</strong> · IBM<br><a href="https://ollama.com/library/granite-embedding" target="_blank" rel="noopener">ollama.com</a></td><td>384 · 768<br><span class="model-ctx">512 ctx · Dec 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">62.5</span><span class="model-score-bench">MTEB avg</span></td><td>IBM's enterprise-grade embeddings. Apache = commercial-safe. <span class="model-license-note">Apache 2.0</span></td><td>1 GB</td><td>$0 <span class="model-cost-vs">vs enterprise embedding rates</span></td><td><code>ollama pull granite-embedding</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>Nomic Embed Text</strong><br><a href="https://ollama.com/library/nomic-embed-text" target="_blank" rel="noopener">ollama.com</a></td><td>768<br><span class="model-ctx">8k ctx · Feb 2024</span></td><td class="model-score"><span class="model-score-val">62.3</span><span class="model-score-bench">MTEB avg</span></td><td>SOTA open embeddings for general text. Fast, tokenizer-friendly. <span class="model-license-note">Apache 2.0</span></td><td>1 GB</td><td>$0 <span class="model-cost-vs">vs $0.02 / M tokens (text-embedding-3)</span></td><td><code>ollama pull nomic-embed-text</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>Paraphrase Multilingual</strong><br><a href="https://ollama.com/library/paraphrase-multilingual" target="_blank" rel="noopener">ollama.com</a></td><td>768<br><span class="model-ctx">128 ctx · Jun 2022</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">58.4</span><span class="model-score-bench">MIRACL</span></td><td>Sentence-Transformers lineage. 50+ languages. <span class="model-license-note">Apache 2.0</span></td><td>1 GB</td><td>$0 <span class="model-cost-vs">vs $0.10 / M multilingual (Cohere)</span></td><td><code>ollama pull paraphrase-multilingual</code></td></tr>
        <tr><td><span class="model-rank">7</span><strong>Snowflake Arctic Embed</strong><br><a href="https://ollama.com/library/snowflake-arctic-embed" target="_blank" rel="noopener">ollama.com</a></td><td>1024<br><span class="model-ctx">512 ctx · Apr 2024</span></td><td class="model-score"><span class="model-score-val">55.9</span><span class="model-score-bench">MTEB retrieval</span></td><td>Multi-domain retrieval. Strong on business docs + code. <span class="model-license-note">Apache 2.0</span></td><td>1 GB</td><td>$0 <span class="model-cost-vs">vs $0.02 / M tokens (text-embedding-3)</span></td><td><code>ollama pull snowflake-arctic-embed</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="function-calling">
  <h2>Function-calling &amp; agent tuning</h2>
  <p class="model-cat-lede">Tuned specifically for tool-use, JSON output, and structured agent workflows.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Sizes</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>Firefunction v2</strong><br><a href="https://ollama.com/library/firefunction-v2" target="_blank" rel="noopener">ollama.com</a></td><td>70B<br><span class="model-ctx">8k ctx · Jul 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">85.7</span><span class="model-score-bench">BFCL v2</span></td><td>Fireworks AI's function-calling tune of Llama 3. GPT-4-class tool use. <span class="model-license-note">Llama 3 license</span></td><td>70B → 40 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.10 / tool call (Sonnet)</span></td><td><code>ollama pull firefunction-v2</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>Hermes 2 Pro</strong> · Nous<br><a href="https://ollama.com/library/hermes3" target="_blank" rel="noopener">ollama.com</a></td><td>7B · 8B · 70B<br><span class="model-ctx">8k ctx · Mar 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">75.4</span><span class="model-score-bench">BFCL v2</span></td><td>Tool-use tuned Llama. Native JSON mode. <span class="model-license-note">Llama terms</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.05 / call (Sonnet)</span></td><td><code>ollama pull hermes3</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>Nexus Raven</strong><br><a href="https://ollama.com/library/nexusraven" target="_blank" rel="noopener">ollama.com</a></td><td>13B<br><span class="model-ctx">16k ctx · Jan 2024</span></td><td class="model-score" data-provisional="true"><span class="model-score-val">74.8</span><span class="model-score-bench">BFCL v2</span></td><td>Function-calling on CodeLlama base. Compact. <span class="model-license-note">Llama 2 license</span></td><td>13B → 9 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.08 / tool call</span></td><td><code>ollama pull nexusraven</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>Command R (again)</strong></td><td>35B<br><span class="model-ctx">128k ctx · Aug 2024</span></td><td class="model-score"><span class="model-score-val">68.2</span><span class="model-score-bench">MMLU</span></td><td>Cohere's RAG + tool-use flagship at accessible size. See General table. <span class="model-license-note">CC-BY-NC 4.0</span></td><td>35B → 22 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.15 / RAG call</span></td><td><code>ollama pull command-r</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="moe">
  <h2>Mixture-of-Experts (MoE)</h2>
  <p class="model-cat-lede">Sparse — activates only a fraction of parameters per token. High capability, moderate active compute.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Config</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>DeepSeek V3 (again)</strong></td><td>685B params · ~37B active<br><span class="model-ctx">128k ctx · Dec 2024</span></td><td class="model-score"><span class="model-score-val">88.5</span><span class="model-score-bench">MMLU</span></td><td>The current OSS MoE flagship. Only for fat servers. <span class="model-license-note">DeepSeek license</span></td><td>~400 GB</td><td>$0 <span class="model-cost-vs">vs GPT-4-class rates</span></td><td><code>ollama pull deepseek-v3</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>Llama 4 Maverick (again)</strong></td><td>400B params · 17B active<br><span class="model-ctx">1M ctx · Apr 2026</span></td><td class="model-score"><span class="model-score-val">85.5</span><span class="model-score-bench">MMLU · MoE</span></td><td>Meta's flagship native-multimodal MoE. Datacenter class. <span class="model-license-note">Llama 4 license</span></td><td>~200 GB</td><td>$0 <span class="model-cost-vs">vs GPT-4-class rates</span></td><td><code>ollama pull llama4:maverick</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>Llama 4 Scout (again)</strong></td><td>109B params · 17B active<br><span class="model-ctx">10M ctx · Apr 2026</span></td><td class="model-score"><span class="model-score-val">79.6</span><span class="model-score-bench">MMLU · MoE</span></td><td>Massive-context multimodal at 17B active — fits a fat consumer rig. <span class="model-license-note">Llama 4 license</span></td><td>~50 GB (Q4)</td><td>$0 <span class="model-cost-vs">vs long-context Sonnet</span></td><td><code>ollama pull llama4:scout</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>DeepSeek Coder V2 (MoE) (again)</strong></td><td>236B params · ~21B active<br><span class="model-ctx">128k ctx · Jun 2024</span></td><td class="model-score"><span class="model-score-val">79.2</span><span class="model-score-bench">MMLU · 236B</span><span class="model-score-secondary">90.2 HumanEval</span></td><td>MoE coding model. Very fast for its capability. See Coding table for HumanEval. <span class="model-license-note">DeepSeek license</span></td><td>16B → 10 GB</td><td>$0 <span class="model-cost-vs">vs ~$1 / complex refactor</span></td><td><code>ollama pull deepseek-coder-v2</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>Mixtral 8x22B (Mistral)</strong></td><td>141B params · ~39B active<br><span class="model-ctx">64k ctx · Apr 2024</span></td><td class="model-score"><span class="model-score-val">77.3</span><span class="model-score-bench">MMLU</span></td><td>Larger MoE. Excellent general purpose for beefy hardware. <span class="model-license-note">Apache 2.0</span></td><td>141B → 80 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.20 / prompt (Opus)</span></td><td><code>ollama pull mixtral:8x22b</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>DBRX (Databricks) (again)</strong></td><td>132B params · 36B active<br><span class="model-ctx">32k ctx · Mar 2024</span></td><td class="model-score"><span class="model-score-val">73.7</span><span class="model-score-bench">MMLU</span></td><td>Databricks fine-grained MoE. Enterprise-focused. <span class="model-license-note">DBRX Open Model License</span></td><td>132B → 74 GB</td><td>$0 <span class="model-cost-vs">vs enterprise API rates</span></td><td><code>ollama pull dbrx</code></td></tr>
        <tr><td><span class="model-rank">7</span><strong>Mixtral 8x7B (Mistral)</strong></td><td>47B params · ~13B active<br><span class="model-ctx">32k ctx · Dec 2023</span></td><td class="model-score"><span class="model-score-val">70.6</span><span class="model-score-bench">MMLU</span></td><td>Original MoE. Still strong. GPT-3.5-class at fraction of compute. <span class="model-license-note">Apache 2.0</span></td><td>47B → 26 GB</td><td>$0 <span class="model-cost-vs">vs ~$0.05 / prompt (Sonnet)</span></td><td><code>ollama pull mixtral</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="uncensored">
  <h2>Uncensored / research</h2>
  <p class="model-cat-lede">Alignment removed for research, red-teaming, or specific unrestricted workflows. <strong>Not for production without your own guardrails.</strong></p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Model</th><th>Sizes</th><th>Score</th><th>Best for</th><th>RAM (Q4)</th><th>Cost vs cloud</th><th>Get it</th></tr></thead>
                  <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>Nous Hermes 2 Mixtral</strong><br><a href="https://ollama.com/library/nous-hermes2-mixtral" target="_blank" rel="noopener">ollama.com</a></td><td>8x7B<br><span class="model-ctx">32k ctx · Jan 2024</span></td><td class="model-score"><span class="model-score-val">71.8</span><span class="model-score-bench">MMLU · Mixtral base</span></td><td>Nous Research fine-tune on Mixtral. Very steerable. <span class="model-license-note">Apache 2.0</span></td><td>26 GB</td><td>$0 <span class="model-cost-vs">no cloud equivalent</span></td><td><code>ollama pull nous-hermes2-mixtral</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>Dolphin Mixtral</strong><br><a href="https://ollama.com/library/dolphin-mixtral" target="_blank" rel="noopener">ollama.com</a></td><td>8x7B · 8x22B<br><span class="model-ctx">32k ctx · Feb 2024</span></td><td class="model-score"><span class="model-score-val">70.6</span><span class="model-score-bench">MMLU · Mixtral base</span></td><td>Uncensored fine-tune of Mixtral. High capability + no refusal. <span class="model-license-note">Apache 2.0</span></td><td>8x7B → 26 GB</td><td>$0 <span class="model-cost-vs">no cloud equivalent</span></td><td><code>ollama pull dolphin-mixtral</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>Dolphin 3</strong><br><a href="https://ollama.com/library/dolphin3" target="_blank" rel="noopener">ollama.com</a></td><td>8B<br><span class="model-ctx">8k ctx · Nov 2024</span></td><td class="model-score"><span class="model-score-val">66.5</span><span class="model-score-bench">MMLU · Llama 3 base</span></td><td>Eric Hartford's uncensored Llama 3 fine-tune. Community classic. <span class="model-license-note">Llama 3 license</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">no cloud equivalent</span></td><td><code>ollama pull dolphin3</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>Dolphin Llama 3</strong><br><a href="https://ollama.com/library/dolphin-llama3" target="_blank" rel="noopener">ollama.com</a></td><td>8B · 70B<br><span class="model-ctx">8k ctx · May 2024</span></td><td class="model-score"><span class="model-score-val">66.5</span><span class="model-score-bench">MMLU · Llama 3 base</span></td><td>Uncensored Llama 3 fine-tune. Alignment stripped. <span class="model-license-note">Llama 3 license</span></td><td>8B → 6 GB</td><td>$0 <span class="model-cost-vs">no cloud equivalent</span></td><td><code>ollama pull dolphin-llama3</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>WizardLM 2 Uncensored</strong><br><a href="https://ollama.com/library/wizardlm-uncensored" target="_blank" rel="noopener">ollama.com</a></td><td>7B · 8x22B<br><span class="model-ctx">32k ctx · Apr 2024</span></td><td class="model-score"><span class="model-score-val">61.2</span><span class="model-score-bench">MMLU · Mistral base</span></td><td>Evol-Instruct fine-tune with alignment removed. <span class="model-license-note">Llama terms</span></td><td>7B → 5 GB</td><td>$0 <span class="model-cost-vs">no cloud equivalent</span></td><td><code>ollama pull wizardlm-uncensored</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="how-to-use">
  <h2>How to use these on vinOS.</h2>
  <p style="max-width: 60ch; color: var(--color-ink-2); font-size: var(--text-md); line-height: 1.55;">
    Once the <code>ai</code> bundle is installed (<code>vinos-install ai</code>), Ollama is already running. Then:
  </p>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">ollama pull &lt;model&gt;</span><span class="model-usage-desc">Download the weights (one-time, per model).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">ollama run &lt;model&gt;</span><span class="model-usage-desc">Interactive chat in the terminal.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-ai chat</span><span class="model-usage-desc">vinOS wrapper. Uses your default model. Bound to <kbd>Super</kbd>+<kbd>A</kbd>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-ai models</span><span class="model-usage-desc">List everything you've pulled.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-ai status</span><span class="model-usage-desc">Ollama up? Which model is default? What's using RAM?</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">ollama rm &lt;model&gt;</span><span class="model-usage-desc">Delete weights to reclaim disk.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">ollama ls</span><span class="model-usage-desc">List installed models + sizes on disk.</span></div>
  </div>
</section>

<section class="audience-cta">
  <h2>This list will be <span class="accent">automated in v1.2.</span></h2>
  <p class="audience-cta-note">
    Right now this is a curated snapshot maintained by hand. A future <code>vinos-models</code> command will populate this table live from the Ollama registry plus a vinOS-blessed metadata layer (RAM estimates, cost anchors, workload tags, license badges) — and, more importantly, will <em>recommend the right model for your specific machine and workflow</em>. RAG pipeline? Code assistant? Long-context research? Edge deployment? The current picker is the raw material; the v1.2 personalization layer is what turns it into an answer. Model missing? File a PR against <a href="https://github.com/vinpatel/vinos/blob/main/site/content/models.md" target="_blank" rel="noopener"><code>site/content/models.md</code></a>.
  </p>
  <div class="hero-actions">
    <a href="https://archive.org/details/vinos-1.1.0-x86_64" class="btn-primary" target="_blank" rel="noopener">Download vinOS v1.1.0</a>
    <a href="/install/" class="link-ghost">Install guide →</a>
    <a href="https://ollama.com/library" class="link-ghost" target="_blank" rel="noopener">Full Ollama library →</a>
  </div>
</section>
