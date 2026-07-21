-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = true
vim.opt.cinoptions:append("l1")
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.statusline:append("%= %w")
vim.opt.updatetime = 300 --this line is not included by default
