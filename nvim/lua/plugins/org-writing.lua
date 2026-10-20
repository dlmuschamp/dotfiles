return {
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
    end,
  },
}
