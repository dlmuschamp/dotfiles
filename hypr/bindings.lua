-- Published application bindings. These intentionally override any changing
-- Omarchy defaults and do not install the applications they reference.
o.bind("SUPER + RETURN", "Terminal", [=[uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"]=])
o.bind("SUPER + ALT + RETURN", "Tmux", [=[uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" bash -c "tmux attach || tmux new -s Work"]=])
o.bind("SUPER + SHIFT + RETURN", "Browser", "omarchy-launch-browser")
o.bind("SUPER + SHIFT + F", "File manager", "uwsm-app -- nautilus --new-window")
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", [=[uwsm-app -- nautilus --new-window "$(omarchy-cmd-terminal-cwd)"]=])
o.bind("SUPER + SHIFT + B", "Browser", "omarchy-launch-browser")
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", "omarchy-launch-browser --private")
o.bind("SUPER + SHIFT + M", "Music", "omarchy-launch-or-focus spotify")
o.bind("SUPER + SHIFT + ALT + M", "Music TUI", "omarchy-launch-or-focus-tui cliamp")
o.bind("SUPER + SHIFT + N", "Editor", "omarchy-launch-editor")
o.bind("SUPER + SHIFT + D", "Docker", "omarchy-launch-tui lazydocker")
o.bind("SUPER + SHIFT + G", "Signal", [=[omarchy-launch-or-focus ^signal$ "uwsm-app -- signal-desktop"]=])
o.bind("SUPER + SHIFT + O", "Obsidian", [=[omarchy-launch-or-focus ^obsidian$ "uwsm-app -- obsidian"]=])
o.bind("SUPER + SHIFT + W", "Typora", "uwsm-app -- typora --enable-wayland-ime")
o.bind("SUPER + SHIFT + SLASH", "Passwords", "uwsm-app -- 1password")

o.bind("SUPER + SHIFT + A", "ChatGPT", [=[omarchy-launch-webapp "https://chatgpt.com"]=])
o.bind("SUPER + SHIFT + ALT + A", "Grok", [=[omarchy-launch-webapp "https://grok.com"]=])
o.bind("SUPER + SHIFT + C", "Calendar", [=[omarchy-launch-webapp "https://app.hey.com/calendar/weeks/"]=])
o.bind("SUPER + SHIFT + E", "Email", [=[omarchy-launch-webapp "https://app.hey.com"]=])
o.bind("SUPER + SHIFT + Y", "YouTube", [=[omarchy-launch-webapp "https://youtube.com/"]=])
o.bind("SUPER + SHIFT + ALT + G", "WhatsApp", [=[omarchy-launch-or-focus-webapp WhatsApp "https://web.whatsapp.com/"]=])
o.bind("SUPER + SHIFT + CTRL + G", "Google Messages", [=[omarchy-launch-or-focus-webapp "Google Messages" "https://messages.google.com/web/conversations"]=])
o.bind("SUPER + SHIFT + P", "Google Photos", [=[omarchy-launch-or-focus-webapp "Google Photos" "https://photos.google.com/"]=])
o.bind("SUPER + SHIFT + X", "X", [=[omarchy-launch-webapp "https://x.com/"]=])
o.bind("SUPER + SHIFT + ALT + X", "X Post", [=[omarchy-launch-webapp "https://x.com/compose/post"]=])

-- Omarchy-style menus, without app installation, theme, or background actions.
o.bind("SUPER + SPACE", "Main menu", "omarchy-menu toggle root")
o.bind("SUPER + ALT + SPACE", "Applications", "omarchy-menu toggle apps")
o.bind("SUPER + CTRL + C", "Capture menu", "omarchy-menu toggle capture")
o.bind("SUPER + CTRL + H", "Hardware menu", "omarchy-menu toggle hardware")
o.bind("SUPER + ESCAPE", "System menu", "omarchy-menu toggle system")
o.bind("XF86PowerOff", "Power menu", "omarchy-menu toggle system", { locked = true })
o.bind("SUPER + K", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + ALT + K", "Tmux keybindings", "omarchy-menu-tmux-keybindings")

-- Capture and hardware panels.
o.bind("PRINT", "Screenshot", "omarchy-capture-screenshot")
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + CTRL + B", "Bluetooth", "omarchy-shell shell toggle omarchy.bluetooth")
o.bind("SUPER + CTRL + A", "Audio", "omarchy-shell shell toggle omarchy.audio")
o.bind("SUPER + CTRL + ALT + B", "Battery status", "omarchy-notification-battery")

-- Integrated notification controls.
o.bind("SUPER + comma", "Dismiss last notification", "omarchy-shell notifications dismissOne")
o.bind("SUPER + SHIFT + comma", "Dismiss all notifications", "omarchy-shell notifications dismissAll")
o.bind("SUPER + CTRL + comma", "Toggle do not disturb", "omarchy-toggle-notification-silencing")
o.bind("SUPER + ALT + comma", "Invoke last notification", "omarchy-shell notifications invokeLast")
o.bind("SUPER + SHIFT + ALT + comma", "Notification history", "omarchy-shell notifications showHistory")

-- Reminders are retained.
o.bind("SUPER + CTRL + R", "Set reminder", "omarchy-menu toggle reminder-set")
o.bind("SUPER + CTRL + ALT + R", "Show reminders", "omarchy-reminder show")
o.bind("SUPER + SHIFT + CTRL + R", "Clear reminders", "omarchy-reminder clear")

-- Unbranded local lock screen.
o.bind("SUPER + CTRL + L", "Lock system", "dotfiles-lock", { locked = true })
