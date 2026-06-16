-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- 1. Create the Pure Black / Transparent overrides
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    -- The Pure Black Hack
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

    -- Kill the gray cursor line
    vim.api.nvim_set_hl(0, "CursorLine", { bg = "#111111" })

    -- Clean up the status line
    vim.api.nvim_set_hl(0, "lualine_c_normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "StatusLine", { bg = "none" })
  end,
})

-- 2. Lock in the built-in darkblue theme
vim.cmd.colorscheme("darkblue")
