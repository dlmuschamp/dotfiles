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

    -- Custom rule for Typst Math ($)
    -- This ensures that when you type $, it gives you $$ and puts you in the middle.
    local Rule = require("nvim-autopairs.rule")
    local cond = require("nvim-autopairs.conds")

    autopairs.add_rules({
      Rule("$", "$", "typst")
        -- Don't pair if the next character is already a $
        :with_pair(cond.not_after_regex("$"))
        -- Don't pair if we are in a code block
        :with_pair(cond.not_before_regex("```", 3)),
    })
  end,
}
