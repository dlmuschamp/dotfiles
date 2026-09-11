return {
  {
    "omacom/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#1d2021",
        dark_bg    = "#161819",
        darker_bg  = "#0f1011",
        lighter_bg = "#343637",

        fg         = "#d4be98",
        dark_fg    = "#9f8f72",
        light_fg   = "#dac8a7",
        bright_fg  = "#dfceb2",
        muted      = "#32302f",

        red        = "#ea6962",
        yellow     = "#d8a657",
        orange     = "#ed807a",
        green      = "#a9b665",
        cyan       = "#89b482",
        blue       = "#7daea3",
        purple     = "#d3869b",
        brown      = "#8e4d49",

        bright_red    = "#ea6962",
        bright_yellow = "#d8a657",
        bright_green  = "#a9b665",
        bright_cyan   = "#89b482",
        bright_blue   = "#7daea3",
        bright_purple = "#d3869b",

        accent               = "#7daea3",
        cursor               = "#d4be98",
        foreground           = "#d4be98",
        background           = "#1d2021",
        selection             = "#343637",
        selection_foreground = "#d4be98",
        selection_background = "#343637",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
