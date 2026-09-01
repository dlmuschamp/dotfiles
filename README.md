# Dotfiles

This repository contains the configuration files and custom automation scripts for my Omarchy (Arch Linux) environment. It serves as a live backup and a sync point for eventually migrating this configuration to a desktop setup.

## Configurations

Quality-of-life enhancements, keybindings, and theming for my core workflow tools:

* **Terminal & Multiplexer:** Alacritty, Tmux
* **Editor & Viewer:** Neovim, Doom Emacs, Sioyek
* **Wayland & UI:** Hyprland Lua configuration, Omarchy's Quickshell UI,
  Hyprlock, and Hypridle
* **Writing:** Org mode with Typst math, plus clean LaTeX PDF export for
  write-ups and essays (see [`doom/README.md`](doom/README.md))

The Omarchy runtime supplies the rice engine, menus, hardware panels, OSD,
notifications, and polkit UI. This repository supplies the authoritative
personal configuration. Omarchy's preinstalled applications, system
provisioners, theme packs, screensaver, background switcher, and branded lock
screen are not enabled.

## Provisioning a new machine

`./provision` takes a fresh Arch install to this environment end to end:
packages first, then the symlink layout. It is idempotent, so running it on an
existing machine only fills in what is missing.

```sh
git clone https://github.com/dlmuschamp/dotfiles ~/dotfiles
cd ~/dotfiles && ./provision --hardware --services
```

| Flag | Effect |
| --- | --- |
| `--hardware` | Also install `packages/native-hardware.txt` (AMD laptop specific) |
| `--no-aur` | Skip `yay` and every AUR package |
| `--services` | Enable SDDM, NetworkManager, Bluetooth and ufw |
| `--yes` | Do not pause for confirmation |

Package sets are plain newline-delimited manifests under `packages/`:
`native.txt` for portable official-repo packages, `native-hardware.txt` for
kernel, firmware and GPU packages that should be reviewed on different hardware,
and `aur.txt` for AUR packages. `yay` is absent from `aur.txt` because provision
builds it from source first. Regenerate the candidate lists with `pacman -Qqen`
and `pacman -Qqem`.

Provision ends by printing the few steps that still need a human, notably the
SDDM/PAM installers and the Zen profile setup below.

## Deployment

To deploy configuration only, without touching packages, run the bootstrap from
any checkout location:

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

Required packages are tracked in `packages/` and installed by `./provision`.

Desktop notifications are handled by omarchy-shell (not mako or dunst).
`./bootstrap` masks `mako.service` so it cannot steal
`org.freedesktop.Notifications` at login; without that, Super+, Super+Alt+,
and screenshot edit toasts (`tensaku-edit` via the notification click) silently
fail because the keybindings talk to omarchy-shell while mako shows the popups.

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

## Zen (`zen/`)

Zen stores prefs inside a profile directory whose name is randomized per
install, so `bootstrap` resolves the active profile from `profiles.ini` and
links `zen/user.js` into it. Launch Zen once on a new machine to create the
profile, then re-run `./bootstrap`.

`user.js` carries only the SSO workaround described below. Bookmarks, saved
passwords and extensions are account data and are deliberately not stored in
this repo; pull them down with Zen Sync instead.

### The Microsoft SSO logout loop

Signing in to Outlook would land on "You're signed out of your account. It's a
good idea to close all browser windows," over and over. Two Firefox
anti-tracking mechanisms were the cause, neither of which Brave applies to
Microsoft login domains:

* **Bounce Tracking Protection** classifies `login.microsoftonline.com` as a
  bounce tracker, since a working SSO redirect passes through it without any
  user interaction, and purges its session cookies on a timer. `user.js`
  disables it.
* **Total Cookie Protection** partitions the hidden `login.microsoftonline.com`
  iframe that OWA uses to silently renew its token. The renewal fails and OWA
  responds by logging the session out entirely.

Cookie exceptions are not expressible as prefs, so the second half of the fix
lives in `bin/zen-sso-fix`, which writes permanent allow rules into the
profile's `permissions.sqlite`. Zen must be closed when it runs:

```sh
zen-sso-fix
```

## Maintenance (`bin/dotfiles-update`)

```sh
dotfiles-update            # interactive full upgrade: repos, AUR, cache, Doom
dotfiles-update --check    # unprivileged check, notify only, changes nothing
```

A weekly user timer (`systemd/user/dotfiles-update.timer`, Sundays at 11:00)
runs `--check` and sends a desktop notification with the pending update counts.
It deliberately does not upgrade unattended: Arch upgrades occasionally need a
human for a manual intervention posted to Arch news, a `.pacnew` merge, or a
kernel bump that wants a reboot, and an interrupted `pacman -Syu` leaves the
system half-upgraded. The check is unprivileged because `checkupdates` and
`yay -Qua` both work against a throwaway copy of the pacman database, so no
`sudoers` exception is needed.

The upgrade path also runs `doom sync`, since Emacs packages pin to the Emacs
version and a bumped `emacs-wayland` otherwise leaves Doom throwing
native-compilation errors.

## Custom Automations (`automations/`)

The automation stack is actively being refactored to use **event-driven hardware interrupts** rather than resource-heavy polling daemons.

* **Bluetooth Audio Daemon (`epoll_manager`):** A custom Linux-native C daemon utilizing `epoll` that listens to BlueZ D-Bus signals. Upon connection or disconnection of specific headsets (like the Moondrop Edge or Aria), it safely forks a Bash script to seamlessly route Pipewire audio sinks, apply device-specific parametric EQs via EasyEffects, and dispatch Spotify to a designated Hyprland workspace.
* **Legacy Polling (`hardwareListener.sh`):** Shell scripts managing power profiles based on battery percentage and toggling a "tablet" mode (currently being migrated to the event-driven architecture).

## Typst Workflow (`bin/typst`)

A custom shell wrapper that streamlines typesetting. Running `typst [document_name]` automatically scaffolds the file from a core template (`typst/templates/write_up.typ`) and spins up side-by-side instances of Neovim and Sioyek for live-preview editing.

## Future Plans

* Create a dedicated desktop branch while keeping `main` for the active laptop configuration.
* Complete the migration of all legacy polling scripts to the new C-based `epoll` interrupt system.
