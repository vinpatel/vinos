/* experiential.js — homepage interactions
 * 5 modules, one file, no deps, no framework, no bundler.
 *   1. hero parallax (0.5× wallpaper scroll)
 *   2. theme re-skinner (chip strip → CSS custom properties on :root)
 *   3. interactive router (slider + SVG particles)
 *   4. cost ticker (living ledger, 500 ms tick)
 *   5. scroll-driven day timeline (IntersectionObserver reveal + marker)
 *
 * Every module honors prefers-reduced-motion and is a no-op if its host
 * element is absent, so this file is safe to load on every page.
 */
(function () {
  'use strict';

  var REDUCED = window.matchMedia &&
                window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var $  = function (sel, ctx) { return (ctx || document).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); };

  /* ══════════════════ 1. hero parallax ══════════════════ */
  function initHeroParallax() {
    var hero = $('[data-exp-hero]');
    if (!hero || REDUCED) return;
    var ticking = false;
    function update() {
      var rect = hero.getBoundingClientRect();
      // Only animate while hero is in / near viewport (perf).
      if (rect.bottom < -200 || rect.top > window.innerHeight + 200) {
        ticking = false; return;
      }
      var offset = Math.max(-200, Math.min(200, -rect.top * 0.5));
      hero.style.setProperty('--hero-parallax', offset + 'px');
      ticking = false;
    }
    function onScroll() {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(update);
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    update();
  }

  /* ══════════════════ 2. theme re-skinner ══════════════════ */
  var THEME_KEY = 'vinos.theme';
  // Map palette keys → CSS variable names on :root.
  var THEME_VARS = {
    bg:       ['--bg-0'],
    bgDark:   ['--bg-1'],
    bgLight:  ['--bg-2', '--bg-3'],
    fg:       ['--fg-0'],
    fgDark:   ['--fg-1'],
    accent:   ['--accent', '--color-accent'],
    green:    ['--success'],
    yellow:   ['--warning'],
    red:      ['--danger'],
    muted:    ['--line', '--line-strong']
  };

  function applyTheme(slug) {
    var themes = window.VINOS_THEMES || {};
    var t = themes[slug];
    var root = document.documentElement;
    if (!t) {
      // Reset — clear every var we set, drop attribute.
      Object.keys(THEME_VARS).forEach(function (k) {
        THEME_VARS[k].forEach(function (v) { root.style.removeProperty(v); });
      });
      root.style.removeProperty('--accent-ink');
      root.removeAttribute('data-theme');
      return;
    }
    Object.keys(THEME_VARS).forEach(function (k) {
      var v = t[k]; if (!v) return;
      THEME_VARS[k].forEach(function (cssVar) { root.style.setProperty(cssVar, v); });
    });
    // Accent-ink = dark for light modes, teal-ink for dark.
    root.style.setProperty('--accent-ink', t.mode === 'light' ? '#0a0d12' : '#062736');
    root.setAttribute('data-theme', slug);
    root.setAttribute('data-theme-mode', t.mode || 'dark');
  }

  function initReskinner() {
    var wrap = $('[data-exp-reskin]');
    if (!wrap) return;
    var chips  = $$('.reskin-chip', wrap);
    var preview = $('[data-reskin-preview]', wrap);
    var previewImg = preview && preview.querySelector('img');
    var previewName = preview && preview.querySelector('.reskin-preview-name');
    var activeOut = $('[data-reskin-active]', wrap);

    function paintChips() {
      var themes = window.VINOS_THEMES || {};
      chips.forEach(function (chip) {
        var slug = chip.getAttribute('data-theme');
        var t = themes[slug]; if (!t) return;
        var sw = chip.querySelector('.reskin-chip-swatch');
        if (sw) sw.style.background = 'linear-gradient(135deg,' + t.bg + ' 0%,' + t.bg + ' 50%,' + t.accent + ' 50%,' + t.accent + ' 100%)';
      });
    }

    function setActive(slug) {
      chips.forEach(function (c) {
        var is = c.getAttribute('data-theme') === slug;
        c.setAttribute('aria-selected', is ? 'true' : 'false');
        c.classList.toggle('is-active', is);
      });
      if (activeOut) activeOut.textContent = slug ? 'Active: ' + slug : '';
    }

    chips.forEach(function (chip) {
      var slug = chip.getAttribute('data-theme');
      var isReset = chip.hasAttribute('data-theme-reset');
      chip.addEventListener('click', function () {
        if (isReset) {
          applyTheme(null); setActive(null);
          try { localStorage.removeItem(THEME_KEY); } catch (e) {}
        } else {
          applyTheme(slug); setActive(slug);
          try { localStorage.setItem(THEME_KEY, slug); } catch (e) {}
        }
      });
      chip.addEventListener('mouseenter', function () {
        var url = chip.getAttribute('data-preview');
        if (preview && previewImg && url) {
          previewImg.src = url;
          previewName.textContent = slug || '';
          preview.classList.add('is-visible');
        }
      });
      chip.addEventListener('mouseleave', function () {
        if (preview) preview.classList.remove('is-visible');
      });
      chip.addEventListener('focus', function () {
        var url = chip.getAttribute('data-preview');
        if (preview && previewImg && url) {
          previewImg.src = url; previewName.textContent = slug || '';
          preview.classList.add('is-visible');
        }
      });
      chip.addEventListener('blur', function () {
        if (preview) preview.classList.remove('is-visible');
      });
    });

    paintChips();
    var saved = null;
    try { saved = localStorage.getItem(THEME_KEY); } catch (e) {}
    if (saved && window.VINOS_THEMES && window.VINOS_THEMES[saved]) {
      applyTheme(saved); setActive(saved);
    }
  }

  /* ══════════════════ 3. interactive router ══════════════════ */
  function initRouter() {
    var wrap = $('[data-exp-router]'); if (!wrap) return;
    var slider = $('[data-router-threshold]', wrap);
    var out    = $('[data-router-threshold-out]', wrap);
    var svgOut = $('[data-router-svg-threshold]', wrap);
    var localPct   = $('[data-router-svg-local-pct]', wrap);
    var premiumPct = $('[data-router-svg-premium-pct]', wrap);
    var localCt  = $('[data-router-count-local]', wrap);
    var premCt   = $('[data-router-count-premium]', wrap);
    var costOut  = $('[data-router-cost]', wrap);
    var reset    = $('[data-router-reset]', wrap);
    var layer    = $('[data-router-particles]', wrap);
    var pathL    = $('#rli-path-local', wrap);
    var pathP    = $('#rli-path-premium', wrap);
    if (!slider || !layer || !pathL || !pathP) return;

    var state = { local: 0, premium: 0, cost: 0, threshold: 20 };
    var particles = [];
    var lastEmit = 0;
    var running = !REDUCED; // reduced-motion → static; slider still updates counters via a synthetic tick

    function updateThreshold(v) {
      state.threshold = Math.max(0, Math.min(100, +v || 0));
      out.textContent = String(state.threshold);
      if (svgOut) svgOut.textContent = state.threshold + '%';
      if (localPct) localPct.textContent = (100 - state.threshold) + '% · local';
      if (premiumPct) premiumPct.textContent = state.threshold + '% · escalate';
    }
    function refresh() {
      localCt.textContent = state.local;
      premCt.textContent  = state.premium;
      costOut.textContent = state.cost.toFixed(2);
    }
    function emit() {
      var roll = Math.random() * 100;
      var premium = roll < state.threshold;
      if (premium) {
        state.premium++;
        state.cost += 0.01 + Math.random() * 0.04;
      } else {
        state.local++;
      }
      refresh();
      if (!running) return;
      var path = premium ? pathP : pathL;
      var color = premium ? 'var(--accent)' : 'var(--success)';
      var c = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      c.setAttribute('r', '3.2');
      c.setAttribute('fill', color);
      c.setAttribute('opacity', '0.9');
      layer.appendChild(c);
      particles.push({ el: c, path: path, len: path.getTotalLength(),
                       t: 0, speed: premium ? 0.45 : 0.75 });
    }
    function tick(ts) {
      if (!lastEmit) lastEmit = ts;
      if (running && ts - lastEmit > 250) { // ~4 particles/s
        emit(); lastEmit = ts;
      }
      // advance particles
      for (var i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        p.t += p.speed / 60; // frame-normalised
        if (p.t >= 1) { p.el.remove(); particles.splice(i, 1); continue; }
        var pt = p.path.getPointAtLength(p.t * p.len);
        p.el.setAttribute('cx', pt.x);
        p.el.setAttribute('cy', pt.y);
        p.el.setAttribute('opacity', 0.9 * (1 - p.t * 0.4));
      }
      window.requestAnimationFrame(tick);
    }

    slider.addEventListener('input', function () { updateThreshold(slider.value); });
    reset && reset.addEventListener('click', function () {
      state.local = 0; state.premium = 0; state.cost = 0;
      particles.forEach(function (p) { p.el.remove(); });
      particles.length = 0;
      refresh();
    });

    updateThreshold(slider.value);
    refresh();
    if (!REDUCED) window.requestAnimationFrame(tick);
    // Reduced-motion: no particles, but the slider still updates the labels
    // and clicking reset zeroes counters. We also seed a synthetic sample so
    // the numbers aren't stuck at 0.
    if (REDUCED) { for (var i = 0; i < 100; i++) emit(); refresh(); }
  }

  /* ══════════════════ 4. cost ticker ══════════════════ */
  function initCostTicker() {
    var wrap = $('[data-exp-cost]'); if (!wrap) return;
    var routedOut  = $('[data-cost-routed]', wrap);
    var fullOut    = $('[data-cost-full]', wrap);
    var savedOut   = $('[data-cost-saved]', wrap);
    var pctOut     = $('[data-cost-pct]', wrap);
    var runsOut    = $('[data-cost-runs]', wrap);
    var premRunsOut= $('[data-cost-premium-runs]', wrap);
    var reset      = $('[data-cost-reset]', wrap);
    var pause      = $('[data-cost-pause]', wrap);
    var state = { runs: 0, premiumRuns: 0, routed: 0, full: 0 };
    var running = true;
    var timer = null;

    function paint() {
      routedOut.textContent = state.routed.toFixed(2);
      fullOut.textContent   = state.full.toFixed(2);
      var saved = Math.max(0, state.full - state.routed);
      savedOut.textContent  = saved.toFixed(2);
      pctOut.textContent    = state.full > 0
        ? Math.round((saved / state.full) * 100)
        : 0;
      runsOut.textContent   = state.runs;
      premRunsOut.textContent = state.premiumRuns;
    }
    function tick() {
      state.runs++;
      // Full-premium: every routine costs 0.01-0.05.
      var fullCost = 0.01 + Math.random() * 0.04;
      state.full += fullCost;
      // Routed: 20% chance we actually paid it.
      if (Math.random() < 0.2) {
        state.routed += fullCost;
        state.premiumRuns++;
      }
      paint();
    }
    function start() {
      if (timer) return;
      timer = window.setInterval(tick, 500);
      if (pause) pause.textContent = 'pause';
    }
    function stop() {
      if (!timer) return;
      clearInterval(timer); timer = null;
      if (pause) pause.textContent = 'resume';
    }

    reset && reset.addEventListener('click', function () {
      state = { runs: 0, premiumRuns: 0, routed: 0, full: 0 }; paint();
    });
    pause && pause.addEventListener('click', function () {
      running = !running; running ? start() : stop();
    });

    paint();
    // Only tick when the ticker is on-screen to avoid off-tab CPU burn.
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting && running) start(); else stop();
        });
      }, { threshold: 0.1 }).observe(wrap);
    } else {
      start();
    }
  }

  /* ══════════════════ 5. scroll-driven day timeline ══════════════════ */
  function initDayTimeline() {
    var wrap = $('[data-exp-daytimeline]'); if (!wrap) return;
    var events = $$('.day-scroll-event', wrap);
    var marker = $('[data-day-marker]', wrap);
    if (!('IntersectionObserver' in window)) {
      // Fallback: reveal everything.
      events.forEach(function (e) { e.classList.add('is-in'); });
      return;
    }

    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add('is-in');
          if (!REDUCED && marker) {
            var pct = parseFloat(e.target.getAttribute('data-pct')) || 0;
            marker.style.top = pct + '%';
            marker.classList.add('is-live');
          }
        }
      });
    }, { threshold: 0.35, rootMargin: '0px 0px -20% 0px' });

    events.forEach(function (e) { io.observe(e); });
  }

  /* ══════════════════ 6. routine playback ══════════════════ */
  // Scripted playback of a day-brief routine. Terminal types the command,
  // trace lines fade in on a timer, brief panel populates line-by-line.
  // prefers-reduced-motion → dump everything at once. IntersectionObserver
  // → auto-play once when scrolled into view (first time only).
  var PB_TRACE = [
    { txt: '→ routine    day-brief',                                   d: 120 },
    { txt: '→ schedule   0 6 * * *          (daily · 06:00 local)', d: 90 },
    { txt: '→ model      llama3.1:8b          (local · ollama)',    d: 90 },
    { txt: '→ tools      calendar, inbox, github, weather',            d: 90 },
    { txt: '',                                                              d: 60 },
    { txt: '✓ context assembled       (3 sources · 412 tokens)',  d: 260, cls: 'ok' },
    { txt: '✓ agent step 1/3           llama3.1:8b · 0.8s',       d: 340, cls: 'ok' },
    { txt: '✓ agent step 2/3           llama3.1:8b · 1.1s',       d: 340, cls: 'ok' },
    { txt: '✓ agent step 3/3           llama3.1:8b · 0.6s',       d: 300, cls: 'ok' },
    { txt: '✓ rendered brief           → ~/.local/state/vinos/brief.md', d: 240, cls: 'ok' },
    { txt: '',                                                              d: 40 }
  ];
  var PB_BRIEF = [
    { h: 1, t: 'Today · Fri 25 Jul' },
    { h: 2, t: 'Top 3' },
    { l: '1. Ship v2.0.5 ISO to dl.vinos.computer' },
    { l: '2. Review 3 open PRs on vinpatel/vinos' },
    { l: '3. Draft the routines.yaml spec' },
    { h: 2, t: 'Signals' },
    { l: '• 1 new sponsor via GitHub' },
    { l: '• 4 stars overnight' },
    { l: '• 2 issues opened (labels: enhancement, docs)' },
    { h: 2, t: 'Reflect' },
    { l: 'Yesterday you shipped $0.30 in local-model savings.' }
  ];

  function initPlayback() {
    var wrap = $('[data-exp-playback]'); if (!wrap) return;
    var stream = $('[data-playback-stream]', wrap);
    var cursor = $('[data-playback-cursor]', wrap);
    var brief  = $('[data-playback-brief]', wrap);
    var briefStatus = $('[data-playback-brief-status]', wrap);
    var playBtn = $('[data-playback-play]', wrap);
    var playLbl = $('[data-playback-play-label]', wrap);
    var pauseBtn= $('[data-playback-pause]', wrap);
    var skipBtn = $('[data-playback-skip]', wrap);
    if (!stream || !cursor || !brief || !playBtn) return;

    var CMD = 'vinos-routine run day-brief';
    var timers = [];
    var state = { running: false, done: false, paused: false, autoPlayed: false };

    function clearTimers() {
      timers.forEach(function (t) { clearTimeout(t); });
      timers.length = 0;
    }
    function reset() {
      clearTimers();
      state.running = false; state.done = false; state.paused = false;
      stream.innerHTML = '<span class="prompt">$</span> ';
      stream.appendChild(cursor);
      brief.innerHTML = '';
      briefStatus.textContent = 'waiting…';
      playLbl.textContent = 'Play';
    }
    function writeLine(text, cls) {
      // Insert a text line before the cursor.
      var span = document.createElement('span');
      if (cls) span.className = cls;
      span.textContent = text;
      stream.insertBefore(span, cursor);
      stream.insertBefore(document.createTextNode('\n'), cursor);
    }
    function writeChar(ch) {
      stream.insertBefore(document.createTextNode(ch), cursor);
    }
    function renderBriefEntry(entry) {
      var el;
      if (entry.h === 1)       { el = document.createElement('h4'); el.textContent = entry.t; el.className = 'pb-brief-h1'; }
      else if (entry.h === 2)  { el = document.createElement('h5'); el.textContent = entry.t; el.className = 'pb-brief-h2'; }
      else                     { el = document.createElement('p');  el.textContent = entry.l; el.className = 'pb-brief-l'; }
      el.classList.add('pb-brief-in');
      brief.appendChild(el);
    }
    function dumpAll() {
      // Reduced-motion / skip path — render everything instantly.
      clearTimers();
      stream.innerHTML = '';
      var p = document.createElement('span'); p.className = 'prompt'; p.textContent = '$';
      stream.appendChild(p);
      stream.appendChild(document.createTextNode(' ' + CMD + '\n'));
      PB_TRACE.forEach(function (line) {
        if (!line.txt) { stream.appendChild(document.createTextNode('\n')); return; }
        var s = document.createElement('span');
        if (line.cls) s.className = line.cls;
        s.textContent = line.txt;
        stream.appendChild(s);
        stream.appendChild(document.createTextNode('\n'));
      });
      var tail = document.createElement('span'); tail.className = 'prompt'; tail.textContent = '$';
      stream.appendChild(tail);
      stream.appendChild(document.createTextNode(' '));
      stream.appendChild(cursor);
      brief.innerHTML = '';
      PB_BRIEF.forEach(renderBriefEntry);
      briefStatus.textContent = 'ready';
      state.done = true; state.running = false;
      playLbl.textContent = 'Play again';
    }
    function schedule(fn, ms) {
      var t = setTimeout(function () {
        // filter self out
        var i = timers.indexOf(t); if (i >= 0) timers.splice(i, 1);
        fn();
      }, ms);
      timers.push(t);
    }
    function play() {
      if (state.running || state.done) {
        if (state.done) reset();
        else return;
      }
      state.running = true; playLbl.textContent = 'Playing…';
      briefStatus.textContent = 'running…';
      if (REDUCED) { dumpAll(); return; }

      // Type the command char-by-char.
      var i = 0;
      function typeNext() {
        if (i >= CMD.length) {
          writeChar('\n');
          schedule(traceStep(0), 260);
          return;
        }
        writeChar(CMD.charAt(i++));
        schedule(typeNext, 30);
      }
      typeNext();
    }
    function traceStep(idx) {
      return function () {
        if (idx >= PB_TRACE.length) {
          // Start rendering the brief; the tail prompt lands last.
          briefStatus.textContent = 'rendered';
          renderBriefStep(0)();
          return;
        }
        var line = PB_TRACE[idx];
        if (line.txt) writeLine(line.txt, line.cls);
        else writeChar('\n');
        schedule(traceStep(idx + 1), line.d);
      };
    }
    function renderBriefStep(idx) {
      return function () {
        if (idx >= PB_BRIEF.length) {
          writeLine('$ ', 'prompt');
          // The literal "$ " above wrote a newline; drop the trailing NL so
          // the caret sits on that prompt line.
          if (stream.lastChild && stream.lastChild.nodeType === 3 && stream.lastChild.textContent === '\n') {
            stream.removeChild(stream.lastChild);
          }
          state.done = true; state.running = false;
          playLbl.textContent = 'Play again';
          return;
        }
        renderBriefEntry(PB_BRIEF[idx]);
        schedule(renderBriefStep(idx + 1), 180);
      };
    }

    playBtn.addEventListener('click', play);
    pauseBtn && pauseBtn.addEventListener('click', function () {
      if (state.done || !state.running) return;
      // Simple pause: cancel pending timers; a subsequent Play resumes with a
      // fresh run (documented in the label). Keeps the state machine simple.
      clearTimers(); state.running = false; state.paused = true;
      playLbl.textContent = 'Resume';
    });
    skipBtn && skipBtn.addEventListener('click', function () { dumpAll(); });

    // Auto-play once when the section scrolls into view.
    if ('IntersectionObserver' in window && !REDUCED) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting && !state.autoPlayed) {
            state.autoPlayed = true;
            play();
            io.disconnect();
          }
        });
      }, { threshold: 0.35 });
      io.observe(wrap);
    }

    // Header/hero anchor clicks: scroll here and trigger play if idle.
    $$('[data-exp-scroll-play]').forEach(function (a) {
      a.addEventListener('click', function () {
        // Delay slightly so the scroll settles before the autotype starts.
        window.setTimeout(function () {
          if (!state.running && !state.done) play();
          else if (state.done) { reset(); play(); }
        }, 500);
      });
    });
  }

  /* ══════════════════ 7. hero life — waybar clock + agent activity ══════════════════
     Makes the hero feel like an operating system managing agents for a
     startup founder. Live clock, rotating agent-activity strip in the
     waybar center, cycling notification toast, ambient live-typing at
     the terminal tail prompt. Small, cheap, no dependencies. */
  var HERO_AGENTS = [
    { app: 'day-brief',        note: 'rendered · 3 priorities · $0.00',  money: '$0.00' },
    { app: 'pr-review',        note: 'reviewed 4 PRs · escalated 1',     money: '$0.03' },
    { app: 'inbox-triage',     note: 'triaged 12 emails · 0 urgent',     money: '$0.00' },
    { app: 'evening-shutdown', note: 'wrote day-log · $0.30 saved',      money: '$0.00' },
    { app: 'research-recap',   note: 'read 2 papers · 4 cards generated',money: '$0.00' }
  ];
  var HERO_TAIL_LINES = [
    'checking github…',
    'reading inbox…',
    'thinking (llama3.1)…',
    'ollama warm · idle',
    ''
  ];
  function initHeroLife() {
    var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    // Live waybar clock — updates every 30s (cheap, no visible jitter).
    var clock = $('[data-hwb-clock]');
    if (clock) {
      var tick = function () {
        var d = new Date();
        var h = String(d.getHours()).padStart(2, '0');
        var m = String(d.getMinutes()).padStart(2, '0');
        clock.textContent = h + ':' + m;
      };
      tick();
      window.setInterval(tick, 30 * 1000);
    }

    // Rotating agent activity in the waybar center: cycles through
    // HERO_AGENTS every 5s, updates the app name + money delta.
    var waybarApp   = $('.home-hero-waybar .hwb-app');
    var waybarMoney = $('.home-hero-waybar .hwb-money');
    // Rotating notification: same source, refreshes toast body every 8s
    // in-place so it feels like a running mako. Small opacity dip on
    // change to signal freshness.
    var toast       = $('.hos-toast');
    var toastTitle  = $('.hos-toast-title');
    var toastNote   = $('.hos-toast-note');
    var idx = 0;
    function bumpAgent() {
      idx = (idx + 1) % HERO_AGENTS.length;
      var a = HERO_AGENTS[idx];
      if (waybarApp && waybarMoney) {
        waybarApp.firstChild && (waybarApp.firstChild.textContent = a.app + ' · rendered · ');
        waybarMoney.textContent = a.money;
      }
      if (toast && toastTitle && toastNote) {
        toast.style.opacity = '0.35';
        window.setTimeout(function () {
          toastTitle.textContent = a.app + ' ready';
          // Rebuild note with accent spans around counts / money.
          var n = a.note
            .replace(/(\d+)\s+priorit/,   '<span class="accent">$1</span> priorit')
            .replace(/(\d+)\s+PRs?/,      '<span class="accent">$1</span> PRs')
            .replace(/(\d+)\s+email/,     '<span class="accent">$1</span> email')
            .replace(/(\d+)\s+urgent/,    '<span class="accent">$1</span> urgent')
            .replace(/(\d+)\s+paper/,     '<span class="accent">$1</span> paper')
            .replace(/(\d+)\s+card/,      '<span class="accent">$1</span> card')
            .replace(/\$(\d+\.\d+)/g,     '<span class="accent">$$$1</span>');
          toastNote.innerHTML = n;
          toast.style.opacity = '1';
        }, 220);
      }
    }
    if (!reduced && (waybarApp || toast)) {
      window.setInterval(bumpAgent, 5000);
    }

    // Ambient tail-prompt activity in the mock terminal: pseudo-typing
    // that rotates HERO_TAIL_LINES with a caret. Small — the routine-
    // playback below the fold is the real animation; this is atmosphere.
    var live = $('[data-hos-live]');
    if (live && !reduced) {
      var lineIdx = 0, charIdx = 0, dwell = 0, dir = 1;
      function step() {
        var target = HERO_TAIL_LINES[lineIdx];
        if (dir === 1) {
          // Typing
          if (charIdx <= target.length) {
            live.textContent = target.slice(0, charIdx);
            charIdx += 1;
          } else {
            dwell += 1;
            if (dwell > 20) { dir = -1; dwell = 0; }
          }
        } else {
          // Erasing
          if (charIdx > 0) {
            charIdx -= 1;
            live.textContent = target.slice(0, charIdx);
          } else {
            lineIdx = (lineIdx + 1) % HERO_TAIL_LINES.length;
            dir = 1;
          }
        }
      }
      window.setInterval(step, 110);
    }
  }

  /* ══════════════════ boot ══════════════════ */
  function boot() {
    initHeroParallax();
    initHeroLife();
    initReskinner();
    initRouter();
    initCostTicker();
    initDayTimeline();
    initPlayback();
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
