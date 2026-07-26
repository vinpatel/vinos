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

  /* ══════════════════ boot ══════════════════ */
  function boot() {
    initHeroParallax();
    initReskinner();
    initRouter();
    initCostTicker();
    initDayTimeline();
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
