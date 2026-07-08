# Prior art

vinOS borrows several install-time patterns and desktop-config choices
from other Arch-based projects. This file documents that chain of
credit so the MIT license's attribution requirement is satisfied.

- **Overlay/fork architecture** — the layered installer with base
  scripts (01–09) and overlay scripts (10–99), plus config shadowing,
  is a common pattern in Arch-based personal distros. vinOS's specific
  Three Rules formulation is original.
- **Curated app + Hyprland desktop set** — hypridle, hyprlock,
  hyprpicker, hyprsunset, walker, swayosd, satty, mako, foot,
  waybar, iwd/impala, plus Yaru icons and Kvantum Qt theming. These
  packages, and the specific keybinding conventions around them
  (`Super+Ctrl+W` for wifi, `Super+P` for annotated screenshot,
  `Super+Space` for the launcher), are conventions established by
  upstream Arch + Hyprland community distros.

If you spot an omission, open an issue. This file is source of truth
for attribution.
