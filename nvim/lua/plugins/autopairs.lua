return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = function()
    local autopairs = require("nvim-autopairs")

    autopairs.setup({
      check_ts = true, -- Use Treesitter to check for context (like not pairing inside strings)
      disable_filetype = { "TelescopePrompt" },
      fast_wrap = {
        map = "<M-e>", -- Alt-e to wrap the word after the cursor in pairs
      },
    })
  end,
}
