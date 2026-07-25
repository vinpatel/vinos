-- Bloom — vinOS Neovim colorscheme pin
-- Uses tokyonight (LazyVim default). Users can swap in their nvim config.
return {
  { "folke/tokyonight.nvim", opts = { style = "day" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight-day" } },
}
