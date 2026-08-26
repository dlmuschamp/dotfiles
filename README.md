# Dotfiles

This repository contains the configuration files and custom automation scripts for my Omarchy (Arch Linux) environment. It serves as a live backup and a sync point for eventually migrating this configuration to a desktop setup.

## Configurations

Quality-of-life enhancements, keybindings, and theming for my core workflow tools:

* **Terminal & Multiplexer:** Alacritty, Tmux
* **Editor & Viewer:** Neovim, Doom Emacs, Sioyek
* **Wayland & UI:** Hyprland Lua configuration, Omarchy's Quickshell UI,
  Hyprlock, and Hypridle
* **Writing:** Org mode with Typst math (see [`doom/README.md`](doom/README.md))

The Omarchy runtime supplies the rice engine, menus, hardware panels, OSD,
notifications, and polkit UI. This repository supplies the authoritative
personal configuration. Omarchy's preinstalled applications, system
provisioners, theme packs, screensaver, background switcher, and branded lock
screen are not enabled.

## Deployment

Run the bootstrap from any checkout location:

```sh
./bootstrap
```

It pins the user-space Omarchy runtime under `~/.local/share/omarchy`, then
symlinks the tracked configurations into `~/.config`, personal commands into
`~/.local/bin`, and the tracked font files into `~/.local/share/fonts`.
Existing non-symlinked targets are moved to timestamped backups rather than
overwritten.

After bootstrap (or whenever the greeter drifts), install the tracked SDDM
theme and login PAM policy (needs sudo / fingerprint once):

```sh
dotfiles-pam-login
dotfiles-sddm-install
```

Hyprlock and the desktop both read
`~/.local/state/omarchy/current/background`. The SDDM greeter copies that
same image into its theme as `background.jpg`.

Required Arch packages:

```text
quickshell jq hyprlock hypridle hyprsunset hyprpicker inotify-tools
xdg-terminal-exec nautilus ttf-jetbrains-mono-nerd noto-fonts-emoji
gnome-themes-extra
```

GTK apps follow dark mode via the tracked `gtk-3.0/` and `gtk-4.0/`
`settings.ini` overrides (`prefer-dark` + `Adwaita-dark`). Bootstrap clones
[ubuntu/yaru](https://github.com/ubuntu/yaru) into `~/.local/src/ubuntu-yaru`
and installs the Yaru icon flavors Omarchy themes reference (including
`Yaru-magenta`) under `~/.local/share/icons`.

The bar, menus, and panels draw their icons from Nerd Font private-use
codepoints, and `fontconfig/fonts.conf` points the `monospace` alias at
`JetBrainsMono Nerd Font` so those glyphs resolve. `fonts/omarchy.ttf` supplies
the menu glyph.

Log out and back in after the first deployment so UWSM loads the tracked
environment.

## Custom Automations (`automations/`)

The automation stack is actively being refactored to use **event-driven hardware interrupts** rather than resource-heavy polling daemons.

* **Bluetooth Audio Daemon (`epoll_manager`):** A custom Linux-native C daemon utilizing `epoll` that listens to BlueZ D-Bus signals. Upon connection or disconnection of specific headsets (like the Moondrop Edge or Aria), it safely forks a Bash script to seamlessly route Pipewire audio sinks, apply device-specific parametric EQs via EasyEffects, and dispatch Spotify to a designated Hyprland workspace.
* **Legacy Polling (`hardwareListener.sh`):** Shell scripts managing power profiles based on battery percentage and toggling a "tablet" mode (currently being migrated to the event-driven architecture).

## Typst Workflow (`bin/typst`)

A custom shell wrapper that streamlines typesetting. Running `typst [document_name]` automatically scaffolds the file from a core template (`typst/templates/write_up.typ`) and spins up side-by-side instances of Neovim and Sioyek for live-preview editing.

## Future Plans

* Create a dedicated desktop branch while keeping `main` for the active laptop configuration.
* Complete the migration of all legacy polling scripts to the new C-based `epoll` interrupt system.
