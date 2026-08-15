-- Personal input behavior, ported from the published input.conf.
hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:caps",
    repeat_rate = 40,
    repeat_delay = 600,
    numlock_by_default = true,
    sensitivity = 0.25,

    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true,
      scroll_factor = 0.5,
      disable_while_typing = true,
    },
  },
})

o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
