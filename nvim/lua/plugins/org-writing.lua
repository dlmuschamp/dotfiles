return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      -- LazyVim extends this list on main and installs missing parsers.
      -- Orgmode owns its Org parser and injection directives. Keep those intact.
      ensure_installed = {
        "matlab",
        "c",
        "cpp",
        "python",
        "javascript",
        "bash",
        "lua",
        "typescript",
        "typst",
        "rust",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Keep the old optional Typst LSP, without requiring it at startup.
        tinymist = { mason = false },
      },
    },
  },
  {
    "nvim-orgmode/orgmode",
    ft = { "org" },
    cmd = { "Org" },
    keys = {
      {
        "<leader>oa",
        function()
          require("orgmode").action("agenda.prompt")
        end,
        desc = "Org agenda",
      },
      {
        "<leader>oc",
        function()
          require("orgmode").action("capture.prompt")
        end,
        desc = "Org capture",
      },
    },
    opts = {
      org_agenda_files = "~/org/**/*.org",
      org_default_notes_file = "~/org/refile.org",
      org_startup_folded = "showeverything",
      -- Orgmode already resolves js/ts and sh/shell in its injection directives.
      -- The directives lowercase names, so C works too, but C++ needs an alias.
      org_edit_src_filetype_map = { ["c++"] = "cpp" },
    },
    config = function(_, opts)
      require("orgmode").setup(opts)
    end,
  },
  {
    name = "org-writing",
    dir = vim.fn.stdpath("config"),
    lazy = false,
    config = function()
      require("config.org-writing").setup()
      require("config.org-snippets")
      require("config.org-plot-export")
    end,
  },
}
