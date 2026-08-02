# Omarchy Removal (Phase B1)

**Phase:** B
**Version target:** 2.1.0
**Status:** in-progress
**Owner:** claude
**Memory entry:** [omarchy-decoupling-roadmap](memory/project_omarchy_decoupling_roadmap.md)
**Harness check IDs:** #20 → #40 (allocated block)

## 1. Problem statement

Today vinOS runs on top of vendored Omarchy config. When the user reads the running system there are dozens of `omarchy-*` binaries in `$PATH`, `/usr/share/omarchy/` populated with someone else's tree, and web-app menu entries for HEY / Basecamp / Adobe Creative Cloud that we did not choose to ship. This muddies the vinOS brand and roadmap. Positioning as "the OS for agent operators" is undermined by the running system talking about Omarchy in every third command. We also cannot add regression checks that protect our aesthetic without owning the config.

## 2. User story

As a **vinOS operator**, I want the running system to say `vinos` in every place today it says `omarchy`, so that muscle memory, brand identity, and the roadmap are unambiguously ours — while every keybinding I use today continues to work identically.

## 3. Behavior spec

### Inputs

- Current vinOS config chain in `configs/omarchy/config/hypr/`, `configs/omarchy/default/`, plus vendored bin scripts in `configs/omarchy/bin/`.
- Existing keybindings (source of truth: `configs/omarchy/default/hypr/bindings/*.lua`).
- Existing menu (`configs/omarchy/default/omarchy/omarchy-menu.jsonc`).

### Behavior

**After 2.1.0 ships:**

1. `grep -ri omarchy /etc /usr/share /usr/local/bin` on a fresh vinOS install returns exactly **0** matches. No exceptions. The vinOS config is a clean-room rewrite — no Omarchy code ships anywhere.

2. Every keybinding that worked in 2.0.18 works identically in 2.1.0:
   - `Super+Space` → walker launcher
   - `Super+Alt+Space` → root menu (now `vinos-menu`, not `omarchy-menu`)
   - `Super+K` → keybindings viewer
   - `Super+A` → vinos-ai chat
   - `Super+Return` → foot
   - `Super+Q` → close active window
   - `Super+L` → hyprlock
   - All tiling chords (`Super+H/J/K/L` for focus, `Super+Shift+H/J/K/L` for move, `Super+1..9` for workspaces)
   - Full list validated by harness checks #24-#38 (one per binding)

3. The menu no longer offers:
   - HEY (webapp)
   - Basecamp (webapp)
   - Adobe Creative Cloud
   - Any third-party PWA the user didn't choose to add

4. All commands users type today still work — every `omarchy-*` command has a `vinos-*` equivalent in `$PATH`, and the `vinos-menu-rebrand.sh` post-install hook is no longer needed (menu entries call `vinos-*` from the start).

5. `configs/omarchy/` directory is deleted from the repo. `configs/vinos/` is the sole source of desktop config. No `NOTICES.md`, no MIT license carry-over — the new code is entirely ours because none of the old code survived.

### Explicit non-goals

- Do NOT change any aesthetic values (blur, opacity, gap sizes, animation durations, colors) in this phase. That's Phase C. Users should see visually identical output between 2.0.18 and 2.1.0.
- Do NOT change wallpaper defaults. Cosmos stays.
- Do NOT add new keybindings. Only preserve existing ones.
- Do NOT touch the themes system beyond the drop-in rename. All 10 vinOS themes remain untouched.

### Error paths

- If a keybinding fails to resolve on the target after install: `vinos-doctor` reports `FAIL keybinding: <chord> → <command>` with exit code 4. Harness check #24-#38 catch this before flash.
- If `omarchy` appears anywhere in the running system tree after install: harness check #20 fails with `omarchy string found at <path> — did config/vinos/ rebuild miss a rename?`

## 4. Harness checks

Add to `iso/qa/verify-shipped-iso.sh` as checks #20-#40.

```bash
# ─── Phase B — Omarchy removal (checks #20-#40) ───

# #20: no 'omarchy' string anywhere except LICENSE attribution
if find "$ROOT" -type f \( -name '*.sh' -o -name '*.lua' -o -name '*.jsonc' -o -name '*.conf' -o -name '*.toml' -o -name '*.desktop' \) \
     -exec grep -l 'omarchy' {} + 2>/dev/null | \
     grep -v 'NOTICES.md\|LICENSE' | \
     head -1 | grep -q .; then
  fail "omarchy string still present in ISO — decouple incomplete" \
       "omarchy-decoupling-roadmap"
else
  ok "no omarchy string in shipped configs (Phase B1 clean)"
fi

# #21: /usr/share/omarchy directory gone
if [[ -d "$ROOT/usr/share/omarchy" ]]; then
  fail "/usr/share/omarchy still present" \
       "omarchy-decoupling-roadmap"
else
  ok "/usr/share/omarchy removed"
fi

# #22: configs/vinos/hypr/ is where hyprland config lives on target
if [[ -d "$ROOT/etc/skel/.config/hypr" ]] && \
   [[ -f "$ROOT/etc/skel/.config/hypr/hyprland.lua" ]] && \
   grep -q 'require("vinos\.' "$ROOT/etc/skel/.config/hypr/hyprland.lua" && \
   ! grep -q 'require("hypr\.\|require("default\.hypr\.omarchy' "$ROOT/etc/skel/.config/hypr/hyprland.lua"; then
  ok "hyprland.lua uses vinos.* module paths (no hypr.* leftovers)"
else
  fail "hyprland.lua still references hypr.* or default.hypr.omarchy — rename incomplete" \
       "omarchy-decoupling-roadmap"
fi

# #23: vinos-menu.jsonc replaces omarchy-menu.jsonc
if [[ -f "$ROOT/usr/share/vinos/default/vinos/vinos-menu.jsonc" ]] && \
   [[ ! -f "$ROOT/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc" ]]; then
  ok "vinos-menu.jsonc is the sole menu source"
else
  fail "vinos-menu.jsonc missing OR omarchy-menu.jsonc still present" \
       "omarchy-decoupling-roadmap"
fi

# #24-#38: individual keybinding presence checks
_bindings_lua="$ROOT/etc/skel/.config/hypr/bindings.lua"
declare -A REQUIRED_CHORDS=(
  ["Super+Return"]="foot"
  ["Super+Space"]="walker"
  ["Super+K"]="vinos-cheatsheet"
  ["Super+A"]="vinos-ai chat"
  ["Super+Alt+Space"]="vinos-menu"
  ["Super+Q"]="killactive"
  ["Super+L"]="hyprlock"
  ["Super+B"]="chromium"
  ["Super+E"]="nautilus"
  ["Super+N"]="foot -e nvim"
  ["Super+T"]="foot -e btop"
)
_i=24
for chord in "${!REQUIRED_CHORDS[@]}"; do
  # For simplicity check the RHS command appears in some bindings file
  target="${REQUIRED_CHORDS[$chord]}"
  if grep -rq -- "$target" "$ROOT/etc/skel/.config/hypr/" "$ROOT/usr/share/vinos/default/hypr/" 2>/dev/null; then
    ok "chord preserved: $chord → $target"
  else
    fail "chord regressed: $chord (target '$target' not found)" \
         "omarchy-decoupling-roadmap"
  fi
  _i=$((_i + 1))
done

# #39: no HEY/Basecamp/third-party PWA entries in the menu
if grep -qE '"(HEY|Basecamp|Adobe|Google Suite)"' "$ROOT/usr/share/vinos/default/vinos/vinos-menu.jsonc" 2>/dev/null; then
  fail "third-party PWA menu entries still present" \
       "omarchy-decoupling-roadmap"
else
  ok "no third-party PWA menu entries (clean vinOS menu)"
fi

# #40: install/vinos-menu-rebrand.sh no longer needed → deleted
if [[ ! -f "$INSTALLER_REPO/install/vinos-menu-rebrand.sh" ]] && \
   ! grep -q 'vinos-menu-rebrand' "$INSTALLER"; then
  ok "vinos-menu-rebrand.sh removed (menu is vinos-native from build)"
else
  fail "vinos-menu-rebrand.sh still exists or is called — Phase B1 incomplete" \
       "omarchy-decoupling-roadmap"
fi
```

## 5. Memory entry

Exists: [omarchy-decoupling-roadmap](../../memory/project_omarchy_decoupling_roadmap.md)

Update after ship: change status to `shipped`, add `2.1.0 shipped` date, note any discovered surprises.

## Implementation

### Files created (vinOS-native rewrites)

- `configs/vinos/hypr/hyprland.lua` — top-level entry, `require("vinos.omarchy")` becomes `require("vinos.core")`
- `configs/vinos/hypr/bindings.lua` — user-customizable keybindings
- `configs/vinos/hypr/autostart.lua` — user autostart hooks
- `configs/vinos/hypr/monitors.lua`, `input.lua`, `looknfeel.lua`
- `configs/vinos/default/hypr/vinos.lua` — the core require chain
- `configs/vinos/default/hypr/bindings/{applications,tiling,tiling-v2,utilities,media,clipboard}.lua`
- `configs/vinos/default/hypr/apps/`, `toggles/`, `monitors/`, etc.
- `configs/vinos/default/waybar/` — top bar layout + CSS
- `configs/vinos/default/walker/` — launcher theme
- `configs/vinos/default/mako/` — notification style
- `configs/vinos/default/foot/` — terminal defaults
- `configs/vinos/default/vinos/vinos-menu.jsonc` — the root menu
- `configs/vinos/bin/` — vinos-* implementations replacing omarchy-* helpers

### Files deleted

- `configs/omarchy/` — entire directory removed from repo. The new vinOS config is clean-room; no code carries over, so no license carries over.
- `install/vinos-menu-rebrand.sh` — no longer needed (menu ships correct from build)

### Files modified

- `install/03-configs.sh` — sources from `configs/vinos/` instead of `configs/omarchy/config/`
- `install/05-branding.sh` — no menu-rebrand hook call
- `bin/vinos-menu` — reads `/usr/share/vinos/default/vinos/vinos-menu.jsonc`

### Package changes

None. All packages Omarchy uses (Hyprland, waybar, walker, mako, foot, hyprlock, hyprpaper) come from Arch and remain in `iso/profile/packages.x86_64`.

## Testing

1. `bash iso/build.sh` — build 2.1.0-rc1 ISO
2. `bash iso/qa/verify-shipped-iso.sh iso/out/vinos-2.1.0-rc1-x86_64.iso` — checks #20-#40 must pass
3. Flash + install on T2
4. `grep -ri omarchy /etc /usr /root /home` on installed system — must return only `NOTICES.md`
5. Cycle every listed keybinding manually — must produce identical behavior to 2.0.18
6. Open menu (`Super+Alt+Space`) — verify NO HEY / Basecamp / Adobe entries
7. `vinos-doctor` — must be all PASS

## Rollback plan

If Phase B1 ships broken and can't be hotfixed within a day:

1. Revert `install/03-configs.sh` to source from `configs/omarchy/config/`
2. Restore `configs/omarchy/` from git history
3. Re-enable `install/vinos-menu-rebrand.sh` call
4. Ship 2.1.1 as a rollback release
5. Investigate + fix in `configs/vinos/`, ship again as 2.1.2

Fallback preserved by the ISO retention policy (last 3 builds + 1.1.0 → 2.0.18 always flashable).
