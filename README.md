# Dotfiles

This repository contains the configuration files and custom automation scripts for my Omarchy (Arch Linux) environment. It serves as a live backup and a sync point for eventually migrating this configuration to a desktop setup.

## Configurations

Quality-of-life enhancements, keybindings, and theming for my core workflow tools:

* **Terminal & Multiplexer:** Alacritty, Tmux
* **Editor & Viewer:** Neovim, Sioyek
* **Wayland & UI:** Hyprland, Waybar, Mako

## Custom Automations (`automations/`)

The automation stack is actively being refactored to use **event-driven hardware interrupts** rather than resource-heavy polling daemons.

* **Bluetooth Audio Daemon (`epoll_manager`):** A custom Linux-native C daemon utilizing `epoll` that listens to BlueZ D-Bus signals. Upon connection or disconnection of specific headsets (like the Moondrop Edge or Aria), it safely forks a Bash script to seamlessly route Pipewire audio sinks, apply device-specific parametric EQs via EasyEffects, and dispatch Spotify to a designated Hyprland workspace.
* **Legacy Polling (`hardwareListener.sh`):** Shell scripts managing power profiles based on battery percentage and toggling a "tablet" mode (currently being migrated to the event-driven architecture).

## Typst Workflow (`bin/typst`)

A custom shell wrapper that streamlines typesetting. Running `typst [document_name]` automatically scaffolds the file from a core template (`typst/templates/write_up.typ`) and spins up side-by-side instances of Neovim and Sioyek for live-preview editing.

## Future Plans

* Create a dedicated desktop branch while keeping `main` for the active laptop configuration.
* Complete the migration of all legacy polling scripts to the new C-based `epoll` interrupt system.
