return {
  -- 1. Function Signature Pop-ups
  {
    "ray-x/lsp_signature.nvim",
    event = "VeryLazy",
    opts = {
      bind = true,
      handler_opts = {
        border = "rounded",
      },
      hint_enable = false, -- Disables the inline virtual text so it doesn't clutter your C code
    },
    config = function(_, opts)
      require("lsp_signature").setup(opts)
    end,
  },

  -- 2. Doxygen Comment Generator
  {
    "danymat/neogen",
    config = function()
      require("neogen").setup({
        snippet_engine = "luasnip", -- Standard engine for most pre-configured setups
      })
    end,
    -- Creating a custom hotkey to trigger the generation
    keys = {
      {
        "<leader>cd",
        function()
          require("neogen").generate()
        end,
        desc = "Generate [C]ode [D]ocstring",
      },
    },
  },
  -- 3. Force-disable Noice's signature help (The Bulletproof Method)
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      -- Intercept Omarchy's existing configuration and forcefully turn off the signature module
      opts.lsp = opts.lsp or {}
      opts.lsp.signature = opts.lsp.signature or {}
      opts.lsp.signature.enabled = false
    end,
  },
}
