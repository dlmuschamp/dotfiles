-- Personal Hyprland entry point. Omarchy supplies the rice runtime; this
-- repository remains authoritative for user-visible behavior and overrides.
local home = os.getenv("HOME")
local omarchy_path = os.getenv("OMARCHY_PATH") or (home .. "/.local/share/omarchy")

dofile(omarchy_path .. "/default/hypr/bootstrap.lua")

require("default.hypr.helpers")
local require_optional = require("default.hypr.require_optional")

-- Import only the Omarchy desktop pieces used by this setup. In particular,
-- do not run Omarchy's provisioning/preinstall autostart.
require("default.hypr.bindings.media")
require("default.hypr.bindings.clipboard")
require("default.hypr.bindings.tiling")
require("default.hypr.envs")
require("default.hypr.looknfeel")
require("default.hypr.input")
require("default.hypr.windows")
require_optional.module("omarchy.current.theme.hyprland")

-- Personal configuration is loaded last and therefore always wins.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("default.hypr.toggles")

-- Published Picture-in-Picture behavior.
o.window({ title = "^(Picture.*picture)$" }, {
  float = true,
  pin = true,
  opacity = 1,
})

-- Keep pen and touch input constrained to the laptop display.
hl.device({
  name = "wacom-hid-53fc-pen",
  output = "eDP-1",
})

hl.device({
  name = "wacom-hid-53fc-finger",
  output = "eDP-1",
})

hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_STYLE_OVERRIDE", "")
hl.env("SSH_AUTH_SOCK", (os.getenv("XDG_RUNTIME_DIR") or "") .. "/keyring/ssh")
