# Indoor embedded-workstation display profile

Current profile, October 18, 2026. Supersedes the original JetBrains Mono 15 pt choice in the historical study-theme audit.

## Typography and appearance

- Genuine **IBM Plex Mono Regular, 16 pt** in Kitty, Alacritty and Doom. Doom uses height 160 and big-font 18 pt. Proportional Plex Sans/Serif document faces remain 15 pt.
- Unpatched ASCII glyphs with separate Symbols Nerd Font Mono fallback for interface icons. Fontconfig resolves actual Regular/Bold/Italic/Bold Italic Plex files. Explicit requests for other font families remain respected.
- Kitty explicitly disables programming ligatures. Operators remain literal, without decorative cursor trails, transparency or blinking. Bold keywords and functions add structural cues without making all text heavy.
- Chosen for this user's clean, understated, technical, slightly old-terminal preference and embedded workflow. It is a practical trial setting, not a claim that a font or size is objectively best for every reader.
- Warm off-white Study Day and charcoal Study Night remain. Neither mode changes display brightness, scale, wallpaper or the existing night-light settings. Indoors does not establish a single correct brightness: match the display to the actual room, avoiding a glaring bright panel in a dim room.

## Stable syntax semantics

Both modes use pink/raspberry keywords, blue functions, violet types, green strings, amber numbers and red errors. The October 18 evening revision strengthens night syntax separation without changing the light palette or charcoal background. Comments remain upright and readable, keywords/functions bold, and errors retain diagnostic underlines.

Night now uses the same minimum pairwise Oklab distance guard (0.10) as day, instead of the former relaxed night-only 0.075 guard. This is a project-specific normal-color-vision regression check, not an accessibility standard or a guarantee of identical perceived contrast. The checker reports audited text against both canvas and current line, selected/search text and highlight visibility.

Both modes share genuine IBM Plex Mono Regular at 16 pt with actual Bold faces for structural emphasis. Typography tests and Kitty's actual font resolver verify that dark mode does not fall back to a thinner or smaller font. No blanket bolding, brightness, scale or font-family change is needed.

## System light/dark synchronization

`study-theme day`, `study-theme night`, and `study-theme auto` remain the controls. Auto uses 07:00 day / 20:00 night in local time. This is a schedule, not an ambient-light sensor. Final state was restored to auto.

Observed on the running desktop, without restarting the test terminal/editor:

- Day: Kitty and Neovim light palettes, GTK `prefer-light` / `Adwaita`, desktop portal appearance `2`.
- Night: Kitty and Neovim dark palettes, GTK `prefer-dark` / `Adwaita-dark`, desktop portal appearance `1`.
- Existing wallpaper remained unchanged and Hyprland reported no configuration errors.

Apps and websites with forced appearance settings need System/Automatic selected. This does not prove that every third-party toolkit or application follows the preference. Doom's batch face/font tests pass, but a live GUI Doom session was not available for visual verification.

## Kitty default and embedded connections

Kitty was already installed. The desktop terminal resolver now prefers `kitty.desktop`, retaining Alacritty as fallback. Open a new terminal to use it; existing terminals were not forcibly replaced. Bootstrap links only a missing Kitty config and preserves existing personal files or symlinks.

Render an image directly in Kitty with `kitten icat image.png`. A real PNG was rendered and visually checked, and Kitty's terminal query reported IBM Plex Mono at 16 pt. This does not make every application emit images; multiplexers and remote applications require compatible graphics handling. Global remote control remains disabled.

Kitty uses `xterm-kitty` terminfo. Minimal embedded SSH targets may lack it. Use `kitten ssh host` where supported, install the matching terminfo on the target, or use a connection-specific compatible TERM fallback when necessary. Do not globally misrepresent the terminal as another type. Serial-console applications and text-only targets remain text-only.

## Concrete verification

Real Kitty plus the installed Neovim configuration displayed a C firmware sample containing GPIO constants, uint32_t types, pointer casts, bit shifts, strings and functions in both modes. All six syntax role colors appeared in captured pixels. Exact counts from the first capture were night 4063/780/297/1458/1133/2873 and day 4016/771/288/1417/1089/2781 for keywords/functions/strings/numbers/types/comments respectively.

A second capture explicitly cleared the search register, confirmed Normal mode, and showed that the earlier gold space backgrounds were transient Search highlights rather than the theme. Literal `Il1 O0 {} [] () != <= >= -> & | ^ ~` were visible without clipping. Day and night were visually inspected, not just compared as config values. Transient Lazy config-change notifications appear during theme replacement; they are not syntax colors. Kitty also logged a nonfatal unsupported resize escape during Neovim startup; window rendering and subsequent live reloads worked, and arbitrary terminal resizing was not enabled to suppress it.

Local evidence, not committed binary fixtures:

- `~/.jcode/scratch/plex-kitty-day-clean.png`
- `~/.jcode/scratch/plex-kitty-night-clean.png`
- `~/.jcode/scratch/plex-kitty-inline-image.png`

Retained regression commands, from this repository:

```sh
python3 docs/check-display-palette.py
PYTHONDONTWRITEBYTECODE=1 python3 docs/test-study-theme.py
PYTHONDONTWRITEBYTECODE=1 python3 docs/test-study-typography.py
kitty +runpy 'import runpy; runpy.run_path("docs/test-kitty-study.py", run_name="__main__")'
nvim --headless -u NONE '+luafile docs/test-study-syntax.lua'
nvim --headless '+luafile docs/test-study-syntax.lua'
emacs --batch -Q -l docs/test-doom-study.el
bash -n bootstrap
```

The Kitty test runs inside Kitty's Python runtime intentionally. It exercises its real config parser and font selection API, palette parity, literal ligatures setting, default key mappings, safe bootstrap installation and desktop resolver/fallback behavior. Personal all-day comfort and reading performance still require use over time.
