return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#010419",
        dark_bg    = "#010313",
        darker_bg  = "#01020d",
        lighter_bg = "#1a1d30",

        fg         = "#E5DBBA",
        dark_fg    = "#aca48c",
        light_fg   = "#e9e0c4",
        bright_fg  = "#ece4cb",
        muted      = "#67696f",

        red        = "#ff8b73",
        yellow     = "#e7bc3f",
        orange     = "#ff9c88",
        green      = "#61bc5c",
        cyan       = "#008e8e",
        blue       = "#5582dc",
        purple     = "#e762d2",
        brown      = "#995e52",

        bright_red    = "#ffa686",
        bright_yellow = "#ffc800",
        bright_green  = "#7ce762",
        bright_cyan   = "#2fb5b5",
        bright_blue   = "#76a4ff",
        bright_purple = "#ea79d7",

        accent               = "#dc5582",
        cursor               = "#E5DBBA",
        foreground           = "#E5DBBA",
        background           = "#010419",
        selection             = "#1a1d30",
        selection_foreground = "#E5DBBA",
        selection_background = "#1a1d30",
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
