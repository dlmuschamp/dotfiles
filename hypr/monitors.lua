-- Personal monitor layout.
hl.env("GDK_SCALE", "1")

-- New external displays use their advertised native/preferred mode.
-- Do not use highres: some QHD monitors advertise a 4K/30 input mode.
-- Refresh rates belong in mode, never in position. No artificial 144 Hz cap.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.monitor({ output = "eDP-1", mode = "highres", position = "0x0", scale = 1 })

-- Keep the external display directly left of the laptop at any resolution.
-- The dock/HDMI path currently advertises native 2560x1440 at only 60 Hz.
-- Preferred mode is re-evaluated when reconnecting through another path.
hl.monitor({ output = "DP-1", mode = "preferred", position = "auto-left", scale = 1 })
hl.monitor({ output = "DP-2", mode = "preferred", position = "auto-left", scale = 1.25 })
