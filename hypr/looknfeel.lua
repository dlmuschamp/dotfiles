-- Personal rice overrides, ported from the published looknfeel.conf.
hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 1,
  },

  decoration = {
    rounding = 0,
    -- Solid windows: wallpaper stays behind them, not bleeding through.
    -- Set both to e.g. 0.92 if you want a light frosted look later.
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    dim_inactive = false,
    dim_strength = 0,
  },

  animations = {
    enabled = true,
  },
})
