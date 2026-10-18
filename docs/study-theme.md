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

## Syntax discrimination follow-up, October 18 at 16:49 local time

The original 7:1 checks established text/background contrast, not how easily syntax roles could be distinguished. In response to the user's report that colors looked too similar, Study Day now uses a more chromatic palette and additional weight cues:

| Role | Light color | Editor treatment |
|---|---|---|
| Keywords | Raspberry `#8F005F` | Bold |
| Functions and calls | Blue `#0031A9` | Bold |
| Strings | Green `#005700` | Regular |
| Numbers/constants | Ochre-brown `#684200` | Regular |
| Types | Violet `#5F00A5` | Regular |
| Errors | Red `#990000` | Bold indicators, existing diagnostic underlines |
| Comments | Slate `#454B54` | Upright, normal weight, not faint |
| Variables/operators/punctuation | `#24272E` | Neutral, regular |

Both study editors have selective keyword/function emphasis. Night hues are unchanged. The ANSI cyan slot follows the type role, so in Study Day it is deliberately violet rather than literal cyan. This avoids the old green/teal grouping but is not a guarantee that every third-party TUI will respect semantic roles.

Selection is now blue `#ADC8E6`; search matches are gold `#EBC45C`. Their background contrasts against the canvas increased from **1.19 to 1.58** and **1.27 to 1.53**, respectively. These are visibility improvements, not claims of a 3:1 non-text contrast certification. Selected/search text remains dark and exceeds 7:1.

All eight listed text roles still exceed **7:1** on both the canvas and current line. Light syntax/comments range from **8.07–9.58:1** on the canvas and **7.38–8.75:1** on the current line. Main text is **13.72:1** on the canvas.

The checker now also compares colors in **Oklab**, rather than misusing luminance contrast as a hue metric. The closest pair among the six colored roles is now about **0.123** in that model, versus about **0.067** originally. Green strings vs violet types move from **0.067 to 0.342**. Its `0.10` minimum is a project-specific regression guard, not an accessibility standard or proof of personal performance. Normal-vision modeling cannot certify color-blind differentiation. Bold structure and diagnostic underlines supply extra cues.

### Font and size decision

Keep **JetBrainsMonoNL Nerd Font Mono Regular at 15 pt**, with genuine bold faces for emphasis and no programming ligatures. This is a deliberate practical choice, not a finding that any font is universally optimal. JetBrains documents its increased lowercase height and distinct symbol design. Changing to another fashionable family without a reported legibility issue would not establish an improvement.

Verified on the actual **1920×1200, scale-1** laptop display with a real Alacritty startup:

- Fontconfig resolves the requested regular and bold faces, without substituting BlexMono.
- Alacritty loads Regular, Bold, Italic and Bold Italic without font/config warnings.
- **15 pt renders as 20 px**, with **12×27 px terminal cells** at the current scale. These are measured rasterizer metrics, not a claim that the physical letters equal 15 printer points.
- The settings allow roughly 157 terminal columns by 42 rows in a full-width/maximized workspace after typical padding and panel space. Actual tiling and UI chrome reduce this.
- Doom uses regular weight explicitly and the corresponding 150 face height. Its GUI rendering has not been measured because no Emacs GUI is running. Terminal Neovim uses Alacritty's font/size, not a separate GUI font.

A larger size is appropriate if reading requires leaning forward or small punctuation is hard to distinguish. A full personal reading trial is still necessary to choose between 15 and 16 pt. No screen brightness, scale, proportional document font or physical display calibration was changed.

### Verification of this revision

```sh
python3 docs/check-display-palette.py
PYTHONDONTWRITEBYTECODE=1 python3 docs/test-study-theme.py
nvim --headless -u NONE '+luafile docs/test-study-syntax.lua'
nvim --headless '+luafile docs/test-study-syntax.lua'
emacs --batch -Q -l docs/test-doom-study.el
```

The checker now verifies JSON/native/Alacritty consistency, all 15 light colored-role pairs in Oklab, stronger selection/search surfaces and the existing text/background constraints. Neovim tests verify legacy, Tree-sitter and LSP highlight mappings, weights, diagnostics, selection/search, terminal entries and five day/night transitions. These verify highlight definitions, not every language server's custom semantic modifiers.

A separate actual-config Neovim process was kept running while `theme-colors study-day` refreshed the live desktop. Its existing parent-directory watcher changed function color from `#124B80` to `#0031A9` and applied keyword/function bold without restarting the process. The generated active palette matches the revision, the wallpaper is unchanged, the automatic timer remains active and Hyprland reports no configuration errors. No user editor buffers were closed. Doom loads configuration changes on next startup, or via a narrow reload after loading the new function definitions.

### Rendered outcome check, October 18 at 16:51 local time

Opened a disposable **real Alacritty + real-config Neovim** window at the configured 15 pt, with Python Tree-sitter highlighting a 19-line sample. Queried actual token captures, then captured the window's rendered pixels. Revised keyword, function, string, number, type and comment colors all appeared in the framebuffer, with respectively **1543, 1284, 1464, 168, 712 and 1571 exact-color pixels** in the 958×1168 window crop. Counts are observations from that frame, not stable benchmark assertions.

For a controlled visual comparison in the same disposable process, restaged the previous six syntax foregrounds and normal weights, then captured a second frame. This was a **restaged syntax-only baseline**, not an exact prior desktop snapshot. Visual inspection of both captures showed the intended improvement: blue bold callable names separate clearly from violet type annotations, raspberry bold control flow is prominent without bolding variables, and green string text no longer groups with teal type text. The sample's `Il1`, `O0`, braces, brackets and comparison operators are visibly distinct and unclipped at the current size. This is an assistant observation of the rendered result, not a user eyesight/readability-speed trial.

Artifacts were kept locally in Jcode scratch as `study-revised.png`, `study-prior-syntax.png` and `study-render.log`. The popup visible in both frames is Lazy's temporary configuration-reload notice inside the disposable test editor, not a font/rendering error. That test window was closed afterward without closing user apps or changing the active desktop palette. Auto mode still selected Study Day and Hyprland's error report remained empty.

The retained Neovim test now also parses a real Python buffer and asserts six actual token classifications and their role colors under the installed configuration. It explicitly skips that additional integration part under `-u NONE`, where configured parser/query runtime paths are absent. Both test modes pass. This closes the gap between inspecting highlight definitions and observing them on real code; it still does not certify every language server or determine a universally optimal font/size.

Primary design references:
- JetBrains Mono's type-design rationale: `https://www.jetbrains.com/lp/mono/`
- W3C text contrast guidance: `https://www.w3.org/WAI/WCAG22/Understanding/contrast-enhanced.html`
- Björn Ottosson's Oklab definition: `https://bottosson.github.io/posts/oklab/`
- Modus documentation on optional bold constructs: `https://protesilaos.com/emacs/modus-themes`

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

### Outcome follow-up, October 18 at 03:33 local time

The live generated terminal palette improves three measured contrast weaknesses versus the recorded pre-change colors: default text **11.26:1 → 12.49:1**, ANSI bright-black **1.38:1 → 8.23:1**, and ANSI red **3.22:1 → 8.91:1**. These comparisons use actual installed palette values, not just the proposal file. They establish improved text/background contrast, not proven personal comfort or reduced eyestrain.

To exercise automatic application rather than only manual switching, I deliberately selected Study Day while auto mode called for night, then invoked the actual systemd service. It selected Study Night, restored the desktop dark preference, and preserved the wallpaper. The service journal records `Applied study-night at 03:33` with success. Independent scheduled executions at 03:32 and 03:33 also completed successfully. This verifies the scheduler's executor and ongoing timer operation, without changing the system clock or claiming a tested overnight session.
