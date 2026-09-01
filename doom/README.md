# Doom Emacs

Tracked Doom **user config** (`~/.config/doom` → this directory via
`./bootstrap`). The Doom framework itself lives at `~/.config/emacs` (cloned
by `./bootstrap`, updated with `doom upgrade`) and is not in this repo.

## Layout

| Path | Role |
|------|------|
| `init.el` | Enabled Doom modules (`doom!` block) |
| `config.el` | Personal settings (Org agenda, GCal hooks, Typst, …) |
| `org-pdf.el` | Org → PDF export classes (`spec`, `essay`) |
| `packages.el` | Extra packages (`org-gcal`, `ox-typst`, …) |
| `org-gcal-secrets.el.example` | Template for local OAuth + calendar IDs |
| `private/` | **Gitignored** — real secrets (never commit) |

```sh
mkdir -p doom/private
cp doom/org-gcal-secrets.el.example doom/private/org-gcal-secrets.el
# edit private/org-gcal-secrets.el with your Google OAuth + calendar IDs
```

After pulling: `./bootstrap` (links), then `doom sync` if `init.el` /
`packages.el` changed. Restart Emacs.

OS packages this setup expects: `emacs-wayland`, `aspell`, `aspell-en`,
`clang` (clangd + clang-format), `libvterm`, `cmake` (vterm build), `typst`,
`ripgrep`, `fd`, `shfmt`, `shellcheck`, `discount` (`markdown` for preview),
`ttf-nerd-fonts-symbols-mono`, and AUR `ttf-symbola` (Emacs fallback font).

For LaTeX PDF export (see [Org → PDF](#org--pdf-latex)):

```text
texlive-basic texlive-latex texlive-latexrecommended texlive-latexextra
texlive-fontsrecommended texlive-xetex texlive-binextra texlive-plaingeneric
ttf-ibm-plex
```

## Enabled modules (beyond Doom defaults)

- `(lsp +eglot)`, `(cc +lsp +tree-sitter)`, `tree-sitter`
- `(format +onsave)`, `(spell +aspell)`, `pdf`, `vterm`

## Org + Google Calendar

Org files live in `~/org/` (not in this repo). Captures route to Personal /
Arbor / School calendars; Canvas is pull-only. OAuth client ID/secret and
calendar IDs stay in `private/org-gcal-secrets.el`.

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

## Org → PDF (LaTeX)

Turns Org notes into clean, shareable PDFs — technical write-ups and essays,
not academic papers. Defined in `org-pdf.el`, loaded from the top of
`config.el`. Rendering is XeLaTeX + IBM Plex.

Nothing special is needed in the document: write normal Org and export.

| Key | Action |
|-----|--------|
| `SPC m E` | Export to PDF and open it in the system viewer |
| `SPC m e l o` | Doom's standard export dispatch → LaTeX → PDF and open |
| `SPC m e l l` | Export to `.tex` only (useful when debugging a build) |

### The two classes

| Class | For | Look |
|-------|-----|------|
| `spec` *(default)* | write-ups, documentation, notes | IBM Plex **Sans**, unindented paragraphs with space between them, ruled section headings |
| `essay` | essays, long-form prose | IBM Plex **Serif**, indented paragraphs, narrower measure |

Switch a document to prose style with a keyword at the top:

```org
#+TITLE: Buck Converter Evaluation
#+SUBTITLE: Bench measurements and design rationale
#+AUTHOR: Luciano
#+DATE: August 2026
#+LATEX_CLASS: essay
```

`TITLE` / `SUBTITLE` / `AUTHOR` / `DATE` feed the title block. `TITLE` and
`DATE` also become the running header on every page; the footer carries
`page N / M`.

Both classes share: accent rule above the title, `booktabs` tables (no
vertical rules), framed and syntax-highlighted source blocks, muted blue
links, and headings that will not strand themselves at the foot of a page.

Defaults worth knowing:

- **No table of contents.** Add `#+OPTIONS: toc:t` for one.
- **Sections are numbered.** Turn it off with `#+OPTIONS: num:nil`.
- **Code has no line numbers** unless you ask: `#+BEGIN_SRC python -n`.

### Caveat: Typst math does not survive this path

The LaTeX classes and the [Typst math](#org--typst-math) setup above are two
separate PDF pipelines, and they do not mix:

- Typst **display** math (`$ sum_(k=1)^n k $`) exports as *literal text* — no
  error, no warning, just wrong output in the PDF.
- Typst **inline** math only survives when it happens to also be valid LaTeX
  (`$a^2 + b^2 = c^2$` is fine; `$sum_(k=1)^n$` is not).

So use the **Typst backend (`C-c C-e y`) for math-heavy notes**, and the
`spec` / `essay` classes for prose, tables, and code. If you want real math in
a `spec` document, write LaTeX (`\(...\)` and `\[...\]`) rather than Typst.

### Modifying the template

Everything lives in **`doom/org-pdf.el`**, split so the common styling is
written once:

| Variable in `org-pdf.el` | Controls |
|--------------------------|----------|
| `luciano/latex-preamble-common` | Everything both classes share — fonts, colours, headings, header/footer, title block, tables, lists, code blocks |
| `luciano/latex-class-spec` | Only what makes `spec` different: 10pt, sans body, margins, paragraph spacing |
| `luciano/latex-class-essay` | Only what makes `essay` different: 11pt, serif body, wider margins, indents |

The preamble is a list of LaTeX lines as Emacs strings, so **every backslash
is doubled** — `\section` is written `"\\section"`.

Common edits:

- **Accent colour** — `\definecolor{accent}` near the top of the common
  preamble. `ink`, `muted`, `rulegray`, and `codebg` are beside it.
- **Fonts** — the `\setsansfont` / `\setmainfont` / `\setmonofont` block.
  Fonts are loaded *by filename* from `/usr/share/fonts/TTF/`, not by family
  name, because fontconfig on Arch abbreviates Plex's style names to `SmBld`,
  which fontspec cannot resolve. If you swap in another family, keep that
  pattern and check the real filenames with `fc-list | grep -i <family>`.
- **Heading size / colour** — the `\titleformat{\section}` group.
- **Title block** — the `\renewcommand{\maketitle}` group.
- **Header and footer** — the `\fancyhead` / `\fancyfoot` group.
- **Margins and leading** — in each class rather than the common preamble.

To add a third class, define another string and add it to the `dolist` near
the bottom that registers entries in `org-latex-classes`.

Changes take effect on **restart** (`org-pdf.el` is plain config, so no
`doom sync` is needed). To iterate faster, export with `SPC m e l l` to get
the `.tex`, then run `latexmk -pdfxe file.tex` in a terminal and read the
errors directly.

## Useful commands

```sh
doom sync          # after init.el / packages.el changes
doom sync --env    # refresh PATH env for GUI Emacs (needs typst on PATH)
doom upgrade       # update Doom + packages
doom doctor        # diagnose setup issues
```
