# Doom Emacs

Tracked Doom **user config** (`~/.config/doom` → this directory). The Doom
framework itself lives at `~/.config/emacs` (cloned by `./bootstrap`, updated
with `doom upgrade`) and is not in this repo.

## Layout

| Path | Role |
|------|------|
| `init.el` | Enabled Doom modules (`doom!` block) |
| `config.el` | Personal settings (Org + Typst math, etc.) |
| `packages.el` | Extra packages (`ox-typst`, `typst-overlay`, `typst-ts-mode`) |

After pulling: `./bootstrap` (links), then `doom sync` if `init.el` /
`packages.el` changed. Restart Emacs.

OS packages this setup expects: `emacs-wayland`, `aspell`, `aspell-en`,
`clang` (clangd + clang-format), `libvterm`, `cmake` (vterm build), `typst`,
`ripgrep`, `fd`, `shfmt`, `shellcheck`, `discount` (`markdown` for preview),
`ttf-nerd-fonts-symbols-mono`, and AUR `ttf-symbola` (Emacs fallback font).

## Enabled modules (beyond Doom defaults)

- `(lsp +eglot)`, `(cc +lsp +tree-sitter)`, `tree-sitter`
- `(format +onsave)`, `(spell +aspell)`, `pdf`, `vterm`

## Org + Typst math

Write **Typst** inside `$...$` (not LaTeX). Previews via `typst-overlay`;
export via `ox-typst`.

```org
Inline: $a^2 + b^2 = c^2$

Display:
$
sum_(k=1)^n k = (n(n+1))/2
$
```

- Preview: automatic in Org; refresh with save or `M-x typst-overlay-refresh`
- Export PDF: `C-c C-e y` (Typst backend)
- Figures / Xournal++ PNGs: `M-x org-attach` or `[[file:sketch.png]]`
- Smoke test: `~/org/typst-math-smoke.org`

Do not use Org’s LaTeX fragment preview (`C-c C-x C-l`) for these buffers —
it conflicts with Typst math.

## Useful commands

```sh
doom sync          # after init.el / packages.el changes
doom sync --env    # refresh PATH env for GUI Emacs (needs typst on PATH)
doom upgrade       # update Doom + packages
doom doctor        # diagnose setup issues
```
