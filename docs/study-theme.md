# Automatic readable study themes

Configured October 18, 2026. This is a comfort-oriented starting point, not a medical guarantee.

## Everyday behavior

- **07:00 to 19:59, local laptop time:** Study Day, warm off-white `#F7F5F0`, dark text `#24272E`.
- **20:00 to 06:59:** Study Night, charcoal `#1F2329`, light text `#E2E5E9`.
- A user timer checks once per minute and only applies a theme when needed. It catches up after login or sleep. It does not wake the laptop.
- Alacritty and Doom use **JetBrainsMonoNL Nerd Font Mono Regular, 15 pt**. NL means no programming ligatures. Nerd Font symbols remain available.
- The proportional IBM Plex Sans family and document/math fonts are retained. Screen resolution, scaling, brightness, and the existing night-light schedule are unchanged.
- Wallpaper, zero outside/inter-window gaps, solid windows, and 1-pixel colored borders are preserved.

Omarchy applies the palette to its shell and supported applications. Neovim and Doom have explicit syntax/comment/search colors. GTK desktop preference follows day/night rather than forcing dark all day. Websites and applications with their own appearance overrides may need **System/Automatic** selected once. MATLAB settings and exported figures have not been changed.

Existing terminal windows should reload their theme and font configuration. Applications that cache Fontconfig may need reopening to use the changed family. Doom reads the new configuration on its next startup. No running editor buffers are closed to apply these settings.

**Reopen already-running Neovim/Doom once after this installation** to load the new configuration. Subsequent day/night switches are automatic. Neovim now watches Omarchy's parent directory, so atomic theme replacements are detected even when the loader file itself is unchanged.

## Controls

```sh
study-theme status       # show mode, current theme, target, and hours
study-theme day          # hold light mode until you choose auto again
study-theme night        # hold dark mode until you choose auto again
study-theme auto         # resume scheduled switching and apply current time
study-theme off          # stop automatic changes, leave appearance as-is
study-theme --at 07:00   # dry-run schedule, no changes
```

Hours and theme names are in `~/.config/omarchy/study-theme.toml`. Changes take effect on the next minute without a daemon reload. Times follow the operating system's local timezone, including daylight-saving/timezone changes. No location lookup or ambient-light sensor is used.

While auto mode is active, manually choosing a different Omarchy theme will be corrected on the next timer tick. Run `study-theme off` before choosing an unrelated theme.

```sh
systemctl --user status study-theme.timer
journalctl --user -u study-theme.service -n 30 --no-pager
```

## Disable or roll back

To stop scheduling and return to the previous color theme, keeping the new font:

```sh
systemctl --user disable --now study-theme.timer
study-theme off
theme-colors aether
```

To re-enable:

```sh
systemctl --user enable --now study-theme.timer
study-theme auto
```

The previous terminal family was `BlexMono Nerd Font Mono` at 14.5 pt, and Doom used that family at 14.4 pt. To restore typography, change the Alacritty `[font]` entries, Doom's `luciano/ui-font-family` / `luciano/ui-font-height`, and the generic `monospace` preference in `fontconfig/fonts.conf`. Keep the new Fontconfig **alias** structure rather than the old rule that overrode explicitly requested families.

## Reproduction and checks

`bootstrap` links the command, config directories, and service units. `provision` enables the timer. The already-listed `ttf-jetbrains-mono-nerd` package provides the font. No new font download is required on this laptop.

```sh
PYTHONDONTWRITEBYTECODE=1 python docs/test-study-theme.py
python docs/check-display-palette.py
emacs --batch -Q -l docs/test-doom-study.el
systemd-analyze --user verify systemd/user/study-theme.service systemd/user/study-theme.timer
fc-match 'JetBrainsMonoNL Nerd Font Mono:style=Regular'
```

The contrast checker covers the explicit palette pairs, not every plugin, application, hardcoded TUI color, physical display characteristic, or personal comfort response. See `display-comfort.md` for the original research and exact palette tables.

### Verified on this laptop

- Eight scheduler tests pass, including exact boundaries, midnight-crossing schedules, invalid times, overrides, no-op rechecks, and side-effect-free previews.
- The palette checker passes 32 main/current-line text pairs at 7:1 or better, plus selection/search/border checks.
- Actual day/night desktop switches changed both GNOME preference and portal mode, preserved the wallpaper, and produced no Hyprland config errors. Border width remained 1 and gaps remained 0.
- A real Alacritty startup loaded the requested JetBrains Mono NL regular/bold/italic faces without configuration warnings.
- A real-config headless Neovim instance detected both live switches through the filesystem watcher and reported the exact expected background/comment colors. A pre-existing LazyReload-only approach failed this test and was repaired.
- Two retained Emacs tests pass against installed Doom themes and real palette files, including repeated light/dark transitions, nested hooks, and return to non-study themes. No live GUI Emacs instance was running, so that GUI path was not tested.
- The user timer is enabled and active. Suspend/resume and an overnight physical-use session have not been exercised. Initial state after testing is automatic mode with Study Night selected.
