-- Personal monitor layout, ported from the published monitors.conf.
hl.env("GDK_SCALE", "1")

-- USB C Monitors
hl.monitor({ output = "eDP-1", mode = "highres", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-1", mode = "highres", position = "auto", scale = 1.5 })
hl.monitor({ output = "DP-2", mode = "highres", position = "auto", scale = 1.5 })

-- TV Monitor. Newest kernel breaks 4k so swapped to 1080@120hz
-- 4K@60 (highres) flakes on Krackan HDMI; 1080p is stable on this LG TV.
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@120", position = "auto", scale = 1 })
