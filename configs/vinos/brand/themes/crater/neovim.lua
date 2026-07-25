-- Crater — vinOS Neovim colorscheme pin
-- Uses tokyonight (LazyVim default). Users can swap in their nvim config.
return {
  { "folke/tokyonight.nvim", opts = { style = "storm" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight-storm" } },
}
