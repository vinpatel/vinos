---
title: "Routines — scheduled agents on vinOS"
description: "Real Claude/Ollama-powered agents that run on a schedule, on your machine. Declarative TOML, whitelist-enforced tools, per-run and per-day budgets, SQLite ledger. Ships five starter routines in the ISO."
url: "/routines/"
type: "for"
---

<section class="audience-hero">
  <span class="audience-eyebrow">scheduled <span class="accent">agents</span></span>
  <h1>Agents that <span class="accent">run without you.</span></h1>
  <p class="audience-lede">
    A <strong>routine</strong> is a real Claude- or Ollama-powered agent with
    tools, memory, and a budget, running on a systemd timer, on your machine,
    on your terms. Everyone else has agents you talk to. vinOS has agents that
    <em>work while you sleep</em> — briefing you at 6&nbsp;am, reviewing your
    PRs at 1&nbsp;pm, closing your day at 6&nbsp;pm — and shut up when they
    have nothing to say. All output lands as human-readable markdown in
    <code>~/.vinos/routines/state/</code>. Every run is metered in a SQLite
    ledger.
  </p>
</section>

<section class="audience-section">
  <h2>What is a routine, exactly?</h2>
  <div class="prose measure">
    <p>
      One declarative <a href="https://toml.io" target="_blank" rel="noopener">TOML</a>
      file. It names an agent, sets a cron-ish schedule, declares the tools
      the agent may call (read-globs and shell commands, both whitelist-enforced
      by the runtime — <em>not by the model</em>), points at an output
      destination, and caps the budget in tokens per run and dollars per day.
      <code>vinos-routine enable &lt;name&gt;</code> generates a systemd user
      timer. Every run executes shell tools inside a
      <a href="https://github.com/containers/bubblewrap" target="_blank" rel="noopener">bwrap</a>
      sandbox — no network unless you ask for it — and logs cost, duration,
      and exit status to <code>~/.vinos/routines/state/ledger.db</code>.
    </p>
    <p>
      Full spec:
      <a href="https://github.com/vinpatel/vinos/blob/main/docs/v2/vinos-routine-spec.md" target="_blank" rel="noopener">docs/v2/vinos-routine-spec.md</a>.
    </p>
  </div>
</section>

<section class="audience-section" id="starters">
  <h2>Starter routines <span class="accent">shipped in the ISO</span></h2>
  <p style="max-width: 62ch; color: var(--color-ink-2); font-size: var(--text-md); line-height: 1.55; margin-bottom: var(--space-lg);">
    All five live in <code>/etc/vinos/routines/</code>. All ship
    <strong>disabled</strong> — <code>vinos-welcome</code> asks which you want
    active on first boot. Copy any to <code>~/.vinos/routines/</code> to
    customize; the user copy wins.
  </p>

  <div class="spec-grid">

    <div class="spec-block">
      <h3>day-brief</h3>
      <p><strong>06:00 daily</strong> · Morning brief: top 3 for today, tech/AI/OS signals, one reflection.</p>
      <p class="small-print"><code>vinos-routine enable day-brief</code></p>
<pre><code class="language-toml">[routine]
name = "day-brief"
enabled = false

[schedule]
oncalendar = "*-*-* 06:00:00"
jitter     = "5m"

[agent]
route  = "anthropic"
model  = "claude-sonnet-4-6"
tools  = [
  "read:~/Notes/today.md",
  "shell:gh api /notifications --paginate",
  "shell:gcalcli agenda today",
]

[output]
type = "brief"
open_on_login = true

[budget]
max_tokens_per_run  = 4000
max_dollars_per_day = 0.20
</code></pre>
    </div>

    <div class="spec-block">
      <h3>github-review</h3>
      <p><strong>09:00 · 13:00 · 17:00</strong> · Summarizes new PRs across your repos and flags what needs your eyes.</p>
      <p class="small-print"><code>vinos-routine enable github-review</code></p>
<pre><code class="language-toml">[routine]
name = "github-review"

[schedule]
oncalendar = "*-*-* 09,13,17:00:00"

[agent]
route = "anthropic"
model = "claude-sonnet-4-6"
tools = [
  "shell:gh pr list --state=open --json url,title,author,updatedAt",
]
</code></pre>
    </div>

    <div class="spec-block">
      <h3>evening-shutdown</h3>
      <p><strong>18:00 daily</strong> · What shipped today, what's stuck, tomorrow's top-3. Files a git note.</p>
      <p class="small-print"><code>vinos-routine enable evening-shutdown</code></p>
<pre><code class="language-toml">[routine]
name = "evening-shutdown"

[schedule]
oncalendar = "*-*-* 18:00:00"

[agent]
route = "anthropic"
model = "claude-sonnet-4-6"
# short prompt, three fixed sections

[budget]
max_tokens_per_run  = 3000
max_dollars_per_day = 0.20
</code></pre>
    </div>

    <div class="spec-block">
      <h3>inbox-triage</h3>
      <p><strong>hourly</strong> · Reads unread mail, drafts responses, tags them — <strong>never sends</strong>. You approve and send yourself.</p>
      <p class="small-print"><code>vinos-routine enable inbox-triage</code></p>
<pre><code class="language-toml">[routine]
name = "inbox-triage"

[schedule]
oncalendar = "hourly"

[agent]
route = "auto"           # local first, escalate on complex threads
tools = [
  "read:~/inbox/*.eml",
  "shell:notmuch search tag:unread",
]

[output]
type = "notification"    # mako toast when N drafts ready
</code></pre>
    </div>

    <div class="spec-block">
      <h3>research-recap</h3>
      <p><strong>22:00 nightly</strong> · Reads new saved articles/PDFs in <code>~/Reading</code>, generates cross-links and spaced-repetition cards.</p>
      <p class="small-print"><code>vinos-routine enable research-recap</code></p>
<pre><code class="language-toml">[routine]
name = "research-recap"

[schedule]
oncalendar = "*-*-* 22:00:00"

[agent]
route = "ollama"                # 80% case — pure summarization
model = "qwen2.5:7b"
tools = [
  "read:~/Reading/*.md",
  "read:~/Reading/*.pdf",
]
</code></pre>
    </div>

  </div>
</section>

<section class="audience-section" id="install">
  <h2>Three ways to install a routine</h2>

  <ol class="steps">
    <li>
      <span class="stage">01</span>
      <div>
        <h3>Enable a shipped one</h3>
        <p>Every starter above lives in <code>/etc/vinos/routines/</code>. Enable turns it on.</p>
        <code class="cmd">vinos-routine enable day-brief</code>
      </div>
    </li>
    <li>
      <span class="stage">02</span>
      <div>
        <h3>Author your own</h3>
        <p>Scaffold a routine, edit in your <code>$EDITOR</code>, enable when ready.</p>
        <code class="cmd">vinos-routine create weekly-review &amp;&amp; vinos-routine edit weekly-review</code>
      </div>
    </li>
    <li>
      <span class="stage">03</span>
      <div>
        <h3>Load from a project</h3>
        <p>Drop a <code>.vinos/routines.yaml</code> in your repo — teammates run <code>vinos-routine load .</code> after clone and inherit the same agent set. The way <code>.github/workflows/</code> did for CI.</p>
        <code class="cmd">git clone git@github.com:acme/monorepo &amp;&amp; cd monorepo &amp;&amp; vinos-routine load .</code>
      </div>
    </li>
  </ol>
</section>

<section class="audience-section" id="cli">
  <h2>The CLI</h2>
  <div class="model-usage" style="margin-top: var(--space-md);">
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine list</span>
      <span class="model-usage-desc">All routines + next-run + last status</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine enable &lt;name&gt;</span>
      <span class="model-usage-desc">Activate the systemd timer</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine run &lt;name&gt;</span>
      <span class="model-usage-desc">Ad-hoc run, streams to stdout</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine logs &lt;name&gt; --tail</span>
      <span class="model-usage-desc">Per-routine execution log</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine cost --today</span>
      <span class="model-usage-desc">Ledger summary + top spenders</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine create &lt;name&gt;</span>
      <span class="model-usage-desc">Scaffold a new routine from a template</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine load &lt;path&gt;</span>
      <span class="model-usage-desc">Install all routines in a repo's <code>.vinos/routines.yaml</code></span>
    </div>
  </div>
  <p class="small-print" style="margin-top: var(--space-md);">
    Full CLI + waybar module + <code>vinos-brief</code> panel:
    <a href="https://github.com/vinpatel/vinos/blob/main/docs/v2/vinos-routine-spec.md" target="_blank" rel="noopener">vinos-routine-spec.md</a>.
  </p>
</section>

<section class="audience-section" id="build-your-own">
  <h2>Build your own</h2>
  <div class="prose measure">
    <p>
      The spec is short and reads in ten minutes. Two files cover everything:
    </p>
    <ul>
      <li>
        <a href="/spec/"><strong>Routine spec</strong></a> — the single-file TOML the runtime consumes.
      </li>
      <li>
        <a href="/spec/"><strong>routines.yaml spec</strong></a> — the project-scoped bundle you commit next to your code.
      </li>
    </ul>
    <p>
      The runtime is deliberately boring: whitelist-enforced tools, bwrap
      sandbox, atomic writes to the state store, hard budget caps in a
      SQLite ledger, auto-disable after 3 consecutive failures. If it fails,
      you get a mako notification — never a silent drop.
    </p>
  </div>
</section>

<section class="audience-section" id="community">
  <h2>Community-contributed routines</h2>
  <div class="prose measure">
    <p style="color: var(--color-muted);">
      <em>Coming in v2.0.6.</em> The submission flow — <code>vinos-routine
      install &lt;slug&gt;</code>, a public gallery, per-author sponsor
      profiles — lands with the next release. In the meantime, share your
      TOMLs in
      <a href="https://github.com/vinpatel/vinos/discussions/categories/routines" target="_blank" rel="noopener">GitHub Discussions</a>
      and we'll help you get them installed.
    </p>
  </div>
</section>

<section class="audience-section">
  <div class="hero-actions" style="justify-content: flex-start;">
    <a href="https://archive.org/details/vinos-1.1.0-x86_64" class="btn-primary" target="_blank" rel="noopener">Download the ISO</a>
    <a href="/utilities/" class="link-ghost">Utilities reference →</a>
    <a href="/models/" class="link-ghost">The 80/20 router →</a>
  </div>
</section>
