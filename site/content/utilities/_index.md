---
title: "Utilities — the vinos-* CLI reference"
description: "Every vinos-* command shipped in the ISO. Founder utilities, agent shortcuts, routine runner, first-run + doctor, hardware helpers, install bundles. One-line description and quick example per row."
url: "/utilities/"
type: "for"
---

<section class="audience-hero">
  <span class="audience-eyebrow">the <span class="accent">vinos-*</span> reference</span>
  <h1>One command per job. <span class="accent">Composable.</span> Boring.</h1>
  <p class="audience-lede">
    vinOS ships ~90 <code>vinos-*</code> bins in <code>/usr/local/bin</code>.
    Each is a plain script — bash or python, no daemons, no magic. Pipe them,
    hook them, read them, replace them. Nothing on this page is undocumented;
    each script's top comment is the source of truth.
  </p>
</section>

<nav class="model-catnav" aria-label="Utility categories">
  <span class="model-catnav-label">Jump to:</span>
  <a href="#founder">Founder</a>
  <a href="#agents">Agents</a>
  <a href="#routines">Routines</a>
  <a href="#system">System</a>
  <a href="#hardware">Hardware</a>
  <a href="#launch">Launch</a>
  <a href="#hyprland">Hyprland</a>
  <a href="#capture">Capture</a>
  <a href="#menus">Menus</a>
  <a href="#install">Install bundles</a>
</nav>

<section class="audience-section" id="founder">
  <h2>Founder utilities</h2>
  <p class="model-cat-lede">The four you'll use daily. Wired into the default keybindings and the routines that ship in the ISO.</p>
  <div class="model-usage">
    <div class="model-usage-row highlight">
      <span class="model-usage-cmd">vinos-standup</span>
      <span class="model-usage-desc">Plain-English daily standup from your git activity. <code>vinos-standup --yesterday</code> · <code>vinos-standup --week</code></span>
    </div>
    <div class="model-usage-row highlight">
      <span class="model-usage-cmd">vinos-commit</span>
      <span class="model-usage-desc">AI-drafted commit message from your staged diff. Edit / Accept / Retry / Quit. <code>vinos-commit -y</code> to skip the prompt.</span>
    </div>
    <div class="model-usage-row highlight">
      <span class="model-usage-cmd">vinos-focus [minutes]</span>
      <span class="model-usage-desc">Enter DND mode for N minutes — notifications muted, mako paused, waybar shows a timer. Default 25.</span>
    </div>
    <div class="model-usage-row highlight">
      <span class="model-usage-cmd">vinos-brief [routine]</span>
      <span class="model-usage-desc">Show today's routine outputs. No arg dumps everything; an argument shows only that routine's latest.</span>
    </div>
  </div>
</section>

<section class="audience-section" id="agents">
  <h2>Agent shortcuts</h2>
  <p class="model-cat-lede">Interactive AI helpers. Pipe stdin in, get plain-English answers back. Route to local or Claude per <code>~/.config/vinos/ai.toml</code>.</p>
  <div class="model-usage">
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-ai [chat|code|prompt]</span>
      <span class="model-usage-desc">Stable CLI over ollama, claude-code, and aichat — one command instead of three tools to remember.</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-fix</span>
      <span class="model-usage-desc">Pipe an error → AI diagnostic + fix suggestion. <code>some-command 2&gt;&amp;1 | vinos-fix</code></span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-explain</span>
      <span class="model-usage-desc">Pipe anything → plain-English explanation. <code>cat script.sh | vinos-explain</code></span>
    </div>
  </div>
</section>

<section class="audience-section" id="routines">
  <h2>Routines</h2>
  <p class="model-cat-lede">The scheduled-agent runtime. Full walkthrough on <a href="/routines/">the routines page</a>.</p>
  <div class="model-usage">
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine list</span>
      <span class="model-usage-desc">All routines + next-run + last status</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine enable &lt;name&gt;</span>
      <span class="model-usage-desc">Activate the systemd user timer for a routine</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine run &lt;name&gt;</span>
      <span class="model-usage-desc">Ad-hoc run of a routine, streaming to stdout</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine cost --today</span>
      <span class="model-usage-desc">Ledger summary — tokens, dollars, top spenders</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-routine load &lt;path&gt;</span>
      <span class="model-usage-desc">Install every routine from a repo's <code>.vinos/routines.yaml</code></span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-brief</span>
      <span class="model-usage-desc">Open today's routine outputs in a walker panel</span>
    </div>
  </div>
</section>

<section class="audience-section" id="system">
  <h2>System</h2>
  <p class="model-cat-lede">Health checks, first-boot flow, menus, hooks.</p>
  <div class="model-usage">
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-doctor</span>
      <span class="model-usage-desc">Health check. Prints PASS/FAIL per check; non-zero exit if anything fails. <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>S</kbd>.</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-first-run</span>
      <span class="model-usage-desc">Finish the install with items that can only run after your first login (services, keys, tuning).</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-menu</span>
      <span class="model-usage-desc">Walker/dmenu-style hub for user actions — installs, wifi, updates, themes. <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>O</kbd>.</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-cheatsheet</span>
      <span class="model-usage-desc">Pretty-print the shipped Hyprland keybindings. Parses <code>~/.config/hypr/hyprland.conf</code> live. <kbd>Super</kbd>+<kbd>K</kbd>.</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-hook [name] [args...]</span>
      <span class="model-usage-desc">Run a named hook from <code>~/.config/vinos/hooks/&lt;name&gt;</code> and the <code>.d/</code> directory.</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-hook-install &lt;type&gt; &lt;path&gt;</span>
      <span class="model-usage-desc">Install a hook into <code>~/.config/vinos/hooks/&lt;type&gt;.d/</code></span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-sudo-keepalive</span>
      <span class="model-usage-desc">Prompt for sudo once; keep the credential alive in the background for long-running installers.</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-notification-send &lt;glyph&gt; &lt;headline&gt; [body]</span>
      <span class="model-usage-desc">Send a desktop notification with a vinOS glyph and correct body spacing.</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-reminder &lt;min&gt; [msg] | show | clear</span>
      <span class="model-usage-desc">Set and show lightweight desktop notification reminders.</span>
    </div>
    <div class="model-usage-row">
      <span class="model-usage-cmd">vinos-restart-waybar</span>
      <span class="model-usage-desc">Restart Waybar cleanly after a config edit.</span>
    </div>
  </div>
</section>

<section class="audience-section" id="hardware">
  <h2>Hardware helpers</h2>
  <p class="model-cat-lede">Small, composable primitives waybar and hyprland call. All safe to script against; each prints one line.</p>

  <h3 style="margin-top: var(--space-lg);">Battery + power</h3>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-battery-status</span><span class="model-usage-desc">Formatted battery status: percentage + power draw/charge.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-battery-capacity</span><span class="model-usage-desc">Battery full capacity in Wh, rounded.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-battery-present</span><span class="model-usage-desc">True if a battery is present on the system.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-battery-remaining-time</span><span class="model-usage-desc">Battery time-to-empty (or full) in a compact format.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-ac-present</span><span class="model-usage-desc">True if AC power is connected.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-powerprofiles-init</span><span class="model-usage-desc">Set the correct power profile on boot based on current AC/battery state.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-powerprofiles-set &lt;level&gt;</span><span class="model-usage-desc">Set the power profile, falling back to <code>balanced</code>.</span></div>
  </div>

  <h3 style="margin-top: var(--space-lg);">Brightness + audio</h3>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-brightness-display &lt;+N%|N%-|N%|off|on&gt;</span><span class="model-usage-desc">Adjust brightness on the most-likely display device.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-brightness-display-apple</span><span class="model-usage-desc">Adjust brightness on Apple Studio + XDR Displays via <code>asdcontrol</code>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-brightness-keyboard</span><span class="model-usage-desc">Adjust keyboard backlight through available steps.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-brightness-keyboard-mute</span><span class="model-usage-desc">Set the mic-mute indicator LED on laptops that expose <code>platform::micmute</code>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-audio-input-mute</span><span class="model-usage-desc">Toggle microphone mute. Drives the hardware mic-mute LED where available.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-audio-output-switch</span><span class="model-usage-desc">Switch between audio outputs while preserving mute status.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-swayosd-brightness</span><span class="model-usage-desc">Show display brightness via SwayOSD on the current monitor.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-swayosd-kbd-brightness</span><span class="model-usage-desc">Show keyboard brightness via SwayOSD on the current monitor.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-swayosd-client</span><span class="model-usage-desc">Wrapper for <code>swayosd-client</code> that targets the focused monitor.</span></div>
  </div>

  <h3 style="margin-top: var(--space-lg);">Reporting</h3>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hw-report</span><span class="model-usage-desc">Markdown hardware report suitable for a GitHub issue or a HARDWARE.md row.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hw-hints</span><span class="model-usage-desc">Detect hardware quirks and post one-shot notifications.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hw-touchpad</span><span class="model-usage-desc">Print the detected Hyprland touchpad or trackpad device name.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hw-external-monitors</span><span class="model-usage-desc">True when an external monitor is physically connected.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-cmd-present &lt;cmd&gt;…</span><span class="model-usage-desc">Check whether all required commands are available.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-cmd-terminal-cwd</span><span class="model-usage-desc">Print the current working directory of the active terminal window.</span></div>
  </div>
</section>

<section class="audience-section" id="launch">
  <h2>Launch helpers</h2>
  <p class="model-cat-lede">Small floating-window launchers for TUIs and pickers. Every one respects your theme and terminal choice.</p>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-launch-wifi</span><span class="model-usage-desc">Open the <code>impala</code> Wi-Fi TUI in a floating foot window. <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>W</kbd>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-launch-bluetooth</span><span class="model-usage-desc">Open the <code>bluetui</code> pairing TUI in a floating window. <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>B</kbd>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-launch-audio</span><span class="model-usage-desc">Open a floating audio mixer (<code>wiremix</code>). <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>U</kbd>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-launch-browser</span><span class="model-usage-desc">Launch the default browser as determined by <code>xdg-settings</code>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-launch-editor &lt;path&gt;</span><span class="model-usage-desc">Launch the default editor from <code>$EDITOR</code> (falls back to nvim).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-launch-tui &lt;cmd&gt;</span><span class="model-usage-desc">Launch a TUI command in the default terminal with vinOS styling.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-launch-walker</span><span class="model-usage-desc">Launch Walker and ensure its Elephant data provider is running.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-launch-webapp &lt;url&gt;</span><span class="model-usage-desc">Launch a URL as a web app in the default supported browser.</span></div>
  </div>
</section>

<section class="audience-section" id="hyprland">
  <h2>Hyprland integration</h2>
  <p class="model-cat-lede">Monitor + window helpers wired into the shipped Hyprland config.</p>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-toggle</span><span class="model-usage-desc">Toggle permanent Hyprland flags by copying them into a directory sourced entirely.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-toggle-enabled / -disabled</span><span class="model-usage-desc">Companion helpers for the toggle pipeline.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-monitor-focused</span><span class="model-usage-desc">Print the currently focused monitor name.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-monitor-focused-apple</span><span class="model-usage-desc">Apple-Display-aware variant of the above.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-monitor-internal</span><span class="model-usage-desc">Print the internal display name.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-monitor-internal-mirror</span><span class="model-usage-desc">Mirror the internal display to any external.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-monitor-scaling-cycle</span><span class="model-usage-desc">Cycle scaling factors (1.0 / 1.25 / 1.5 / 2.0) on the focused monitor.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-monitor-watch</span><span class="model-usage-desc">React to monitor hotplug events (used by the systemd hook).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-window-close-all</span><span class="model-usage-desc">Close every window on the current workspace.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-window-gaps-toggle</span><span class="model-usage-desc">Toggle gaps on/off for zen-mode work.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-window-pop</span><span class="model-usage-desc">Pop the focused window into a temporary floating overlay.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-window-single-square-aspect-toggle</span><span class="model-usage-desc">Toggle single-square aspect for the focused window (useful for pinned utilities).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-window-transparency-toggle</span><span class="model-usage-desc">Toggle transparency on the focused window.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-hyprland-workspace-layout-toggle</span><span class="model-usage-desc">Cycle workspace layouts (dwindle ↔ master).</span></div>
  </div>
</section>

<section class="audience-section" id="capture">
  <h2>Screen capture</h2>
  <p class="model-cat-lede">Screenshots + OCR. All output routes to the clipboard by default; keep them piped-composable.</p>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-capture-screenshot</span><span class="model-usage-desc">Take a screenshot (region → annotate → clipboard). <kbd>Super</kbd>+<kbd>P</kbd>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-capture-text-extraction</span><span class="model-usage-desc">OCR the selected region and copy plain text to the clipboard.</span></div>
  </div>
</section>

<section class="audience-section" id="menus">
  <h2>Walker menu primitives</h2>
  <p class="model-cat-lede">One-shot pickers for scripts and hyprland bindings.</p>
  <div class="model-usage">
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-menu-select</span><span class="model-usage-desc">Pick one option from stdin using Walker.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-menu-file</span><span class="model-usage-desc">Pick a file with Walker.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-menu-keybindings</span><span class="model-usage-desc">Interactive search of your Hyprland keybindings.</span></div>
  </div>
</section>

<section class="audience-section" id="install">
  <h2>Install bundles</h2>
  <p class="model-cat-lede">Opt-in package sets. Each bundle is idempotent — safe to re-run. Full list: <a href="/bundles/">the bundles page</a>.</p>
  <div class="model-usage">
    <div class="model-usage-row highlight"><span class="model-usage-cmd">vinos-install-ai</span><span class="model-usage-desc">Ollama, llama.cpp, huggingface-cli, python-{openai,anthropic,torch}, aichat, open-webui, CUDA (on NVIDIA).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-browser</span><span class="model-usage-desc">Chromium (base) plus firefox/brave alternatives.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-comms</span><span class="model-usage-desc">Chat, video, and file-share apps (Signal, Slack, Zoom, Discord).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-dev</span><span class="model-usage-desc">Server + devops + language runtimes (postgres, docker, jdk, rust, go, mise).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-disk</span><span class="model-usage-desc">One-command installer from the live ISO to a disk. Wraps <code>archinstall</code> with a hardware-aware preset.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-gaming</span><span class="model-usage-desc">Steam, Lutris, gamemode, mangohud, protontricks.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-media</span><span class="model-usage-desc">mpv, kdenlive, obs-studio, imv, pinta, gpu-screen-recorder, spotify.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-office</span><span class="model-usage-desc">LibreOffice + Thunderbird.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-productivity</span><span class="model-usage-desc">Notes + writing tools (obsidian, notion, typora, 1password).</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-once</span><span class="model-usage-desc">First-boot wrapper — launches <code>vinos-welcome</code> from a Hyprland <code>exec-once</code>.</span></div>
    <div class="model-usage-row"><span class="model-usage-cmd">vinos-install-common</span><span class="model-usage-desc">Shared helpers sourced by every <code>vinos-install-*</code> bundle. Not run directly.</span></div>
  </div>
</section>

<section class="audience-section">
  <div class="prose measure">
    <p class="small-print">
      Missing something? Every script lives at
      <a href="https://github.com/vinpatel/vinos/tree/main/bin" target="_blank" rel="noopener">bin/</a>
      in the repo — the top comment of each file is authoritative. If a
      description here drifts from the script, file an issue and we'll fix
      the page.
    </p>
  </div>
</section>
