# A readable daily-study display setup for your Yoga

**Research baseline, October 18, 2026.** The initial report below preceded implementation. Following your request for automatic switching and a new font, `study-theme.md` documents the implemented day/night schedule and JetBrains Mono NL 15 pt configuration. Hardware and original configuration observations below describe the pre-change baseline.

**Historical baseline:** the palette and typography tables below describe the original proposal. The installed light syntax palette was revised later on October 18 for stronger hue separation and selective bold. Use `study-theme.md` and `display-palette-proposal.json` for current colors, verification and remaining limits.

## My recommendation in one sentence

Use a **high-contrast light palette for your main daytime homework/email/PDF workflow**, keep a **high-contrast dark alternative for a dimmer room or personal preference**, and retain your familiar **IBM Plex/BlexMono family at a comfortably large size**. Fix faint terminal colors before chasing a different font.

There is no scientifically established universally optimal theme, hex code, or programming font. The exact values below are **my engineered starting points**, not a clinically validated treatment. Evidence supports readable contrast and, in several proofreading experiments, dark text on a light background. Those experiments do not prove that every student will feel more comfortable in light mode all day. [S1–S4]

## What I checked on your actual laptop

- Lenovo **Yoga 7 2-in-1 14AKP10**, machine family **83JR**.
- Internal panel: **Samsung ATNA40CT03-0**, EDID native **1920×1200 at 60 Hz**, approximately **302×189 mm**, roughly **161 pixels/inch**. Hyprland scale is **1.0**.
- Lenovo lists both IPS and OLED WUXGA options for this model family. Your panel identity and wide-gamut EDID are consistent with the OLED variant, but I have not independently verified the exact panel technology with a manufacturer panel datasheet. I have not measured PWM/flicker or subpixel layout. Do not infer that a particular brightness percentage is flicker-free. [S5]
- Alacritty: **BlexMono Nerd Font Mono, 14.5 pt**, 14-pixel internal padding. Your default monospace resolves to BlexMono.
- Doom: actual configured font height is **144, or 14.4 pt**, despite stale comments mentioning 12.2 pt. Its theme is `doom-one`; it does not automatically match the terminal theme.
- IBM Plex Sans and STIX Two are available. A test request for JetBrainsMonoNL resolved to BlexMono through your font configuration, so merely naming another font would not guarantee it was used.
- Terminal background: **#1F1F28**. Default text: **#DCD7BA**. Screen brightness currently reports 140000/400000, a **35% control setting**, not a measured luminance or 35% of 400 nits.
- Your night-light file specifies **4000 K after 20:00**. That is configuration, not a measurement of current white balance.

Local evidence: `alacritty/alacritty.toml`, `fontconfig/fonts.conf`, `doom/config.el`, `hypr/monitors.lua`, `hypr/hyprsunset.conf`, the active generated Alacritty theme, `hyprctl`, Fontconfig and EDID.

## The most useful improvement to your current theme

Calculated sRGB contrast against your current terminal background:

| Current role | Foreground | Contrast |
|---|---|---:|
| Default text | #DCD7BA | **11.26:1** |
| Bright-black/dim gray | #363646 | **1.38:1** |
| Normal red | #C34043 | **3.22:1** |
| Normal green | #76946A | 4.84:1 |
| Normal cyan | #6A9589 | 4.88:1 |
| Normal blue | #7E9CD8 | 5.94:1 |

Your main text is already high-contrast. **Dim text and red terminal output are the weak spots**, when applications use those entries for informative text. This is not a finding that the theme damages your eyes. It also does not measure Doom's separate syntax palette.

W3C specifies **4.5:1 for ordinary text at AA** and **7:1 at AAA**, with exceptions such as sufficiently large text. I used 7:1 as a conservative design target for your small syntax tokens and comments, not as a medical threshold. Some people need or prefer different contrast. [S1, S2]

## Exact color combinations I recommend

### A. Study Light: my first choice for a lit room

Background **#F7F5F0**; main text **#24272E**. The off-white is a design preference, not protective filtering. Pure white is not inherently harmful, and brightness still needs adjustment.

### B. Study Dark: alternate for a dimmer room

Background **#1F2329**; main text **#E2E5E9**. This retains a dark workspace without relying on faint gray comments. It is not inherently healthier than light mode.

### Text and syntax

Numbers below are **my calculated ratios against each palette's main background**, rounded for display. Validation uses unrounded values.

| Role | Study Light | Contrast | Study Dark | Contrast |
|---|---|---:|---|---:|
| Main text, identifiers, operators, punctuation | **#24272E** | **13.72:1** | **#E2E5E9** | **12.49:1** |
| Comments, secondary text, line numbers | #454B54 | 8.07:1 | #B4BCC6 | 8.23:1 |
| Keywords: `if`, `for`, `function`, `end` | #6C2E91 | 7.91:1 | #D1B2FA | 8.61:1 |
| Functions, links, callable names | #124B80 | 8.22:1 | #9FC3FA | 8.76:1 |
| Strings and successful status text | #20532E | 8.24:1 | #A8C98B | 8.56:1 |
| Numbers, constants, warning text | #6E3B08 | 8.41:1 | #E9BD7A | 9.04:1 |
| Types, built-ins, special symbols | #005055 | 8.46:1 | #7AC9C2 | 8.24:1 |
| Errors and invalid syntax | #902030 | 7.91:1 | #FFADB0 | 8.91:1 |

Keep ordinary variables neutral. Use bold sparingly for keywords/headings, normal weight for most code, and avoid globally italic or extra-dim comments. Errors should also have a label, underline or icon; color should not be the only cue.

### Backgrounds and interaction states

| Element | Study Light | Study Dark |
|---|---|---|
| Main canvas, terminal, editor | **#F7F5F0** | **#1F2329** |
| Current line / secondary surface | #EDEBE5 | #292F38 |
| Selected-text background | #D6E4F2 | #35465C |
| Selected-text foreground | #24272E | #E2E5E9 |
| Search-match background | #F4D98A | #E9BD7A |
| Search-match foreground | #24272E | #1F2329 |
| Cursor | #24272E | #E2E5E9 |
| Text under a block cursor | #F7F5F0 | #1F2329 |
| Active window border, 1 px | #124B80 | #9FC3FA |
| Inactive window border, 1 px | #7C828C | #68717F |

All eight text roles also exceed **7:1 on the current-line background**. Selected/search text uses its explicitly specified foreground, not arbitrary syntax colors underneath a highlight. The four selection/search pairs exceed 7:1; the borders exceed 3:1 against the main canvas. These checks do **not** certify every tooltip, diff background, 256-color TUI, antialiased glyph or app state.

Keep opacity at **100%**, inactive text undimmed, zero external window gaps and your restored visible borders. Internal terminal padding is separate from wallpaper showing between windows.

### Terminal ANSI mapping

Map both normal and bright red/green/yellow/blue/magenta/cyan to the corresponding **errors/strings/numbers/functions/keywords/types** colors above. Using the same readable hue for both is deliberate; use font weight rather than making one unreadably dim.

| ANSI neutral entry | Study Light | Study Dark |
|---|---|---|
| Normal black | #24272E | #15181D |
| Bright black / readable gray | #454B54 | #B4BCC6 |
| Normal white | #454B54 | #E2E5E9 |
| Bright white | #24272E | #E2E5E9 |

Dark-mode normal black is a conventional **background/swatch color**, not readable text on the dark canvas. Light-mode white entries are deliberately remapped to dark text. Test your TUIs: programs that set their own backgrounds, use dim attributes, indexed colors beyond the first 16, or hard-code RGB can defeat an otherwise readable palette. Neovim/Doom/MATLAB syntax themes must be configured separately from terminal ANSI colors.

## Exact font and sizing starting points

These are practical starting settings for your measured panel and current setup, **not evidence that 15 pt beats every other size or that IBM Plex is medically superior**.

| Use | My starting setting |
|---|---|
| Alacritty / terminal code | **BlexMono Nerd Font Mono Regular, 15 pt**; your existing 14.5 pt is already reasonable |
| Terminal line spacing | Start with existing spacing; trial **2 additional pixels per row** only if lines feel crowded |
| Doom code | Keep actual **14.4 pt** initially; trial **3 px additional line spacing** independently |
| MATLAB Editor / Command Window | **IBM Plex Mono Regular, 15 pt**, if installed under that name; otherwise your verified BlexMono family |
| Org prose / email composition | **IBM Plex Sans Regular, 14 pt**, approximately **1.4 line height** where supported |
| Browser/email reading | Start at **110% zoom**; use **18–20 CSS px** body text where you control styles |
| General desktop labels | **IBM Plex Sans Regular, 12 pt** as a starting point, checked visually per toolkit |
| Homework typesetting | Keep **STIX Two Text + STIX Two Math**; preserve assignment-specified print sizes and enlarge the PDF viewer instead |
| Font weight | Regular for body/code, semibold or bold for emphasis; avoid light/thin as a default |
| Programming ligatures | **Off initially**, so operators match what you type and what coursework shows |
| Cursor | Trial a **steady beam or block** rather than your current 325 ms blink; this is a distraction preference |

Point sizes are not visually identical across applications. Your own Doom comments already document that problem. Match actual letter size and comfortable reading distance rather than forcing every settings field to the same number.

IBM Plex includes coordinated mono, sans and serif families. JetBrains Mono is a sensible alternative to compare for symbol recognition, not a proven eye-health upgrade. If you prefer it, first verify that Fontconfig really selects it instead of silently falling back to BlexMono. [S6, S7]

Keep native **1920×1200**. Start by enlarging text rather than lowering resolution. If menus remain too small, trial **125% desktop scale**, understanding that it reduces effective workspace to about **1536×960 logical pixels**. Do not simultaneously change scale, font family, font size and theme if you want to know which helped.

## How I would use this in your applications

- **Doom:** an existing theme family worth trying before maintaining custom faces is **Modus Operandi** for light and **Modus Vivendi** for dark. Its author explicitly targets 7:1 text contrast. The custom tables above are separate proposals, not the shipped Modus palettes. [S8]
- **Neovim/terminal:** align the light/dark background across editor, terminal, tmux and completion popups. Check comments, diffs and diagnostics, not just plain shell output.
- **MATLAB:** current releases expose Settings → MATLAB → Appearance → Colors, including text/background, syntax and output colors. Before R2025a, the path is MATLAB → Colors. Apply the roles the version exposes; not every token category in my table has its own MATLAB control. Keep homework figures/export previews on a light or white background with dark axes and check the exported PDF. Current MATLAB supports choosing a figure theme separately from the desktop theme. [S9]
- **Email/PDFs/problem sets:** I would favor the light setup in a lit room because much of this material is designed for a light page. Do not blanket-invert plots, scans, photographs or syntax screenshots. Use viewer zoom for small equations.

## What matters beyond the hex codes

Screen comfort is not only a theme problem. AAO guidance emphasizes breaks, blinking, glare reduction and appropriate brightness. Try the **20-20-20 rule**, keep the screen roughly an arm's length away, and avoid forcing yourself to read small text. Match screen brightness to the room rather than using an arbitrary fixed percentage. A palette cannot diagnose persistent pain, blur, headaches or dry-eye symptoms; get an eye-care assessment if those continue. [S4]

I cannot give you a defensible exact nit level from software alone. Your glossy-screen reflections and room lighting need to be considered. If a white document feels like a lamp, reduce display brightness or improve ambient lighting rather than automatically lowering text contrast.

Your 4000 K evening tint can remain a comfort preference, but disable it while judging palette hues or color-sensitive MATLAB plots. Blue-light filtering is not established protection against damage from ordinary computer-screen use; AAO notes that screen-emitted blue light has not been shown to damage eyes. [S4]

I have not measured your panel's flicker, calibrated its colors, determined your visual acuity, or tested the palettes over a full study day. The ratios here describe nominal sRGB colors, not physical display luminance, reflections or the effects of night-light processing.

## My order of changes

1. First fix the low-contrast terminal red and gray. Keep your current font family.
2. Trial Study Light in a normally lit room for a representative homework/email session, not only a five-minute screenshot comparison.
3. Compare Study Dark under comparable conditions if you prefer it. Record squinting, reading mistakes, urge to lean forward, and comfort, not just appearance.
4. Change font size or spacing one step at a time. Keep whichever lets you read equations, comments and small punctuation without effort.
5. Only after that consider changing font families. Your current BlexMono is not an obvious problem.

**My default pick for you:** Study Light + BlexMono Regular 15 pt for code, IBM Plex Sans for prose, and your existing STIX math workflow. Keep Study Dark one toggle away. No claim that one fixed theme is optimal in every room or for every pair of eyes.

## Sources and reproducibility

[S1] W3C, Understanding WCAG 2.2 SC 1.4.3, Contrast (Minimum): `https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html`

[S2] W3C, Understanding WCAG 2.2 SC 1.4.6, Contrast (Enhanced), including the relative-luminance contrast model and individual-needs caveats: `https://www.w3.org/WAI/WCAG22/Understanding/contrast-enhanced.html`

[S3] Buchner & Baumgartner (2007), *Text-background polarity affects performance irrespective of ambient illumination and colour contrast*, Ergonomics, DOI `10.1080/00140130701306413`. Piepenbrock, Mayr & Buchner (2014), *Positive display polarity is particularly advantageous for small character sizes: implications for display design*, Human Factors, PubMed `25141597`. Evidence here concerns task performance, not a universal cure for eye strain.

[S4] American Academy of Ophthalmology, *Computers, Digital Devices, and Eye Strain* and *Digital Devices and Your Eyes*: `https://aao.org/eye-health/tips-prevention/computer-usage` and `https://aao.org/eye-health/tips-prevention/blue-light-digital-eye-strain`. Relevant guidance was available in indexed AAO excerpts; direct fetching of some AAO pages returned access errors.

[S5] Lenovo PSREF, *Yoga 7 2-in-1 14AKP10*, display-options table: `https://psref.lenovo.com/syspool/Sys/PDF/Yoga/Yoga_7_2_in_1_14AKP10/Yoga_7_2_in_1_14AKP10_Spec.html`

[S6] IBM, *Plex*: `https://www.ibm.com/design/impact/plex/`

[S7] JetBrains, *JetBrains Mono*: `https://www.jetbrains.com/lp/mono/`

[S8] Protesilaos Stavrou, *Modus Themes* manual, accessible-readability overview: `https://protesilaos.com/emacs/modus-themes`

[S9] MathWorks, *Change Desktop Theme and Colors*: `https://www.mathworks.com/help/matlab/matlab_env/change-desktop-colors-and-select-dark-theme.html`

Exact values are in `docs/display-palette-proposal.json`. Reproduce the contrast checks from your dotfiles repository:

```sh
python3 docs/check-display-palette.py
```

Checks cover 32 primary/current-line text pairs at 7:1, four selected/search pairs at 7:1, and four border pairs at 3:1. Values and document were saved for review only. **No live theme, font, brightness, scale or night-light configuration was changed.**
