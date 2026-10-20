# Org writing with native Typst math

`bin/org-pdf` exports Org prose with Pandoc, preserving **native Typst** math,
then compiles a PDF with `/usr/bin/typst`. It does not use Emacs, ox-typst,
LaTeX, or a TeX installation. Org source blocks are never evaluated.

## Dependencies

- Python 3 (standard library only)
- Pandoc with the Typst writer and Lua filters (`pandoc-cli` on Arch)
- Typst at `/usr/bin/typst` (`typst` on Arch)
- New Computer Modern fonts, including its math font, and DejaVu Sans Mono.
  Check `/usr/bin/typst fonts`; Typst can fall back if a requested font is absent.
- `xdg-open`, only for `--open`
- `pdftotext` (`poppler`), only for the PDF text integration tests

Validated locally with Pandoc 3.12.1 and Typst 0.15.1. No additional Lua
interpreter, Python packages, fzf, Neovim, or PDF viewer is needed to export.
The existing `bin/typst` interactive picker wraps the compiler on PATH. The
exporter deliberately bypasses that picker and calls `/usr/bin/typst` directly.

## Minimal workflow

Try the complete essay in `typst/org/example.org`, which includes metadata,
introductory prose, lists, a quotation, and inline/display native Typst math:

```sh
org-pdf typst/org/example.org --open
```

```sh
org-pdf 'My homework.org'
org-pdf 'My homework.org' --template report --open
org-pdf 'My homework.org' --output '/path with spaces/submission.pdf'
org-pdf --list-templates
```

Without `--output`, the result is a sibling PDF. Existing PDFs are replaced
**only after a successful compile**, using a temporary file on the destination
filesystem and atomic rename. Errors leave the previous PDF intact. The output
directory must already exist. An opener failure is reported after saving the PDF.

Template precedence: `--template NAME`, then `#+PDF_TEMPLATE: NAME`, then `essay`.
Builtins are:

| Name | Style |
| --- | --- |
| `essay` | MLA-like, US Letter, 1-inch margins, 12pt serif, Muschamp page header, author/course block |
| `report` | 11pt serif, numbered headings, title/author/date, page numbers |
| `notes` | Compact 10pt serif, unnumbered headings, narrow margins |

The essay style adapts the existing `typst/templates/write_up.typ`. Its fallback
author is Damian Luciano Muschamp and its running surname is Muschamp. It is
MLA-like, not a claim of exact compliance with every instructor's requirements.
Use explicit `#+AUTHOR:` and `#+DATE:` for stable exported metadata.

```org
#+TITLE: Summation homework
#+AUTHOR: Damian Luciano Muschamp
#+DATE: October 19, 2026
#+INSTRUCTOR: Professor Example
#+COURSE: Algebra 101
#+PDF_TEMPLATE: essay
#+OPTIONS: toc:nil

* Working
Inline native math: $sqrt(2)$ and $sum_(k=1)^n k$.

$ sum_(k=1)^n k = (n(n+1))/2 $

$
mat(1, 2; 3, 4)
$

An image: [[file:my figure.svg]]
```

`TITLE`, `AUTHOR`, and `DATE` use Pandoc's Org metadata reader. `INSTRUCTOR` and
`COURSE` are passed to the template by the CLI. The Org file is not modified.
Put `PDF_TEMPLATE`, `INSTRUCTOR`, and `COURSE` in the document header before the
first heading. The CLI ignores copies inside blocks or under headings, so
examples and quoted source cannot override the document's export settings.
Run from any directory: relative figures and Typst paths resolve within the Org
file's directory, which is also the Typst project root. Put required assets
under that directory. Parent-directory paths outside that root are rejected by
Typst. Org attachments requiring Emacs ID resolution are not automatically
resolved; use ordinary `file:` links to concrete exported images.

## Native math and parsing boundaries

Pandoc normally assumes that Org math is **LaTeX**, and its Typst writer converts
it through texmath. `typst/org/native-math.lua` instead converts every Math node
to raw Typst, preserving its contents. Write Typst consistently in these files.
LaTeX commands such as `\\frac` are not converted by this workflow.

There is a separate Org reader issue: `$ x $` is Typst display math but **not**
an Org math fragment. Before invoking Pandoc, the CLI normalizes standalone
spaced-dollar equations to Org `$$ ... $$` math. It supports both a single-line
`$ expression $` and multi-line equations with a single `$` opening/closing line.
Raw export block contents remain untouched. Source and example block bodies
are likewise protected from math/backtick conversion, with only their opening
headers adjusted to retain indentation. Inline math has no spaces at its
delimiters: `$sqrt(2)$`.

Do not put `$ x $` midway through a prose paragraph and expect automatic display
recognition. Use a standalone equation with blank lines around it, Org `$$`
delimiters, or explicit raw Typst:

```org
Inline raw: @@typst:$sqrt(2)$@@.

#+begin_export typst
$ sum_(k=1)^n k = (n(n+1))/2 $
#+end_export
```

Raw blocks are also the dependable escape hatch for unusual equations and Typst
layout. `#+begin_src typst` is a **code listing**, not an equation to execute.
The preprocessor is intentionally conservative, not a replacement Org parser.
Use raw export blocks for equations embedded in complex lists or literal text
containing dollar signs. Typst-specific raw content will not survive unrelated
output formats such as DOCX or HTML without a separate conversion policy.

## Code snippets, indentation, and native Typst layout

The full copyable example is `org/code-and-math.org`. Export it with:

```sh
org-pdf ~/dotfiles/typst/org/code-and-math.org --output ~/code-and-math.pdf
```

Use single backticks for Typst-style inline code, for example
`` `array[index]` ``. These are single-line literals with no padding at the
ends and spaces/punctuation around them. Org-native `=array[index]=` and
`~array[index]~` remain supported. For language-highlighted inline snippets,
Org also supports `src_python{print(42)}`. Do not use Markdown fenced blocks
in an Org document. Use Org source blocks:

```org
#+begin_src matlab :exports code :eval never
for k = 1:3
    fprintf('value: %g\n', k);
end
#+end_src
```

Language tags include `matlab`, `c` / `C`, `cpp` / `C++`, `python`,
`javascript` / `js`, `typescript` / `ts`, `bash` / `sh`, `lua`, and `rust`.
The exporter normalizes aliases and uses Typst's native code highlighter,
without requiring a package download or running the code. Unknown language
names fall back to a plain listing. `typst` listings are printed as code,
not evaluated as document layout.

The export preprocessor preserves source and example block indentation,
including a shared leading margin that Pandoc's Org reader normally removes.
It does this in the temporary conversion input only, by adding the Org `-i`
switch. Tabs in exported code use four-column stops. Source bodies are not
rewritten, evaluated, or modified on disk. Use `#+begin_example` /
`#+end_example` when aligned literal text needs no highlighting. Ordinary
paragraphs follow the selected template's paragraph spacing and indentation,
not arbitrary spaces typed into prose. Keep code lines reasonably short to
fit the page width.

Org headings, lists, emphasis, and tables remain Org syntax. Typst-only
formatting such as `#align`, `#box`, `#grid`, or show/set rules belongs inside
`#+begin_export typst` / `#+end_export` or an inline `@@typst:...@@` export
snippet. Merely typing arbitrary Typst markup in an Org paragraph does not
make it native Typst input. Single-backtick compatibility and standalone math
normalization apply to this exporter, not every Org renderer.

## Custom templates

```sh
org-pdf --import-template '/path with spaces/my-style.typ' --name my-style
org-pdf homework.org --template my-style
```

Imports copy the file to `~/.config/org-writing/templates/NAME.typ`, respecting
`$XDG_CONFIG_HOME` if set. Neither existing imports nor builtin names are
overwritten. Names accept letters, digits, hyphens and underscores, starting
with a letter or digit. A custom template must be a **Pandoc Typst template**
containing `$body$`. This check is a basic format guard, not a full validator.
Start from `typst/org/templates/notes.typ` or inspect `pandoc -D typst`.

A standalone Typst document, a Typst Universe package identifier, and the old
`{{TITLE}}` creation template are not Pandoc templates. Pandoc templates use
`$title$`, `$body$`, `$if(...)$`, and related directives. Literal dollar signs in
custom template source must use Pandoc's `$$` escape. An import copies only the
`.typ` file, not an asset tree. Relative includes refer to the Org project, not
the original imported template directory.

Only import templates and process documents you trust. Raw Typst can read files
within its project root, and referenced Typst packages may require a network
fetch/cache. Pandoc Org includes can read other files. This is not a sandbox,
even though Org Babel/source blocks and shell snippets are never executed.
No document-supplied shell command or arbitrary Pandoc filter is invoked.

## Relationship to Doom and existing Typst picker

`doom/config.el` already selects `org-typst-from-latex-with-naive` for ox-typst
and previews dollar-delimited math using a custom regex. A preview succeeding
does not prove Org recognized an equation during export: the local ox-typst
smoke test preserved `$sum_(k=1)^n k$` but exported `$ sum_(k=1)^n k $` as escaped
prose. This CLI addresses that standalone display-math gap without changing Doom.
Doom's separate `org-pdf.el` export classes use XeLaTeX, not these templates.

`bin/typst` and `typst/templates/write_up.typ` remain the separate interactive
native `.typ` creation/edit/watch workflow. The CLI does not launch a watcher,
change that template, or alter its viewer lifecycle.

## Verification

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_org_*py' -v
```

Tests compile real PDFs with all three builtins and an imported template, extract
PDF text, verify native inline/display/matrix math, metadata, lists/tables/rules,
relative images and paths containing spaces, assert no source-block evaluation,
check non-overwriting imports, check opener argv without opening the desktop,
and verify readable failures and preservation of an existing PDF after a failed
compile. Real conversion tests skip when the required binaries are absent.

## Primary references

- Pandoc User's Guide, Typst writer, PDF engine and templates: `https://pandoc.org/MANUAL.html`
- Pandoc Org reader features and differences: `https://pandoc.org/org.html`
- Pandoc Typst writer source (Math conversion and raw passthrough): `https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Writers/Typst.hs`
- Typst equation syntax, including whitespace display rules: `https://typst.app/docs/reference/math/equation/`
- ox-typst native versus LaTeX math settings: `https://github.com/jmpunkt/ox-typst`
