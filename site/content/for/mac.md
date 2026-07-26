---
title: "vinOS for Intel Macs"
description: "Turn a 2018–2020 T2 MacBook Apple stopped caring about into an AI workstation. linux-t2 baked in. Wi-Fi, keyboard, trackpad, Touch Bar — first boot."
url: "/for/mac/"
---

<section class="audience-hero">
  <span class="audience-eyebrow">for <span class="accent">Intel Mac owners</span></span>
  <h1>Apple stopped caring about your Mac. <span class="accent">We didn't.</span></h1>
  <p class="audience-lede">
    That 2018–2020 MacBook Pro with the T2 chip — the one macOS 15 dropped —
    is still a perfectly good machine. It just needs an OS that acknowledges
    the T2 exists. vinOS ships the <code>linux-t2</code> kernel <em>in the ISO
    itself</em>: keyboard, trackpad, Wi-Fi, and Touch Bar work from the moment
    the live USB boots.
  </p>
</section>

<section class="audience-section">
  <h2>Why installing Linux on a T2 Mac has been a nightmare.</h2>
  <ul class="audience-pain">
    <li>
      <h3>The stock Arch kernel doesn't talk to the T2.</h3>
      <p>Boot vanilla Arch and you get: no Wi-Fi, no keyboard, no trackpad. You need <code>linux-t2</code>, <code>apple-bcm-firmware</code>, and a specific <code>brcmfmac</code> feature-disable mask before the machine is usable.</p>
    </li>
    <li>
      <h3>The firmware scavenger hunt is real.</h3>
      <p>Your Wi-Fi chip needs a symlink from <code>brcm/brcmfmac4364b3-pcie.txt</code> to your specific model. Get it wrong and the driver crashes at 5GHz. Every T2 model has a different quirk.</p>
    </li>
    <li>
      <h3>Suspend is a whole other saga.</h3>
      <p>Upstream <code>apple-bce</code> + <code>hci_bcm4377</code> quirks. The blog posts contradict each other. Every kernel bump might break it again.</p>
    </li>
  </ul>
</section>

<section class="audience-section">
  <h2>What we did <span class="accent">so you don't have to.</span></h2>
  <ul class="audience-solutions">
    <li>
      <h3>The T2 recipe, verified.</h3>
      <p>8 items — <code>linux-t2</code>, <code>apple-bcm-firmware</code>, <code>wireless-regdb</code>, iwd Country, brcmfmac feature-disable, model-specific firmware symlinks, T2 initramfs modules, cfg80211 cmdline. Wi-Fi associates on the first boot of the live USB.</p>
    </li>
    <li>
      <h3>Touch Bar, on Linux.</h3>
      <p><code>tiny-dfr</code> ships in the base. Escape / function keys / brightness / volume all work. Not identical to macOS, but functional out of the box.</p>
    </li>
    <li>
      <h3>Command key as Super.</h3>
      <p><code>hid_apple fnmode=2</code> + <code>swap_opt_cmd=0</code> — F-row acts like F-keys, ⌘ acts like Super. Muscle memory transfers. No remap script required.</p>
    </li>
    <li>
      <h3>Verified on real hardware, not just docs.</h3>
      <p>vinOS is boot-tested on a 2019 MacBook Pro (T2, MacBookPro15,4). Wi-Fi, keyboard, trackpad, Touch Bar all green.</p>
    </li>
  </ul>
</section>

<section class="audience-proof">
  <figure>
    <img src="/img/for/mac-doctor.png" alt="vinos-doctor detecting Apple T2 hardware"
         onerror="this.onerror=null;this.src='/img/screenshots/01-desktop.png';">
    <figcaption>First-boot detection on a 2019 MacBook Pro. <code>hardware profile · t2mac (MacBookPro15,4)</code> · <code>t2 firmware · ok · 0.1-4</code> · <code>touchbar · ok · tiny-dfr</code>.</figcaption>
  </figure>
</section>

<section class="audience-cta">
  <h2>Fifteen minutes to a <span class="accent">Linux Mac.</span></h2>
  <p class="audience-cta-note">
    Flash the ISO, boot with <kbd>Option</kbd> held, pick the USB. The T2 kernel is the default boot entry — no menu-picking required. Full T2 guide: <a href="/install/">install docs</a>.
  </p>
  <div class="hero-actions">
    <a href="{{< param isoURL >}}" class="btn-primary" target="_blank" rel="noopener">Download vinOS v{{< param version >}}</a>
    <a href="/install/" class="link-ghost">Read the T2 install path →</a>
    <a href="https://github.com/vinpatel/vinos/discussions" class="link-ghost" target="_blank" rel="noopener">Join the T2 discussion</a>
  </div>
  <p class="small-print" style="margin-top: var(--space-md); font-family: var(--font-mono); font-size: var(--text-xs); color: var(--color-muted);">
    <strong>Known limits:</strong> Touch ID doesn't work under Linux (Apple never released the drivers). Suspend is unreliable upstream — we document the workarounds. Everything else does.
  </p>
</section>
