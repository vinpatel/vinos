---
title: "Hosted opensource models on vinOS"
description: "Route to 290+ opensource-friendly providers through one local endpoint via OmniRoute. ~1.53B free tokens/month across 90+ free tiers — Kimi, DeepSeek, GLM, Gemini, Claude Sonnet, GPT-4o mini, and more. Auto-fallback, OpenAI-compatible, MIT-licensed."
url: "/hosted/"
type: "for"
---

<section class="audience-hero">
  <span class="audience-eyebrow"><span class="accent">hosted</span> opensource + the OmniRoute gateway</span>
  <h1>Same opensource models. Hosted. <span class="accent">One endpoint.</span></h1>
  <p class="audience-lede">
    Not every rig can run a 70B model. <a href="https://github.com/diegosouzapw/OmniRoute" target="_blank" rel="noopener">OmniRoute</a>
    is an MIT-licensed gateway that stacks the free tiers of 290+ providers
    into <strong>one local OpenAI-compatible endpoint</strong>. Point
    <code>vinos-ai</code> and your routines at it and you get frontier
    opensource models — Kimi K2/K3, DeepSeek, GLM, Llama, Qwen — without
    a single API key on day one. <em>~1.53B free tokens per month, auto-fallback
    when one provider throttles, works out of the box.</em>
    Complement to <a href="/models/">/models/</a> (local Ollama) — use both.
  </p>
  <div class="models-freshness" role="status" aria-label="upstream freshness">
    <span class="models-freshness-dot" aria-hidden="true"></span>
    <span class="models-freshness-label">
      <strong>OmniRoute upstream, re-audited every two weeks.</strong>
      Free-tier math lives at
      <a href="https://github.com/diegosouzapw/OmniRoute/blob/main/docs/reference/FREE_TIERS.md" target="_blank" rel="noopener">docs/reference/FREE_TIERS.md</a>
      — a provider ends a free tier and the number drops; a new one
      lands and it climbs. Numbers below reflect the current catalog.
    </span>
  </div>
</section>

<section class="audience-section" id="quickstart">
  <h2>Zero-config <span class="accent">quickstart</span></h2>
  <p class="model-cat-lede">Two commands. First one installs OmniRoute; second points vinos-ai at it. That's it.</p>
<pre><code class="language-bash">npm i -g omniroute                # boots on http://localhost:20128
export VINOS_AI_BASE_URL=http://localhost:20128/v1
export VINOS_AI_MODEL=auto        # OmniRoute picks the cheapest working provider

vinos-ai chat "hello"             # answers via a free-tier provider — no API key
</code></pre>
  <p class="small-print" style="margin-top: var(--space-md);">
    Pre-wired keyless providers (OpenCode Free, Felo) mean <code>auto</code>
    works before you sign up anywhere. Add API keys later for Kimi,
    DeepSeek, Groq, etc. — OmniRoute layers them in and prefers the
    cheapest one that's still under quota.
    Endpoint reference:
    <a href="https://github.com/diegosouzapw/OmniRoute#-quick-start" target="_blank" rel="noopener">OmniRoute quick start</a>.
  </p>
</section>

<section class="audience-section" id="tiers">
  <h2>The <span class="accent">4-tier</span> auto-fallback</h2>
  <div class="prose measure">
    <p>
      Every call goes through OmniRoute's smart router. If the top-tier
      provider is out of quota, or the request fails, or the response
      confidence is low — it slides to the next tier <em>silently, in
      milliseconds</em>. No retries in your code, no downtime.
    </p>
  </div>
  <div class="model-usage" style="margin-top: var(--space-md);">
    <div class="model-usage-row">
      <span class="model-usage-cmd">Tier 1 — Subscription</span>
      <span class="model-usage-desc">Claude Code plan, Copilot plan, Codex plan (if you already pay)</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">Tier 2 — API key</span>
      <span class="model-usage-desc">DeepSeek, Groq, xAI, Anthropic direct — the ones you brought your own key for</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">Tier 3 — Cheap paid</span>
      <span class="model-usage-desc">GLM $0.50/M, MiniMax $0.20/M — routed when you're willing to spend pennies</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">Tier 4 — Free tier</span>
      <span class="model-usage-desc">90+ free-tier providers, ~1.53B tokens/mo aggregate — the default fallback</span>
    </div>
  </div>
</section>

<section class="audience-section">
  <h2>Configure vinOS routines</h2>
  <p style="max-width: 62ch; color: var(--color-ink-2); font-size: var(--text-md); line-height: 1.55; margin-bottom: var(--space-lg);">
    Same routine TOML as <a href="/models/#the-80-20-router">local routing</a> — the router still runs local first for the 80% case. The <code>premium_model</code> now points at OmniRoute instead of Anthropic direct, so escalations go through the gateway's free/cheap tiers before spending real money.
  </p>
<pre><code class="language-toml">[agent]
route          = "auto"                      # anthropic | ollama | omniroute | auto
local_model    = "qwen2.5:7b"                # local Ollama for the 80% case
premium_model  = "auto/smart"                # OmniRoute meta-model — picks best free provider

[agent.omniroute]
base_url       = "http://localhost:20128/v1"
api_key        = "sk-any-string"             # OmniRoute ignores it locally

[agent.escalation]
on_low_confidence   = true
on_reasoning_task   = true
on_context_overflow = true
max_escalations_per_run = 3
</code></pre>
  <p class="small-print" style="margin-top: var(--space-md);">
    Model IDs to try: <code>auto</code> (balanced), <code>auto/coding</code>
    (code-quality-first), <code>auto/fast</code> (lowest latency),
    <code>auto/cheap</code> (cheapest first), <code>auto/smart</code>
    (quality-first + exploration). OmniRoute maps each of these to
    a live combo across whichever providers are currently under quota.
  </p>
</section>

<section class="audience-section">
  <h2>When <span class="accent">local</span>, when <span class="accent">hosted</span>?</h2>
  <div class="model-usage" style="margin-top: var(--space-md);">
    <div class="model-usage-row">
      <span class="model-usage-cmd">Use local (/models/)</span>
      <span class="model-usage-desc">Offline / airgapped work · sensitive data · always-on daemons · when you own the GPU · sub-second latency</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">Use hosted (this page)</span>
      <span class="model-usage-desc">Frontier models your box can't run (Kimi K3, Claude Sonnet, GPT-4o) · burst workloads · rigs without a GPU · free-tier stacking on principle</span>
    </div>
    <div class="model-usage-row highlight">
      <span class="model-usage-cmd">Use both (recommended)</span>
      <span class="model-usage-desc"><code>route = "auto"</code> — local for the 80% case, OmniRoute escalation for the 20% that needs frontier · cheapest total spend, fastest common path</span>
    </div>
  </div>
</section>

<nav class="model-catnav" aria-label="Provider categories">
  <span class="model-catnav-label">Jump to:</span>
  <a href="#free-forever">Free forever</a>
  <a href="#free-monthly">Free monthly quota</a>
  <a href="#signup-credits">Signup credits</a>
  <a href="#cheap-paid">Cheap paid</a>
  <a href="#byok">Bring-your-own-key</a>
  <a href="#how-to-use">How to use</a>
</nav>

<section class="audience-section" id="free-forever">
  <h2>Free forever <span class="accent">(no token cap)</span></h2>
  <p class="model-cat-lede">These providers don't publish a monthly cap — auto-fallback keeps them warm as the last-resort tier so <code>auto</code> always answers something.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Provider</th><th>Models</th><th>Terms</th><th>Auth</th><th>Best for</th><th>OmniRoute ID</th></tr></thead>
      <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>SiliconFlow</strong><br><a href="https://siliconflow.com" target="_blank" rel="noopener">siliconflow.com</a></td><td>Qwen, DeepSeek, GLM, Llama, Yi variants</td><td>Free tier, no cap, rate-limited</td><td>API key (free signup)</td><td>Broadest opensource selection on a single free provider</td><td><code>siliconflow/qwen2.5-coder-32b</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>Z.AI (GLM-Flash)</strong><br><a href="https://open.bigmodel.cn" target="_blank" rel="noopener">bigmodel.cn</a></td><td>GLM-4.5-Flash</td><td>Free forever · rate limited</td><td>API key</td><td>Fast general chat · Chinese/English</td><td><code>zai/glm-4.5-flash</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>OpenCode Zen</strong><br><a href="https://opencode.zen" target="_blank" rel="noopener">opencode.zen</a></td><td>Kimi K2, DeepSeek V3, Llama 3.3</td><td>Free · rate limited</td><td>None (keyless)</td><td>Zero-signup coding assistant · pre-wired in the <code>auto</code> combo</td><td><code>oc/&lt;model&gt;</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>Kilo</strong><br><a href="https://kilocode.ai" target="_blank" rel="noopener">kilocode.ai</a></td><td>Sonnet-class + coding models</td><td>Free tier · no token cap</td><td>API key</td><td>Coding agent workloads</td><td><code>kilo/&lt;model&gt;</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>Baidu Qianfan</strong><br><a href="https://qianfan.cloud.baidu.com" target="_blank" rel="noopener">qianfan.cloud.baidu.com</a></td><td>ERNIE 4.5, DeepSeek, various</td><td>Free tier · rate limited</td><td>API key</td><td>Sovereign-friendly · Chinese-first</td><td><code>baidu/ernie-4.5</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>Felo</strong><br><a href="https://felo.ai" target="_blank" rel="noopener">felo.ai</a></td><td>Search-augmented chat</td><td>Free · keyless</td><td>None (keyless)</td><td>Search-grounded answers · pre-wired in <code>auto</code></td><td><code>felo/&lt;model&gt;</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="free-monthly">
  <h2>Free monthly quota</h2>
  <p class="model-cat-lede">Documented monthly free tokens — reset on rollover. OmniRoute exhausts these first before touching paid tiers.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Provider</th><th>Free tokens / mo</th><th>Notable models</th><th>License / terms</th><th>Best for</th><th>OmniRoute ID</th></tr></thead>
      <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>Mistral La Plateforme</strong><br><a href="https://console.mistral.ai" target="_blank" rel="noopener">console.mistral.ai</a></td><td>~1B / mo (Mistral Large 3)</td><td>Mistral Large 3, Codestral, Nemo, Mistral Small</td><td>Free tier · commercial-safe once paid</td><td>Highest single-provider free quota · European stack</td><td><code>mistral/mistral-large-3</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>OpenAI</strong> (via free tools)<br><a href="https://platform.openai.com" target="_blank" rel="noopener">platform.openai.com</a></td><td>~150M / mo (GPT-4o mini)</td><td>GPT-4o mini, o1-mini, embeddings</td><td>Free credits program</td><td>Frontier general-purpose · vision + reasoning</td><td><code>openai/gpt-4o-mini</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>Google AI Studio</strong><br><a href="https://aistudio.google.com" target="_blank" rel="noopener">aistudio.google.com</a></td><td>~60M / mo (Gemini 2.5 Flash)</td><td>Gemini 2.5 Flash / Pro, 1M-token context</td><td>Free tier · GCP terms</td><td>Long-context ingest · vision</td><td><code>google/gemini-2.5-flash</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>Groq</strong><br><a href="https://console.groq.com" target="_blank" rel="noopener">console.groq.com</a></td><td>~50M / mo · rate-limited</td><td>Llama 3.3 70B, DeepSeek R1 distill, Kimi K2, Qwen 2.5</td><td>Free tier · LPU inference</td><td>Sub-100ms latency · streaming</td><td><code>groq/llama-3.3-70b-versatile</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>Cerebras</strong><br><a href="https://inference-docs.cerebras.ai" target="_blank" rel="noopener">cerebras.ai</a></td><td>~30M / mo · rate-limited</td><td>Llama 3.3 70B, Llama 4 Scout, Qwen 3 32B</td><td>Free tier · wafer-scale inference</td><td>Fastest tokens/sec on frontier open models</td><td><code>cerebras/llama-3.3-70b</code></td></tr>
        <tr><td><span class="model-rank">6</span><strong>Cloudflare Workers AI</strong><br><a href="https://developers.cloudflare.com/workers-ai" target="_blank" rel="noopener">workers-ai docs</a></td><td>Daily neurons · ~free tier</td><td>Llama, Mistral, Gemma, DeepSeek</td><td>Free tier · edge network</td><td>Edge-latency in 300+ cities · cheap per-token</td><td><code>cloudflare/llama-3.3-70b</code></td></tr>
        <tr><td><span class="model-rank">7</span><strong>Anthropic (Claude Sonnet)</strong><br><a href="https://console.anthropic.com" target="_blank" rel="noopener">console.anthropic.com</a></td><td>~25K / mo (Sonnet 4.5)</td><td>Claude Sonnet 4.5 / Haiku 4.5</td><td>Free trial credits</td><td>Deep reasoning · long context · frontier</td><td><code>anthropic/claude-sonnet-4.5</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="signup-credits">
  <h2>Signup credits <span class="accent">(one-time)</span></h2>
  <p class="model-cat-lede">First-month bumps that inflate the aggregate to ~2.15B tokens in month one. Non-repeating — flagged separately in OmniRoute's dashboard so they don't inflate the "steady-state" number.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Provider</th><th>Signup credit</th><th>Notable models</th><th>Terms</th><th>OmniRoute ID</th></tr></thead>
      <tbody>
        <tr><td><strong>Google Vertex AI</strong></td><td>~300M / one-time</td><td>Gemini 2.5 Pro / Flash, PaLM</td><td>$300 GCP credit · 90 days</td><td><code>vertex/gemini-2.5-pro</code></td></tr>
        <tr><td><strong>AgentRouter</strong></td><td>~200M / one-time</td><td>Aggregated frontier models</td><td>Signup credit</td><td><code>agentrouter/&lt;model&gt;</code></td></tr>
        <tr><td><strong>Predibase</strong></td><td>~25M / one-time</td><td>Fine-tuned open models</td><td>Signup credit</td><td><code>predibase/&lt;model&gt;</code></td></tr>
        <tr><td><strong>Together AI</strong></td><td>~25M / one-time</td><td>Llama 3.3, Kimi K2, DeepSeek, Mixtral, Qwen</td><td>$25 signup credit</td><td><code>together/llama-3.3-70b</code></td></tr>
        <tr><td><strong>Z.AI (GLM-CN)</strong></td><td>~20M / one-time</td><td>GLM-4.5, GLM-Air, GLM-Flash</td><td>Chinese cloud tier signup</td><td><code>zai-cn/glm-4.5</code></td></tr>
        <tr><td><strong>Doubao</strong> · ByteDance</td><td>~15M / one-time</td><td>Doubao Pro, Doubao Lite</td><td>Signup credit</td><td><code>doubao/&lt;model&gt;</code></td></tr>
        <tr><td><strong>AI21 Labs</strong></td><td>~10M / one-time</td><td>Jamba 1.5, Jurassic</td><td>Signup credit</td><td><code>ai21/jamba-1.5-large</code></td></tr>
        <tr><td><strong>LongCat</strong></td><td>~10M / one-time</td><td>LongCat Flash, long-context</td><td>Signup credit</td><td><code>longcat/&lt;model&gt;</code></td></tr>
        <tr><td><strong>DeepSeek Platform</strong></td><td>~5M / one-time</td><td>DeepSeek V3, R1</td><td>Signup credit</td><td><code>deepseek/deepseek-chat</code></td></tr>
        <tr><td><strong>Hyperbolic</strong></td><td>~5M / one-time</td><td>Llama, Qwen, DeepSeek variants</td><td>Signup credit</td><td><code>hyperbolic/&lt;model&gt;</code></td></tr>
        <tr><td><strong>Nscale</strong></td><td>~5M / one-time</td><td>Frontier open models</td><td>Signup credit</td><td><code>nscale/&lt;model&gt;</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="cheap-paid">
  <h2>Cheap paid <span class="accent">(when free runs out)</span></h2>
  <p class="model-cat-lede">Tier 3 fallback. Pennies per million, but only touched when free tiers are exhausted and <code>auto</code> can't find a working free provider.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Provider</th><th>Price</th><th>Notable models</th><th>Terms</th><th>OmniRoute ID</th></tr></thead>
      <tbody>
        <tr class="model-top-pick"><td><span class="model-rank gold">1</span><strong>DeepSeek Platform</strong><br><a href="https://platform.deepseek.com" target="_blank" rel="noopener">platform.deepseek.com</a></td><td>$0.14 / M in · $0.28 / M out</td><td>DeepSeek V3, R1 reasoning</td><td>Pay-as-you-go · MIT-licensed weights</td><td><code>deepseek/deepseek-chat</code></td></tr>
        <tr><td><span class="model-rank silver">2</span><strong>MiniMax</strong><br><a href="https://minimax.chat" target="_blank" rel="noopener">minimax.chat</a></td><td>~$0.20 / M in · out</td><td>MiniMax-M1, MiniMax-Text-01</td><td>Pay-as-you-go</td><td><code>minimax/&lt;model&gt;</code></td></tr>
        <tr><td><span class="model-rank bronze">3</span><strong>Z.AI (GLM paid)</strong><br><a href="https://open.bigmodel.cn" target="_blank" rel="noopener">bigmodel.cn</a></td><td>~$0.50 / M</td><td>GLM-4.5, GLM-4-Plus</td><td>Pay-as-you-go</td><td><code>zai/glm-4.5</code></td></tr>
        <tr><td><span class="model-rank">4</span><strong>Kimi (Moonshot)</strong><br><a href="https://platform.kimi.ai" target="_blank" rel="noopener">platform.kimi.ai</a></td><td>$0.15 / M in · $2.50 / M out (K2)</td><td>Kimi K2, Kimi K3 (1M ctx)</td><td>Pay-as-you-go · Modified MIT weights</td><td><code>kimi/k2</code></td></tr>
        <tr><td><span class="model-rank">5</span><strong>xAI</strong> (Grok)<br><a href="https://x.ai/api" target="_blank" rel="noopener">x.ai/api</a></td><td>$3 / M in · $15 / M out (grok-4)</td><td>Grok 4, Grok 3, Grok Imagine</td><td>Pay-as-you-go · closed weights</td><td><code>xai/grok-4</code></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="byok">
  <h2>Bring-your-own-key <span class="accent">(subscription tier)</span></h2>
  <p class="model-cat-lede">Already paying for a plan? OmniRoute routes to it first, before any free tier. Your subscription quota gets used the way you already paid for it.</p>
  <div class="model-table-wrap">
    <table class="model-table">
      <thead><tr><th>Plan / provider</th><th>What it gives</th><th>OmniRoute integration</th><th>OmniRoute ID</th></tr></thead>
      <tbody>
        <tr><td><strong>Claude Code plan</strong></td><td>Anthropic Claude Sonnet / Opus via subscription</td><td>OAuth flow · uses your plan quota first</td><td><code>anthropic-code/&lt;model&gt;</code></td></tr>
        <tr><td><strong>Kimi Code plan</strong></td><td>Kimi K2 / K3 via subscription</td><td>OAuth or API key</td><td><code>kimi-code/k3</code></td></tr>
        <tr><td><strong>GitHub Copilot Pro</strong></td><td>GPT-4-class via Copilot subscription</td><td>Copilot API key</td><td><code>copilot/&lt;model&gt;</code></td></tr>
        <tr><td><strong>Codex plan</strong></td><td>OpenAI Codex via plan</td><td>OAuth</td><td><code>codex/&lt;model&gt;</code></td></tr>
        <tr><td><strong>Any OpenAI-compatible API key</strong></td><td>OpenRouter, Together, Fireworks, etc.</td><td>API key in OmniRoute dashboard</td><td>Provider-specific prefix</td></tr>
      </tbody>
    </table>
  </div>
</section>

<section class="audience-section" id="how-to-use">
  <h2>How to use these on vinOS.</h2>
  <p style="max-width: 60ch; color: var(--color-ink-2); font-size: var(--text-md); line-height: 1.55;">
    OmniRoute is not shipped in the vinOS ISO (Node/npm dependency, moves fast). Install post-boot:
  </p>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">sudo vinos-install-ai</span><span class="model-usage-desc">Ensures Node + npm are present (from the ai bundle).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">npm i -g omniroute</span><span class="model-usage-desc">Global install. Server boots on <code>localhost:20128</code>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">omniroute start</span><span class="model-usage-desc">Systemd service starts on boot after this. Dashboard at <code>http://localhost:20128</code>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">export VINOS_AI_BASE_URL=http://localhost:20128/v1</span><span class="model-usage-desc">Point <code>vinos-ai</code> at the gateway. Add to <code>~/.bashrc</code> to persist.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-ai chat "hello"</span><span class="model-usage-desc">Answers via OmniRoute. Uses <code>auto</code> by default — routes to whatever's cheapest under quota right now.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">omniroute status</span><span class="model-usage-desc">Live view of provider health, quota remaining, active combos, saved tokens.</span></div>
  </div>
</section>

<section class="audience-cta">
  <h2>OmniRoute is <span class="accent">upstream</span>. vinOS just points at it.</h2>
  <p class="audience-cta-note">
    We didn't build this gateway — <a href="https://github.com/diegosouzapw/OmniRoute" target="_blank" rel="noopener">diegosouzapw/OmniRoute</a> did, and it's MIT-licensed. vinOS's contribution is the integration layer: <code>vinos-ai</code> honours <code>VINOS_AI_BASE_URL</code>, the routine TOML has an <code>omniroute</code> block, and a future <code>vinos-install-omniroute</code> bundle will one-shot the npm install + systemd unit + <code>~/.bashrc</code> export. Support the upstream project on <a href="https://github.com/diegosouzapw/OmniRoute" target="_blank" rel="noopener">GitHub</a> — they're the reason this page exists.
  </p>
  <div class="hero-actions">
    <a href="{{< param isoURL >}}" class="btn-primary" target="_blank" rel="noopener">Download vinOS v{{< param version >}}</a>
    <a href="/models/" class="link-ghost">Or run local via Ollama →</a>
    <a href="https://github.com/diegosouzapw/OmniRoute" class="link-ghost" target="_blank" rel="noopener">OmniRoute on GitHub →</a>
  </div>
</section>
