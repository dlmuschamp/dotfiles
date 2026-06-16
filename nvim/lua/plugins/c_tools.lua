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
        snippet_engine = "nvim",
      })
    end,
    -- Creating a custom hotkey to trigger the generation
    keys = {
      {
        "<leader>cd",
        -- Force Neogen to ONLY look for functions, never files
        function()
          require("neogen").generate({ type = "func" })
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
  -- 4. Inlay Hint Management
  {
    "neovim/nvim-lspconfig",
    init = function()
      -- 1. Create a clean, custom command so you don't need a hotkey
      vim.api.nvim_create_user_command("ToggleHints", function()
        local current = vim.lsp.inlay_hint.is_enabled()
        vim.lsp.inlay_hint.enable(not current)
      end, {})

      -- 2. Force hints OFF automatically every time you open a file
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          -- Turn off inlay hints for the current buffer
          vim.lsp.inlay_hint.enable(false, { bufnr = args.buf })
        end,
      })
    end,
  },
}
