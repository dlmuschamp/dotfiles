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

### Notifications

Desktop notifications are rendered by **omarchy-shell** (Quickshell), not mako or
dunst. `graphical-session.target` pulls in `mako.service` even when it is
disabled, and mako usually wins the race for `org.freedesktop.Notifications` at
login. When that happens, popups appear to work but omarchy-shell never
registers as the notification server — so dismiss/invoke shortcuts and
screenshot edit toasts silently fail.

`./bootstrap` masks and stops `mako.service` so omarchy-shell can own the dbus
name. `mako` is also omitted from `packages/native.txt` for the same reason.

Keybindings (from `hypr/bindings.lua`):

| Shortcut | Action |
| --- | --- |
| `Super + ,` | Dismiss last notification |
| `Super + Shift + ,` | Dismiss all notifications |
| `Super + Ctrl + ,` | Toggle do not disturb |
| `Super + Alt + ,` | Invoke last notification (e.g. open screenshot in Tensaku) |
| `Super + Shift + Alt + ,` | Notification history |

After a screenshot (`Print`), the toast includes a click action and the
`Super + Alt + ,` shortcut both run `tensaku-edit` on the saved file.

**If notifications misbehave after an upgrade or login**, check who owns the
dbus name and restart the shell:

```sh
busctl --user list | grep Notifications   # should show quickshell, not mako
systemctl --user is-enabled mako          # should be masked
./bootstrap                                 # re-apply the mako mask
pkill -f 'quickshell.*omarchy'              # autostart relaunches omarchy-shell
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
good idea to close all browser windows," over and over — even in Zen safe mode,
while a private window worked fine.

**Root cause:** stale Outlook *site data* in the normal profile, not extensions
or missing cookies. OWA boots against localStorage (including
`olk-login_hint_claim_*`), IndexedDB, service workers at `/mail/sw.js`, and
Outlook cookies left from earlier sessions. A fresh Stanford SAML token
disagrees with that cached identity and OWA calls `logoutRedirect()`. Private
windows work because they start with none of this state. Safe mode does not
help because it only disables extensions; the poisoned site data is still there.

Two Firefox anti-tracking mechanisms also widen the margins around Outlook's
auth flow and are pinned in `zen/user.js`:

* **Bounce Tracking Protection** classifies `login.microsoftonline.com` as a
  bounce tracker and can purge its session cookies on a timer. `user.js`
  disables it.
* **Total Cookie Protection** partitions the hidden `login.microsoftonline.com`
  iframe that OWA uses to silently renew its token. Cookie exceptions in
  `permissions.sqlite` prevent that.

Cookie exceptions are not expressible as prefs, so `bin/zen-sso-fix` applies
them on every run. Zen must be fully closed when it runs.

**Recovery** — clears Outlook cookies, localStorage, IndexedDB, and service
workers for OWA hosts only. Your AAD, Stanford, and Duo cookies survive, so
this should not cost a password prompt or Duo push:

```sh
zen-sso-fix          # default: Outlook site data + cookies
zen-sso-fix --deep   # widen to every Microsoft origin if the default is not enough
```

**Daily use** — always open mail at the `/mail/` path, never the bare domain:

```sh
zen-outlook              # open https://outlook.office.com/mail/ in a new tab
zen-outlook --recover    # quit Zen, run zen-sso-fix, reopen mail
```

If the sign-out page returns, quit Zen and run `zen-outlook --recover` (or
`zen-sso-fix` then reopen manually). Do not disable cookies for Outlook — that
breaks SSO entirely.

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
