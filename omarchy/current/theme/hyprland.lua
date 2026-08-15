-- Lua equivalent of the published Aether Hyprland theme override.
local active_border_color = "rgb(ebae6c)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
    },
  },
  group = {
    col = {
      border_active = active_border_color,
    },
  },
})
