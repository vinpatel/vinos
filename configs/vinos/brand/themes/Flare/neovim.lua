-- Flare — vinOS Neovim colorscheme pin
-- Uses the tokyonight base as the closest maintained palette parent; v2.1
-- will ship a proper vinOS Neovim theme derived from this palette.
return {
  { "folke/tokyonight.nvim", priority = 1000 },
  { "LazyVim/LazyVim",
    opts = { colorscheme = "tokyonight-nightdark" } },
}
