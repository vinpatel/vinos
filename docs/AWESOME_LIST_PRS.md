# Awesome-list PR playbook

Long-tail passive discovery. Each merged PR = a permanent inbound link from a repo people star. Submit from your own GitHub identity.

## Canonical vinOS entry (copy-paste)

Use this as the base line, trim to each list's format:

> **vinOS** — An agentic Linux distro. Local LLMs + Claude Code one keystroke away. Arch + Hyprland, boots on any x86_64 including T2 Intel Macs. MIT. [`github.com/vinpatel/vinos`](https://github.com/vinpatel/vinos)

Short (one line): `[vinOS](https://github.com/vinpatel/vinos) - Agentic Linux distro: local LLMs + Claude Code one keystroke away. Arch + Hyprland. Boots on T2 Intel Macs.`

## Target lists (highest ROI first)

### 1. `hyprwm/awesome` — official Hyprland awesome-list
- **URL:** https://github.com/hyprwm/awesome
- **File under:** "Distros" or "Setups / rice" (verify current README)
- **Entry:** `[vinOS](https://github.com/vinpatel/vinos) - Arch-based distro with Hyprland preconfigured; boots on x86_64 including T2 Intel Macs; local LLMs + Claude Code one keystroke away.`
- **PR title:** `Add vinOS — Hyprland-preconfigured Arch distro`
- **Why here first:** Small, curated, actively-merged list. Highly relevant audience (Hyprland users are the exact ricing crowd who star distros).

### 2. `awesome-selfhosted/awesome-selfhosted`
- **URL:** https://github.com/awesome-selfhosted/awesome-selfhosted
- **File under:** Uncertain — strict criteria (must be self-hostable service). vinOS is a distro, not a service, so **may be out of scope**. Consider `awesome-selfhosted/awesome-sysadmin` instead if it exists.
- **Skip unless the maintainers explicitly accept OS-level entries.** Low probability of merge, don't waste the PR.

### 3. `t2linux/wiki` (community wiki, not a strict awesome-list)
- **URL:** https://wiki.t2linux.org — check its GitHub source repo
- **File under:** Distros / Recommended installs
- **Entry:** longer-form paragraph noting the 8-item T2 hardware-enablement recipe is baked into the ISO
- **Why:** *The* T2 audience. High conversion.

### 4. `awesome-mac` / macOS-hardware Linux lists
- Search: `awesome-macbook-linux`, `awesome-mac-linux`, `awesome-apple-hardware-linux`
- **Entry:** lead with the T2 angle, mention the specific verified models (memory says 2019 T2 MacBookPro15,3 verified)
- **PR title:** `Add vinOS — Linux distro with T2 Intel Mac support out of the box`

### 5. `awesome-linux-distros` / general Linux distro lists
- Multiple exist (e.g., `friendlyanon/awesome-linux`, `ligurio/awesome-linux`) — verify which is still maintained (merged PRs in last 90 days)
- **File under:** Arch-based derivatives
- **Entry:** standard one-liner

### 6. `awesome-ollama` / local-LLM lists
- Search: `awesome-ollama`, `awesome-local-llm`, `awesome-local-ai`
- **Angle:** vinOS ships Ollama + Claude Code preconfigured with `Super+A` / `Super+Shift+A` — position as "the OS layer of the local-AI stack"
- **PR title:** `Add vinOS — Linux distro with Ollama + Claude Code preconfigured`

### 7. `awesome-agents` / agent-framework lists
- Search: `e2b-dev/awesome-ai-agents`, `slavakurilyak/awesome-ai-agents`
- **Angle:** vinOS as substrate for running agents locally
- **Lower priority** — noisier space, less curated lists.

## PR body template

```markdown
## Adding vinOS

vinOS is an agentic Linux distro — Arch + Hyprland with local LLMs and Claude Code integrated as first-class desktop citizens. Ships as a bootable ISO that works on any x86_64 including Intel T2 Macs (Wi-Fi, keyboard, trackpad, Touch Bar all verified on real hardware).

- Repo: https://github.com/vinpatel/vinos
- Site: https://vinos.computer
- ISO v1.1.0: https://archive.org/details/vinos-1.1.0-x86_64
- License: MIT
- Language: Shell (primary)

I've placed the entry under **<section>** in alphabetical order and matched the surrounding format. Happy to move it if you prefer a different section.

Thanks for maintaining this list — it's how I found several of the tools vinOS bundles.
```

## Batching order (submit over ~10 days, not all at once)

1. Day 1: `hyprwm/awesome` (highest fit, warmest audience)
2. Day 2: t2linux community wiki
3. Day 4: dotfiles-inspiration / ricing lists (if strong fit)
4. Day 6: general Linux distro list (verify maintained first)
5. Day 8+: local-LLM / Ollama lists

**Rationale for spacing:** if all 5 PRs get merged in one day, the star burst is nice — but if 2-3 stall in review for a week, you don't learn from the first before submitting the fifth. Space them; adjust the pitch as you learn.

## Not yet submitted

None of these PRs are drafted or pushed. Repos to fork first, drafts to land in a `awesome-<name>-vinos` branch on each fork.
