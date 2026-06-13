-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("lazy").setup("plugins")
require("lspconfig").tinymist.setup({})
vim.opt.number = true
vim.opt.relativenumber = true

-- Auto-save on TextChange or leaving Insert mode
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  pattern = { "*.typ" },
  command = "silent! write",
})
vim.opt.statusline:append("%= %w")
vim.opt.updatetime = 300 --this line is not included by default
